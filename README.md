# Proxmox Lab Ansible (Sanitized)

This repo intentionally contains no personal/sensitive values.

## Safety rules
- Never commit real usernames, passwords, keys, hostnames, public IPs, or private IPs.
- Keep inventory as placeholders only.
- Put secrets in local vault files that are git-ignored.

## Structure
- `ansible/inventory/hosts.yml` placeholder inventory
- `ansible/inventory/group_vars/all.yml` placeholder variables
- `ansible/playbooks/site.yml` guest baseline config (Linux + Windows)
- `ansible/playbooks/proxmox_media_cleanup.yml` remove installer ISOs, set boot order
- `ansible/playbooks/proxmox_snapshot_clone.yml` shutdown, snapshot, and clone from Proxmox
- `ansible/roles/*` task implementations

## Execution order
1. Fill placeholders in inventory + vars.
2. Run guest baseline config:
   `ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml`
3. Optional media cleanup on Proxmox host:
   `ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/proxmox_media_cleanup.yml`
4. Snapshot and clone lifecycle from Proxmox host:
   `ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/proxmox_snapshot_clone.yml`

## Notes
- Windows tasks configure WinRM, disable auto updates, and log to `C:\LabSetup`.
- Linux tasks ensure SSH + qemu-guest-agent and disable auto update timers.
- Keep all secrets out of git.
