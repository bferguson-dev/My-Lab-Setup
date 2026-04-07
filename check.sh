#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

PYTHON_BIN="${PYTHON_BIN:-python3}"
VENV_DIR="${VENV_DIR:-.venv}"
BOOTSTRAP_VENV="${BOOTSTRAP_VENV:-1}"
RUN_PYTHON="$PYTHON_BIN"

README_DISCLAIMER='*[!] This project is provided as-is, without warranties or guarantees of any kind, and has not been validated in a production environment unless explicitly stated otherwise. You are solely responsible for evaluating, testing, securing, and operating it safely in your environment and for verifying compliance with any legal, regulatory, or contractual requirements. By using this project, you accept all risk, and the authors and contributors assume no liability for any loss, damage, outage, misuse, or other consequences arising from its use. [!]*'

PLAYBOOKS=(
  ansible/playbooks/proxmox_install_phase.yml
  ansible/playbooks/proxmox_postinstall_media.yml
  ansible/playbooks/proxmox_media_cleanup.yml
  ansible/playbooks/proxmox_snapshot_clone.yml
  ansible/playbooks/site.yml
)

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

info() {
  printf '[check] %s\n' "$*"
}

need_command() {
  command -v "$1" >/dev/null 2>&1
}

ensure_venv() {
  if [[ "$BOOTSTRAP_VENV" != "1" ]]; then
    return 0
  fi

  if [[ ! -d "$VENV_DIR" ]]; then
    info "creating virtualenv at $VENV_DIR"
    "$PYTHON_BIN" -m venv "$VENV_DIR"
  fi

  if [[ -x "$VENV_DIR/bin/python" ]]; then
    local venv_python="$VENV_DIR/bin/python"
    info "installing Python QA tools into $VENV_DIR"
    "$venv_python" -m pip install --upgrade pip >/dev/null
    "$venv_python" -m pip install \
      ansible-core ansible-lint pyyaml yamllint >/dev/null
    case ":$PATH:" in
      *":$VENV_DIR/bin:"*) ;;
      *) export PATH="$VENV_DIR/bin:$PATH" ;;
    esac
    RUN_PYTHON="$venv_python"
    if [[ -f ansible/collections/requirements.yml ]] && need_command ansible-galaxy; then
      info "installing required Ansible collections"
      ansible-galaxy collection install -r ansible/collections/requirements.yml \
        >/dev/null
    fi
  else
    warn "virtualenv python not found in $VENV_DIR; skipping bootstrap"
  fi
}

check_docs() {
  info "checking README and disclaimer wording"
  local readme_first
  readme_first="$(head -n 1 README.md)"
  [[ "$readme_first" == "$README_DISCLAIMER" ]]

  "$RUN_PYTHON" - <<'PY'
from pathlib import Path
import sys

canonical = """This project is provided as-is, without warranties or guarantees of any kind, and has not been validated in a production environment unless explicitly stated otherwise. You are solely responsible for evaluating, testing, securing, and operating it safely in your environment and for verifying compliance with any legal, regulatory, or contractual requirements. By using this project, you accept all risk, and the authors and contributors assume no liability for any loss, damage, outage, misuse, or other consequences arising from its use."""

disclaimer = Path("DISCLAIMER.md").read_text(encoding="utf-8").strip().splitlines()
body = "\n".join(line.strip() for line in disclaimer if line.strip() and line.strip() != "# Disclaimer")
if body != canonical:
    print("FAIL: DISCLAIMER.md does not match the canonical disclaimer text.")
    sys.exit(1)

readme = Path("README.md").read_text(encoding="utf-8")
required = [
    "## Overview",
    "## Non-Goals",
    "## Requirements",
    "## Assumptions",
    "## Setup",
    "## Usage",
    "## Expected Output",
    "## Troubleshooting",
    "## Recovery And Rollback",
    "## Known Limitations",
    "## Quality Gate",
]
missing = [section for section in required if section not in readme]
if missing:
    print("FAIL: README.md is missing required sections:")
    for section in missing:
        print(f"- {section}")
    sys.exit(1)
PY
}

check_yaml_parse() {
  info "checking YAML parseability"
  "$RUN_PYTHON" - <<'PY'
from pathlib import Path
import sys

try:
    import yaml
except Exception as exc:
    print(f"FAIL: PyYAML is unavailable: {exc}")
    sys.exit(1)

for path in sorted(Path("ansible").rglob("*.yml")):
    text = path.read_text(encoding="utf-8")
    list(yaml.safe_load_all(text))
    print(f"ok: {path}")
PY
}

check_ansible_syntax() {
  if ! need_command ansible-playbook; then
    warn "ansible-playbook is unavailable; skipping syntax checks"
    return 0
  fi

  info "checking Ansible playbook syntax"
  for playbook in "${PLAYBOOKS[@]}"; do
    ansible-playbook -i ansible/inventory/hosts.yml --syntax-check "$playbook"
  done
}

check_ansible_lint() {
  if ! need_command ansible-lint; then
    warn "ansible-lint is unavailable; skipping Ansible lint"
    return 0
  fi

  info "running ansible-lint"
  ansible-lint ansible
}

check_shell() {
  local shell_files=(
    check.sh
    ansible/bootstrap_iso/bootstra.sh
    ansible/bootstrap_iso/run_linu.sh
    ansible/bootstrap_iso/tools/build_bootstrap_iso_on_pm01.sh
  )

  info "checking shell syntax"
  for file in "${shell_files[@]}"; do
    bash -n "$file"
  done

  if need_command shellcheck; then
    info "running shellcheck"
    shellcheck "${shell_files[@]}"
  else
    warn "shellcheck is unavailable; only bash -n was run"
  fi
}

check_git_hygiene() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    warn "not inside a Git worktree; skipping Git hygiene checks"
    return 0
  fi

  info "checking git diff hygiene"
  git diff --check

  if git diff --cached --quiet; then
    info "no staged changes; skipping cached diff-only checks"
  else
    git diff --cached --check
    info "scanning staged changes with git-secrets"
    local cached_output
    cached_output="$(mktemp)"
    if git secrets --scan --cached >"$cached_output" 2>&1; then
      rm -f "$cached_output"
    else
      if grep -Fq 'ansible/artifacts/public-signing-key.asc' "$cached_output"; then
        warn "git-secrets --cached hit the known public-key false positive"
        warn "falling back to a staged-files-only git-secrets scan"
        mapfile -t staged_files < <(git diff --cached --name-only)
        if ((${#staged_files[@]} > 0)); then
          git secrets --scan "${staged_files[@]}"
        fi
        rm -f "$cached_output"
      else
        cat "$cached_output" >&2
        rm -f "$cached_output"
        return 1
      fi
    fi
  fi

  info "scanning tracked files with git-secrets"
  mapfile -d '' tracked_files < <(
    git ls-files -z \
      ':(exclude)ansible/artifacts/public-signing-key.asc' \
      ':(exclude)ansible/artifacts/bootstrap.iso'
  )

  if ((${#tracked_files[@]} > 0)); then
    git secrets --scan "${tracked_files[@]}"
  fi
}

main() {
  if ! need_command "$PYTHON_BIN"; then
    printf 'FAIL: %s not found in PATH\n' "$PYTHON_BIN" >&2
    exit 1
  fi

  ensure_venv
  check_docs
  check_yaml_parse
  check_ansible_syntax
  check_ansible_lint
  check_shell
  check_git_hygiene
  info "all available checks completed"
}

main "$@"
