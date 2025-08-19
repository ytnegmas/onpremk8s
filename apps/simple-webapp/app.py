from datetime import datetime, timezone
import os
from flask import Flask, jsonify

app = Flask(__name__)

APP_NAME = os.getenv("APP_NAME", "simple-webapp")
BUILD_SHA = os.getenv("BUILD_SHA", "unknown")

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
