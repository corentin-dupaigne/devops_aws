const API = "/api";

const MODE_COLORS = {
    work: "#e05a47",
    short_break: "#4a90d9",
    long_break: "#5aa469",
};

const state = {
    mode: "work",
    minutes: 25,
    remaining: 25 * 60,
    running: false,
    intervalId: null,
};

// --- DOM refs ---
const timerEl = document.getElementById("timer");
const statusEl = document.getElementById("status");
const startBtn = document.getElementById("startBtn");
const resetBtn = document.getElementById("resetBtn");
const modeBtns = document.querySelectorAll(".mode");
const ding = document.getElementById("ding");

// --- Timer rendering ---
function format(sec) {
    const m = String(Math.floor(sec / 60)).padStart(2, "0");
    const s = String(sec % 60).padStart(2, "0");
    return `${m}:${s}`;
}

function render() {
    timerEl.textContent = format(state.remaining);
    document.title = `${format(state.remaining)} – Pomodoro`;
}

function setMode(mode, minutes) {
    stop();
    state.mode = mode;
    state.minutes = minutes;
    state.remaining = minutes * 60;
    document.documentElement.style.setProperty("--accent", MODE_COLORS[mode]);
    modeBtns.forEach((b) => b.classList.toggle("active", b.dataset.mode === mode));
    statusEl.textContent = mode === "work" ? "Ready to focus." : "Time for a break.";
    render();
}

// --- Timer control ---
function tick() {
    state.remaining -= 1;
    if (state.remaining <= 0) {
        complete();
        return;
    }
    render();
}

function start() {
    if (state.running) return;
    state.running = true;
    startBtn.textContent = "Pause";
    statusEl.textContent = state.mode === "work" ? "Focusing…" : "On a break…";
    state.intervalId = setInterval(tick, 1000);
}

function stop() {
    state.running = false;
    startBtn.textContent = "Start";
    clearInterval(state.intervalId);
}

function reset() {
    stop();
    state.remaining = state.minutes * 60;
    render();
    statusEl.textContent = "Reset.";
}

async function complete() {
    stop();
    render();
    try { ding.play().catch(() => {}); } catch (e) { /* no-op */ }

    const duration = state.minutes * 60;
    statusEl.textContent = "Session complete! Saving…";
    try {
        await fetch(`${API}/sessions`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ session_type: state.mode, duration_sec: duration }),
        });
        statusEl.textContent = "Session complete! 🎉";
    } catch (err) {
        statusEl.textContent = "Session complete (could not save stats).";
    }
    state.remaining = state.minutes * 60;
    render();
    loadStats();
}

// --- Stats ---
function humanTime(seconds) {
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    if (h > 0) return `${h}h ${m}m`;
    return `${m}m`;
}

async function loadStats() {
    try {
        const res = await fetch(`${API}/stats`);
        if (!res.ok) throw new Error("bad response");
        const data = await res.json();

        document.getElementById("todaySessions").textContent =
            data.today.today_sessions ?? 0;
        document.getElementById("todayTime").textContent =
            humanTime(data.today.today_work_seconds || 0);
        document.getElementById("totalSessions").textContent =
            data.totals.work_sessions ?? 0;
        document.getElementById("totalTime").textContent =
            humanTime(data.totals.work_seconds || 0);

        renderChart(data.last_7_days || []);
    } catch (err) {
        statusEl.textContent = "Stats unavailable (backend offline?).";
    }
}

function renderChart(days) {
    // Build a map of the last 7 days so empty days still show.
    const byDay = {};
    days.forEach((d) => (byDay[d.day] = d.work_seconds));

    const labels = [];
    for (let i = 6; i >= 0; i--) {
        const d = new Date();
        d.setDate(d.getDate() - i);
        const key = d.toISOString().slice(0, 10);
        labels.push({
            key,
            short: d.toLocaleDateString(undefined, { weekday: "short" }),
            seconds: byDay[key] || 0,
        });
    }

    const max = Math.max(...labels.map((l) => l.seconds), 1);
    const chart = document.getElementById("chart");
    chart.innerHTML = "";

    labels.forEach((l) => {
        const wrap = document.createElement("div");
        wrap.className = "bar-wrap";

        const val = document.createElement("span");
        val.className = "bar-val";
        val.textContent = l.seconds ? Math.round(l.seconds / 60) : "";

        const bar = document.createElement("div");
        bar.className = "bar";
        bar.style.height = `${(l.seconds / max) * 100}%`;

        const day = document.createElement("span");
        day.className = "bar-day";
        day.textContent = l.short;

        wrap.append(val, bar, day);
        chart.appendChild(wrap);
    });
}

// --- Events ---
startBtn.addEventListener("click", () => (state.running ? stop() : start()));
resetBtn.addEventListener("click", reset);
modeBtns.forEach((btn) =>
    btn.addEventListener("click", () =>
        setMode(btn.dataset.mode, Number(btn.dataset.minutes))
    )
);

// --- Init ---
render();
loadStats();
