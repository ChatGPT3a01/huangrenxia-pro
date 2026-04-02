/**
 * 隨身黃仁蝦AI系統 — 跨平台 USB 心跳檢測
 *
 * Usage: node heartbeat.mjs <DEVICE_TOKEN> <CONFIG_ENV_PATH> [interval_minutes]
 *
 * Periodically scans mounted drives to verify the authorized USB is present.
 * Works on Windows, macOS, and Linux.
 *
 * 作者: 曾慶良 主任（阿亮老師）
 * © 2026 阿亮老師 版權所有
 */

import fs from 'fs';
import path from 'path';
import os from 'os';
import { execSync } from 'child_process';

const DEVICE_TOKEN = process.argv[2];
const CONFIG_ENV_PATH = process.argv[3];
const INTERVAL_MIN = parseInt(process.argv[4] || '10', 10);

if (!DEVICE_TOKEN || !CONFIG_ENV_PATH) {
  console.error('Usage: node heartbeat.mjs <DEVICE_TOKEN> <CONFIG_ENV_PATH> [interval_minutes]');
  process.exit(1);
}

/**
 * Get list of mount points / drive roots to scan
 */
function getDriveRoots() {
  const platform = os.platform();
  const roots = [];

  if (platform === 'win32') {
    // Windows: scan drive letters A-Z
    for (let i = 65; i <= 90; i++) {
      const letter = String.fromCharCode(i);
      const root = `${letter}:\\`;
      try {
        fs.accessSync(root, fs.constants.R_OK);
        roots.push(root);
      } catch {}
    }
  } else if (platform === 'darwin') {
    // macOS: scan /Volumes/
    try {
      const entries = fs.readdirSync('/Volumes');
      for (const entry of entries) {
        roots.push(path.join('/Volumes', entry));
      }
    } catch {}
  } else {
    // Linux: scan /media/$USER/ and /mnt/
    const user = os.userInfo().username;
    for (const base of [`/media/${user}`, '/mnt']) {
      try {
        const entries = fs.readdirSync(base);
        for (const entry of entries) {
          roots.push(path.join(base, entry));
        }
      } catch {}
    }
  }

  return roots;
}

/**
 * Read DEVICE_TOKEN from a config.env file
 */
function readTokenFromConfig(configPath) {
  try {
    const text = fs.readFileSync(configPath, 'utf-8');
    for (const line of text.split(/\r?\n/)) {
      const m = line.match(/^DEVICE_TOKEN="?([^"]*)"?/);
      if (m) return m[1];
    }
  } catch {}
  return null;
}

/**
 * Check if the authorized USB is present
 */
function isUsbPresent() {
  const roots = getDriveRoots();

  for (const root of roots) {
    // Check both root and subfolder
    const candidates = [
      root,
      path.join(root, '隨身黃仁蝦AI系統'),
    ];

    for (const candidate of candidates) {
      const configPath = path.join(candidate, 'data', 'config.env');
      const token = readTokenFromConfig(configPath);
      if (token === DEVICE_TOKEN) return true;
    }
  }

  return false;
}

/**
 * Show alert dialog (platform-specific)
 */
function showAlert(message, title) {
  const platform = os.platform();

  try {
    if (platform === 'darwin') {
      execSync(`osascript -e 'display dialog "${message}" with title "${title}" buttons {"OK"} default button "OK" with icon caution'`, { stdio: 'ignore' });
    } else if (platform === 'win32') {
      // Use PowerShell for Windows notification
      const ps = `Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show("${message}", "${title}", "OK", "Warning")`;
      execSync(`powershell -NoProfile -Command "${ps}"`, { stdio: 'ignore' });
    } else {
      // Linux: try zenity, kdialog, or just console
      try {
        execSync(`zenity --warning --title="${title}" --text="${message}" 2>/dev/null`, { stdio: 'ignore' });
      } catch {
        try {
          execSync(`kdialog --sorry "${message}" --title "${title}" 2>/dev/null`, { stdio: 'ignore' });
        } catch {
          console.warn(`[Heartbeat] ${title}: ${message}`);
        }
      }
    }
  } catch {
    console.warn(`[Heartbeat] ${title}: ${message}`);
  }
}

/**
 * Heartbeat check
 */
function heartbeat() {
  if (!isUsbPresent()) {
    showAlert(
      '隨身黃仁蝦AI需要讀取關鍵設定檔以繼續執行，\\n請插入隨身黃仁蝦AI USB',
      '隨身黃仁蝦AI系統'
    );
  }
}

// Run first check after 1 interval, then repeat
console.log(`[Heartbeat] Started. Checking every ${INTERVAL_MIN} minutes for DEVICE_TOKEN.`);
setInterval(heartbeat, INTERVAL_MIN * 60 * 1000);
