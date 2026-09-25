#!/usr/bin/env node
/**
 * NetCDF Studio compute node agent
 * ================================
 * Lends this machine's CPU (and optionally disk) to a NetCDF Studio server.
 * Runs on macOS, Linux and Windows — it only needs Node 18+ and the same Python
 * environment the server's workers use.
 *
 *   netcdf-studio-node --server https://netcdfstudio.soumalya.in --token <token>
 *
 * IT DIALS OUT, NEVER IN. This machine is almost certainly behind NAT, so the
 * server cannot reach it. The agent opens one outbound WebSocket and receives
 * work on it: no port forwarding, no firewall changes, nothing listening.
 *
 * WHAT IT NEVER DOES:
 *   - Write a credential to disk. Job env (a Copernicus token, say) is held in
 *     memory for the life of one child process and passed via the environment,
 *     never argv — argv is world-readable through /proc.
 *   - Run user-supplied correction modules unless the server says this node was
 *     explicitly opted in by an admin. Otherwise "lend some CPU" would quietly
 *     mean "execute a stranger's Python on my laptop".
 *   - Keep job data. Each job gets a scratch directory that is removed when it
 *     finishes, however it finishes.
 */

import fs from "fs";
import os from "os";
import path from "path";
import { spawn, execFileSync } from "child_process";
import { pipeline } from "stream/promises";
import { fileURLToPath, pathToFileURL } from "url";
import { createRequire } from "module";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const HEARTBEAT_MS = 20_000;

function parseArgs(argv) {
  const out = { concurrency: null };
  for (let i = 0; i < argv.length; i++) {
    const [flag, inline] = argv[i].split("=");
    const take = () => (inline !== undefined ? inline : argv[++i]);
    switch (flag) {
      case "--server": out.server = take(); break;
      case "--token": out.token = take(); break;
      case "--python": out.python = take(); break;
      case "--worker": out.worker = take(); break;
      case "--name": out.name = take(); break;
      case "--concurrency": out.concurrency = Number(take()); break;
      case "--help": case "-h": out.help = true; break;
      default:
        if (flag.startsWith("--")) throw new Error(`Unknown option: ${flag}`);
    }
  }
  return out;
}

const USAGE = `
NetCDF Studio compute node agent

  netcdf-studio-node --server <url> --token <node-token> [options]

Required
  --server <url>        Base URL of the NetCDF Studio server
  --token <token>       Node token, shown once when the node was enrolled
                        (or set NETCDF_NODE_TOKEN)

Options
  --python <path>       Python interpreter (default: python3, or python on Windows)
  --worker <path>       Path to worker_entry.py (default: ../python/worker_entry.py)
  --name <label>        Display name reported to the server
  --concurrency <n>     Max simultaneous jobs (informational; the server enforces)

The token is a credential. Prefer NETCDF_NODE_TOKEN over --token so it does not
land in your shell history or this machine's process list.
`;

function detectPython(explicit) {
  if (explicit) return explicit;
  return process.platform === "win32" ? "python" : "python3";
}

function pythonVersion(bin) {
  try {
    return execFileSync(bin, ["--version"], { encoding: "utf8" }).trim();
  } catch {
    return null;
  }
}

