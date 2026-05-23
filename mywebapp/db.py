from __future__ import annotations

from contextlib import contextmanager
from typing import Iterator

import psycopg2
import psycopg2.extras

from mywebapp.config import DbConfig


@contextmanager
def get_connection(db: DbConfig) -> Iterator[psycopg2.extensions.connection]:
    conn = psycopg2.connect(
        dbname=db.name,
        user=db.user,
        password=db.password,
        host=db.host,
        port=db.port,
    )
    try:
        yield conn
    finally:
        conn.close()

