#!/bin/bash
# Usage: sudo ./fix_rstudio_user.sh <username>

set -e

USER_NAME="$1"

if [[ -z "$USER_NAME" ]]; then
  echo "ERROR: No user supplied"
  echo "Usage: sudo $0 <username>"
  exit 1
fi

HOME_DIR="/home/$USER_NAME"

if ! id "$USER_NAME" &>/dev/null; then
  echo "ERROR: User $USER_NAME does not exist"
  exit 1
fi

# Extract numeric UID and GID (authoritative)
UID_NUM=$(id -u "$USER_NAME")
GID_NUM=$(id -g "$USER_NAME")

echo "User        : $USER_NAME"
echo "Home dir    : $HOME_DIR"
echo "UID         : $UID_NUM"
echo "GID         : $GID_NUM"
echo "-----------------------------"

# Ensure home exists
if [[ ! -d "$HOME_DIR" ]]; then
  echo "ERROR: Home directory does not exist: $HOME_DIR"
  exit 1
fi

# Ensure .local exists
mkdir -p "$HOME_DIR/.local/share/rstudio"

# Fix ownership using numeric IDs (AD-safe)
echo "Fixing ownership..."
chown -R "$UID_NUM:$GID_NUM" "$HOME_DIR/.local"

# Lock permissions (RStudio requirement)
echo "Fixing permissions..."
chmod -R 700 "$HOME_DIR/.local"

# Purge stale RStudio state
echo "Resetting RStudio user cache..."
rm -rf "$HOME_DIR/.local/share/rstudio"
mkdir -p "$HOME_DIR/.local/share/rstudio"
chown -R "$UID_NUM:$GID_NUM" "$HOME_DIR/.local"
chmod -R 700 "$HOME_DIR/.local"

# SELinux fix if enforcing
if command -v getenforce &>/dev/null; then
  SELINUX_MODE=$(getenforce)
  echo "SELinux mode : $SELINUX_MODE"
  if [[ "$SELINUX_MODE" == "Enforcing" ]]; then
    echo "Restoring SELinux contexts..."
    restorecon -Rv "$HOME_DIR" >/dev/null
  fi
fi

# Restart RStudio Server
echo "Restarting RStudio Server..."
systemctl restart rstudio-server

# Hard validation
echo "Validating write access as user..."
if sudo -u "$USER_NAME" touch "$HOME_DIR/.local/share/rstudio/.write_test" 2>/dev/null; then
  rm -f "$HOME_DIR/.local/share/rstudio/.write_test"
  echo "SUCCESS: User can write to RStudio directories"
  echo "RStudio session should start normally"
else
  echo "FAILURE: User cannot write to home directory"
  echo "Root cause is filesystem UID/GID mismatch (EFS/NFS/infra)"
  exit 2
fi
