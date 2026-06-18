# 🍅 Pomodoro App

A simple Pomodoro timer with stats tracking, built as three Docker services:

| Service    | Stack                         | Port  |
|------------|-------------------------------|-------|
| `frontend` | Vanilla HTML/CSS/JS + Nginx   | 8080  |
| `backend`  | Flask (Gunicorn) REST API     | 5000  |
| `db`       | MySQL 8                       | 3306  |

Nginx serves the static frontend and reverse-proxies `/api/*` to the Flask
backend, so the browser only ever talks to one origin.

## Run it

```bash
cp .env.example .env       # optional: customise credentials
docker compose up --build
```

Then open <http://localhost:8080>.

Stop with `docker compose down` (add `-v` to also wipe the database).

## How it works

- Pick a mode (Focus / Short Break / Long Break) and hit **Start**.
- When a timer reaches zero, the frontend POSTs the completed session to the
  backend, which stores it in MySQL.
- The **Stats** panel shows today's focus count/time, all-time totals, and a
  7-day bar chart.

## API

| Method | Endpoint         | Description                                  |
|--------|------------------|----------------------------------------------|
| GET    | `/api/health`    | Service + DB health check                    |
| POST   | `/api/sessions`  | Record a session `{session_type,duration_sec}` |
| GET    | `/api/sessions`  | Last 50 sessions                             |
| GET    | `/api/stats`     | Aggregated totals, today, last 7 days        |

`session_type` is one of `work`, `short_break`, `long_break`.

### Example

```bash
curl -X POST http://localhost:8080/api/sessions \
  -H 'Content-Type: application/json' \
  -d '{"session_type":"work","duration_sec":1500}'

curl http://localhost:8080/api/stats
```

## Project layout

```
.
├── docker-compose.yml
├── .env.example
├── backend/          # Flask API
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile
├── frontend/         # Static UI served by Nginx
│   ├── index.html
│   ├── style.css
│   ├── app.js
│   ├── nginx.conf
│   └── Dockerfile
└── db/
    └── init.sql      # Schema, loaded on first boot
```
