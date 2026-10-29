# External MCP server with user token passthrough

Register an off-cluster MCP server behind the Red Hat Connectivity Link (RHCL)
1.5 MCP gateway so each user's own IdP token reaches it on `tools/call`.
No proxy, no hard-coded user token.

Use this when the external server trusts the **same identity provider** as the
gateway. If it needs its own per-user credential (PAT, API key), use the Vault
pattern in RHCL 1.5 *Secure your traffic*, chapter 6, instead of `06`.

## How it works

The gateway reaches a backend MCP server in two ways:

| Call | Made by | Credential |
|---|---|---|
| `tools/list` (discovery) | Broker, cached | Static Secret via `credentialRef` |
| `tools/call` | Each user request | The user's `Authorization` header |

So a working `tools/list` does not prove user tokens reach the server.

## Files

| File | Purpose |
|---|---|
| `manifests/per-server/01-serviceentry.yaml` | Register the external host with Istio |
| `manifests/per-server/02-destinationrule.yaml` | TLS to the external host |
| `manifests/per-server/03-httproute.yaml` | Route `<name>.mcp.local` to the external host |
| `manifests/per-server/04-secret-broker-credential.yaml` | Discovery-only credential |
| `manifests/per-server/05-mcpserverregistration.yaml` | Register the server with the gateway |
| `manifests/per-server/06-authpolicy-route-passthrough.yaml` | Forward the user token on `tools/call` |
| `manifests/gateway/07-authpolicy-gateway-jwt.yaml` | Validate user tokens (once per gateway) |
| `env.example` | Settings for one server |
| `scripts/render.sh` | Fill in the manifests from an env file |

## Prerequisites

- RHCL 1.5 with the MCP gateway installed. Check that it is supported with
  your OpenShift AI release.
- A `Gateway` with a public listener (e.g. `mcp`) and a `*.mcp.local`
  listener (e.g. `mcps`), plus an `MCPGatewayExtension`.
- A `Kuadrant` CR in the gateway namespace.
- Egress from the gateway pods to the external host.
- A long-lived service credential the external server accepts, for discovery.
  Not a user token: discovery breaks when it expires.

## Usage

```bash
cp env.example my-server.env      # *.env is git-ignored
vi my-server.env
scripts/render.sh my-server.env
oc apply -f rendered/<MCP_SERVER_NAME>/
```

Repeat with a new env file for each additional server.

Notes:

- `07` is applied last. After it, requests without a valid token from
  `OIDC_ISSUER_URL` get a 401, so make sure 01-06 work first.
- For clients that discover OAuth automatically, also set
  `spec.oauthProtectedResource` on the `MCPGatewayExtension`.
- Replacing a proxy setup? Delete the old HTTPRoute, registration, and proxy
  first so two routes don't claim the same hostname.

## Verify

```bash
oc get mcpsr -n <MCP_SERVER_NAMESPACE>   # expect READY=True and TOOLS > 0
```

Then call a `<MCP_TOOL_PREFIX>*` tool as a logged-in user and check the
external server's logs for that user's token.

## Troubleshooting

| Symptom | Check |
|---|---|
| Registration not ready, no tools | Secret label `mcp.kuadrant.io/secret: "true"`; `BROKER_CREDENTIAL` starts with `Bearer `; `EXTERNAL_MCP_PATH` is correct |
| TLS errors | SNI in `02`; add the CA for a private CA |
| 401 from the gateway | Token missing, expired, or from the wrong issuer |
| 401/403 from the external server | Server rejects the IdP token (audience, issuer), or the client isn't sending it |

## References

- RHCL 1.5 [Register MCP servers and create policies](https://docs.redhat.com/en/documentation/red_hat_connectivity_link/1.5/html-single/register_mcp_servers_and_create_policies/index), chapter 2
- RHCL 1.5 [Secure your traffic](https://docs.redhat.com/en/documentation/red_hat_connectivity_link/1.5/html-single/secure_your_traffic/index), chapters 4 and 6
- RHCL 1.5 [MCP gateway architecture](https://docs.redhat.com/en/documentation/red_hat_connectivity_link/1.5/html-single/mcp_gateway/index)
- Upstream [external MCP server guide](https://github.com/Kuadrant/mcp-gateway/blob/main/docs/guides/external-mcp-server.md)
