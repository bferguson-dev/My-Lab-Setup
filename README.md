# Proxmox Lab Ansible (Sanitized)

This repo intentionally contains no personal/sensitive values.

## Safety rules
- Never commit real usernames, passwords, keys, hostnames, public IPs, or private IPs.
- Keep inventory as placeholders only.
- Put secrets in local vault files that are git-ignored (create your own outside this repo or add ignore rules).

## Structure
- `ansible/inventory/hosts.yml` placeholder inventory
- `ansible/inventory/group_vars/all.yml` placeholder variables
- `ansible/playbooks/site.yml` main playbook
- `ansible/roles/*` baseline tasks

## Quick start
1. Fill placeholders in `ansible/inventory/hosts.yml` and `ansible/inventory/group_vars/all.yml` locally.
2. Run:
   `ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml`
