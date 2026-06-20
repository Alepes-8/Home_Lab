# GitHub Runner
 
The GitHub runner is an automated process that doesn't start any work or task on its own. Instead, it's instructed to carry out a given set of tasks and handles them from there.
 
## Responsibility
 
The responsibility given to the GitHub runner in the `Home_Lab` repo is to update the staging image on the server. As noted before, it's instructed by the GitHub processes to pull the image and deploy it — but only for staging, since the responsibility for prod is handled by Jenkins.
 
## How it's triggered
 
The runner itself never watches or polls anything — it sits idle until GitHub Actions explicitly assigns it a job. Because `drink_api_home_lab` (where images are built) and `Home_Lab` (where the runner lives) are separate repositories, a bridge is needed between them:
 
1. `drink_api_home_lab`'s CD workflow builds and pushes `image:staging` to GHCR.
2. It then fires a `repository_dispatch` event at `Home_Lab`, using a fine-grained PAT scoped only to that repo.
3. `Home_Lab` has a workflow (`.github/workflows/deploy-staging.yml`) listening for that event type, with `runs-on: self-hosted` — this is what routes the job specifically to the runner installed on the server.
4. The runner executes `docker compose pull && docker compose up -d` against `docker-compose.staging.yml`, directly on the server.
```
drink_api_home_lab  →  build + push :staging to GHCR  →  repository_dispatch  →  Home_Lab
                                                                                      ↓
                                                                          self-hosted runner
                                                                                      ↓
                                                              docker compose pull && up -d (staging)
```
 
## Setup
 
Setting this up has two parts: creating the access token that lets `drink_api_home_lab` trigger `Home_Lab`, and registering the actual runner process on the server.
 
### Part 1 — Create the dispatch token
 
This token allows `drink_api_home_lab` to call GitHub's API and trigger a workflow in `Home_Lab`. It is **not** the same as `GHCR_PAT` — that one handles pushing/pulling container images; this one only needs permission to trigger repo events.
 
