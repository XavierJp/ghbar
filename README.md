# GHBar

A lightweight macOS menu bar app that shows your GitHub Actions and Pull Requests at a glance. Built with Swift and SwiftUI, powered by the `gh` CLI.

![macOS](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.10-orange)

## Features

- **Menu bar icon** — always visible, one click to open
- **Actions tab** — workflow runs organized by repo, grouped by workflow name
  - Per-workflow stats: success rate, average duration, failure count
  - Most recently active repo auto-expanded
  - Active repo fetches more run history automatically
- **PRs tab** — your open pull requests with CI status and review state
- **Org switcher** — dropdown to switch between orgs and personal repos
- **Smart polling** — only refreshes while the popover is open (every 15s)
- **Click to open** — any run or PR opens directly in your browser
- **Configurable** — edit `~/.ghbar/config.json` to customize everything

## Prerequisites

- macOS 14+
- Swift 5.10+ (comes with Xcode or Command Line Tools)
- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated

```bash
# Install gh if needed
brew install gh
gh auth login
```

## Install

```bash
git clone https://github.com/XavierJp/ghbar.git
cd ghbar
./install.sh
```

This builds a release binary, copies it to `/usr/local/bin/ghbar`, and installs a Launch Agent so GHBar starts automatically on login.

Manual controls:

```bash
# Stop
launchctl unload ~/Library/LaunchAgents/com.ghbar.app.plist

# Restart
launchctl unload ~/Library/LaunchAgents/com.ghbar.app.plist && launchctl load ~/Library/LaunchAgents/com.ghbar.app.plist
```

## Uninstall

```bash
./uninstall.sh
```

## Configuration

Config lives at `~/.ghbar/config.json`. Created automatically on first run.

```json
{
  "orgs": ["my-org"],
  "includePersonal": true,
  "username": "my-github-username",
  "pollingIntervalSeconds": 15,
  "maxReposPerOrg": 25,
  "runsPerRepo": 8,
  "activeRepoRunsLimit": 25,
  "maxConcurrency": 8
}
```

| Key | Description | Default |
|-----|-------------|---------|
| `orgs` | GitHub organizations to monitor | `[]` |
| `includePersonal` | Include your personal repos as a source | `true` |
| `username` | Your GitHub username (for personal repos) | `""` |
| `pollingIntervalSeconds` | Refresh interval when popover is open | `15` |
| `maxReposPerOrg` | Max repos to scan per org | `25` |
| `runsPerRepo` | Workflow runs to fetch per repo | `8` |
| `activeRepoRunsLimit` | Extra runs fetched for the most active repo | `25` |
| `maxConcurrency` | Parallel `gh` CLI calls | `8` |

## Development

```bash
# Build and run (debug)
swift build && .build/debug/GHBar

# Build release
swift build -c release
```

## How it works

GHBar shells out to the `gh` CLI to fetch data from GitHub. No tokens or OAuth needed beyond your existing `gh auth` session. Fetches are parallelized and throttled to stay within API limits.

## License

MIT
