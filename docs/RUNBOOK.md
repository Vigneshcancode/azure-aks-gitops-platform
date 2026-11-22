# Runbook: implement, test and tear down

Follow the steps in order. Total time: about 90 minutes for the first run, most of it waiting for Azure.

**Where to run things**
- Steps 1 to 4 need `az`, `git` and (optionally) `gh`. Azure Cloud Shell (Bash) works.
- Steps 5 onward need `kubectl`. To open the ArgoCD, Grafana and Prometheus web UIs you need a machine where `kubectl port-forward` can open a browser, such as your laptop (`az login`, then `az aks install-cli`). Azure Cloud Shell has no browser preview for forwarded ports; use it only for `curl` based checks.

## Step 0: Check region and quota

The dev cluster needs 2 nodes of `Standard_B2s` (4 vCPUs in total).

```bash
az account show -o table
az vm list-skus --location centralindia --size Standard_B2s \
  --query "[].{name:name, restrictions:restrictions[].reasonCode}" -o json
az vm list-usage --location centralindia -o table | grep -iE "Total Regional vCPUs|Standard BS"
```

If the SKU is restricted or you have fewer than 4 free vCPUs, change `location` and `node_vm_size` in `terraform/envs/dev/main.tf` (for example `Standard_D2as_v5`) and set `LOCATION` when you run the bootstrap script.

## Step 1: Create the repository

1. On GitHub, create an **empty public** repository named `azure-aks-gitops-platform` (no README, no .gitignore). Public keeps ArgoCD simple because it needs no repository credentials.
2. Put the project files in a local folder and initialise git:

```bash
cd azure-aks-gitops-platform
git init -b main
git remote add origin https://github.com/<your-user>/azure-aks-gitops-platform.git
git config user.name "<your name>"
git config user.email "<your email>"
```

Authenticate git with `gh auth login` or a personal access token. Do not put the token in the remote URL.

## Step 2: Bootstrap Azure and GitHub trust (one time)

```bash
export GITHUB_REPO=<your-user>/azure-aks-gitops-platform
./bootstrap/bootstrap.sh
```

This registers resource providers, creates the Terraform state storage account, creates an Entra app registration trusted by your repository through OIDC, assigns its roles, and writes five repository variables (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `TFSTATE_RG`, `TFSTATE_SA`). If `gh` is not available the script prints them; add them under *Settings > Secrets and variables > Actions > Variables*.

Optional:
- Add an `ALERT_EMAIL` variable to receive Azure Monitor alert emails.
- Create the `prod` environment under *Settings > Environments* and add yourself as a required reviewer.

If the script fails creating the app registration, your account lacks permission to create applications in the Entra tenant. Use the tenant that came with the trial, where you are Global Administrator.

## Step 3: Push the infrastructure and let the pipeline build dev

Push only the infrastructure part first. The application is not deployable until the registry exists.

```bash
git add .github bootstrap terraform scripts docs README.md .gitignore
git commit -m "feat: terraform platform, bootstrap and workflows"
git push -u origin main
```

Open the **Actions** tab. `terraform-apply` runs for dev and takes 10 to 15 minutes. When it finishes, check:

```bash
az resource list -g rg-aksgitops-dev -o table
az aks show -g rg-aksgitops-dev -n aks-aksgitops-dev \
  --query "{state:provisioningState, oidc:oidcIssuerProfile.enabled, workloadIdentity:securityProfile.workloadIdentity.enabled}" -o json
```

Expected: the cluster is `Succeeded` with OIDC and workload identity enabled.

If the run fails, read the error, fix the code, and push again or use *Actions > terraform-apply > Run workflow*. Terraform resumes from the state. Common causes are in the troubleshooting table at the end.

## Step 4: Configure and ship the application

```bash
export GITHUB_REPO=<your-user>/azure-aks-gitops-platform
./scripts/configure.sh dev
git add apps helm gitops
git commit -m "feat: hello-api, helm chart and gitops config"
git push
```

`configure.sh` reads the registry, Key Vault and identity from Azure, writes `helm/hello-api/values-dev.yaml`, and points the ArgoCD manifests at your repository.

The push runs `app-ci`: tests, image build, Trivy scan, push to ACR, then a bot commit that sets the image tag in `values-dev.yaml`. Check:

