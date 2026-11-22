"""Small demo service used to exercise the platform end to end."""
import os
from pathlib import Path

from fastapi import FastAPI
from prometheus_client import Counter, make_asgi_app

APP_VERSION = os.getenv("APP_VERSION", "dev")
SECRET_PATH = Path(os.getenv("SECRET_PATH", "/mnt/secrets/demo-secret"))

app = FastAPI(title="hello-api", version=APP_VERSION)

REQUESTS = Counter("hello_api_requests_total", "Requests served", ["endpoint"])

# Prometheus scrapes this endpoint (see the ServiceMonitor in the Helm chart).
app.mount("/metrics", make_asgi_app())


@app.get("/")
def root():
    REQUESTS.labels(endpoint="root").inc()
    return {"service": "hello-api", "version": APP_VERSION, "message": "Hello from AKS"}


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/secret-check")
def secret_check():
    """Proves Key Vault -> CSI driver -> pod works. Never returns the secret itself."""
    REQUESTS.labels(endpoint="secret-check").inc()
    mounted = SECRET_PATH.is_file() and SECRET_PATH.stat().st_size > 0
    return {"secret_mounted": mounted}
