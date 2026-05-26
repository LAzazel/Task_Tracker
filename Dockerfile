FROM python:3.12-slim

WORKDIR /opt/mywebapp

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY mywebapp ./mywebapp
COPY scripts ./scripts
COPY tests ./tests

EXPOSE 5000

CMD ["gunicorn", "--workers", "2", "--bind", "0.0.0.0:5000", "mywebapp.wsgi:app"]