1. Go to [github.com/settings/tokens?type=beta](https://github.com/settings/tokens?type=beta) (fine-grained tokens are separate from classic ones).
2. Under **Repository access**, select **"Only select repositories"** → choose `Home_Lab`.
3. Under **Permissions** → **Repository permissions**, find **Contents** → set to **Read and write** (this is what allows triggering `repository_dispatch`).
4. Set an expiration (your call — shorter is more secure, but means remembering to rotate it).
5. Generate and copy the token immediately (it's shown only once).
6. Add it as a secret **in `drink_api_home_lab`** (the repo that sends the dispatch, not `Home_Lab`):
   `drink_api_home_lab` → Settings → Secrets and variables → Actions → New repository secret
   Name: `HOMELAB_DISPATCH_TOKEN`
   
### Part 2 — Register the runner on the server
 
This installs and registers the actual runner process on `hp-z240-server`, scoped to the `Home_Lab` repo.
 
1. On GitHub: `Home_Lab` → **Settings → Actions → Runners → New self-hosted runner**.
2. Select **OS: Linux**, **Architecture: x64** (matches Ubuntu Server 24.04 LTS x64 on the homelab server).
3. GitHub will display a registration command sequence with a short-lived token (expires within roughly an hour — run the full sequence in one sitting). On the server, create a dedicated folder per runner (keeps multiple future runners cleanly separated):
```bash
   mkdir -p ~/runners/runner-homelab && cd ~/runners/runner-homelab
```
 
4. Run the download, validation, and extraction commands exactly as shown on GitHub's page (version numbers change over time — always copy what the page currently shows, don't reuse old commands):
```bash
   curl -o actions-runner-linux-x64-<version>.tar.gz -L <url-from-github>
   echo "<checksum>  actions-runner-linux-x64-<version>.tar.gz" | shasum -a 256 -c
   tar xzf ./actions-runner-linux-x64-<version>.tar.gz
```
 
5. Configure the runner:
```bash
   ./config.sh --url https://github.com/Alepes-8/Home_Lab --token <token-from-github>
```
 
   During configuration you'll be prompted for:
   - **Runner group** — leave as `Default` (groups are an org-level feature, not relevant for a personal repo).
   - **Runner name** — give it something descriptive, e.g. `homelab-runner`.
   - **Additional labels** — optional, but useful once more than one runner exists (e.g. add `homelab` so workflows can target it precisely instead of relying only on the generic `self-hosted` label).
   - **Work folder** — accept the default (`_work`). It's created relative to the runner's own folder and won't collide with the actual `Home_Lab` git clone elsewhere on the server.
6. **Before going further, confirm the user running the registration has Docker access without `sudo`** — the runner inherits whatever permissions its user account has, and it needs to run `docker compose` commands directly:
```bash
   whoami
   docker ps
```
 
   Both should succeed with no permission errors. If `docker ps` fails, the user needs to be added to the `docker` group (see the `bootstrap.sh` step that does this for the primary user) — log out and back in for group membership to take effect.
 
7. Install and start the runner as a background service, so it survives reboots and terminal/SSH disconnects (the same principle as `docker.service` being enabled in `bootstrap.sh`):
```bash
   sudo ./svc.sh install
   sudo ./svc.sh start
```
 
8. Verify it's running correctly:
```bash
   sudo ./svc.sh status
```
 
   Look for `Active: active (running)`, `enabled`, and a log line reading `Listening for Jobs`. You can also confirm in GitHub's UI — `Home_Lab` → Settings → Actions → Runners should show it as **Idle**, not offline.
 
### Part 3 — Add the workflow files
 
With the token and runner in place, two workflow files complete the chain:
 
**`drink_api_home_lab/.github/workflows/<staging-build-workflow>.yml`** — after pushing `image:staging` to GHCR, add a final job to dispatch the event:
 
```yaml
  notify-homelab:
    needs: <name-of-build-and-push-job>
    runs-on: ubuntu-latest
    steps:
      - name: Dispatch deploy event to Home_Lab
        run: |
          curl -X POST \
            -H "Authorization: token ${{ secrets.HOMELAB_DISPATCH_TOKEN }}" \
            -H "Accept: application/vnd.github.v3+json" \
            https://api.github.com/repos/Alepes-8/Home_Lab/dispatches \
            -d '{"event_type":"staging-deploy","client_payload":{"image_tag":"staging"}}'
```
 
**`Home_Lab/.github/workflows/deploy-staging.yml`** — listens for that event and runs the deploy on the self-hosted runner:
 
```yaml
name: Deploy Staging
 
on:
  repository_dispatch:
    types: [staging-deploy]
 
jobs:
  deploy:
    runs-on: self-hosted
    steps:
      - name: Checkout
        uses: actions/checkout@v4
 
      - name: Pull and restart staging
        working-directory: docker-compose
        run: |
          docker compose -f docker-compose.staging.yml pull
          docker compose -f docker-compose.staging.yml up -d
```
 
This workflow file must exist on `Home_Lab`'s default branch (typically `main`) to be discoverable by `repository_dispatch` — it doesn't matter which branch originally triggered the event in `drink_api_home_lab`.
 
## Status
 
| Step | Status |
|---|---|
| Fine-grained dispatch token created, added to `drink_api_home_lab` secrets | Done |
| Runner registered (`homelab-runner`) | Done |
| Runner installed as systemd service, verified running | Done |
| Docker access verified for runner's user | Done |
| `deploy-staging.yml` committed to `Home_Lab` | Pending |
| Dispatch step added to `drink_api_home_lab`'s staging workflow | Pending |
| Full end-to-end test (push → build → dispatch → deploy) | Not yet run |
 
## Open items / future improvements
 
- Decide whether the `staging` branch workflow should rebuild from source independently (matching how `dev` and `prod` currently work) or promote/re-tag an already-built `:dev` image. Deferred — not yet decided.
- Once a third project repo needs its own runner, switch to a multi-runner orchestration tool rather than continuing to register runners manually one at a time (see separate issue/doc on this).
- `client_payload.image_tag` is sent in the dispatch event but not yet consumed by `deploy-staging.yml` — currently it just pulls whatever `:staging` resolves to in GHCR. Worth revisiting if more precise control (e.g. deploying a specific SHA-tagged image) becomes necessary later.