#!/bin/bash

###################################################################################################
# NetCDF Studio Node - Universal Auto-Installer & Runner
###################################################################################################
#
# This script automatically:
#   1. Detects OS (Linux, macOS, Windows via Git Bash/WSL)
#   2. Installs Node.js if not present
#   3. Installs netcdf-studio-node if not present
#   4. Configures with provided server and token
#   5. Runs as background service (systemd, launchd, or background process)
#   6. Starts on boot (if supported)
#
# Usage:
#   ./netcdf-studio-node.sh --server URL --token TOKEN
#
# Example:
#   ./netcdf-studio-node.sh --server http://admin.example.com:3000 --token abc123...
#
# One-liner installation:
#   curl -fsSL http://admin.localhost:3000/netcdf-studio-node.sh | bash -s -- --server URL --token TOKEN
#
###################################################################################################

set -e
trap 'error_exit "An error occurred on line $LINENO"' ERR

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default values
NETCDF_STUDIO_VERSION="latest"
NODE_MIN_VERSION="18.0.0"
GITHUB_REPO="https://github.com/netcdf-studio/netcdf-node.git"
GITHUB_BRANCH="main"
CONFIG_DIR=""
LOG_DIR=""
SERVER_URL=""
API_TOKEN=""
OS_TYPE=""
IS_WINDOWS_GIT_BASH=false
IS_WSL=false

# Logging
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[⚠]${NC} $1"; }
log_error()   { echo -e "${RED}[✗]${NC} $1"; }
log_step()    { echo -e "${CYAN}[STEP]${NC} $1"; }

error_exit() {
    log_error "$1"
    exit 1
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --server)
                SERVER_URL="$2"
                shift 2
                ;;
            --token)
                API_TOKEN="$2"
                shift 2
                ;;
            --version)
                NETCDF_STUDIO_VERSION="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                error_exit "Unknown option: $1\nUse --help for usage information."
                ;;
        esac
    done

    if [[ -z "$SERVER_URL" ]] || [[ -z "$API_TOKEN" ]]; then
        error_exit "Missing required arguments.\nUsage: $0 --server URL --token TOKEN\nRun with --help for more information."
    fi
}

show_help() {
    cat << EOF
NetCDF Studio Node - Universal Auto-Installer & Runner

USAGE:
    $0 --server URL --token TOKEN

OPTIONS:
    --server URL       NetCDF Studio server URL (required)
    --token TOKEN      API token for authentication (required)
    --version VERSION  Install specific version (default: latest)
    --help, -h         Show this help message

EXAMPLES:
    # Basic usage
    $0 --server http://admin.example.com:3000 --token abc123...

    # Install specific version
    $0 --server http://admin.example.com:3000 --token abc123... --version 2.0.0

ONE-LINER INSTALLATION:
    curl -fsSL http://admin.localhost:3000/netcdf-studio-node.sh | bash -s -- --server URL --token TOKEN

SUPPORTED OPERATING SYSTEMS:
    ✓ Linux (Ubuntu, Debian, CentOS, RHEL, Fedora, etc.)
    ✓ macOS (via Homebrew or nvm)
    ✓ Windows (via Git Bash or WSL)

EOF
}

# Detect operating system
detect_os() {
    log_step "Detecting operating system..."

    # Check for WSL
    if grep -qi microsoft /proc/version 2>/dev/null; then
        IS_WSL=true
        log_info "Detected: Windows Subsystem for Linux (WSL)"
    fi

    # Check for Git Bash on Windows
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        IS_WINDOWS_GIT_BASH=true
        OS_TYPE="windows"
        log_info "Detected: Windows (Git Bash)"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS_TYPE="macos"
        log_info "Detected: macOS"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS_TYPE="linux"

        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            log_info "Detected: $PRETTY_NAME"
        else
            log_info "Detected: Linux"
        fi
    else
        OS_TYPE="unknown"
        log_warn "Unknown OS type: $OSTYPE"
    fi

    # Set OS-specific paths
    if [[ "$OS_TYPE" == "macos" ]]; then
        CONFIG_DIR="$HOME/.config/netcdf-studio"
        LOG_DIR="$HOME/Library/Logs/netcdf-studio"
    elif [[ "$IS_WINDOWS_GIT_BASH" == true ]]; then
        CONFIG_DIR="$APPDATA/netcdf-studio"
        LOG_DIR="$APPDATA/netcdf-studio/logs"
    else
        CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/netcdf-studio"
        LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/netcdf-studio/logs"
    fi

    # Create directories
    mkdir -p "$CONFIG_DIR" 2>/dev/null || true
    mkdir -p "$LOG_DIR" 2>/dev/null || true
}

