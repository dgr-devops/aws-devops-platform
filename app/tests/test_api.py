from sqlalchemy.exc import OperationalError

from app.db import get_db
from app.main import app


def test_health_ok(client):
    assert client.get("/health").json() == {"status": "ok"}


def test_health_db_down(client):
    class Broken:
        def execute(self, *_):
            raise OperationalError("SELECT 1", {}, Exception("down"))

    app.dependency_overrides[get_db] = lambda: Broken()
    assert client.get("/health").status_code == 503


def test_crud_flow(client):
    created = client.post("/tasks", json={"title": "desplegar"})
    assert created.status_code == 201
    task_id = created.json()["id"]
    assert created.json()["done"] is False

    assert client.get("/tasks").json()[0]["title"] == "desplegar"
    assert client.get(f"/tasks/{task_id}").json()["id"] == task_id

    patched = client.patch(f"/tasks/{task_id}", json={"done": True})
    assert patched.json()["done"] is True
    assert patched.json()["title"] == "desplegar"

    assert client.delete(f"/tasks/{task_id}").status_code == 204
    assert client.get(f"/tasks/{task_id}").status_code == 404


def test_not_found_paths(client):
    assert client.patch("/tasks/99", json={"done": True}).status_code == 404
    assert client.delete("/tasks/99").status_code == 404


def test_validation_rejects_empty_title(client):
    assert client.post("/tasks", json={"title": ""}).status_code == 422


def test_metrics_counts_requests(client):
    client.get("/health")
    client.get("/tasks/12345")
    body = client.get("/metrics").text
    assert 'http_requests_total{method="GET",path="/health",status="200"}' in body
    assert 'path="/tasks/{task_id}",status="404"' in body
    assert "http_request_duration_seconds" in body
