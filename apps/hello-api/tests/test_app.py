from fastapi.testclient import TestClient

from app import main

client = TestClient(main.app)


def test_root_returns_service_info():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["service"] == "hello-api"


def test_healthz_is_ok():
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_secret_check_false_when_not_mounted(tmp_path, monkeypatch):
    monkeypatch.setattr(main, "SECRET_PATH", tmp_path / "missing")
    assert client.get("/secret-check").json() == {"secret_mounted": False}


def test_secret_check_true_when_mounted(tmp_path, monkeypatch):
    secret = tmp_path / "demo-secret"
    secret.write_text("value")
    monkeypatch.setattr(main, "SECRET_PATH", secret)
    assert client.get("/secret-check").json() == {"secret_mounted": True}


def test_metrics_endpoint_exposes_counter():
    client.get("/")
    response = client.get("/metrics/")
    assert response.status_code == 200
    assert "hello_api_requests_total" in response.text
