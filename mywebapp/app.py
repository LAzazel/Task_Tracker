from __future__ import annotations

from typing import Any

from flask import Flask, Response, jsonify, request

from mywebapp.config import ConfigError, load_config
from mywebapp.db import get_connection
from mywebapp.html import render_root, render_task_detail, render_task_list


BUSINESS_ENDPOINTS = [
    "GET /tasks",
    "POST /tasks",
    "POST /tasks/<id>/done",
]


def _wants_html() -> bool:
    accept = request.accept_mimetypes
    best = accept.best_match(["text/html", "application/json"])
    return best == "text/html" and accept[best] >= accept["application/json"]


def _task_row_to_dict(row: Any) -> dict:
    return {
        "id": row[0],
        "title": row[1],
        "status": row[2],
        "created_at": row[3],
    }


def _serialize_task(task: dict) -> dict:
    return {
        "id": task["id"],
        "title": task["title"],
        "status": task["status"],
        "created_at": task["created_at"].isoformat() if task["created_at"] else None,
    }


def create_app() -> Flask:
    app = Flask(__name__)

    @app.get("/")
    def root() -> Response:
        html = render_root(BUSINESS_ENDPOINTS)
        return Response(html, mimetype="text/html")

    @app.get("/health/alive")
    def health_alive() -> Response:
        return Response("OK", mimetype="text/plain")

    @app.get("/health/ready")
    def health_ready() -> Response:
        try:
            config = load_config()
            with get_connection(config.db) as conn:
                with conn.cursor() as cursor:
                    cursor.execute("SELECT 1")
            return Response("OK", mimetype="text/plain")
        except Exception as exc:  # noqa: BLE001
            return Response(f"NOT READY: {exc}", status=500, mimetype="text/plain")

    @app.get("/tasks")
    def list_tasks() -> Response:
        config = load_config()
        with get_connection(config.db) as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT id, title, status, created_at FROM tasks ORDER BY id"
                )
                rows = cursor.fetchall()
        tasks = [_task_row_to_dict(row) for row in rows]
        if _wants_html():
            html = render_task_list(tasks)
            return Response(html, mimetype="text/html")
        return jsonify([_serialize_task(task) for task in tasks])

    @app.post("/tasks")
    def create_task() -> Response:
        payload = request.get_json(silent=True) or request.form
        title = (payload.get("title") or "").strip()
        if not title:
            return Response("Missing title", status=400, mimetype="text/plain")

        config = load_config()
        with get_connection(config.db) as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO tasks (title, status)
                    VALUES (%s, %s)
                    RETURNING id, title, status, created_at
                    """,
                    (title, "todo"),
                )
                row = cursor.fetchone()
            conn.commit()
        task = _task_row_to_dict(row)
        if _wants_html():
            html = render_task_detail(task)
            return Response(html, mimetype="text/html", status=201)
        return jsonify(_serialize_task(task)), 201

    @app.post("/tasks/<int:task_id>/done")
    def mark_done(task_id: int) -> Response:
        config = load_config()
        with get_connection(config.db) as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE tasks
                    SET status = %s
                    WHERE id = %s
                    RETURNING id, title, status, created_at
                    """,
                    ("done", task_id),
                )
                row = cursor.fetchone()
            conn.commit()
        if row is None:
            return Response("Task not found", status=404, mimetype="text/plain")
        task = _task_row_to_dict(row)
        if _wants_html():
            html = render_task_detail(task)
            return Response(html, mimetype="text/html")
        return jsonify(_serialize_task(task))

    @app.errorhandler(ConfigError)
    def handle_config_error(exc: ConfigError) -> Response:
        return Response(str(exc), status=500, mimetype="text/plain")

    return app


app = create_app()




