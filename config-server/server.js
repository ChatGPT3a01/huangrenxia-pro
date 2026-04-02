/**
 * 隨身黃仁蝦AI系統 — Config Server
 * Node.js HTTP server (port 18788, 127.0.0.1 only)
 * Provides API for reading/writing openclaw.json and serving web dashboard.
 *
 * 作者: 曾慶良 主任（阿亮老師）
 * 聯絡: 3a01chatgpt@gmail.com
 * © 2026 阿亮老師 版權所有
 */

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 18788;
const HOST = '127.0.0.1';

// Resolve paths relative to project root
const BASE_DIR = path.resolve(__dirname, '..');
const DATA_DIR = path.join(BASE_DIR, 'data');
const CONFIG_ENV = path.join(DATA_DIR, 'config.env');
const OPENCLAW_CONFIG = path.join(DATA_DIR, '.openclaw', 'openclaw.json');
const PUBLIC_DIR = path.join(__dirname, 'public');

// --- Helpers ---

function parseConfigEnv() {
  if (!fs.existsSync(CONFIG_ENV)) return {};
  const text = fs.readFileSync(CONFIG_ENV, 'utf-8');
  const result = {};
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^([A-Z_][A-Z0-9_]*)="?(.*?)"?\s*$/);
    if (m) result[m[1]] = m[2];
  }
  return result;
}

function saveConfigEnv(updates) {
  let text = fs.existsSync(CONFIG_ENV) ? fs.readFileSync(CONFIG_ENV, 'utf-8') : '';
  for (const [key, value] of Object.entries(updates)) {
    const escaped = String(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"');
    const line = `${key}="${escaped}"`;
    const re = new RegExp(`^${key}=.*$`, 'm');
    if (re.test(text)) {
      text = text.replace(re, line);
    } else {
      text += (text.endsWith('\n') ? '' : '\n') + line + '\n';
    }
  }
  fs.writeFileSync(CONFIG_ENV, '\uFEFF' + text, 'utf-8');
}

function readOpenClawConfig() {
  if (!fs.existsSync(OPENCLAW_CONFIG)) return null;
  return JSON.parse(fs.readFileSync(OPENCLAW_CONFIG, 'utf-8'));
}

function writeOpenClawConfig(data) {
  const dir = path.dirname(OPENCLAW_CONFIG);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(OPENCLAW_CONFIG, JSON.stringify(data, null, 2), 'utf-8');
}

function getMimeType(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  const map = {
    '.html': 'text/html; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.js': 'application/javascript; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
  };
  return map[ext] || 'application/octet-stream';
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', c => chunks.push(c));
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf-8')));
    req.on('error', reject);
  });
}

function jsonResponse(res, status, data) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(data));
}

// --- Server ---

const server = http.createServer(async (req, res) => {
  // CORS for local development
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }

  const url = new URL(req.url, `http://${HOST}:${PORT}`);

  // API routes
  if (url.pathname === '/api/config' && req.method === 'GET') {
    const cfg = parseConfigEnv();
    // Mask sensitive values for display
    const masked = { ...cfg };
    for (const k of Object.keys(masked)) {
      if (k.endsWith('_KEY') || k === 'MASTER_PASSWORD') {
        if (masked[k]) masked[k] = masked[k].slice(0, 6) + '***';
      }
    }
    return jsonResponse(res, 200, { ok: true, config: masked, raw: cfg });
  }

  if (url.pathname === '/api/config' && req.method === 'POST') {
    try {
      const body = JSON.parse(await readBody(req));
      if (body.updates && typeof body.updates === 'object') {
        saveConfigEnv(body.updates);
        return jsonResponse(res, 200, { ok: true });
      }
      return jsonResponse(res, 400, { ok: false, error: 'Missing updates object' });
    } catch (e) {
      return jsonResponse(res, 400, { ok: false, error: e.message });
    }
  }

  if (url.pathname === '/api/openclaw' && req.method === 'GET') {
    const data = readOpenClawConfig();
    return jsonResponse(res, 200, { ok: true, config: data });
  }

  if (url.pathname === '/api/openclaw' && req.method === 'POST') {
    try {
      const body = JSON.parse(await readBody(req));
      writeOpenClawConfig(body);
      return jsonResponse(res, 200, { ok: true });
    } catch (e) {
      return jsonResponse(res, 400, { ok: false, error: e.message });
    }
  }

  if (url.pathname === '/api/status' && req.method === 'GET') {
    const cfg = parseConfigEnv();
    const nodeExists = fs.existsSync(path.join(BASE_DIR, 'app', 'runtime', 'node-win-x64', 'node.exe'));
    const openclawExists = fs.existsSync(path.join(BASE_DIR, 'app', 'core', 'node_modules', 'openclaw', 'openclaw.mjs'));
    const keyChecks = ['OPENAI_API_KEY', 'ANTHROPIC_API_KEY', 'GEMINI_API_KEY', 'DEEPSEEK_API_KEY',
      'GROQ_API_KEY', 'QWEN_API_KEY', 'OPENROUTER_API_KEY', 'MISTRAL_API_KEY', 'MINIMAX_API_KEY'];
    const keyCount = keyChecks.filter(k => cfg[k]).length;

    // Check gateway
    let gatewayUp = false;
    const port = cfg.OPENCLAW_PORT || '18789';
    try {
      await new Promise((resolve, reject) => {
        const r = http.get(`http://127.0.0.1:${port}/`, { timeout: 2000 }, (resp) => {
          gatewayUp = resp.statusCode < 500;
          resolve();
        });
        r.on('error', () => resolve());
        r.on('timeout', () => { r.destroy(); resolve(); });
      });
    } catch {}

    return jsonResponse(res, 200, {
      ok: true,
      status: {
        nodeInstalled: nodeExists,
        openclawInstalled: openclawExists,
        gatewayRunning: gatewayUp,
        gatewayPort: port,
        apiKeyCount: keyCount,
        installMode: cfg.INSTALL_MODE || 'portable',
        engineType: cfg.ENGINE_TYPE || 'openclaw',
      }
    });
  }

  // Static files
  let filePath = path.join(PUBLIC_DIR, url.pathname === '/' ? 'index.html' : url.pathname);
  filePath = path.normalize(filePath);

  // Security: prevent path traversal
  if (!filePath.startsWith(PUBLIC_DIR)) {
    res.writeHead(403); res.end('Forbidden'); return;
  }

  if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
    res.writeHead(200, { 'Content-Type': getMimeType(filePath) });
    fs.createReadStream(filePath).pipe(res);
  } else {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not Found');
  }
});

server.listen(PORT, HOST, () => {
  console.log(`Config Server running at http://${HOST}:${PORT}/`);
});
