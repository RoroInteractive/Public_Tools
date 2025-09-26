#!/usr/bin/env bash
set -euo pipefail

[[ $# -ge 1 && $# -le 2 ]] || { echo "usage: $0 <user> [pubkey]"; exit 1; }

USER_NAME="$1"
DEFAULT_PUBKEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFsgdn22Z0Y4yMT2TITZ3KzkGcmZR2Uc3TDzLp9wr4P1'
PUBKEY="${2:-$DEFAULT_PUBKEY}"

# User must exist
id "$USER_NAME" >/dev/null 2>&1 || { echo "no such user: $USER_NAME"; exit 2; }

# Resolve home
USER_HOME="$(/usr/bin/dscl . -read "/Users/$USER_NAME" NFSHomeDirectory 2>/dev/null | awk 'NF>=2{print $2; exit}')" || true
USER_HOME="${USER_HOME:-/Users/$USER_NAME}"

# Install pubkey
SSH_DIR="$USER_HOME/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"
sudo /bin/mkdir -p "$SSH_DIR"
sudo /bin/chmod 700 "$SSH_DIR"
# create file if missing with correct mode
if ! sudo test -f "$AUTH_KEYS"; then
  sudo /usr/bin/install -m 600 /dev/null "$AUTH_KEYS"
fi
# append only if exact line absent
if ! sudo /usr/bin/grep -Fqx -- "$PUBKEY" "$AUTH_KEYS" 2>/dev/null; then
  printf '%s\n' "$PUBKEY" | sudo /usr/bin/tee -a "$AUTH_KEYS" >/dev/null
fi
# ensure ownership/perms
sudo /usr/sbin/chown -R "$USER_NAME:$(/usr/bin/id -gn "$USER_NAME")" "$SSH_DIR"
sudo /bin/chmod 700 "$SSH_DIR"
sudo /bin/chmod 600 "$AUTH_KEYS"

# Passwordless sudo for that user
SUDOERS_D="/private/etc/sudoers.d"
sudo /bin/mkdir -p "$SUDOERS_D"; sudo /bin/chmod 755 "$SUDOERS_D"
LINE="${USER_NAME} ALL=(ALL) NOPASSWD:ALL"
TMP="$(/usr/bin/mktemp)"; printf '%s\n' "$LINE" > "$TMP"
/usr/sbin/visudo -cf "$TMP"
sudo /usr/bin/install -m 440 "$TMP" "$SUDOERS_D/90-${USER_NAME}-nopw"
rm -f "$TMP"

# Force SSH key-only auth (disables password + keyboard-interactive)
SSHD_D="/etc/ssh/sshd_config.d"
sudo /bin/mkdir -p "$SSHD_D"
sudo /usr/bin/tee "$SSHD_D/50-key-only.conf" >/dev/null <<'EOF'
# Managed by bootstrap script: key-only logins
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
UsePAM yes
PermitRootLogin no
EOF

# Enable Remote Login
sudo /usr/sbin/systemsetup -setremotelogin on || true

echo "✅ done: ${USER_NAME} has key auth + NOPASSWD sudo; password SSH logins disabled; sshd enabled."
