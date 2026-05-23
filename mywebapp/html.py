from __future__ import annotations

from datetime import datetime
from typing import Iterable


def _format_dt(value: datetime | None) -> str:
    return value.isoformat(sep=" ", timespec="seconds") if value else ""


def render_layout(title: str, body: str) -> str:
    return (
        "<!doctype html>\n"
        "<html lang=\"en\">\n"
        "<head><meta charset=\"utf-8\"><title>"
        + title
        + "</title></head>\n"
        "<body>\n"
        + body
        + "\n</body></html>"
    )


def render_task_list(tasks: Iterable[dict]) -> str:
    rows = [
        "<tr><th>ID</th><th>Title</th><th>Status</th><th>Created</th></tr>"
    ]
    for task in tasks:
        rows.append(
            "<tr>"
            f"<td>{task['id']}</td>"
            f"<td>{task['title']}</td>"
            f"<td>{task['status']}</td>"
            f"<td>{_format_dt(task['created_at'])}</td>"
            "</tr>"
        )
    table = "<table>" + "".join(rows) + "</table>"
    return render_layout("Tasks", table)


def render_task_detail(task: dict) -> str:
    body = (
        f"<h1>Task {task['id']}</h1>"
        f"<p><strong>Title:</strong> {task['title']}</p>"
        f"<p><strong>Status:</strong> {task['status']}</p>"
        f"<p><strong>Created:</strong> {_format_dt(task['created_at'])}</p>"
    )
    return render_layout("Task", body)


def render_root(endpoints: Iterable[str]) -> str:
    items = "".join(f"<li>{endpoint}</li>" for endpoint in endpoints)
    body = "<h1>mywebapp endpoints</h1><ul>" + items + "</ul>"
    return render_layout("mywebapp", body)

