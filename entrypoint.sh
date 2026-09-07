#!/bin/bash
set -e

# /root is a Railway volume: empty on first boot, root-owned. Seed dotfiles once
# (flag file, not per-file checks: local docker pre-copies the image's /root into a
# fresh volume, which would otherwise shadow our skel).
if [ ! -f /root/.claude-box-seeded ]; then
  cp -af /opt/skel/. /root/ && touch /root/.claude-box-seeded
fi
mkdir -p /root/.ssh /root/src && chmod 700 /root/.ssh

# Persist SSH host keys on the volume so clients don't see "host key changed" after redeploys.
mkdir -p /root/.ssh-host
for t in rsa ed25519; do
  [ -f "/root/.ssh-host/ssh_host_${t}_key" ] || ssh-keygen -q -t "$t" -N '' -f "/root/.ssh-host/ssh_host_${t}_key"
  cp -f "/root/.ssh-host/ssh_host_${t}_key" "/root/.ssh-host/ssh_host_${t}_key.pub" /etc/ssh/
  chmod 600 "/etc/ssh/ssh_host_${t}_key"
done

# Root login: password from ROOT_PASSWORD, optional keys from AUTHORIZED_KEYS.
[ -n "${ROOT_PASSWORD:-}" ] && echo "root:${ROOT_PASSWORD}" | chpasswd
[ -n "${AUTHORIZED_KEYS:-}" ] && printf '%s\n' "$AUTHORIZED_KEYS" > /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys
cat > /etc/ssh/sshd_config.d/railway.conf <<CFG
Port 22
ListenAddress 0.0.0.0
ListenAddress ::
PermitRootLogin yes
PasswordAuthentication $([ -n "${ROOT_PASSWORD:-}" ] && echo yes || echo no)
ClientAliveInterval 60
CFG
/usr/sbin/sshd

# Make service variables visible to SSH sessions too (sshd strips the environment).
env | grep -E '^(ANTHROPIC_|CLAUDE_|GH_TOKEN|GITHUB_TOKEN|TZ|PORT)' | sed 's/^/export /; s/=/="/; s/$/"/' > /etc/profile.d/railway-env.sh || true

echo "== claude-box ready: web terminal on :${PORT}, sshd on :22, claude $(claude --version 2>/dev/null)"
# Web terminal: ttyd with basic auth, each tab attaches to the same tmux session.
exec ttyd -p "${PORT}" -W -c "${WEB_USER:-admin}:${WEB_PASSWORD:?WEB_PASSWORD is required}" \
  -t titleFixed="claude-box" -t fontSize=14 \
  bash -lc 'exec tmux new -A -s main'
