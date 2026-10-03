# Cost notes (verify current prices in the AWS pricing pages)

| Item | Rough cost | Control |
|---|---|---|
| EKS control plane | ~$0.10/h (not free tier) | `make eks-down` after each session |
| NAT gateway (single) | ~$0.045/h + data | destroyed with the stack |
| 2x t3.medium SPOT nodes | a few cents/h | destroyed with the stack |
| Jenkins t3.small | ~$0.02/h | `make jenkins-stop` when idle (EBS still billed) |
| ECR, S3 state | pennies | lifecycle policy keeps 10 images |

Rules of thumb: a 3-hour demo session costs roughly a few dollars. Leaving EKS up for a month costs ~$100+. Set the AWS budget alert (`budget_usd`, default 10) before the first apply and check Cost Explorer after every session.

If you only have credits/free tier: do Phases 1, 3 (locally), 4-8 entirely on kind, and use EKS once for the recording.