function capabilities(python) {
  let freeDiskBytes = null;
  try {
    // statfsSync is Node 18.15+; absence is not worth failing over.
    const st = fs.statfsSync?.(os.tmpdir());
    if (st) freeDiskBytes = st.bavail * st.bsize;
  } catch { /* best effort */ }

  return {
    cores: os.cpus()?.length || 1,
    totalMemBytes: os.totalmem(),
    freeDiskBytes,
    python: pythonVersion(python),
    agentVersion: "1.0.0",
    node: process.version,
  };
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (opts.help) { process.stdout.write(USAGE); return 0; }

  const server = (opts.server || process.env.NETCDF_NODE_SERVER || "").replace(/\/+$/, "");
  const token = opts.token || process.env.NETCDF_NODE_TOKEN || "";
  if (!server || !token) {
    process.stderr.write(USAGE);
    process.stderr.write("\nERROR: --server and --token are both required.\n");
    return 2;
  }

  const python = detectPython(opts.python || process.env.NETCDF_NODE_PYTHON);
  const worker = path.resolve(
    opts.worker || process.env.NETCDF_NODE_WORKER ||
    path.join(__dirname, "..", "python", "worker_entry.py")
  );

  if (!fs.existsSync(worker)) {
    process.stderr.write(
      `ERROR: worker_entry.py not found at ${worker}\n` +
      "Pass --worker with the path to your NetCDF Studio python/ directory.\n"
    );
    return 2;
  }
  const caps = capabilities(python);
  if (!caps.python) {
    process.stderr.write(
      `ERROR: could not run '${python}'. Install Python 3 or pass --python.\n`
    );
    return 2;
  }

  // Resolve socket.io-client relative to this file so global installs work.
  let io;
  try {
    const _require = createRequire(import.meta.url);
    const sioPath = pathToFileURL(_require.resolve("socket.io-client")).href;
    ({ io } = await import(sioPath));
  } catch {
    process.stderr.write(
      "ERROR: socket.io-client is not installed.\n  Run: npm install -g socket.io-client\n"
    );
    return 2;
  }

  const socket = io(`${server}/agent`, {
    auth: {
      token,
      platform: `${process.platform}-${process.arch}`,
      name: opts.name || os.hostname(),
      capabilities: caps,
    },
    transports: ["websocket"],
    reconnection: true,
    reconnectionDelay: 2_000,
    reconnectionDelayMax: 30_000,
  });

  const running = new Map(); // jobId -> { child, scratch }
  let allowCustomModules = false;
  let heartbeat = null;

  const log = (msg) => process.stdout.write(`[agent] ${msg}\n`);

  socket.on("connect", () => {
    log(`connected to ${server} as ${opts.name || os.hostname()} (${caps.cores} cores)`);
    clearInterval(heartbeat);
    heartbeat = setInterval(() => socket.emit("heartbeat"), HEARTBEAT_MS);
    heartbeat.unref?.();
  });

  socket.on("registered", (info) => {
    allowCustomModules = info?.allowCustomModules === true;
    log(`registered as ${info?.nodeId}; custom modules ${allowCustomModules ? "ALLOWED" : "refused"}`);
  });

  socket.on("connect_error", (err) => {
    // Authentication failures are terminal: retrying a rejected token forever
    // just hammers the server and hides the real problem from the operator.
    if (/authentication/i.test(err?.message || "")) {
      process.stderr.write(`\nERROR: ${err.message}\nThe node token was rejected. Re-enrol this node.\n`);
      socket.close();
      process.exitCode = 3;
      return;
    }
    log(`connection failed (${err?.message || err}); retrying`);
  });

  socket.on("disconnect", (reason) => {
    clearInterval(heartbeat);
    log(`disconnected (${reason})`);
  });

  socket.on("cancel_job", ({ jobId }) => {
    const entry = running.get(jobId);
    if (!entry) return;
    log(`cancelling ${jobId}`);
    entry.cancelled = true;
    entry.child?.kill("SIGTERM");
  });

  socket.on("run_job", async (spec) => {
    const { jobId } = spec || {};
    if (!jobId) return;
    if (running.has(jobId)) return;

    const scratch = fs.mkdtempSync(path.join(os.tmpdir(), `netcdf-job-${jobId}-`));
    const entry = { child: null, scratch, cancelled: false };
    running.set(jobId, entry);

    const cleanup = () => {
      running.delete(jobId);
      // Job data never outlives the job.
      try { fs.rmSync(scratch, { recursive: true, force: true }); } catch { /* best effort */ }
    };

    try {
      if (!allowCustomModules && /--module|execute_module/.test(JSON.stringify(spec.args || []))) {
        throw new Error("This node is not permitted to run custom correction modules.");
      }

      // 1. Stage inputs. Placeholders in args are replaced with local paths, so
      //    the server's storage layout is never exposed to this machine.
      const args = [...(spec.args || [])];
      for (const input of spec.inputs || []) {
        const dest = path.join(scratch, input.name || `input_${input.index}.zip`);
        log(`${jobId}: fetching input ${input.index}`);
        await download(input.url, dest);
        replaceAll(args, `@@INPUT${input.index}@@`, dest);
      }

      const outputLocal = spec.output ? path.join(scratch, spec.output.name) : null;
      if (outputLocal) replaceAll(args, "@@OUTPUT@@", outputLocal);

      // 2. Run the SAME worker the server runs, so output is identical.
      log(`${jobId}: running`);
      const code = await runWorker({
        python, worker, args, scratch, entry,
        // Credentials arrive over the authenticated socket and go into the
        // child's environment. Never argv, never disk.
        env: spec.env || {},
        onEvent: (event) => socket.emit("job_event", { jobId, event }),
      });

      if (entry.cancelled) {
        socket.emit("job_complete", { jobId, code, cancelled: true });
        cleanup();
        return;
      }
      if (code !== 0) throw new Error(`Worker exited with code ${code}`);

      // 3. Return the result. The worker writes gzip, so prefer that name.
      if (spec.output && outputLocal) {
        const produced = fs.existsSync(`${outputLocal}.gz`) ? `${outputLocal}.gz` : outputLocal;
        if (fs.existsSync(produced)) {
          log(`${jobId}: uploading ${path.basename(produced)}`);
          await upload(spec.output.url, produced);
        }
      }

      socket.emit("job_complete", { jobId, code: 0, cancelled: false });
      log(`${jobId}: done`);
    } catch (err) {
      log(`${jobId}: failed — ${err.message}`);
      socket.emit("job_failed", { jobId, error: err.message });
    } finally {
      cleanup();
    }
  });

  // ── Storage role: hold cold files for the server ────────────────────────
  // Files live under a dedicated directory keyed by the server's own key, so a
  // machine acting as both compute and storage never mixes the two. Nothing is
  // deleted here on shutdown: the server treats this as the cold copy, and
  // discarding it because the agent restarted would lose a user's data.
  const archiveDir = path.join(
    process.env.NETCDF_NODE_STORAGE || path.join(os.homedir(), ".netcdf-studio", "archive")
  );
  const archivePath = (key) =>
    path.join(archiveDir, key.replace(/[^a-zA-Z0-9._/-]/g, "_").replace(/\.\./g, "_"));

  socket.on("store_file", async ({ transferId, key, url }) => {
    try {
      const dest = archivePath(key);
      fs.mkdirSync(path.dirname(dest), { recursive: true });
      log(`archiving ${key}`);
      await download(url, dest);
      const bytes = fs.statSync(dest).size;
      if (!bytes) throw new Error("Received an empty file.");
      socket.emit("archive_result", { transferId, ok: true, bytes });
      log(`archived ${key} (${(bytes / 1048576).toFixed(1)} MB)`);
    } catch (err) {
      // Reporting failure matters: the server only deletes its own copy after
      // this confirms success.
      socket.emit("archive_result", { transferId, ok: false, error: err.message });
      log(`archive failed for ${key} — ${err.message}`);
    }
  });

  socket.on("fetch_file", async ({ transferId, key, url }) => {
    try {
      const src = archivePath(key);
      if (!fs.existsSync(src)) throw new Error("This node does not hold that file.");
      log(`restoring ${key}`);
      await upload(url, src);
      socket.emit("restore_result", { transferId, ok: true });
      log(`restored ${key}`);
    } catch (err) {
      socket.emit("restore_result", { transferId, ok: false, error: err.message });
      log(`restore failed for ${key} — ${err.message}`);
    }
  });

  const shutdown = () => {
    log("shutting down; abandoning in-flight jobs for the server to re-queue");
    for (const [, entry] of running) entry.child?.kill("SIGTERM");
    socket.close();
    process.exit(0);
  };
  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);

  // Hold the process open on the socket.
  return new Promise(() => {});
}