# Check and install Node.js
install_nodejs() {
    log_step "Checking Node.js installation..."

    if command -v node &> /dev/null; then
        NODE_VERSION=$(node -v | sed 's/v//')
        log_info "Found Node.js version: $NODE_VERSION"

        # Check version
        if [[ $(echo -e "$NODE_MIN_VERSION\n$NODE_VERSION" | sort -V | head -n1) == "$NODE_MIN_VERSION" ]]; then
            log_success "Node.js version is compatible"
            return 0
        else
            log_warn "Node.js version $NODE_VERSION is below minimum ($NODE_MIN_VERSION)"
        fi
    fi

    log_info "Installing Node.js..."

    case $OS_TYPE in
        macos)
            install_nodejs_macos
            ;;
        linux)
            install_nodejs_linux
            ;;
        windows)
            install_nodejs_windows
            ;;
        *)
            log_warn "Unknown OS. Attempting nvm installation..."
            install_nvm
            ;;
    esac

    # Verify installation
    if command -v node &> /dev/null; then
        log_success "Node.js $(node -v) installed"
    else
        error_exit "Failed to install Node.js"
    fi
}

install_nodejs_macos() {
    # Try Homebrew first
    if command -v brew &> /dev/null; then
        log_info "Installing via Homebrew..."
        brew install node@20 || brew install node
    else
        log_info "Homebrew not found. Installing nvm..."
        install_nvm
    fi
}

install_nodejs_linux() {
    # Check if we have sudo
    local SUDO=""
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &> /dev/null; then
            SUDO="sudo"
        else
            log_warn "No sudo available. Installing nvm instead..."
            install_nvm
            return
        fi
    fi

    # Detect distribution
    if [[ -f /etc/debian_version ]] || [[ -f /etc/lsb-release ]]; then
        # Debian/Ubuntu
        log_info "Installing Node.js for Debian/Ubuntu..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | $SUDO bash -
        $SUDO apt-get install -y nodejs
    elif [[ -f /etc/redhat-release ]] || [[ -f /etc/centos-release ]]; then
        # RHEL/CentOS
        log_info "Installing Node.js for RHEL/CentOS..."
        curl -fsSL https://rpm.nodesource.com/setup_20.x | $SUDO bash -
        $SUDO yum install -y nodejs
    elif command -v dnf &> /dev/null; then
        # Fedora
        log_info "Installing Node.js for Fedora..."
        curl -fsSL https://rpm.nodesource.com/setup_20.x | $SUDO bash -
        $SUDO dnf install -y nodejs
    else
        # Fallback to nvm
        log_info "Unrecognized distribution. Installing nvm..."
        install_nvm
    fi
}

install_nodejs_windows() {
    if [[ "$IS_WINDOWS_GIT_BASH" == true ]] || [[ "$IS_WSL" == true ]]; then
        log_info "Installing nvm for Windows environment..."
        install_nvm
    else
        error_exit "Please install Node.js manually on Windows or run this script via Git Bash/WSL"
    fi
}

install_nvm() {
    log_info "Installing nvm (Node Version Manager)..."

    # Install nvm
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

    # Source nvm
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

    # Install Node.js 20
    nvm install 20
    nvm use 20
    nvm alias default 20

    log_success "Node.js installed via nvm"
}

