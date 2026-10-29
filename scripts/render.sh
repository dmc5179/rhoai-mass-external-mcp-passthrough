#!/usr/bin/env bash
# Fill in the manifests for one MCP server.
# Usage: scripts/render.sh my-server.env
set -euo pipefail

env_file=${1:?usage: $0 <server>.env}
root=$(cd "$(dirname "$0")/.." && pwd)

set -a; source "$env_file"; set +a

vars=(
  MCP_GATEWAY_NAME MCP_GATEWAY_NAMESPACE
  MCP_GATEWAY_PUBLIC_LISTENER MCP_GATEWAY_INTERNAL_LISTENER
  MCP_PUBLIC_HOSTNAME OIDC_ISSUER_URL
  MCP_SERVER_NAME MCP_SERVER_NAMESPACE MCP_TOOL_PREFIX
  EXTERNAL_MCP_HOST EXTERNAL_MCP_PORT EXTERNAL_MCP_PATH
  BROKER_CREDENTIAL
)

for v in "${vars[@]}"; do
  if [[ -z ${!v:-} ]]; then
    echo "error: $v is not set in $env_file" >&2
    exit 1
  fi
done

out="$root/rendered/$MCP_SERVER_NAME"
mkdir -p "$out"

# Replace only our variables
only=$(printf '${%s} ' "${vars[@]}")
for f in "$root"/manifests/*/*.yaml; do
  envsubst "$only" < "$f" > "$out/$(basename "$f")"
done

echo "Rendered to $out"
