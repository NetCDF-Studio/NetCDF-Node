# NetCDF Studio Node

Compute node agent for NetCDF Studio — lends your machine's CPU to process climate data jobs over WebSocket.

## Quick Start

### One-Liner Installation

```bash
curl -fsSL https://your-server.com/install.sh | bash -s -- \
  --server https://your-server.com \
  --token YOUR_API_TOKEN
```

### What It Does

1. ✅ Detects OS (Linux, macOS, Windows via Git Bash/WSL)
2. ✅ Installs Node.js if not present
3. ✅ Installs netcdf-studio-node globally
4. ✅ Configures with your server and token
5. ✅ Runs as background service (systemd/launchd)
6. ✅ Starts on boot

## Management

After installation, use the simple CLI:

```bash
netcdf-node status     # Show configuration and service status
netcdf-node start      # Start the background service
netcdf-node stop       # Stop the background service
netcdf-node restart    # Restart the service
netcdf-node logs       # Tail service logs in real-time
netcdf-node connect    # Run in foreground (for debugging)
```

## Requirements

- Node.js 18+ (auto-installed if not present)
- Internet connection to server
- API token from your NetCDF Studio admin panel

## Platform Support

| Platform | Service Manager | Auto-start |
|----------|----------------|------------|
| Linux (systemd) | systemd | ✅ Yes |
| Linux (no systemd) | Background process | ⚠️ Manual |
| macOS | launchd | ✅ Yes |
| Windows (Git Bash) | Background process | ⚠️ Manual |
| WSL | Background process | ⚠️ Manual |

## Installation Methods

### Method 1: One-Liner (Recommended)

```bash
curl -fsSL https://your-server.com/install.sh | bash -s -- \
  --server https://your-server.com \
  --token YOUR_TOKEN
```

### Method 2: Manual Installation

```bash
# Clone and install
git clone https://github.com/netcdf-studio/netcdf-node.git
cd netcdf-node
npm install --production
npm link

# Configure
netcdf-studio-node --server https://your-server.com --token YOUR_TOKEN

# Or use the CLI
netcdf-node start
```

### Method 3: From npm (when published)

```bash
npm install -g netcdf-studio-node
netcdf-studio-node --server https://your-server.com --token YOUR_TOKEN
```

## Configuration

Configuration is stored in:
- **Linux**: `~/.config/netcdf-studio/config.env`
- **macOS**: `~/.config/netcdf-studio/config.env`
- **Windows**: `%USERPROFILE%\.config\netcdf-studio\config.env`

Example config:

```bash
NETCDF_STUDIO_SERVER_URL="https://your-server.com"
NETCDF_STUDIO_API_TOKEN="your-token-here"
LOG_LEVEL=info
LOG_DIR=/Users/you/Library/Logs/netcdf-studio
MAX_CONCURRENT_JOBS=2
ENABLE_GPU=false
```

## Logs

- **Linux**: `/var/log/netcdf-studio/service.log` or `~/.local/share/netcdf-studio/logs/`
- **macOS**: `~/Library/Logs/netcdf-studio/service.log`
- **Windows**: `%USERPROFILE%\.netcdf-studio\logs\service.log`

View live logs:
```bash
netcdf-node logs
```

## Uninstallation

```bash
# Stop and remove service
netcdf-node stop

# Remove global installation
npm uninstall -g netcdf-studio-node

# Remove configuration (optional)
rm -rf ~/.config/netcdf-studio

# Remove logs (optional)
rm -rf ~/Library/Logs/netcdf-studio  # macOS
rm -rf ~/.local/share/netcdf-studio  # Linux
```

## Troubleshooting

### Check Service Status

```bash
netcdf-node status
```

### View Logs

```bash
netcdf-node logs
```

### Connection Issues

1. Verify server URL is correct
2. Check if token is valid (get new token from admin panel)
3. Ensure firewall allows WebSocket connections
4. Check server is running and accessible

### Permission Issues

On Linux/macOS, if you get permission errors:
```bash
# For system-wide installation
sudo npm install -g netcdf-studio-node

# Or use a user-level npm prefix
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'
# Add to ~/.bashrc or ~/.zshrc:
export PATH=~/.npm-global/bin:$PATH
```

### Port/Network Issues

The agent connects to the server via WebSocket (usually port 443 for HTTPS). Ensure your firewall allows outbound connections.

## Development

### Building from Source

```bash
git clone https://github.com/netcdf-studio/netcdf-node.git
cd netcdf-node
npm install
npm link
```

### Running in Development

```bash
# Run once with config
netcdf-studio-node --server http://localhost:3000 --token dev-token

# Or use the CLI
netcdf-node connect
```

## Architecture

```
┌─────────────────┐              ┌──────────────────┐
│  NetCDF Studio  │              │  Compute Node    │
│     Server      │◄────────────►│    (Agent)       │
│                 │   WebSocket  │                  │
└─────────────────┘              └──────────────────┘
        │                                 │
        │                                 │
        ▼                                 ▼
  ┌─────────────┐                 ┌──────────────┐
  │  Job Queue  │                 │  Job Runner  │
  └─────────────┘                 └──────────────┘
                                          │
                                          ▼
                                  ┌──────────────┐
                                  │ Python/CPU   │
                                  │ Processing   │
                                  └──────────────┘
```

## Security

- Tokens are single-use and should be kept secure
- Connections use HTTPS/WSS by default
- Agent only connects to configured server
- No inbound ports required (outbound WebSocket only)

## License

MIT

## Support

- GitHub Issues: https://github.com/netcdf-studio/netcdf-node/issues
- Documentation: https://docs.netcdfstudio.com
- Email: support@netcdfstudio.com
