# Nginx reverse proxy for web-ui-go

This directory contains nginx configuration for proxy mode (`client -> nginx -> web-ui-go`).

## Files

- `nginx.conf` — global worker/event/http tuning (high-load safe defaults)
- `conf.d/web-ui.conf` — virtual host for TLS, HTTP/2, proxying, and static assets

## Key behavior

- TLS and HTTP/2 terminate at nginx (`:443`)
- Upstream to `web-ui` goes over internal HTTP (`web-ui:8080`)
- Static assets are served directly from nginx at `/assets/*`
- Request correlation header is forwarded: `X-Request-ID`

## Notes

- `gzip` is enabled.
- `brotli` is not enabled by default in `nginx:alpine` image (module not guaranteed).
- If you change config files, recreate nginx container:

```bash
docker compose up -d --force-recreate nginx
```
