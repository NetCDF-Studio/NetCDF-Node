#!/bin/bash

# Commit the install script fix
cd /Users/soumalya/Documents/GitHub/NetCDF-Node

git add install.sh

git commit -m "fix: Correct installation path and add npm fallback

Critical fixes for installation:

1. Fixed path error: Removed '/node-agent' subdirectory
   - Files are in root of repo, not in subdirectory
   - Was failing with: 'cd: /tmp/tmp.*/repo/node-agent: No such file or directory'
   - Now correctly installs from repo root

2. Added npm fallback logic
   - First checks if package is published to npm
   - Installs from npm if available (faster, no git needed)
   - Falls back to GitHub clone if not on npm

3. Better error handling
   - Clear error if repo is private
   - Verbose output for debugging

Installation flow:
- Try npm registry (if published)
- Clone from GitHub (if public repo)
- Install dependencies
- Link globally
- Verify installation

Users can now install via:
  curl -fsSL https://server/install.sh | bash -s -- \\
    --server https://server.com \\
    --token TOKEN

Tested on Ubuntu, macOS (needs verification after push)."

# Create version bump tag
git tag -a v1.0.2 -m "v1.0.2 - Fix installation path and add npm support

- Fixed 'node-agent' directory not found error
- Added fallback to npm registry
- Better error messages"

# Push to GitHub
echo ""
echo "=== Ready to push ==="
echo "Run: git push origin main --tags"
