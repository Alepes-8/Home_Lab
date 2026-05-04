#!/bin/bash
# =============================================================
#  rollback.sh — Rollback the API to a specific version
#  Usage: ./rollback.sh <location> <version>
#  Example: ./rollback.sh prod v1.0.12
# =============================================================

# ── Helper ───────────────────────────────────────────────────

Help() {
    echo
    echo "  The rollback script accepts two inputs"
    echo
    echo "  Syntax:  ./rollback.sh <location> <version>"
    echo
    echo "  Options:"
    echo "    location   Server environment to rollback: prod | staging"
    echo "    version    Version to rollback to, format: vXX.XX.XX"
    echo
    echo "  Example: ./rollback.sh prod v1.0.12"
    echo
}

# ── Safety ───────────────────────────────────────────────────

set -e  # Exit immediately if any command fails
set -u  # Treat unset variables as errors

# ── Input Validation ─────────────────────────────────────────

if [ "$#" -ne 2 ]; then
    echo "  Error: Expected 2 arguments, got $#."
    Help
    exit 1
fi

location="$1"
version="$2"

if [[ "$location" != "prod" && "$location" != "staging" ]]; then
    echo "  Error: Invalid location '$location'. Must be prod or staging."
    Help
    exit 1
fi

version_clean="${version#v}"                  # Strip leading v → 1.0.12
versionIN=(${version_clean//./ })             # Split on . → (1 0 12)

if [[ ${#versionIN[@]} -ne 3 ]]; then
    echo "  Error: Invalid version format. Expected vXX.XX.XX, got '$version'."
    Help
    exit 1
fi

re='^[0-9]+$'
if ! [[ ${versionIN[0]} =~ $re && ${versionIN[1]} =~ $re && ${versionIN[2]} =~ $re ]]; then
    echo "  Error: Version segments must be numeric. Got '$version'."
    Help
    exit 1
fi

echo "  Rolling back $location to $version..."

if [[ -z "${GHCR_PAT:-}" || -z "${GHCR_USER:-}" ]]; then
    echo "  Error: GHCR_PAT and GHCR_USER must be set in your environment."
    echo "  Add them to your ~/.bashrc and run: source ~/.bashrc"
    exit 1
fi
# ── Rollback ─────────────────────────────────────────────────
# NOTE: In future this block will be executed via SSH once the
# docker-compose files are moved to the server:
#   ssh user@server "cd /path/to/project && ./rollback.sh $location $version"
COMPOSE_DIR="$(dirname "$0")/../docker-compose"

echo "$GHCR_PAT" | docker login ghcr.io -u "$GHCR_USER" --password-stdin

IMAGE_TAG=$version docker compose -f "$COMPOSE_DIR/docker-compose.$location.yml" pull
docker compose -f "$COMPOSE_DIR/docker-compose.$location.yml" down
IMAGE_TAG=$version docker compose \
    --env-file "$COMPOSE_DIR/.env.$location" \
    -f "$COMPOSE_DIR/docker-compose.$location.yml" \
    up -d --no-build

# ── Health Check ─────────────────────────────────────────────
# TODO: Update ports once server addresses are confirmed

if [[ "$location" == "prod" ]]; then
    port=5001
else
    port=5002
fi

echo "  Waiting for container to be ready..."

success=false
for i in {1..5}; do
    status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$port/drink/health)
    if [[ "$status" == "200" ]]; then
        success=true
        break
    fi
    echo "  Attempt $i/5 failed (status: $status). Retrying in 5s..."
    sleep 5
done

if [[ "$success" == "false" ]]; then
    echo "  Error: Health check failed after 5 attempts."
    echo "  The container may be misconfigured or the image may be corrupt."
    echo "  Resolve the issue manually before attempting another rollback."
    exit 1
fi

body=$(curl -s http://localhost:$port/drink/health)
returned_version=$(echo "$body" | jq -r '.version')

if [[ "$returned_version" != "$version" ]]; then
    echo "  Error: Version mismatch. Expected '$version', got '$returned_version'."
    echo "  The container is running but on the wrong version."
    exit 1
fi

echo "  Rollback complete. $location is running $version."
