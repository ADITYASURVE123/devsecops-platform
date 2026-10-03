from fastapi.testclient import TestClient

import app.main as m

client = TestClient(m.app)


def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_list_and_get():
    assert len(client.get("/items").json()) == 2
    assert client.get("/items/1").json()["id"] == 1


def test_not_found():
    assert client.get("/items/999").status_code == 404


def test_metrics_exposed():
    client.get("/items")
    body = client.get("/metrics").text
    assert "http_requests_total" in body
    assert "http_request_duration_seconds_bucket" in body


def test_fault_injection(monkeypatch):
    monkeypatch.setattr(m, "ERROR_RATE", 1.0)
    assert client.get("/items").status_code == 500
    monkeypatch.setattr(m, "ERROR_RATE", 0.0)
    assert client.get("/items").status_code == 200


def test_latency_injection(monkeypatch):
    slept = []
    monkeypatch.setattr(m.time, "sleep", lambda s: slept.append(s))
    monkeypatch.setattr(m, "LATENCY_MS", 200)
    client.get("/items")
    assert slept == [0.2]
