from __future__ import annotations

import configparser
import os
from dataclasses import dataclass
from typing import Tuple


DEFAULT_CONFIG_PATH = "/etc/mywebapp/config.ini"


@dataclass(frozen=True)
class DbConfig:
    host: str
    port: int
    name: str
    user: str
    password: str


@dataclass(frozen=True)
class AppConfig:
    app_host: str
    app_port: int
    db: DbConfig


class ConfigError(RuntimeError):
    pass


def _require(value: str | None, field_name: str) -> str:
    if value is None or not value.strip():
        raise ConfigError(f"Missing required config value: {field_name}")
    return value.strip()


def load_config(path: str | None = None) -> AppConfig:
    config_path = path or os.getenv("MYWEBAPP_CONFIG") or DEFAULT_CONFIG_PATH
    parser = configparser.ConfigParser()

    if not parser.read(config_path):
        raise ConfigError(f"Config file not found or unreadable: {config_path}")

    app_section = parser["app"] if "app" in parser else {}
    db_section = parser["db"] if "db" in parser else {}

    app_host = _require(app_section.get("host"), "app.host")
    app_port = int(_require(app_section.get("port"), "app.port"))

    db_host = _require(db_section.get("host"), "db.host")
    db_port = int(_require(db_section.get("port"), "db.port"))
    db_name = _require(db_section.get("name"), "db.name")
    db_user = _require(db_section.get("user"), "db.user")
    db_password = _require(db_section.get("password"), "db.password")

    return AppConfig(
        app_host=app_host,
        app_port=app_port,
        db=DbConfig(
            host=db_host,
            port=db_port,
            name=db_name,
            user=db_user,
            password=db_password,
        ),
    )


def to_dsn(db: DbConfig) -> Tuple[str, str]:
    dsn = f"dbname={db.name} user={db.user} password={db.password} host={db.host} port={db.port}"
    return dsn, db.password
