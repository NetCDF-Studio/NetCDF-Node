# Publishing Guide

This document describes how to publish the NetCDF Studio Node package.

## npm Publishing (Recommended)

### Prerequisites

1. Create an npm account at https://www.npmjs.com/
2. Verify your email
3. Ask to be added as a maintainer (if collaborative)

### Steps

```bash
# 1. Login to npm
npm login

# 2. Verify package.json is correct
cat package.json

# 3. Dry run to see what will be published
npm publish --dry-run

# 4. Publish to npm
npm publish

# For scoped packages (if using @yourorg/netcdf-studio-node)
npm publish --access public
```

### After Publishing

Users can then install with:
```bash
npm install -g netcdf-studio-node
```

## GitHub Repository Setup

### 1. Create Repository

Go to https://github.com/new and create:
- Repository name: `netcdf-node`
- Description: Compute node agent for NetCDF Studio
- Public repository
- Add MIT license
- Add .gitignore (Node)

### 2. Push Code

```bash
cd NetCDF-Node
git init
git add .
git commit -m "Initial release v1.0.1"
git branch -M main
git remote add origin https://github.com/netcdf-studio/netcdf-node.git
git push -u origin main
```

### 3. Create Release

1. Go to repository → Releases → Draft a new release
2. Tag: `v1.0.1`
3. Title: `NetCDF Studio Node v1.0.1`
4. Copy release notes from CHANGELOG.md
5. Publish release

### 4. Update Install Script

Update `install.sh` and `README.md` with:
- Correct GitHub repository URL
- npm package URL (after publishing)

## Version Updates

### Bumping Version

```bash
# Patch (1.0.1 → 1.0.2)
npm version patch

# Minor (1.0.1 → 1.1.0)
npm version minor

# Major (1.0.1 → 2.0.0)
npm version major
```

### Publishing Update

```bash
# Update version
npm version patch

# Push tags
git push --tags

# Publish to npm
npm publish

# Create GitHub release
# (follow steps above)
```

## Verification

After publishing, verify:

```bash
# Check npm package
npm view netcdf-studio-node

# Test installation
npx netcdf-studio-node --version

# Test CLI
npx netcdf-node --help
```

## Automation (Optional)

### GitHub Actions for Auto-Publish

Create `.github/workflows/publish.yml`:

```yaml
name: Publish to npm

on:
  release:
    types: [created]

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '20'
          registry-url: 'https://registry.npmjs.org'
      - run: npm ci
      - run: npm publish
        env:
          NODE_AUTH_TOKEN: ${{secrets.npm_token}}
```

Add `npm_token` to repository secrets.

## Checklist Before Publishing

- [ ] All tests pass
- [ ] README.md has correct URLs
- [ ] package.json version is updated
- [ ] CHANGELOG.md is updated
- [ ] License file exists
- [ ] No sensitive data in code
- [ ] Dependencies are production-ready
- [ ] CLI commands work
- [ ] Installation script works
- [ ] Cross-platform testing done

## Support

For questions about publishing:
- npm docs: https://docs.npmjs.com/
- GitHub docs: https://docs.github.com/
