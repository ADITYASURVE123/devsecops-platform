"""Tiny FastAPI service. The platform is the project, so the app stays trivial."""
import os
import random
import time

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

SERVICE = os.getenv("SERVICE_NAME", "orders-api")
# Fault injection, used only for the deliberate "bad release" demo.
ERROR_RATE = float(os.getenv("ERROR_RATE", "0"))
LATENCY_MS = int(os.getenv("LATENCY_MS", "0"))

DATA = {1: {"id": 1, "name": "sample-1"}, 2: {"id": 2, "name": "sample-2"}}

app = FastAPI(title=SERVICE)
REQS = Counter("http_requests_total", "HTTP requests", ["service", "method", "path", "status"])
LAT = Histogram(
    "http_request_duration_seconds",
    "Request latency in seconds",
    ["service", "path"],
    buckets=(0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5),
)


@app.middleware("http")
async def observe(request: Request, call_next):
    start = time.perf_counter()
    status = 500
    try:
        response = await call_next(request)
        status = response.status_code
        return response
    finally:
        route = request.scope.get("route")
        path = route.path if route else "unmatched"  # avoids label-cardinality explosion
        if path != "/metrics":
            REQS.labels(SERVICE, request.method, path, str(status)).inc()
            LAT.labels(SERVICE, path).observe(time.perf_counter() - start)


def _inject_faults() -> None:
    if LATENCY_MS:
        time.sleep(LATENCY_MS / 1000)
    if ERROR_RATE and random.random() < ERROR_RATE:
        raise HTTPException(status_code=500, detail="injected fault")


@app.get("/health")
def health():
    return {"status": "ok", "service": SERVICE}


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/orders")
def list_items():
    _inject_faults()
    return list(DATA.values())


@app.get("/orders/{item_id}")
def get_item(item_id: int):
    _inject_faults()
    if item_id not in DATA:
        raise HTTPException(status_code=404, detail="not found")
    return DATA[item_id]
