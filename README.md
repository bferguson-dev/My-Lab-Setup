# Proxmox Lab Ansible (Sanitized)

This repo intentionally contains no personal/sensitive values.

## Safety rules
- Never commit real usernames, passwords, keys, hostnames, public IPs, or private IPs.
- Keep inventory as placeholders only.
- Put secrets in local vault files that are git-ignored.

## Structure
- `ansible/inventory/hosts.yml` placeholder inventory
- `ansible/inventory/group_vars/all.yml` placeholder variables
- `ansible/playbooks/proxmox_install_phase.yml` create originals, attach OS ISOs, start installers
- `ansible/playbooks/site.yml` guest baseline config (Linux + Windows)
- `ansible/playbooks/proxmox_postinstall_media.yml` detach installer ISOs, attach Linux bootstrap ISO
- `ansible/playbooks/proxmox_media_cleanup.yml` remove installer ISOs, set boot order
- `ansible/playbooks/proxmox_snapshot_clone.yml` shutdown, snapshot, and clone from Proxmox
- `ansible/roles/*` task implementations

## Execution order
1. Fill placeholders in inventory + vars.
2. Provision originals and start OS installers:
   `ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/proxmox_install_phase.yml`
3. Complete OS installation in guest consoles (manual unless you add unattended install files).
4. Attach post-install media (Linux bootstrap ISO) and normalize boot order:
   `ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/proxmox_postinstall_media.yml`
5. Run guest baseline config:
   `ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml`
6. Optional media cleanup on Proxmox host:
   `ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/proxmox_media_cleanup.yml`
7. Snapshot and clone lifecycle from Proxmox host:
   `ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/proxmox_snapshot_clone.yml`

## Notes
- `proxmox_install_phase.yml` can optionally recreate originals if `proxmox_recreate_original_vms: true`.
- Set `proxmox_bootstrap_iso_name` in `group_vars/all.yml` to mount shared lab bootstrap media for both Windows and Linux.
- Windows tasks configure WinRM, disable auto updates, and log to `C:\LabSetup`.
- Linux tasks ensure SSH + qemu-guest-agent, upgrade qemu-guest-agent to latest repo version, and disable auto update timers.
- Baseline order is enforced as: disable auto updates -> install/update tools -> enable remote access -> firewall adjust -> write verification logs.
- Keep all secrets out of git.

## Combined Bootstrap ISO Payload
- Source payload folder: `ansible/bootstrap_iso/`
- Includes:
  - `windows/bootstrap-win.ps1`
  - `windows/run-windows-bootstrap.cmd`
  - `linux/bootstrap-linux.sh`
  - `linux/run-linux-bootstrap.sh`

Build ISO on Proxmox host:
- Script: `ansible/bootstrap_iso/tools/build_bootstrap_iso_on_pm01.sh`
- Output ISO default: `/var/lib/vz/template/iso/LAB_BOOTSTRAP.iso`

Notes:
- `qemu-guest-agent` package binaries are **not** embedded in ISO (distro-specific and quickly stale).
- Bootstrap + Ansible both perform a post-install repo-based qemu-guest-agent upgrade to keep versions current.
