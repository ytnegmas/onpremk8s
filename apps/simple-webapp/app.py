import os
import logging, sys, json
from datetime import datetime, timezone
from flask import Flask, jsonify
from prometheus_flask_exporter import PrometheusMetrics

app = Flask(__name__)

APP_NAME = os.getenv("APP_NAME", "simple-webapp")
BUILD_SHA = os.getenv("BUILD_SHA", "unknown")


#####################################
# -----------------------------------
# Observability instrumentation
class JsonFormatter(logging.Formatter):
    def format(self, record):
        log_record = {
            "time": self.formatTime(record, self.datefmt),
            "level": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
        }
        return json.dumps(log_record)

handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JsonFormatter())

# opens up some default metrics out of the box with prometheus
# request count, latency, etc.
metrics = PrometheusMetrics(app)
metrics.info("simple_webapp", "Simple Webapp info", version=BUILD_SHA)

app.logger.addHandler(handler)
app.logger.setLevel(logging.INFO)
# -----------------------------------
#####################################

@app.get("/info")
def info():
    return jsonify(
        app=APP_NAME,
        build_sha=BUILD_SHA,
        timestamp=datetime.now(timezone.utc).isoformat()
    )

@app.get("/healthz")
def healthz():
    return "ok", 200

@app.get("/readyz")
def readyz():
    return "ready", 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
