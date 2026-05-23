const { spawn } = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const codexHome = path.join(os.homedir(), ".codex");
const logDir = path.join(codexHome, "logs");
const logFile = path.join(logDir, "remote-control-server.log");
fs.mkdirSync(logDir, { recursive: true });

let child = null;
let buffer = "";
let initialized = false;
let requestCounter = 0;
let stopping = false;

function log(message) {
  fs.appendFileSync(logFile, `[${new Date().toISOString()}] ${message}\n`, "utf8");
}

function send(method, params = null, id = undefined) {
  if (!child || !child.stdin.writable) return;
  const payload = { jsonrpc: "2.0", id: id || `${method}-${++requestCounter}`, method, params };
  child.stdin.write(JSON.stringify(payload) + "\n");
  log(`[send] ${method}`);
}

function readStatus(label) {
  send("remoteControl/status/read", null, label || `remote-status-${++requestCounter}`);
}

function handleMessage(obj) {
  if (obj.method === "remoteControl/status/changed" && obj.params) {
    const p = obj.params;
    log(`[remoteControl/status/changed] status=${p.status} server=${p.serverName || ""} environment=${p.environmentId || ""}`);
    return;
  }

  if (obj.id) {
    const data = obj.result || obj.error || {};
    log(`[response] id=${obj.id} ${JSON.stringify(data)}`);
    if (obj.id === "remote-status-before-enable" && /disabled/i.test(JSON.stringify(data))) {
      send("remoteControl/enable", null, "remote-enable");
    }
    return;
  }

  log(`[message] ${JSON.stringify(obj)}`);
}

function start() {
  child = spawn("codex.cmd", ["app-server", "--listen", "stdio://", "--enable", "remote_control"], {
    cwd: os.homedir(),
    env: process.env,
    windowsHide: true,
    shell: true,
    stdio: ["pipe", "pipe", "pipe"],
  });

  initialized = false;
  buffer = "";
  log(`[start] pid=${child.pid}`);

  child.stdout.on("data", (chunk) => {
    buffer += chunk.toString("utf8");
    let idx;
    while ((idx = buffer.indexOf("\n")) >= 0) {
      const line = buffer.slice(0, idx).trim();
      buffer = buffer.slice(idx + 1);
      if (!line) continue;
      try {
        handleMessage(JSON.parse(line));
      } catch {
        log(`[stdout] ${line}`);
      }
    }
  });

  child.stderr.on("data", (chunk) => {
    const text = chunk.toString("utf8").trim();
    if (text) log(`[stderr] ${text}`);
  });

  child.on("exit", (code, signal) => {
    log(`[exit] code=${code} signal=${signal}`);
    child = null;
    if (!stopping) setTimeout(start, 5000);
  });

  setTimeout(() => {
    send("initialize", {
      clientInfo: { name: "codex-remote-control-server", version: "1.0.0" },
      capabilities: { experimentalApi: true },
    }, "initialize");
    initialized = true;
    setTimeout(() => readStatus("remote-status-before-enable"), 1000);
  }, 1000);
}

process.on("SIGTERM", () => {
  stopping = true;
  if (child) child.kill();
  process.exit(0);
});

process.on("SIGINT", () => {
  stopping = true;
  if (child) child.kill();
  process.exit(0);
});

setInterval(() => {
  if (initialized) readStatus();
}, 30000);

log("[boot] remote control helper starting");
start();

