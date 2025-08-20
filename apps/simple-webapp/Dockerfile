FROM python:3.12-slim

# Don't write .pyc and don't buffer stdout
ENV APP_NAME="simple-webapp" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# non root for security
RUN groupadd -g 1001 appgroup \
    && useradd -u 1001 -g appgroup -s /bin/bash -m appuser

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

USER 1001

EXPOSE 8000
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "--threads", "4", "app:app"]
