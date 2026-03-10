#!/usr/bin/env bash
set -e

echo "[INFO] InfraGuardian bootstrap"

# Check Docker
if ! command -v docker >/dev/null 2>&1; then
  echo "[INFO] Docker not found. Installing..."
  curl -fsSL https://get.docker.com | sudo sh
fi

# Add current user to docker group (if not already)
if ! groups "$USER" | grep -q docker; then
  echo "[INFO] Adding user to docker group..."
  sudo usermod -aG docker "$USER"
  echo "[WARN] You must log out and log in again for this to take effect."
fi

echo "[OK] Docker setup complete."
