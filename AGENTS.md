# AGENTS.md

## Project

Lua web crawler targeting `https://konachan.net/post.json` to scrape wallpaper data.

## Key constraint

- **Language: Lua** — all business logic in Lua.
- The site is behind **Cloudflare managed challenge** (type: `MANAGED_CHALLENGE`). Pure Lua HTTP requests get a Turnstile-style JS challenge page (403).
- `post.json` in the repo root is *not* a valid post.json response (it's a Cloudflare challenge HTML page).

## Cloudflare challenge type

Diagnosed on 2026-07-06: Cloudflare returns a **managed challenge** (`cType: 'managed'`), not the older IUAM (`chk_jschl` form). This requires JavaScript execution + browser fingerprinting — **pure Lua cannot solve it**.

## Architecture

1. **FlareSolverr** (Docker sidecar) — headless browser that solves Cloudflare challenges automatically.
2. **Lua calls FlareSolverr API** — sends POST `http://localhost:8191/v1` to proxy requests through the browser.
3. If FlareSolverr is unavailable, **fallback to diagnostic mode** — logs the challenge page for manual analysis.

## Modules

| File | Purpose |
|------|---------|
| `main.lua` | Entry point — FlareSolverr flow with diagnostic fallback |
| `src/flaresolverr.lua` | FlareSolverr API wrapper (POST `/v1` with `request.get`) |
| `src/http.lua` | Direct HTTPS client (`ssl.https` + `ltn12`) with cookie jar integration |
| `src/cookie.lua` | Cookie jar — parse `Set-Cookie`, build `Cookie` header |
| `src/logger.lua` | Timestamped logging to `crawler.log` |
| `src/cf_challenge.lua` | Diagnostic: fetch challenge page, identify type, extract params |
| `headers.txt` | Browser-mimicking HTTP headers (loaded at startup) |

## Local development

```bash
lua main.lua
```

- Requires FlareSolverr running on `localhost:8191`. Without it, falls back to diagnostic.
- Full HTTP request/response trace in `crawler.log`.
- Challenge samples saved to `samples/`.

## CI (GitHub Actions)

`.github/workflows/main.yml`:
- Runs on schedule (`*/10 * * * *`) and `workflow_dispatch`.
- Starts FlareSolverr via Docker before running Lua.
- Installs Lua 5.4 + rocks: `luasocket`, `luasec`, `lua-cjson`, `luafilesystem`, `inspect`.
- Output artifacts: `.data/post.json`.
