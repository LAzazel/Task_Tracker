# mywebapp

Сервіс для відстеження задач з простим HTTP API та HTML-представленням. Розгортається на одній Linux ВМ з reverse proxy (nginx) та PostgreSQL.

## Варіант

N = 19

- V2 = (19 % 2) + 1 = 2
- V3 = (19 % 3) + 1 = 2
- V5 = (19 % 5) + 1 = 5

Індивідуальне завдання: **Task Tracker**.

## Параметри реалізації

- Тематика: Task Tracker
- Конфігурація: `/etc/mywebapp/config.ini`
- СУБД: PostgreSQL
- Порт застосунку: 5000

## Можливості

- Створення задач
- Перегляд списку задач
- Відмітка задачі як виконаної
- Health-ендпоінти для перевірки стану
- Віддача `text/html` або `application/json` залежно від `Accept`

## API

Кореневий ендпоінт (тільки HTML):

- `GET /` — список бізнес-ендпоінтів

Бізнес-ендпоінти:

- `GET /tasks` — список задач
- `POST /tasks` — створити задачу (поле `title`)
- `POST /tasks/<id>/done` — позначити задачу як виконану

Health:

- `GET /health/alive` — завжди `200 OK`
- `GET /health/ready` — `200 OK` якщо є підключення до БД, інакше `500`

Приклади:

```bash
curl -H "Accept: application/json" http://localhost/tasks
curl -H "Accept: text/html" http://localhost/tasks
curl -X POST -d "title=Test" http://localhost/tasks
curl -X POST http://localhost/tasks/1/done
```

## Конфігурація

Файл `/etc/mywebapp/config.ini`:

```ini
[app]
host = 127.0.0.1
port = 5000

[db]
host = 127.0.0.1
port = 5432
name = mywebapp
user = mywebapp
password = mywebapp_pass
```

## Локальний запуск (Windows, PowerShell)

Встановлення залежностей:

```bash
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
```

Запуск міграцій:

```bash
$env:MYWEBAPP_CONFIG="tests\\fixtures\\config.ini"
python scripts/migrate.py
```

Запуск застосунку:

```bash
$env:MYWEBAPP_CONFIG="tests\\fixtures\\config.ini"
python -m flask --app mywebapp.app run --host 127.0.0.1 --port 5000
```

## Запуск через Docker Compose (Lab 2)

Файли:

- `docker-compose.yml`
- `Dockerfile`
- `docker/config.ini`
- `docker/nginx.conf`

Запуск у фоні:

```bash
docker compose up -d --build
```

Перевірка:

```bash
curl -H "Accept: application/json" http://localhost/tasks
curl -X POST -d "title=Check" http://localhost/tasks
```

Зупинка:

```bash
docker compose down
```

Дані PostgreSQL зберігаються у volume `db-data` і переживають перезапуск контейнерів.


## Примітка для WSL

У WSL можливі проблеми із socket activation (помилка `Bad file descriptor`). У такому разі використовуйте прямий запуск сервісу без socket-юнита:

```bash
sudo systemctl stop mywebapp.socket
sudo systemctl disable mywebapp.socket

sudo mkdir -p /etc/systemd/system/mywebapp.service.d
sudo tee /etc/systemd/system/mywebapp.service.d/override.conf <<'EOF'
[Service]
Sockets=
ExecStart=
ExecStart=/opt/mywebapp/venv/bin/gunicorn --workers 2 --bind 127.0.0.1:5000 mywebapp.wsgi:app
EOF

sudo systemctl daemon-reload
sudo systemctl restart mywebapp
```

## Розгортання на ВМ (Ubuntu Server 22.04 LTS)

Рекомендований образ: офіційний ISO Ubuntu Server 22.04 LTS.

Де взяти образ:

- https://ubuntu.com/download/server

Мінімальні ресурси:

- CPU: 2 vCPU
- RAM: 2 GB
- Disk: 15 GB

Вхід:

- Початково: консоль ВМ або SSH (залежно від вашої інсталяції)
- Дефолтний користувач — створений під час встановлення Ubuntu (логін/пароль, які ви задали інсталятором)
- Після автоматизації: SSH для користувачів `student`, `teacher`, `operator`
  - Пароль за замовчуванням: `12345678` (зміна при першому вході)

## Автоматизація

Точка входу: `deploy/install.sh`

Скрипт виконує:

- інсталяцію пакетів
- створення користувачів
- налаштування PostgreSQL
- установку та запуск сервісу `mywebapp` (systemd socket activation)
- налаштування nginx reverse proxy
- створення `/home/student/gradebook` з числом `19`
- блокування дефолтного користувача ОС

Запуск:

```bash
sudo bash deploy/install.sh
```

## Структура репозиторію

- `mywebapp/` — код застосунку
- `scripts/migrate.py` — міграції БД
- `deploy/` — systemd, nginx і автоматизація
- `tests/` — мінімальні тести
- `requirements.txt` — залежності

## Перевірка розгортання

Бізнес-ендпоінти через nginx:

```bash
curl -H "Accept: application/json" http://localhost/tasks
curl -X POST -d "title=Check" http://localhost/tasks
curl -X POST http://localhost/tasks/1/done
```

Перевірка обмеження доступу до health-ендпоінтів:

```bash
# через nginx очікуємо 404
curl -i http://localhost/health/alive

# напряму до застосунку очікуємо 200 OK
curl -i http://127.0.0.1:5000/health/alive
```

## Примітки щодо доступу

- Застосунок слухає `127.0.0.1:5000`
- PostgreSQL доступна лише з `127.0.0.1`
- Зовнішній доступ тільки через nginx (порт 80)

## CI/CD (Lab 3)

CI запускає лінтери, тести з покриттям та збірку образу. CD розгортає застосунок на target node через self-hosted runner за анотованими тегами.

### Необхідні GitHub Secrets

- `TARGET_HOST` - IP або DNS target node
- `TARGET_USER` - користувач для SSH
- `TARGET_PORT` - порт SSH (наприклад, 22)
- `TARGET_SSH_KEY` - приватний ключ для SSH
- `GHCR_TOKEN` - токен з правами read:packages для GHCR

### Структура CI/CD

- CI: `.github/workflows/ci.yml`
  - Flake8, ShellCheck, Hadolint, Yamllint
  - Pytest + coverage (мінімум 40%)
  - Публікація coverage.xml як артефакту на main
  - Збірка образу та пуш у GHCR
- CD: `.github/workflows/deploy.yml`
  - Запуск на self-hosted runner
  - Деплой на target node через SSH
  - Верифікація доступності сервісу

### Підготовка target node

1) Скопіювати файли на target node (один раз):

```bash
scp deploy/docker-compose.prod.yml deploy/target_setup.sh deploy/systemd/mywebapp-container.service docker/nginx.conf docker/config.ini <user>@<host>:/opt/mywebapp/
```

2) Запустити підготовку:

```bash
sudo bash /opt/mywebapp/target_setup.sh
```

### Розгортання

- Пуш анотованого тегу запускає CD:

```bash
git tag -a v1.0.0 -m "release v1.0.0"
git push origin v1.0.0
```

### Верифікація

Скрипт `deploy/verify.sh` перевіряє, що доступні `/` та `/tasks`, а `/health/*` недоступні з nginx.
