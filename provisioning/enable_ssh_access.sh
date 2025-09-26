#!/usr/bin/env bash
set -euo pipefail

[[ $# -ge 1 && $# -le 2 ]] || { echo "usage: $0 <user> [pubkey]"; exit 1; }

# re-exec under sudo if not root
if [ "$(id -u)" -ne 0 ]; then
  if [ -f "$0" ] && [ -r "$0" ]; then
    # works for real files *and* /dev/fd/… from <(…)
    exec sudo sh -s -- "$@" <"$0"
  else
    # works for curl | sh (stdin already has the script)
    exec sudo sh -s -- "$@"
  fi
fi

USER_NAME=$1
DEFAULT_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFsgdn22Z0Y4yMT2TITZ3KzkGcmZR2Uc3TDzLp9wr4P1"
PUBKEY=${2:-$DEFAULT_PUBKEY}

# ensure user exists
id "$USER_NAME" >/dev/null 2>&1 || { echo "no such user: $USER_NAME"; exit 2; }

# enable SSH (Remote Login)
systemsetup -setremotelogin on >/dev/null 2>&1 || true

# resolve home dir
USER_HOME="$(dscl . -read "/Users/$USER_NAME" NFSHomeDirectory 2>/dev/null | awk 'NF>=2{print $2; exit}')"
USER_HOME=${USER_HOME:-/Users/$USER_NAME}

# install pubkey
SSH_DIR="$USER_HOME/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

mkdir -p -m 700 "$SSH_DIR"
[[ -f "$AUTH_KEYS" ]] || install -m 600 /dev/null "$AUTH_KEYS"

# add only if exact line absent
if ! grep -Fxq "$PUBKEY" "$AUTH_KEYS"; then
  printf '%s\n' "$PUBKEY" >> "$AUTH_KEYS"
fi

# ensure ownership/perms (safe to repeat)
chown -R "$USER_NAME:$(id -gn "$USER_NAME")" "$SSH_DIR"
chmod 700 "$SSH_DIR"
chmod 600 "$AUTH_KEYS"

# passwordless sudo
SUDOERS_D=/etc/sudoers.d
mkdir -p "$SUDOERS_D"; chmod 755 "$SUDOERS_D"
LINE="${USER_NAME} ALL=(ALL) NOPASSWD:ALL"
TMP="$(mktemp)"; printf '%s\n' "$LINE" > "$TMP"
/usr/sbin/visudo -cf "$TMP" >/dev/null
install -m 440 "$TMP" "$SUDOERS_D/90-${USER_NAME}-nopw"
rm -f "$TMP"

echo "done"
