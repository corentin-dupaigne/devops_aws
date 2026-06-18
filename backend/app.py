import os
import time

import mysql.connector
from flask import Flask, jsonify, request
from flask_cors import CORS
from mysql.connector import pooling

app = Flask(__name__)
CORS(app)

DB_CONFIG = {
    "host": os.environ.get("DB_HOST", "localhost"),
    "port": int(os.environ.get("DB_PORT", 3306)),
    "database": os.environ.get("DB_NAME", "pomodoro"),
    "user": os.environ.get("DB_USER", "pomodoro"),
    "password": os.environ.get("DB_PASSWORD", "pomodoro"),
}

VALID_TYPES = {"work", "short_break", "long_break"}

_pool = None


def get_pool():
    """Lazily create the connection pool, retrying while the DB warms up."""
    global _pool
    if _pool is not None:
        return _pool
    last_err = None
    for _ in range(30):
        try:
            _pool = pooling.MySQLConnectionPool(
                pool_name="pomodoro_pool", pool_size=5, **DB_CONFIG
            )
            return _pool
        except mysql.connector.Error as err:
            last_err = err
            time.sleep(2)
    raise RuntimeError(f"Could not connect to MySQL: {last_err}")


def query(sql, params=None, fetch=False):
    conn = get_pool().get_connection()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute(sql, params or ())
        result = cur.fetchall() if fetch else None
        conn.commit()
        last_id = cur.lastrowid
        cur.close()
        return result, last_id
    finally:
        conn.close()


@app.get("/api/health")
def health():
    try:
        query("SELECT 1", fetch=True)
        return jsonify(status="ok", db="up"), 200
    except Exception as exc:  # noqa: BLE001
        return jsonify(status="degraded", db="down", error=str(exc)), 503


@app.post("/api/sessions")
def create_session():
    data = request.get_json(silent=True) or {}
    session_type = data.get("session_type", "work")
    duration_sec = data.get("duration_sec")
    label = data.get("label")

    if session_type not in VALID_TYPES:
        return jsonify(error=f"session_type must be one of {sorted(VALID_TYPES)}"), 400
    if not isinstance(duration_sec, int) or duration_sec <= 0:
        return jsonify(error="duration_sec must be a positive integer"), 400

    _, new_id = query(
        "INSERT INTO sessions (session_type, duration_sec, label) VALUES (%s, %s, %s)",
        (session_type, duration_sec, label),
    )
    return jsonify(id=new_id, session_type=session_type, duration_sec=duration_sec), 201


@app.get("/api/sessions")
def list_sessions():
    rows, _ = query(
        "SELECT id, session_type, duration_sec, label, "
        "DATE_FORMAT(completed_at, '%Y-%m-%dT%H:%i:%s') AS completed_at "
        "FROM sessions ORDER BY completed_at DESC LIMIT 50",
        fetch=True,
    )
    return jsonify(rows)


@app.get("/api/stats")
def stats():
    totals, _ = query(
        "SELECT "
        "COUNT(*) AS total_sessions, "
        "COALESCE(SUM(CASE WHEN session_type='work' THEN 1 ELSE 0 END), 0) AS work_sessions, "
        "COALESCE(SUM(CASE WHEN session_type='work' THEN duration_sec ELSE 0 END), 0) AS work_seconds "
        "FROM sessions",
        fetch=True,
    )

    today, _ = query(
        "SELECT "
        "COUNT(*) AS today_sessions, "
        "COALESCE(SUM(CASE WHEN session_type='work' THEN duration_sec ELSE 0 END), 0) AS today_work_seconds "
        "FROM sessions WHERE DATE(completed_at) = CURDATE()",
        fetch=True,
    )

    daily, _ = query(
        "SELECT DATE_FORMAT(completed_at, '%Y-%m-%d') AS day, "
        "COUNT(*) AS sessions, "
        "COALESCE(SUM(CASE WHEN session_type='work' THEN duration_sec ELSE 0 END), 0) AS work_seconds "
        "FROM sessions "
        "WHERE completed_at >= DATE_SUB(CURDATE(), INTERVAL 6 DAY) "
        "GROUP BY day ORDER BY day",
        fetch=True,
    )

    return jsonify(
        totals=totals[0],
        today=today[0],
        last_7_days=daily,
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
