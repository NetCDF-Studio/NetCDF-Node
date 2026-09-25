#!/usr/bin/env node
/**
 * NetCDF Studio Node CLI
 * Management interface for compute node agent
 */

import { spawn, execSync } from 'child_process';
import { existsSync, readFileSync } from 'fs';
import { homedir } from 'os';
import { join } from 'path';

const CONFIG_DIR = join(homedir(), '.config', 'netcdf-studio');
const CONFIG_FILE = join(CONFIG_DIR, 'config.env');
const LOG_DIR = join(homedir(), 'Library', 'Logs', 'netcdf-studio');
const SERVICE_LOG = join(LOG_DIR, 'service.log');
const PLIST_FILE = join(homedir(), 'Library', 'LaunchAgents', 'com.netcdf.studio.node.plist');

// Parse config.env
function loadConfig() {
  if (!existsSync(CONFIG_FILE)) {
    return null;
  }

  const content = readFileSync(CONFIG_FILE, 'utf-8');
  const config = {};

  content.split('\n').forEach(line => {
    const trimmed = line.trim();
    if (trimmed && !trimmed.startsWith('#')) {
      const [key, ...valueParts] = trimmed.split('=');
      if (key && valueParts.length > 0) {
        config[key.trim()] = valueParts.join('=').trim().replace(/^["']|["']$/g, '');
      }
    }
  });

  return config;
}

// Check if service is running
function isRunning() {
  try {
    const result = execSync('launchctl list com.netcdf.studio.node 2>/dev/null', { encoding: 'utf-8' });
    return result.includes('PID');
  } catch {
    return false;
  }
}

// Get PID
function getPID() {
  try {
    const result = execSync('launchctl list com.netcdf.studio.node 2>/dev/null', { encoding: 'utf-8' });
    const match = result.match(/PID\s*=\s*(\d+)/);
    return match ? match[1] : null;
  } catch {
    return null;
  }
}

// Actions
function start() {
  if (isRunning()) {
    console.log('✓ Service already running');
    const pid = getPID();
    if (pid) console.log(`  PID: ${pid}`);
    return;
  }

  try {
    if (existsSync(PLIST_FILE)) {
      execSync(`launchctl load "${PLIST_FILE}"`, { stdio: 'inherit' });
      console.log('✓ Service started');
      const pid = getPID();
      if (pid) console.log(`  PID: ${pid}`);
    } else {
      console.error('✗ Service not installed. Run the installer first:');
      console.error('  curl -fsSL https://netcdfstudio.soumalya.in/netcdf-studio-node.sh | bash');
    }
  } catch (err) {
    console.error('✗ Failed to start service:', err.message);
  }
}

function stop() {
  if (!existsSync(PLIST_FILE)) {
    console.log('Service not installed');
    return;
  }

  try {
    execSync(`launchctl unload "${PLIST_FILE}" 2>/dev/null`, { stdio: 'pipe' });
    console.log('✓ Service stopped');
  } catch {
    console.log('✓ Service was not running');
  }
}

function restart() {
  stop();
  setTimeout(() => start(), 1000);
}

function status() {
  const config = loadConfig();

  if (!config) {
    console.log('✗ Not configured');
    console.log('\nRun the installer first:');
    console.log('  curl -fsSL https://netcdfstudio.soumalya.in/netcdf-studio-node.sh | bash');
    return;
  }

  console.log('Configuration:');
  console.log(`  Server URL  : ${config.NETCDF_STUDIO_SERVER_URL || 'not set'}`);
  console.log(`  Config Dir  : ${CONFIG_DIR}`);
  console.log(`  Log Dir     : ${LOG_DIR}`);
  console.log();

  const running = isRunning();
  if (running) {
    const pid = getPID();
    console.log('✓ Service Running');
    if (pid) console.log(`  PID: ${pid}`);
  } else {
    console.log('✗ Service Stopped');
  }

  console.log();
  console.log('Management Commands:');
  console.log('  netcdf-node start    - Start the service');
  console.log('  netcdf-node stop     - Stop the service');
  console.log('  netcdf-node restart  - Restart the service');
  console.log('  netcdf-node logs     - View live logs');
}

function logs() {
  if (!existsSync(SERVICE_LOG)) {
    console.log('No logs found');
    return;
  }

  console.log('Tailing logs (Ctrl+C to stop)...\n');
  const tail = spawn('tail', ['-f', SERVICE_LOG], { stdio: 'inherit' });

  tail.on('error', err => {
    console.error('Failed to tail logs:', err.message);
  });
}

function connect() {
  const config = loadConfig();

  if (!config || !config.NETCDF_STUDIO_SERVER_URL || !config.NETCDF_STUDIO_API_TOKEN) {
    console.error('✗ Not configured. Run the installer first:');
    console.error('  curl -fsSL https://netcdfstudio.soumalya.in/netcdf-studio-node.sh | bash');
    process.exit(1);
  }

  console.log('Starting netcdf-studio-node agent...\n');

  const agent = spawn('node', [join(new URL(import.meta.url).pathname, '..', 'agent.js'), '--server', config.NETCDF_STUDIO_SERVER_URL, '--token', config.NETCDF_STUDIO_API_TOKEN], { stdio: 'inherit' });

  agent.on('error', err => {
    console.error('Failed to start agent:', err.message);
    process.exit(1);
  });

  agent.on('exit', code => {
    process.exit(code || 0);
  });
}

// Help
function help() {
  console.log(`
NetCDF Studio Node CLI

Usage:
  netcdf-node <command>

Commands:
  start      Start the background service
  stop       Stop the background service
  restart    Restart the background service
  status     Show configuration and status
  logs       Tail service logs (Ctrl+C to stop)
  connect    Run agent in foreground (for debugging)
  help       Show this help message

Examples:
  netcdf-node status
  netcdf-node start
  netcdf-node logs
`);
}

// Main
const command = process.argv[2] || 'help';

switch (command) {
  case 'start':
    start();
    break;
  case 'stop':
    stop();
    break;
  case 'restart':
    restart();
    break;
  case 'status':
    status();
    break;
  case 'logs':
    logs();
    break;
  case 'connect':
    connect();
    break;
  case 'help':
  case '--help':
  case '-h':
    help();
    break;
  default:
    console.error(`Unknown command: ${command}`);
    console.error('Run "netcdf-node help" for usage');
    process.exit(1);
}
