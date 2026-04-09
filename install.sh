#!/bin/bash
set -e

INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="$HOME/.ghbar"
BINARY_NAME="ghbar"

echo "Building GHBar..."
swift build -c release --quiet

echo "Installing to $INSTALL_DIR/$BINARY_NAME..."
sudo cp -f .build/release/GHBar "$INSTALL_DIR/$BINARY_NAME"

# Create default config if missing
if [ ! -f "$CONFIG_DIR/config.json" ]; then
  mkdir -p "$CONFIG_DIR"
  cat > "$CONFIG_DIR/config.json" <<'EOF'
{
  "activeRepoRunsLimit": 25,
  "includePersonal": true,
  "maxConcurrency": 8,
  "maxReposPerOrg": 25,
  "orgs": ["parsio-ai"],
  "pollingIntervalSeconds": 15,
  "runsPerRepo": 8,
  "username": "XavierJp"
}
EOF
  echo "Created default config at $CONFIG_DIR/config.json"
else
  echo "Config already exists at $CONFIG_DIR/config.json"
fi

echo "Done. Run 'ghbar' to start."
