#!/bin/bash

# NetCDF-Node Git Push Script
# Run this script to commit and push to GitHub

cd /Users/soumalya/Documents/GitHub/NetCDF-Node

echo "=== Committing files ==="
git add .gitignore CHANGELOG.md DEPLOYMENT-CHECKLIST.md LICENSE PUBLISHING.md README.md agent.js cli.js install.sh package.json

git commit -m "Initial release v1.0.1 - Production-ready compute node agent

Features:
- Universal installer for Linux, macOS, Windows
- Simple CLI management (start/stop/restart/status/logs)
- Auto-service setup (systemd/launchd)
- Cross-platform WebSocket agent
- Production-ready with comprehensive docs

Package includes:
- agent.js - Core compute node agent
- cli.js - Management CLI tool
- install.sh - Universal one-liner installer
- Comprehensive documentation (README, CHANGELOG, guides)

CLI Commands:
- netcdf-node start
- netcdf-node stop
- netcdf-node restart
- netcdf-node status
- netcdf-node logs

Installation:
  curl -fsSL https://your-server/install.sh | bash -s -- \\
    --server https://your-server.com \\
    --token YOUR_TOKEN"

echo ""
echo "=== Creating tag ==="
git tag -a v1.0.1 -m "Release v1.0.1

- Universal installer (Linux, macOS, Windows)
- Simple CLI management
- Auto-service setup
- Comprehensive documentation"

echo ""
echo "=== Pushing to GitHub ==="
git push -u origin main --tags

echo ""
echo "=== Done! ==="
echo "Repository: https://github.com/NetCDF-Studio/NetCDF-Node"
echo "Check your repo to verify the push was successful"
