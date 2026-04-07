*[!] This project is provided as-is, without warranties or guarantees of any kind, and has not been validated in a production environment unless explicitly stated otherwise. You are solely responsible for evaluating, testing, securing, and operating it safely in your environment and for verifying compliance with any legal, regulatory, or contractual requirements. By using this project, you accept all risk, and the authors and contributors assume no liability for any loss, damage, outage, misuse, or other consequences arising from its use. [!]*

# Proxmox Lab Ansible (Sanitized)

This repository contains sanitized Ansible playbooks and bootstrap helpers for
building a Proxmox-backed lab with Windows and Linux originals, applying a
guest baseline, and cloning from known snapshots. It is intended for isolated
lab automation, not for production provisioning.

The full legal disclaimer is in `DISCLAIMER.md`.

## Overview

The repository manages a lab lifecycle with these phases:

1. Create or recreate original VMs on a Proxmox host.
2. Attach installer media and start manual guest installation.
3. Attach post-install bootstrap media and normalize boot order.
4. Resolve guest IPs dynamically from the Proxmox guest agent.
5. Apply Linux and Windows guest baselines with Ansible.
6. Snapshot originals and create full clones.

## Non-Goals

- This repo does not include real secrets, hostnames, IPs, or personal data.
- This repo does not provide unattended OS installation files.
- This repo does not harden systems for production use.
- This repo does not manage cloud services, DNS, certificates, or internet
  exposure.

## Requirements

- A reachable Proxmox host with `qm` available.
- Python 3 for `check.sh`.
- Ansible control-node access to the repository.
- Proxmox guest agent enabled in the guest templates or originals.
- Windows guests that can expose WinRM on TCP `5985`.
- Linux guests that can expose SSH after bootstrap/baseline.

## Assumptions

- Inventory values in this repo remain placeholders until you replace them
  locally.
- Secrets are injected only through local ignored files such as
  `ansible/inventory/group_vars/local-secrets.yml`.
- Windows remoting is for a trusted lab network only. The baseline config uses
  WinRM over HTTP with NTLM, not TLS.
- Guest IP addresses are not stable and are discovered at run time from the
  Proxmox guest agent.

## Repository Layout

- `ansible/inventory/hosts.yml`: placeholder inventory keyed by host name and
  Proxmox VMID.
- `ansible/inventory/group_vars/all.yml`: non-secret placeholder defaults.
- `ansible/collections/requirements.yml`: collection dependency manifest for
  local and CI validation.
- `ansible/inventory/group_vars/local-secrets.yml.example`: local secret
  template to copy and fill outside Git.
- `ansible/playbooks/proxmox_install_phase.yml`: create originals, attach
  installer media, and start installers.
- `ansible/playbooks/site.yml`: discover guest IPs and apply Linux and Windows
  baselines.
- `ansible/playbooks/proxmox_postinstall_media.yml`: detach installer media,
  attach bootstrap media, and normalize boot order.
- `ansible/playbooks/proxmox_media_cleanup.yml`: remove ISO attachments and
  restore disk boot.
- `ansible/playbooks/proxmox_snapshot_clone.yml`: stop originals, snapshot
  them, and create full clones.
- `ansible/bootstrap_iso/`: combined Linux and Windows bootstrap payload.
- `check.sh`: local quality gate for docs, YAML, Ansible syntax, lint, shell
  syntax, and secret hygiene.

## Setup

1. Copy the secret template and fill it locally:

   ```bash
   cp ansible/inventory/group_vars/local-secrets.yml.example \
     ansible/inventory/group_vars/local-secrets.yml
   ```

2. Edit `ansible/inventory/hosts.yml` and
   `ansible/inventory/group_vars/all.yml` with your local Proxmox and guest
   placeholders.

3. If you use the bootstrap ISO flow, copy the payload from
   `ansible/bootstrap_iso/` to a working directory on the Proxmox host and
   build the ISO:

   ```bash
   ./ansible/bootstrap_iso/tools/build_bootstrap_iso_on_pm01.sh \
     /root/lab-bootstrap-src \
     /var/lib/vz/template/iso/LAB_BOOTSTRAP.iso
   ```

