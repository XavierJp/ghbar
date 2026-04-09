#!/bin/bash
set -e

INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="$HOME/.ghbar"
BINARY_NAME="ghbar"

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
