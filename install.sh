#!/bin/bash
set -e

INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="$HOME/.ghbar"
BINARY_NAME="ghbar"
PLIST_NAME="com.ghbar.app"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"

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

# Install Launch Agent (start on login)
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$PLIST_NAME</string>
  <key>ProgramArguments</key>
  <array>
    <string>$INSTALL_DIR/$BINARY_NAME</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <false/>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
</dict>
</plist>
EOF

# Load the agent (starts it now + on future logins)
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo "Done. GHBar is running and will start automatically on login."
echo "  Stop:    launchctl unload $PLIST_PATH"
echo "  Restart: launchctl unload $PLIST_PATH && launchctl load $PLIST_PATH"
