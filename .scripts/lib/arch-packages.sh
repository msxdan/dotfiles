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
declare -ga PKG_ERRORS=()
: "${AUR_HELPER:=paru}"

# Record a failure together with the tail of its output. Without the error text a
# summary of 21 failed package names is unactionable -- the real cause has already
# scrolled off screen by the time the report prints.
pkg::_fail() {
  local id=$1 log=${2:-}
  PKG_FAILED+=("$id")
  if [ -n "$log" ] && [ -s "$log" ]; then
    PKG_ERRORS+=("${id}
$(sed -e 's/^/      /' -e '/^ *$/d' "$log" | tail -n 4)")
  fi
}

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
  local pkg log
  log=$(mktemp)
  for pkg in "$@"; do
    if "${cmd[@]}" "$pkg" >"$log" 2>&1; then
      echo "    ok   ${pkg}"
    else
      echo "    FAIL ${pkg}"
      sed -e 's/^/         /' -e '/^ *$/d' "$log" | tail -n 4
      pkg::_fail "${label}:${pkg}" "$log"
    fi
  done
  rm -f "$log"
}

pkg::pacman() {
  pkg::_install pacman sudo pacman -S --needed --noconfirm -- "$@"
}

pkg::aur() {
  (($#)) || return 0
  if ! command -v "$AUR_HELPER" &>/dev/null; then
    pkg::_fail "aur:<${AUR_HELPER} not installed>"
    return 0
  fi
  # --skipreview is required for unattended use: paru otherwise opens each PKGBUILD
  # in a pager for review, which cannot succeed with no terminal attached and fails
  # every single package identically.
  pkg::_install aur "$AUR_HELPER" -S --needed --noconfirm --skipreview -- "$@"
}

pkg::pipx() {
  (($#)) || return 0
  if ! command -v pipx &>/dev/null; then
    pkg::_fail "pipx:<pipx not installed>"
    return 0
  fi

  local installed spec name log
  installed=$(pipx list --short 2>/dev/null | cut -d' ' -f1)
  log=$(mktemp)
  for spec in "$@"; do
    name=${spec%%[<>=]*}
    if grep -qxF "$name" <<<"$installed"; then
      continue
    fi
    pkg::log "Installing pipx package ${spec}"
    pipx install "$spec" --quiet >"$log" 2>&1 || {
      sed -e 's/^/      /' -e '/^ *$/d' "$log" | tail -n 4
      pkg::_fail "pipx:${spec}" "$log"
    }
  done
  rm -f "$log"
}

# mise replaces goenv/pyenv/volta on Linux.
pkg::mise() {
  (($#)) || return 0
  if ! command -v mise &>/dev/null; then
    pkg::_fail "mise:<mise not installed>"
    return 0
  fi

  local tool
  for tool in "$@"; do
    pkg::log "Pinning ${tool}"
    mise use --global --yes "$tool" || pkg::_fail "mise:${tool}"
  done
}

# tenv manages terraform/terragrunt/opentofu versions on every OS.
pkg::tenv() {
  local kind=$1 version=$2
  if ! command -v tenv &>/dev/null; then
    pkg::_fail "tenv:<tenv not installed> (needs the tenv-bin AUR package)"
    return 0
  fi
  pkg::log "Installing ${kind} ${version} via tenv"
  tenv "$kind" install "$version" || pkg::_fail "tenv:${kind}@${version}"
}

# Enable a systemd unit only if its package actually landed.
pkg::enable_service() {
  local unit=$1
  if ! systemctl list-unit-files "$unit" &>/dev/null; then
    return 0
  fi
  pkg::log "Enabling ${unit}"
  sudo systemctl enable --now "$unit" || pkg::_fail "service:${unit}"
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

  if ((${#PKG_ERRORS[@]})); then
    printf '\nErrors:\n'
    printf '  %s\n' "${PKG_ERRORS[@]}"
  fi

  cat <<'EOF'

If a single package failed, it was probably renamed or dropped upstream: fix the
name in .chezmoidata/hosts.yaml. If every AUR package failed, the helper itself is
the problem, not the names -- check that paru can build at all:

  paru -S --needed --noconfirm --skipreview tenv-bin

Then re-run: chezmoi apply
EOF
  return 1
}
