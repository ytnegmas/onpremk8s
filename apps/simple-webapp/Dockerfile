FROM python:3.12-slim

ARG GIT_SHA=unknown
ENV APP_NAME="simple-webapp" \
    BUILD_SHA="${GIT_SHA}" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

LABEL org.opencontainers.image.title="simple-webapp" \
      org.opencontainers.image.revision="${GIT_SHA}"

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