4. Set `proxmox_bootstrap_iso_name` in
   `ansible/inventory/group_vars/all.yml` to the ISO filename you built.

5. Run the local quality gate before applying anything:

   ```bash
   ./check.sh
   ```

## Usage

1. Provision originals and attach installer media:

   ```bash
   ansible-playbook -i ansible/inventory/hosts.yml \
     ansible/playbooks/proxmox_install_phase.yml
   ```

2. Complete OS installation manually from the guest consoles.

3. Attach post-install media and set disk boot defaults:

   ```bash
   ansible-playbook -i ansible/inventory/hosts.yml \
     ansible/playbooks/proxmox_postinstall_media.yml
   ```

4. Run the guest baseline:

   ```bash
   ansible-playbook -i ansible/inventory/hosts.yml \
     ansible/playbooks/site.yml
   ```

5. Optionally detach ISO media after baseline:

   ```bash
   ansible-playbook -i ansible/inventory/hosts.yml \
     ansible/playbooks/proxmox_media_cleanup.yml
   ```

6. Snapshot originals and create clones:

   ```bash
   ansible-playbook -i ansible/inventory/hosts.yml \
     ansible/playbooks/proxmox_snapshot_clone.yml
   ```

## Expected Output

- Linux baseline logs under `/var/log/labsetup/`.
- Windows baseline logs under `C:\LabSetup`.
- Runtime guest targeting based on current IPs returned by the Proxmox guest
  agent.
- Stopped originals and created snapshots/clones when
  `proxmox_snapshot_clone.yml` succeeds.

## Bootstrap ISO Payload

The combined bootstrap ISO expects these files at the ISO root:

- `bootstra.ps1`
- `run_wind.cmd`
- `bootstra.sh`
- `run_linu.sh`

Bootstrap order is intentionally fixed:

1. Disable automatic updates.
2. Install or update access tooling.
3. Enable remote access.
4. Adjust local firewall state.
5. Write verification logs.

## Quality Gate

Use `./check.sh` as the local gate before commit or push. It currently checks:

- README and disclaimer wording.
- YAML parseability for tracked repo YAML files.
- Ansible playbook syntax when `ansible-playbook` is available.
- `ansible-lint` when available or after the script bootstraps its local venv.
- Shell syntax for repo shell scripts and optional `shellcheck`.
- `git diff --check`, staged-diff review helpers, and local secret scans when
  run inside a Git worktree.

GitHub Actions runs `./check.sh` on pushes and pull requests.

## Troubleshooting

- `site.yml` fails while resolving guest IPs:
  Confirm the Proxmox guest agent is installed, enabled, and responsive in the
  guest before running the baseline.
- Windows baseline cannot connect over WinRM:
  Confirm the guest agent bootstrap succeeded, the guest firewall allows TCP
  `5985`, and your lab network allows host-to-guest access.
- Linux baseline cannot connect over SSH:
  Confirm the bootstrap ISO or baseline enabled `ssh` or `sshd` and that the
  selected admin user matches the guest image.
- `check.sh` reports missing tools:
  Re-run it with network access so it can populate `.venv`, or install the
  missing tool manually and run it again.

## Recovery And Rollback

- `proxmox_install_phase.yml` can recreate originals only when
  `proxmox_recreate_original_vms: true`; leave it `false` for safer reruns.
- `proxmox_media_cleanup.yml` is the rollback path for attached ISO media and
  boot-order cleanup.
- `proxmox_snapshot_clone.yml` waits for graceful shutdown first and only then
  force-stops originals, which reduces dirty snapshot risk but does not
  guarantee application-consistent guest state.
- Snapshot names in `group_vars/all.yml` should change deliberately if you need
  a new baseline generation instead of reusing an older one.

## Known Limitations

- The repo has not been validated in production.
- Windows remoting is lab-oriented and not TLS-terminated.
- The current automation assumes a single Proxmox delegate host from the
  `proxmox` inventory group.
- The repo does not include automated guest installation or image sealing.
- Large artifact files under `ansible/artifacts/` are tracked and can trigger
  slower scans or false positives in history-wide secret tooling.
