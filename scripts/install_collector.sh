#!/bin/bash

set -e

echo "Installing InfraGuardian Collector..."

INSTALL_DIR="/opt/infraguardian"
COLLECTOR_DIR="$INSTALL_DIR/collector"
VENV_DIR="$INSTALL_DIR/venv"

echo "Creating directories..."
sudo mkdir -p $COLLECTOR_DIR

echo "Copying collector files..."
sudo cp collector/collector.py $COLLECTOR_DIR/
sudo cp collector/requirements.txt $COLLECTOR_DIR/

if [ ! -f "$COLLECTOR_DIR/config.env" ]; then
    echo "Creating default config.env"
    sudo cp collector/config.env $COLLECTOR_DIR/
fi

echo "Creating Python virtual environment..."
sudo python3 -m venv $VENV_DIR

echo "Installing dependencies..."
sudo $VENV_DIR/bin/pip install -r $COLLECTOR_DIR/requirements.txt

echo "Installing systemd service..."
sudo cp systemd/infraguardian-collector.service /etc/systemd/system/

echo "Reloading systemd..."
sudo systemctl daemon-reload

echo "Enabling InfraGuardian Collector..."
sudo systemctl enable --now infraguardian-collector

echo "Installation complete."
echo ""
echo "Check status with:"
echo "systemctl status infraguardian-collector"