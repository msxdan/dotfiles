#!/usr/bin/env bash
#
# Package helpers for Arch-family hosts (CachyOS).
#
# Sourced by run_onchange_install-packages.sh.tmpl -- not meant to be run directly.
# Every helper is idempotent, and collects failures instead of aborting, so one
# package renamed upstream cannot stop the rest of the machine from converging.
# Call pkg::report last: it exits non-zero if anything failed, which makes chezmoi
# surface the problem and retry the script on the next apply.

declare -ga PKG_FAILED=()
: "${AUR_HELPER:=paru}"

pkg::log() { printf '\n==> %s\n' "$*"; }

# Arch has no supported partial-upgrade path, so a full -Syu must precede any -S
# that could pull in a newer dependency.
pkg::sync() {
  pkg::log "Upgrading system packages"
  sudo pacman -Syu --noconfirm
}

# Usage: pkg::_install <label> <cmd> [args...] -- [packages...]
# One transaction for the whole list; on failure retry individually so a single bad
# name is isolated and reported rather than taking the batch down with it.
pkg::_install() {
  local label=$1
  shift

  local -a cmd=()
  while (($#)) && [[ $1 != -- ]]; do
    cmd+=("$1")
    shift
  done
  shift || true
  (($#)) || return 0

  pkg::log "Installing $# ${label} package(s)"
  if "${cmd[@]}" "$@"; then
    return 0
  fi

  pkg::log "Batch ${label} install failed, retrying one by one"
  local pkg
  for pkg in "$@"; do
    "${cmd[@]}" "$pkg" || PKG_FAILED+=("${label}:${pkg}")
  done
}

pkg::pacman() {
  pkg::_install pacman sudo pacman -S --needed --noconfirm -- "$@"
}

pkg::aur() {
  (($#)) || return 0
  if ! command -v "$AUR_HELPER" &>/dev/null; then
    PKG_FAILED+=("aur:<${AUR_HELPER} not installed>")
    return 0
  fi
  pkg::_install aur "$AUR_HELPER" -S --needed --noconfirm -- "$@"
}

pkg::pipx() {
  (($#)) || return 0
  if ! command -v pipx &>/dev/null; then
    PKG_FAILED+=("pipx:<pipx not installed>")
    return 0
  fi

  local installed spec name
  installed=$(pipx list --short 2>/dev/null | cut -d' ' -f1)
  for spec in "$@"; do
    name=${spec%%[<>=]*}
    if grep -qxF "$name" <<<"$installed"; then
      continue
    fi
    pkg::log "Installing pipx package ${spec}"
    pipx install "$spec" --quiet || PKG_FAILED+=("pipx:${spec}")
  done
}

# mise replaces goenv/pyenv/volta on Linux.
pkg::mise() {
  (($#)) || return 0
  if ! command -v mise &>/dev/null; then
    PKG_FAILED+=("mise:<mise not installed>")
    return 0
  fi

  local tool
  for tool in "$@"; do
    pkg::log "Pinning ${tool}"
    mise use --global --yes "$tool" || PKG_FAILED+=("mise:${tool}")
  done
}

# tenv manages terraform/terragrunt/opentofu versions on every OS.
pkg::tenv() {
  local kind=$1 version=$2
  if ! command -v tenv &>/dev/null; then
    PKG_FAILED+=("tenv:<tenv not installed>")
    return 0
  fi
  pkg::log "Installing ${kind} ${version} via tenv"
  tenv "$kind" install "$version" || PKG_FAILED+=("tenv:${kind}@${version}")
}

# Enable a systemd unit only if its package actually landed.
pkg::enable_service() {
  local unit=$1
  if ! systemctl list-unit-files "$unit" &>/dev/null; then
    return 0
  fi
  pkg::log "Enabling ${unit}"
  sudo systemctl enable --now "$unit" || PKG_FAILED+=("service:${unit}")
}

pkg::add_user_to_group() {
  local group=$1
  getent group "$group" >/dev/null || return 0
  if id -nG "$USER" | grep -qw "$group"; then
    return 0
  fi
  pkg::log "Adding ${USER} to the ${group} group"
  sudo usermod -aG "$group" "$USER"
  echo "    Log out and back in for ${group} membership to take effect."
}

pkg::report() {
  ((${#PKG_FAILED[@]})) || {
    pkg::log "All packages installed"
    return 0
  }
  printf '\nWARNING: %d package(s) failed to install:\n' "${#PKG_FAILED[@]}"
  printf '  - %s\n' "${PKG_FAILED[@]}"
  cat <<'EOF'

These were most likely renamed or dropped upstream. Fix the names in
.chezmoidata/packages.yaml, then re-run: chezmoi apply
EOF
  return 1
}
