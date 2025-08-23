[build]
  command = "bash ./netlify-build.sh"
  publish = "build/web"

[build.environment]
  FLUTTER_VERSION = "3.27.1"
  NODE_VERSION = "18"

[context.production.environment]
  FLUTTER_ENVIRONMENT = "production"

# ---------- Security & CSP (HTML renderer, no external fonts/Canvaskit) ----------
[[headers]]
  for = "/*"
  [headers.values]
    X-Frame-Options = "DENY"
    X-XSS-Protection = "1; mode=block"
    X-Content-Type-Options = "nosniff"
    Referrer-Policy = "strict-origin-when-cross-origin"
    Strict-Transport-Security = "max-age=31536000; includeSubDomains; preload"
    # If you later decide to allow Google Fonts, see the "Optional: allow external fonts" note below.
    Content-Security-Policy = "default-src 'self' data: blob:; base-uri 'self'; object-src 'none'; frame-ancestors 'self'; img-src 'self' data: https:; style-src 'self' 'unsafe-inline'; font-src 'self' data:; script-src 'self' 'unsafe-inline' 'unsafe-eval'; connect-src 'self' https://*.supabase.co https://*.supabase.in wss://*.supabase.co wss://*.supabase.in https://showtrackai.app.n8n.cloud; worker-src 'self' blob:;"

# App shell: always revalidate
[[headers]]
  for = "/index.html"
  [headers.values]
    Cache-Control = "public, max-age=0, must-revalidate"

[[headers]]
  for = "/flutter_service_worker.js"
  [headers.values]
    Cache-Control = "public, max-age=0, must-revalidate"

[[headers]]
  for = "/version.json"
  [headers.values]
    Cache-Control = "public, max-age=0, must-revalidate"

# Top-level JS/CSS: revalidate (these filenames aren’t hashed)
[[headers]]
  for = "/*.js"
  [headers.values]
    Cache-Control = "public, max-age=0, must-revalidate"

[[headers]]
  for = "/*.css"
  [headers.values]
    Cache-Control = "public, max-age=0, must-revalidate"

# Immutable hashed assets
[[headers]]
  for = "/assets/*"
  [headers.values]
    Cache-Control = "public, max-age=31536000, immutable"

# CanvasKit & WASM (kept harmless even if unused)
[[headers]]
  for = "/canvaskit/*"
  [headers.values]
    Cache-Control = "public, max-age=31536000, immutable"

[[headers]]
  for = "/*.wasm"
  [headers.values]
    Cache-Control = "public, max-age=31536000, immutable"
    Content-Type = "application/wasm"

# Web fonts (if you ever ship local .woff2 in /assets/)
[[headers]]
  for = "/*.woff2"
  [headers.values]
    Cache-Control = "public, max-age=31536000, immutable"

# SPA fallback
[[redirects]]
  from = "/*"
  to   = "/index.html"
  status = 200
