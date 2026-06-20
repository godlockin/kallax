# API Authentication

> Configuration guide for KALLAX API authentication and authorization.

---

## Authentication Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| `none` | No auth (default) | Local dev, trusted network |
| `api-key` | Single static API key | Single-user production |
| `jwt` | JSON Web Token | Multi-user / SSO |
| `header` | Custom header injection | Reverse proxy auth |

---

## Configuration

### API Key Mode

```yaml
# config.yml
server:
  auth:
    mode: api-key
    api_key: "sk-abc123..."   # required
    header_name: "X-API-Key"  # default
```

```bash
# Or via env var
export KALLAX_API_KEY="sk-abc123..."
```

Client usage:
```bash
curl -H "X-API-Key: sk-abc123..." http://localhost:3000/api/v1/tasks
```

### JWT Mode

```yaml
server:
  auth:
    mode: jwt
    jwt_secret: "your-256-bit-secret"   # HMAC secret or RSA public key path
    jwt_algo: "HS256"                   # HS256 | RS256
    jwt_audience: "kallax-server"
    jwt_issuer: "kallax"
```

Client usage:
```bash
curl -H "Authorization: Bearer <token>" http://localhost:3000/api/v1/tasks
```

### Header Injection Mode

```yaml
server:
  auth:
    mode: header
    header_name: "X-Forwarded-User"  # trusted header from reverse proxy
```

Intended for use behind nginx/Envoy with external authentication.

---

## Role-Based Access Control

When JWT or API key auth is enabled, each request carries a role:

| Role | Permissions |
|------|-------------|
| `admin` | Full access — all endpoints, config modification |
| `conductor` | Task management, ticket assignment, PR review |
| `performer` | Task claim, status update, branch operations |
| `reader` | Read-only — status, logs, reports |

JWT payload for RBAC:
```json
{
  "sub": "perf-001",
  "role": "performer",
  "iat": 1700000000,
  "exp": 1700086400
}
```

---

## Rate Limiting

```yaml
server:
  rate_limit:
    enabled: true
    window_ms: 60000     # 1 minute
    max_requests: 100     # burst limit
```

---

## Related Files

- `node/src/middleware/auth.ts` — Auth middleware implementation
- `node/src/middleware/rate-limit.ts` — Rate limiter
- `docs/reference/config-reference.md` — Full server config
- `examples/api-auth/` — Example auth configurations
