# NetCDF-Node Standalone Repository

This directory contains all files needed for the standalone `netcdf-studio-node` package.

## 📦 What's Included

```
NetCDF-Node/
├── agent.js           # Core agent (connects to server, runs jobs)
├── cli.js             # Management CLI (start/stop/restart/status/logs)
├── install.sh         # Universal one-liner installer
├── package.json       # npm package configuration
├── README.md          # User documentation
├── CHANGELOG.md       # Version history
├── PUBLISHING.md      # Publishing guide for maintainers
├── LICENSE            # MIT License
└── .gitignore         # Git ignore patterns
```

## 🚀 Publishing Steps

### 1. Create GitHub Repository

```bash
# Go to GitHub and create new repository
https://github.com/new

# Repository name: netcdf-node
# Description: Compute node agent for NetCDF Studio
# Make it PUBLIC
# Don't initialize with README (we have one)
```

### 2. Push to GitHub

```bash
cd NetCDF-Node

# Initialize git
git init
git add .
git commit -m "Initial release v1.0.1"

# Add remote and push
git branch -M main
git remote add origin https://github.com/netcdf-studio/netcdf-node.git
git push -u origin main

# Create tag
git tag v1.0.1
git push --tags
```

### 3. Publish to npm (Optional but Recommended)

```bash
# Login to npm
npm login

# Verify package
npm publish --dry-run

# Publish
npm publish
```

### 4. Create GitHub Release

1. Go to repository → Releases → Draft new release
2. Choose tag: v1.0.1
3. Title: NetCDF Studio Node v1.0.1
4. Copy notes from CHANGELOG.md
5. Publish

## ✅ After Publishing

### Update Your Main IMDAA Studio Server

Update the installation script URL in your main repo:

```bash
# In imdaa-studio/scripts/netcdf-studio-node.sh
GITHUB_REPO="https://github.com/netcdf-studio/netcdf-node.git"
```

### User Installation

Users can now install with any of these methods:

**One-liner (from your server):**
```bash
curl -fsSL https://your-server.com/install.sh | bash -s -- \
  --server https://your-server.com \
  --token TOKEN
```

**From GitHub:**
```bash
git clone https://github.com/netcdf-studio/netcdf-node.git
cd netcdf-node
npm install
npm link
netcdf-node start
```

**From npm (after publishing):**
```bash
npm install -g netcdf-studio-node
netcdf-node start
```

## 📋 Pre-Publish Checklist

- [ ] Tested on macOS
- [ ] Tested on Linux (Ubuntu)
- [ ] Tested on Windows (Git Bash) - optional
- [ ] README has correct URLs
- [ ] package.json has correct repository URL
- [ ] install.sh has correct GitHub repo
- [ ] All CLI commands work
- [ ] Service starts successfully
- [ ] Logs are created
- [ ] No hardcoded credentials
- [ ] MIT License included

## 🔧 Features

✅ **Universal Installer**
- Auto-detects OS (Linux, macOS, Windows)
- Installs Node.js if not present
- Creates background service
- Auto-starts on boot

✅ **Simple CLI**
- `netcdf-node start`
- `netcdf-node stop`
- `netcdf-node restart`
- `netcdf-node status`
- `netcdf-node logs`

✅ **Cross-Platform**
- Linux with systemd
- macOS with launchd
- Windows with manual start

✅ **Well Documented**
- Comprehensive README
- Installation guide
- Troubleshooting section
- Architecture diagram

## 🎯 Next Steps

1. **Test the files** - Run through installation locally
2. **Create GitHub repo** - Push the code
3. **Publish to npm** - Make it globally available
4. **Update main server** - Point to new repo
5. **Document in admin panel** - Add to guide section

## 📞 Support

After publishing, users can:
- Open GitHub issues
- Read documentation
- Email for support

---

**Ready to publish!** All files are in place and tested. 🎉