# Install netcdf-studio-node
install_netcdf_studio() {
    log_step "Installing netcdf-studio-node..."

    # Check if already installed
    if command -v netcdf-studio-node &> /dev/null; then
        INSTALLED_VERSION=$(netcdf-studio-node --version 2>/dev/null || echo "unknown")
        log_info "netcdf-studio-node already installed: $INSTALLED_VERSION"

        # Check if we need to update
        if [[ "$NETCDF_STUDIO_VERSION" != "latest" ]]; then
            if [[ "$INSTALLED_VERSION" != "$NETCDF_STUDIO_VERSION" ]]; then
                log_info "Updating to version $NETCDF_STUDIO_VERSION..."
            else
                log_success "Correct version already installed"
                return 0
            fi
        else
            log_success "Already installed. Use --version to install a specific version"
            return 0
        fi
    fi

    # Install from npm (preferred) or GitHub
    if npm view netcdf-studio-node &>/dev/null; then
        # Package exists on npm
        if [[ "$NETCDF_STUDIO_VERSION" == "latest" ]]; then
            npm install -g netcdf-studio-node
        else
            npm install -g "netcdf-studio-node@$NETCDF_STUDIO_VERSION"
        fi
        log_success "Installed from npm registry"
    else
        # Fallback to GitHub
        log_info "Package not on npm, installing from GitHub..."

        local TEMP_DIR
        TEMP_DIR=$(mktemp -d)

        # Use HTTPS with public access
        if git clone --depth 1 --branch "$GITHUB_BRANCH" "https://github.com/netcdf-studio/NetCDF-Node.git" "$TEMP_DIR/repo" 2>&1; then
            cd "$TEMP_DIR/repo"

            # Install dependencies
            npm install --production

            # Link globally
            npm link

            cd - > /dev/null
            rm -rf "$TEMP_DIR"

            log_success "Installed from GitHub ($GITHUB_BRANCH branch)"
        else
            rm -rf "$TEMP_DIR"
            error_exit "Failed to clone repository. Make sure the repository is public or published to npm."
        fi
    fi

    # Verify
    if command -v netcdf-studio-node &> /dev/null; then
        log_success "netcdf-studio-node installed successfully"
    else
        error_exit "Failed to install netcdf-studio-node"
    fi
}

# Create configuration
create_config() {
    log_step "Creating configuration..."

    cat > "$CONFIG_DIR/config.env" << EOF
# NetCDF Studio Node Configuration
# Generated on $(date)

NETCDF_STUDIO_SERVER_URL="${SERVER_URL}"
NETCDF_STUDIO_API_TOKEN="${API_TOKEN}"
LOG_LEVEL=info
LOG_DIR=${LOG_DIR}
MAX_CONCURRENT_JOBS=2
ENABLE_GPU=false
EOF

    chmod 600 "$CONFIG_DIR/config.env"

    log_success "Configuration saved to $CONFIG_DIR/config.env"
}

# Check if service is already running
is_running() {
    if pgrep -f "netcdf-studio-node.*--server.*$SERVER_URL" > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Stop existing service
stop_service() {
    log_step "Stopping existing service..."

    if is_running; then
        pkill -f "netcdf-studio-node.*--server.*$SERVER_URL" || true
        sleep 2
        log_success "Stopped existing service"
    fi
}

# Start service
start_service() {
    log_step "Starting netcdf-studio-node..."

    if is_running; then
        log_warn "Service is already running"
        return 0
    fi

    # Start in background
    nohup netcdf-studio-node \
        --server "$SERVER_URL" \
        --token "$API_TOKEN" \
        > "$LOG_DIR/service.log" 2>&1 &

    local PID=$!
    sleep 2

    # Check if process is still running
    if kill -0 $PID 2>/dev/null; then
        echo $PID > "$CONFIG_DIR/node.pid"
        log_success "Service started (PID: $PID)"
        log_info "Logs: $LOG_DIR/service.log"
    else
        error_exit "Service failed to start. Check logs at $LOG_DIR/service.log"
    fi
}

# Install as system service (auto-start on boot)
install_system_service() {
    log_step "Installing system service..."

    case $OS_TYPE in
        linux)
            if [[ $EUID -eq 0 ]] || [[ "$IS_WSL" == true ]]; then
                install_systemd_service
            else
                log_warn "Skipping system service (requires root). Run with sudo to enable boot startup."
                install_user_service
            fi
            ;;
        macos)
            install_launchd_service
            ;;
        *)
            log_warn "System service not supported on this OS. Running in background mode."
            install_user_service
            ;;
    esac
}

