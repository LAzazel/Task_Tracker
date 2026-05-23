from __future__ import annotations

import sys

from mywebapp.config import ConfigError, load_config
from mywebapp.db import get_connection


SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    status TEXT NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
"""


def main() -> int:
    try:
        config = load_config()
    except ConfigError as exc:
        print(f"Config error: {exc}", file=sys.stderr)
        return 1

    with get_connection(config.db) as conn:
        with conn.cursor() as cursor:
            cursor.execute(SCHEMA_SQL)
        conn.commit()

    print("Migration complete")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

