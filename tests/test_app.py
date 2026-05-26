from __future__ import annotations

from datetime import datetime

import pytest

from mywebapp.app import create_app
from mywebapp.config import AppConfig, DbConfig


class FakeCursor:
    def __init__(self, rows=None, row=None):
        self._rows = rows or []
        self._row = row

    def execute(self, *_args, **_kwargs):
        return None

    def fetchall(self):
        return list(self._rows)

    def fetchone(self):
        return self._row

    def __enter__(self):
        return self

    def __exit__(self, _exc_type, _exc, _tb):
        return False


class FakeConnection:
    def __init__(self, cursor: FakeCursor):
        self._cursor = cursor

    def cursor(self):
        return self._cursor

    def commit(self):
        return None

    def close(self):
        return None

    def __enter__(self):
        return self

    def __exit__(self, _exc_type, _exc, _tb):
        return False


def _dummy_config() -> AppConfig:
    return AppConfig(
        app_host="127.0.0.1",
        app_port=5000,
        db=DbConfig(host="localhost", port=5432, name="db", user="user", password="pass"),
    )


@pytest.fixture()
def client(monkeypatch):
    app = create_app()
    app.config.update(TESTING=True)
    monkeypatch.setattr("mywebapp.app.load_config", lambda: _dummy_config())
    return app.test_client()


def test_root_html(client):
    response = client.get("/")
    assert response.status_code == 200
    assert response.mimetype == "text/html"
    assert "GET /tasks" in response.get_data(as_text=True)


def test_health_alive(client):
    response = client.get("/health/alive")
    assert response.status_code == 200
    assert response.get_data(as_text=True) == "OK"


def test_list_tasks_json(client, monkeypatch):
    rows = [(1, "Task", "todo", datetime(2026, 5, 26, 12, 0, 0))]
    cursor = FakeCursor(rows=rows)
    monkeypatch.setattr("mywebapp.app.get_connection", lambda _db: FakeConnection(cursor))

    response = client.get("/tasks", headers={"Accept": "application/json"})
    assert response.status_code == 200
    data = response.get_json()
    assert data[0]["title"] == "Task"


def test_create_task_missing_title(client):
    response = client.post("/tasks", data={"title": ""})
    assert response.status_code == 400


def test_create_task_json(client, monkeypatch):
    row = (1, "New Task", "todo", datetime(2026, 5, 26, 12, 0, 0))
    cursor = FakeCursor(row=row)
    monkeypatch.setattr("mywebapp.app.get_connection", lambda _db: FakeConnection(cursor))

    response = client.post("/tasks", json={"title": "New Task"})
    assert response.status_code == 201
    data = response.get_json()
    assert data["status"] == "todo"


def test_mark_done_not_found(client, monkeypatch):
    cursor = FakeCursor(row=None)
    monkeypatch.setattr("mywebapp.app.get_connection", lambda _db: FakeConnection(cursor))

    response = client.post("/tasks/42/done")
    assert response.status_code == 404


def test_mark_done_ok(client, monkeypatch):
    row = (2, "Done Task", "done", datetime(2026, 5, 26, 12, 0, 0))
    cursor = FakeCursor(row=row)
    monkeypatch.setattr("mywebapp.app.get_connection", lambda _db: FakeConnection(cursor))

    response = client.post("/tasks/2/done", headers={"Accept": "application/json"})
    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "done"

