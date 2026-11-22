# Design decisions

Each entry: what was chosen, why, and the trade-off accepted.

## 1. Plain Terraform environments instead of Terragrunt
Shared logic lives in `modules/platform`; `envs/dev` and `envs/prod` are thin callers.
**Why:** fewer moving parts while learning a new cloud, and the same DRY result.
**Trade-off:** each environment repeats its provider and backend block. Terragrunt would remove that.

## 2. GitHub OIDC federation, no stored credentials
An Entra app registration trusts specific GitHub subjects: pull requests, the `main` branch, and the `dev` and `prod` environments.
**Why:** no client secret to leak or rotate, and tokens are short-lived.
**Trade-off:** one-time bootstrap, and every new trigger type needs its own federated credential.

## 3. Remote state in Blob Storage with Entra authentication
State is stored with versioning enabled and accessed with Entra identity rather than account keys. Blob leases provide state locking.
**Why:** no shared keys in CI, and versioning allows recovery from a bad state write.
**Trade-off:** the pipeline identity needs a data-plane role on the storage account.

## 4. Terraform runs only from the pipeline
**Why:** Terraform grants some data-plane roles (Key Vault, ACR push) to whichever identity runs it. A single applying identity keeps those assignments consistent.
**Trade-off:** local `apply` is not supported. Local `plan` and `validate` are fine.

## 5. AKS Free tier, Azure CNI Overlay, user-assigned control plane identity
**Why:** Free tier has no control plane fee. Overlay conserves VNet IP space. A user-assigned identity can be given subnet permissions before the cluster is created, which avoids a chicken-and-egg ordering problem.
**Trade-off:** no uptime SLA on Free. Prod uses the Standard tier.

## 6. Workload Identity and Key Vault CSI driver for secrets
The pod's service account is federated with a managed identity that has `Key Vault Secrets User` on one vault.
**Why:** the application never holds a credential, and access is auditable and revocable per identity.
**Trade-off:** more moving parts than a Kubernetes Secret. Terraform state also contains the demo secret value, so state access must be restricted.

## 7. ArgoCD app-of-apps, image tag committed back to Git
CI builds and pushes the image, then commits the tag to the environment values file. ArgoCD reconciles from Git.
**Why:** Git is the single source of truth, rollbacks are `git revert`, and CI never needs cluster credentials.
**Trade-off:** CI needs permission to push to `main`. Branch protection would need a bypass or a PR-based tag update.

## 8. No ingress, no public IP
Services are `ClusterIP` and reached with `kubectl port-forward`.
**Why:** saves cost and avoids exposing a lab cluster.
**Trade-off:** not a complete production edge. Ingress and TLS are listed as next steps.

## 9. Two monitoring layers
Container Insights covers platform health; Prometheus and Grafana cover application metrics and alert rules in-cluster.
**Why:** mirrors a common real-world split, and shows both Azure-native and open-source tooling.
**Trade-off:** more resource use. Retention is short, Alertmanager is off and storage is ephemeral to fit two small nodes.

## 10. Azure Policy: allowed locations
**Why:** a simple, verifiable guardrail that is cheap to demonstrate.
**Trade-off:** one policy is a sample, not a governance programme.

## 11. Broad roles for the pipeline identity
Contributor, User Access Administrator and Resource Policy Contributor at subscription scope.
**Why:** Terraform creates resource groups, role assignments and policy assignments.
**Trade-off:** over-privileged for anything but a single-subscription lab. In an organisation, scope to resource groups and use a custom role or conditions.

## 12. Prod is plan-only
**Why:** protects trial credit while still proving the multi-environment structure and approval gate.
**Trade-off:** prod behaviour is not exercised. Treat prod settings as unverified.

## 13. Trivy gate on fixable CRITICAL findings only
**Why:** a strict gate on HIGH findings tends to fail on base-image noise outside the team's control.
**Trade-off:** HIGH findings are not blocked. Tighten the gate once the baseline is clean.
