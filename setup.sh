#!/bin/bash
# =============================================================================
# setup.sh - One-time setup for the Ansible Cache Clear project
# =============================================================================
# Run this script on your Ansible control node (the machine you run Ansible from)
# Usage: bash setup.sh
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "============================================="
echo "  Ansible Cache Clear - Initial Setup"
echo "============================================="
echo ""

# ── Step 1: Check Ansible is installed ──────────────────────────────────────
if ! command -v ansible &> /dev/null; then
    echo "❌ Ansible is not installed."
    echo "   Install it with: sudo dnf install ansible-core  (RHEL/CentOS)"
    echo "   Or:              pip3 install ansible"
    exit 1
fi
echo "✅ Ansible found: $(ansible --version | head -1)"
echo ""

# ── Step 2: Create logs directory ───────────────────────────────────────────
mkdir -p logs
echo "✅ Created logs/ directory"

# ── Step 3: Create the Ansible Vault encrypted credentials file ─────────────
VAULT_FILE="group_vars/rhel_servers/vault.yml"
if [ -f "$VAULT_FILE" ]; then
    echo "⚠️  $VAULT_FILE already exists. Skipping vault creation."
    echo "   To edit: ansible-vault edit $VAULT_FILE"
else
    echo ""
    echo "─── Creating Encrypted Vault for Credentials ───"
    echo ""
    echo "You will be asked to set a VAULT PASSWORD."
    echo "This vault password is used to encrypt/decrypt your server credentials."
    echo "Remember this password — you'll need it every time you run the playbook."
    echo ""

    # Prompt for credentials
    read -p "Enter SSH username for the servers: " SSH_USER
    read -sp "Enter password (SSH + sudo — same password): " SSH_PASS
    echo ""

    # Create the vault file with credentials
    mkdir -p "$(dirname "$VAULT_FILE")"

    # Write to a temp file first, then encrypt it
    TEMP_FILE=$(mktemp)
    cat > "$TEMP_FILE" <<EOF
---
# Encrypted credentials for RHEL servers
# Edit with: ansible-vault edit $VAULT_FILE
vault_ssh_user: "$SSH_USER"
vault_ssh_password: "$SSH_PASS"
vault_sudo_password: "$SSH_PASS"
EOF

    # Encrypt the file
    ansible-vault encrypt "$TEMP_FILE" --output "$VAULT_FILE"
    rm -f "$TEMP_FILE"

    echo ""
    echo "✅ Vault file created and encrypted: $VAULT_FILE"
    echo "   To view:  ansible-vault view $VAULT_FILE"
    echo "   To edit:  ansible-vault edit $VAULT_FILE"
fi

# ── Step 4: Create vault password file (optional convenience) ───────────────
echo ""
read -p "Do you want to save the vault password to a file (.vault_pass) so you don't type it every run? (y/N): " SAVE_VAULT_PASS
if [[ "$SAVE_VAULT_PASS" =~ ^[Yy]$ ]]; then
    read -sp "Enter your vault password: " VAULT_PASSWORD
    echo ""
    echo "$VAULT_PASSWORD" > .vault_pass
    chmod 600 .vault_pass
    echo "✅ Vault password saved to .vault_pass (chmod 600)"
    echo "   Uncomment 'vault_password_file' in ansible.cfg to use it."

    # Add to .gitignore
    echo ".vault_pass" >> .gitignore 2>/dev/null || true
else
    echo "ℹ️  No vault password file created."
    echo "   You'll need to add --ask-vault-pass when running playbooks."
fi

# ── Step 5: Remind to update inventory ──────────────────────────────────────
echo ""
echo "============================================="
echo "  Setup Complete!"
echo "============================================="
echo ""
echo "📝 NEXT STEPS:"
echo ""
echo "  1. Edit inventory/hosts.ini"
echo "     Replace the example IPs with your actual 20 server IPs/hostnames"
echo ""
echo "  2. Test connectivity:"
echo "     ansible rhel_servers -m ping --ask-vault-pass"
echo ""
echo "  3. Dry run (check mode):"
echo "     ansible-playbook clear_cache.yml --check --ask-vault-pass"
echo ""
echo "  4. Run for real:"
echo "     ansible-playbook clear_cache.yml --ask-vault-pass"
echo ""
echo "  5. Schedule at 1:00 AM via cron on this control node:"
echo "     crontab -e"
echo '     0 1 * * * cd '"$SCRIPT_DIR"' && ansible-playbook clear_cache.yml --vault-password-file .vault_pass >> logs/cron.log 2>&1'
echo ""