```bash
ACR=$(az acr list -g rg-aksgitops-dev --query "[0].name" -o tsv)
az acr repository show-tags -n "$ACR" --repository hello-api -o table
git pull --rebase origin main    # bring the bot commit into your clone
grep "tag:" helm/hello-api/values-dev.yaml
```

## Step 5: Install ArgoCD (the last manual step)

```bash
./scripts/bootstrap-argocd.sh dev
```

The script installs ArgoCD, applies the `root` application and prints the admin password. From here ArgoCD installs Prometheus and Grafana first, then `hello-api`. Allow 5 to 10 minutes.

```bash
kubectl get applications -n argocd -w
kubectl get pods -A
```

Expected: `root`, `kube-prometheus-stack` and `hello-api` all `Synced` and `Healthy`.

## Step 6: Smoke test

```bash
./scripts/smoke-test.sh
```

Expected: seven `PASS` lines and `passed=7 failed=0`.

## Step 7: Open the UIs (needs a browser on your machine)

```bash
# ArgoCD            https://localhost:8080   user: admin
kubectl -n argocd port-forward svc/argocd-server 8080:443

# Grafana           http://localhost:3000    user: admin
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo

# Prometheus        http://localhost:9090
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090

# The API           http://localhost:8081
kubectl -n hello-api port-forward svc/hello-api 8081:80
curl localhost:8081/
curl localhost:8081/secret-check
```

Take your first screenshots now (ArgoCD synced, Grafana dashboard).

## Step 8: Test the flows

Run these in order and capture a screenshot for each one that matters.

### T1. Pull request plan automation
```bash
git checkout -b test/add-owner-tag
# edit terraform/modules/platform/main.tf: add  owner = "your-name"  inside locals.tags
git commit -am "chore: add owner tag" && git push -u origin test/add-owner-tag
```
Open a pull request. **Expected:** `terraform-plan` runs for dev and prod and posts two plan comments. Dev shows in-place updates; prod shows a full create plan because it is not deployed. Merge it: `terraform-apply` updates dev.

### T2. Full GitOps path (the main demo)
```bash
git checkout main && git pull
git checkout -b test/change-message
# edit apps/hello-api/app/main.py: change the message to "Hello from AKS v2"
git commit -am "feat: change message" && git push -u origin test/change-message
```
Open a pull request. **Expected:** `app-ci` runs tests, builds and scans; it does not push. Merge it. **Expected:** `app-ci` pushes the image and commits a new tag; ArgoCD rolls out within a few minutes.
```bash
git checkout main && git pull
kubectl -n hello-api rollout status deploy/hello-api
curl localhost:8081/        # restart the port-forward first; the message and version have changed
```

### T3. Self-heal
```bash
kubectl -n hello-api scale deploy/hello-api --replicas=5
kubectl -n hello-api get deploy hello-api -w
```
**Expected:** ArgoCD reverts the replica count to 2 without any action from you.

### T4. Prometheus alert
Edit `helm/hello-api/values-dev.yaml`, add `replicaCount: 0` at the top level, and push to `main` through a pull request. **Expected:** pods terminate; in the Prometheus UI under *Alerts*, `HelloApiNoAvailableReplicas` goes Pending, then Firing after about a minute. Revert with `git revert` through a pull request and confirm the alert clears.

### T5. Workload Identity and Key Vault
```bash
curl localhost:8081/secret-check                               # {"secret_mounted":true}
kubectl -n hello-api exec deploy/hello-api -- ls /mnt/secrets  # demo-secret
```
Optional failure test:
```bash
KV=$(az keyvault list -g rg-aksgitops-dev --query "[0].name" -o tsv)
CID=$(az identity show -g rg-aksgitops-dev -n id-aksgitops-dev-hello-api --query clientId -o tsv)
az role assignment delete --assignee "$CID" --role "Key Vault Secrets User" --scope "$(az keyvault show -n "$KV" --query id -o tsv)"
kubectl -n hello-api rollout restart deploy/hello-api
kubectl -n hello-api describe pod -l app.kubernetes.io/name=hello-api | tail -20   # mount error, 403
```
Restore it by running *Actions > terraform-apply > Run workflow* for dev.

### T6. Security gate
```bash
git checkout -b test/vulnerable-dep
echo "django==2.2.0" >> apps/hello-api/requirements.txt
git commit -am "test: add vulnerable dependency" && git push -u origin test/vulnerable-dep
```
Open a pull request. **Expected:** `app-ci` fails at the Trivy step and lists fixable CRITICAL vulnerabilities. Close the pull request without merging and delete the branch.

