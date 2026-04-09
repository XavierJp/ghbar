#!/bin/bash
set -e

INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="$HOME/.ghbar"
BINARY_NAME="ghbar"
PLIST_NAME="com.ghbar.app"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"

# Stop and remove Launch Agent
if [ -f "$PLIST_PATH" ]; then
  launchctl unload "$PLIST_PATH" 2>/dev/null || true
  rm -f "$PLIST_PATH"
  echo "Launch Agent removed."
fi

echo "Removing $INSTALL_DIR/$BINARY_NAME..."
sudo rm -f "$INSTALL_DIR/$BINARY_NAME"

read -p "Remove config at $CONFIG_DIR? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  rm -rf "$CONFIG_DIR"
  echo "Config removed."
else
  echo "Config kept."
fi

echo "Done."
