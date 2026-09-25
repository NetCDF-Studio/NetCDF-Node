# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-09-25

### Added
- `netcdf-node` CLI for easy service management
- One-liner installation script with auto-detection
- Cross-platform support (Linux, macOS, Windows, WSL)
- Auto-installation of Node.js if not present
- Background service installation (systemd, launchd)
- Auto-start on boot capability
- Comprehensive README documentation
- MIT License

### Features
- **CLI Commands**: `start`, `stop`, `restart`, `status`, `logs`, `connect`
- **Smart Installation**: Detects OS and chooses appropriate method
- **Service Management**: Integrates with systemd (Linux) and launchd (macOS)
- **Configuration**: Auto-generates config files in standard locations
- **Logging**: Dedicated log directories and real-time log tailing
- **Error Handling**: Graceful failures with clear error messages

### Changed
- Installation now clones from standalone GitHub repository
- Simplified CLI interface replacing complex system commands
- Better error messages and user guidance

### Technical Details
- Built with Node.js ES modules
- WebSocket client using socket.io-client
- No native dependencies for easy cross-platform support
- Minimal footprint (only essential dependencies)

## [1.0.0] - 2026-09-24

### Added
- Initial release
- Core agent functionality
- WebSocket connection to NetCDF Studio server
- Job execution engine
- Basic CLI