### T7. Azure Policy
```bash
az policy assignment list -g rg-aksgitops-dev -o table
az network vnet create -g rg-aksgitops-dev -n vnet-policy-test -l westeurope --address-prefixes 10.99.0.0/16
```
**Expected:** `RequestDisallowedByPolicy`. A new assignment can take several minutes to start enforcing; retry if the first attempt succeeds, and delete the test vnet if it was created.

### T8. Azure Monitor
```bash
az monitor metrics alert list -g rg-aksgitops-dev -o table
```
In the portal, open the AKS cluster, then *Insights*. In Log Analytics, run `KubePodInventory | where Namespace == "hello-api" | summarize count() by Name`. The CPU alert normally stays quiet; checking that it exists and is enabled is enough.

### T9. Prod approval gate (no cost)
*Actions > terraform-apply > Run workflow > environment: prod.* **Expected:** the job waits for your approval. Reject it. This shows the gate without creating prod.

## Step 9: Tear down (do this after every session)

*Actions > terraform-destroy > Run workflow*, environment `dev`, type `destroy`.

```bash
az group list -o table    # only rg-aksgitops-tfstate should remain
```

**Resuming later**
1. Run `terraform-apply` for dev.
2. Run `./scripts/configure.sh dev`, commit and push. This updates the registry, Key Vault and identity values, which change on every rebuild because of random name suffixes.
3. Run *Actions > app-ci > Run workflow* to push an image to the new registry.
4. `git pull --rebase origin main`, then `./scripts/bootstrap-argocd.sh dev`.

**Full cleanup when the project is finished**
```bash
az group delete -n rg-aksgitops-tfstate --yes
az ad app delete --id "$(az ad app list --display-name sp-aksgitops-github-oidc --query '[0].appId' -o tsv)"
```
Also remove the role assignments for the deleted app if any remain.

## Step 10: Finish and publish the documentation

1. Create `docs/img/` and add the screenshots listed in the README under *Evidence*.
2. Fill in *What broke and how I fixed it* from your real runs. Keep it honest and specific.
3. Add your name and links to the *Author* section.
4. Commit and push, pin the repository on your GitHub profile, and add topics: `azure`, `aks`, `terraform`, `gitops`, `argocd`, `github-actions`, `devops`.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Plan or apply fails with a subscription ID error | `AZURE_SUBSCRIPTION_ID` variable missing | Re-run bootstrap or add the variable |
| `SkuNotAvailable` or quota error on AKS | Region or VM size restricted on the trial | Change `node_vm_size` or `location` (Step 0) |
| `AuthorizationFailed` creating role assignments or policy | Roles not assigned or not yet propagated | Check the app's roles in the portal, wait a minute, re-run |
| 403 creating the Key Vault secret | RBAC propagation | Re-run the apply; the 60 second wait normally covers it |
| `terraform init` cannot reach the state account | Missing data-plane role | Confirm *Storage Blob Data Contributor* on the state account |
| `hello-api` app `OutOfSync` mentioning ServiceMonitor | Prometheus CRDs not installed yet | Wait for `kube-prometheus-stack`; retries are configured |
| Pods `ImagePullBackOff` | Tag is still `pending`, or `app-ci` has not run | Run `app-ci`, then `git pull`; check `AcrPull` on the kubelet identity |
| Pods `ContainerCreating` with a CSI mount error | Wrong federated credential subject, or missing Key Vault role | Subject must be `system:serviceaccount:hello-api:hello-api`; check the role assignment |
| `app-ci` cannot push the tag commit | Branch protection on `main` | Allow the Actions bot to bypass, or switch to a pull request based tag update |
| Trivy fails on a clean change | New fixable CRITICAL in the base image | Rebuild on a newer base image or bump the dependency |
| Prometheus pods `Pending` or `OOMKilled` | Nodes too small | Raise node size or lower the Prometheus memory limit |
| Destroy fails on the Key Vault or leftovers | Partial state | Re-run destroy; delete the resource group in the portal as a last resort |

## Rough cost while running

Two `Standard_B2s` nodes plus a small registry and Log Analytics cap come to roughly 2 USD per day. Verify with the Azure pricing calculator for your region. A single session of a few hours costs very little; the risk is leaving it running.
