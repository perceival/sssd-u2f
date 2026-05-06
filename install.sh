#!/bin/bash
set -e

echo "=== 1/6 Installing build dependencies ==="
sudo dnf -y install pam-devel openssl-devel rust cargo git authselect pam-u2f pamu2fcfg

echo "=== 2/6 Building pam_rssh ==="
mkdir -p /tmp/work && cd /tmp/work
[ -d pam_rssh ] || git clone --recurse-submodule https://github.com/z4yx/pam_rssh.git
cd pam_rssh && cargo build --release

echo "=== 3/6 Installing libpam_rssh.so ==="
sudo install -m 644 target/release/libpam_rssh.so /usr/lib64/security/pam_rssh.so

echo "=== 4/6 Syncing profile from /tmp/work/sssd-u2f to /etc/authselect/custom/sssd-u2f/ ==="
[ -d /tmp/work/sssd-u2f ] || git clone https://github.com/perceival/sssd-u2f /tmp/work/sssd-u2f
sudo cp -av /tmp/work/sssd-u2f/. /etc/authselect/custom/sssd-u2f/

echo "=== 5/6 Configure sudoers env_keep for SSH_AUTH_SOCK ==="
echo 'Defaults env_keep += "SSH_AUTH_SOCK"' | sudo tee /etc/sudoers.d/10-rssh-agent
sudo chmod 0440 /etc/sudoers.d/10-rssh-agent
sudo visudo -cf /etc/sudoers.d/10-rssh-agent

echo "=== 6/6 Apply authselect ==="
sudo authselect apply-changes
echo
echo "=== VERIFICATION ==="
ls -la /usr/lib64/security/pam_rssh.so
authselect current
echo "--- /etc/pam.d/sudo + system-auth (rssh/u2f lines) ---"
grep -E "rssh|u2f" /etc/pam.d/sudo /etc/pam.d/system-auth | head -15
echo
echo "--- sshd config: AllowAgentForwarding ---"
sudo grep -i "allowagentforward" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/* 2>/dev/null | head -5
echo
echo "✅ Done. Test from your laptop:"
echo "    ssh -A mmpc10"
echo "    sudo whoami    # YubiKey miga → touch → root"
