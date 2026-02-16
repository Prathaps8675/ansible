# Ansible - Production RHEL Cache Clear

Safe, automated cache clearing across 20 RHEL production servers using Ansible with encrypted credentials.

## What It Does (in order)

| Step | Action | Impact on Apps |
|------|--------|----------------|
| 1 | `sync` — flush filesystem buffers to disk | ✅ None |
| 2 | `drop_caches` — free PageCache + Dentries + Inodes | ✅ None — only frees **unused** cache |
| 3 | Swap clear (only if free RAM > swap used) | ✅ None — pages moved back to RAM |
| 4 | `journalctl --vacuum-size=100M` — trim journal logs | ✅ None |
| 5 | `dnf clean all` — clear package manager cache | ✅ None |
| 6 | Remove `/tmp` files older than 7 days | ✅ None — skips active sessions |

> **Key safety point:** `drop_caches` only releases memory the kernel cached for performance. It does NOT touch application memory (heap, stack, mmap). Applications keep running with zero interruption. The kernel transparently re-caches data as needed.

## Project Structure

```
ansible-cache-clear/
├── ansible.cfg                              # Ansible configuration
├── clear_cache.yml                          # Main playbook
├── setup.sh                                 # Interactive one-time setup
├── inventory/
│   └── hosts.ini                            # 20 server inventory
├── group_vars/
│   └── rhel_servers/
│       └── vault.yml.example                # Example vault (credentials)
└── logs/                                    # Ansible run logs
```

## Quick Start (on your Ansible control node)

### 1. Copy the project to your control node (Linux machine with Ansible)

```bash
# scp or git clone this folder to your control node
cd ansible-cache-clear
```

### 2. Run the setup script

```bash
bash setup.sh
```

This will:
- ✅ Check Ansible is installed
- ✅ Ask for your **SSH username** and **password** (same for SSH + sudo)
- ✅ Create an **encrypted vault file** (`group_vars/rhel_servers/vault.yml`)
- ✅ Optionally save the vault password to `.vault_pass` for unattended runs

### 3. Edit the inventory

```bash
vi inventory/hosts.ini
# Replace the example IPs with your actual 20 server IPs
```

### 4. Test connectivity

```bash
ansible rhel_servers -m ping --ask-vault-pass
```

### 5. Dry run (see what would happen)

```bash
ansible-playbook clear_cache.yml --check --ask-vault-pass
```

### 6. Run it for real

```bash
ansible-playbook clear_cache.yml --ask-vault-pass
```

## Password Handling — How It Works

```
┌──────────────────────────────────────────────────────────┐
│  Your Password (SSH + sudo)                              │
│  ↓                                                       │
│  Encrypted with AES-256 into vault.yml                   │
│  ↓                                                       │
│  Decrypted at runtime by Ansible using vault password    │
│  ↓                                                       │
│  Used for SSH login (ansible_ssh_pass)                   │
│  Used for sudo (ansible_become_pass)                     │
└──────────────────────────────────────────────────────────┘
```

- Your server password is **never stored in plain text**
- The vault file is encrypted with **AES-256**
- You unlock it with a separate vault password at runtime
- Optionally save the vault password to `.vault_pass` (chmod 600) for automated/cron runs

### Managing Vault

```bash
# View encrypted credentials
ansible-vault view group_vars/rhel_servers/vault.yml

# Edit/change password
ansible-vault edit group_vars/rhel_servers/vault.yml

# Re-key (change vault encryption password)
ansible-vault rekey group_vars/rhel_servers/vault.yml
```

## Scheduling at 1:00 AM (cron)

If you want to automate the 1 AM run, add a cron job on your **control node**:

```bash
crontab -e
```

Add this line:

```
0 1 * * * cd /path/to/ansible-cache-clear && ansible-playbook clear_cache.yml --vault-password-file .vault_pass >> logs/cron.log 2>&1
```

> Make sure `.vault_pass` exists (setup.sh can create it for you).

## Run on Specific Servers Only

```bash
# Only server-01 and server-02
ansible-playbook clear_cache.yml --limit server-01,server-02 --ask-vault-pass

# Only first 5 servers
ansible-playbook clear_cache.yml --limit 'rhel_servers[0:4]' --ask-vault-pass
```

## Safety Guarantees

1. **`sync` runs first** — all dirty filesystem pages written to disk before cache drop
2. **`serial: 5`** — only 5 servers at a time (rolling), never all 20 at once
3. **Swap only cleared if safe** — checks free RAM > swap used before attempting
4. **No service restarts** — nothing is restarted or stopped
5. **No application impact** — `drop_caches` only frees kernel-level unused cache
6. **`--check` mode** — always dry-run first to verify