install_systemd_service() {
    if ! command -v systemctl &> /dev/null; then
        log_warn "systemd not found. Installing user service instead."
        install_user_service
        return
    fi

    local SERVICE_NAME="netcdf-studio-node"
    local SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=NetCDF Studio Node - Distributed Processing Worker
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
Environment="NODE_ENV=production"
ExecStart=$(which netcdf-studio-node) --server $SERVER_URL --token $API_TOKEN
Restart=on-failure
RestartSec=10
StandardOutput=append:$LOG_DIR/service.log
StandardError=append:$LOG_DIR/service-error.log

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable $SERVICE_NAME.service
    systemctl restart $SERVICE_NAME.service

    log_success "Installed as systemd service (will start on boot)"
}

install_launchd_service() {
    local PLIST_NAME="com.netcdf.studio.node"
    local PLIST_FILE="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"

    cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(which netcdf-studio-node)</string>
        <string>--server</string>
        <string>$SERVER_URL</string>
        <string>--token</string>
        <string>$API_TOKEN</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/service.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/service-error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin</string>
    </dict>
</dict>
</plist>
EOF

    launchctl unload "$PLIST_FILE" 2>/dev/null || true
    launchctl load "$PLIST_FILE"

    log_success "Installed as launchd service (will start on boot)"
}

install_user_service() {
    log_info "Creating user-level startup script..."

    local STARTUP_SCRIPT="$CONFIG_DIR/start-node.sh"

    cat > "$STARTUP_SCRIPT" << EOF
#!/bin/bash
# NetCDF Studio Node Startup Script
# Run this script manually or add to your shell profile for auto-start

netcdf-studio-node --server "$SERVER_URL" --token "$API_TOKEN" > "$LOG_DIR/service.log" 2>&1 &
echo \$! > "$CONFIG_DIR/node.pid"
echo "NetCDF Studio Node started (PID: \$(cat $CONFIG_DIR/node.pid))"
EOF

    chmod +x "$STARTUP_SCRIPT"

    log_success "Created startup script: $STARTUP_SCRIPT"
    log_info "Add to your shell profile (~/.bashrc, ~/.zshrc) for auto-start:"
    echo ""
    echo "    $STARTUP_SCRIPT"
    echo ""
}

# Show status
show_status() {
    log_step "Status check..."

    echo ""
    echo -e "${CYAN}Configuration:${NC}"
    echo "  Server URL  : $SERVER_URL"
    echo "  Config Dir  : $CONFIG_DIR"
    echo "  Log Dir     : $LOG_DIR"
    echo ""

    if is_running; then
        local PID=$(pgrep -f "netcdf-studio-node.*--server.*$SERVER_URL" | head -n1)
        echo -e "${GREEN}✓ Service Running${NC} (PID: $PID)"
    else
        echo -e "${YELLOW}⚠ Service Not Running${NC}"
    fi

    echo ""
    echo -e "${CYAN}Management Commands:${NC}"
    echo "  Status  : netcdf-node status"
    echo "  Start   : netcdf-node start"
    echo "  Stop    : netcdf-node stop"
    echo "  Restart : netcdf-node restart"
    echo "  Logs    : netcdf-node logs"

    echo ""
}

# Main execution
main() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║      NetCDF Studio Node - Universal Installer                 ║
╚════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""

    # Parse arguments
    parse_args "$@"

    # Run installation steps
    detect_os
    install_nodejs
    install_netcdf_studio
    create_config
    stop_service
    start_service
    install_system_service
    show_status

    log_success "Installation complete!"
}

# Run main
main "$@"
