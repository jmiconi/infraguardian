#!/bin/bash

set -e

echo "Installing InfraGuardian Collector..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

INSTALL_DIR="/opt/infraguardian"
COLLECTOR_DIR="$INSTALL_DIR/collector"
VENV_DIR="$INSTALL_DIR/venv"
SERVICE_NAME="infraguardian-collector.service"

echo "Creating directories..."
sudo mkdir -p "$COLLECTOR_DIR"

echo "Copying collector files..."
sudo cp "$REPO_DIR/collector/collector.py" "$COLLECTOR_DIR/"
sudo cp "$REPO_DIR/collector/requirements.txt" "$COLLECTOR_DIR/"

if [ ! -f "$COLLECTOR_DIR/config.env" ]; then
    echo "Creating default config.env..."
    sudo cp "$REPO_DIR/collector/config.env" "$COLLECTOR_DIR/"
else
    echo "config.env already exists, keeping current file."
fi

echo "Creating Python virtual environment..."
sudo python3 -m venv "$VENV_DIR"

echo "Installing dependencies..."
sudo "$VENV_DIR/bin/pip" install -r "$COLLECTOR_DIR/requirements.txt"

echo "Installing systemd service..."
sudo cp "$REPO_DIR/systemd/$SERVICE_NAME" "/etc/systemd/system/$SERVICE_NAME"

echo "Reloading systemd..."
sudo systemctl daemon-reload

echo "Enabling and starting InfraGuardian Collector..."
sudo systemctl enable --now infraguardian-collector

echo ""
echo "Installation complete."
echo "Check status with:"
echo "systemctl status infraguardian-collector"
echo "Check logs with:"
echo "journalctl -u infraguardian-collector -f"