function replaceAll(args, placeholder, value) {
  for (let i = 0; i < args.length; i++) {
    if (args[i] === placeholder) args[i] = value;
  }
}

async function download(url, dest) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Input fetch failed: HTTP ${res.status}`);
  await pipeline(res.body, fs.createWriteStream(dest));
}

async function upload(url, filePath) {
  const size = fs.statSync(filePath).size;
  const res = await fetch(url, {
    method: "POST",
    body: fs.createReadStream(filePath),
    duplex: "half", // required by undici when streaming a request body
    headers: { "Content-Type": "application/octet-stream", "Content-Length": String(size) },
  });
  if (!res.ok) throw new Error(`Output upload failed: HTTP ${res.status}`);
}

/**
 * Run worker_entry.py and forward its newline-delimited JSON events.
 *
 * Identical parsing to the server's spawnPython(): one JSON object per line on
 * stdout, anything unparseable surfaced as an info event rather than dropped.
 */
function runWorker({ python, worker, args, env, entry, onEvent }) {
  return new Promise((resolve, reject) => {
    const child = spawn(python, [worker, ...args], {
      env: { ...process.env, ...env },
    });
    entry.child = child;

    let buffer = "";
    child.stdout.on("data", (chunk) => {
      buffer += chunk.toString();
      const lines = buffer.split("\n");
      buffer = lines.pop() || "";
      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed) continue;
        try {
          onEvent(JSON.parse(trimmed));
        } catch {
          onEvent({ event: "info", message: trimmed });
        }
      }
    });

    child.stderr.on("data", (chunk) => {
      const message = chunk.toString().trim();
      if (message) process.stderr.write(`[worker] ${message}\n`);
    });

    child.on("error", reject);
    child.on("close", (code) => resolve(code ?? 1));
  });
}

main()
  .then((code) => { if (typeof code === "number") process.exitCode = code; })
  .catch((err) => {
    process.stderr.write(`\n${err.stack || err.message}\n`);
    process.exitCode = 1;
  });
