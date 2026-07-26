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

  # Arch does not support running a partially upgraded system. A package built
  # against a newer glibc than the installed one fails at load time with a
  # confusing "GLIBC_x.yy not found (required by <some library>)", which points at
  # the library rather than at the real cause. If anything is still pending after a
  # full upgrade then the mirror is out of sync or the transaction did not finish,
  # and installing more packages on top only spreads the inconsistency.
  local -a pending
  mapfile -t pending < <(pacman -Qu 2>/dev/null)
  if ((${#pending[@]})); then
    {
      echo
      echo "ERROR: ${#pending[@]} package(s) still pending after a full upgrade:"
      printf '  %s\n' "${pending[@]}"
      echo
      echo "The system is partially upgraded, which Arch does not support. Refresh the"
      echo "mirrors and upgrade again before re-running chezmoi apply:"
      echo "  sudo cachyos-rate-mirrors && sudo pacman -Syyu"
      echo
      echo "If these are held back on purpose, check IgnorePkg in /etc/pacman.conf."
    } >&2
    return 1
  fi
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
  # Being on PATH is not the same as being runnable: a helper installed from a -bin
  # package stops loading after a libalpm soname bump. Left unchecked, every AUR
  # package then fails with the same linker error, which reads as "all these
  # packages are broken" rather than "the helper is". Run it once to find out.
  # Not piped into tail here: the exit status of a pipeline is the last command's,
  # so a broken helper would still look like it succeeded.
  local helper_err
  if ! helper_err=$("$AUR_HELPER" --version 2>&1); then
    pkg::_fail "aur:<${AUR_HELPER} is installed but will not run: $(tail -n 1 <<<"$helper_err")>"
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

# VS Code extensions. `code --install-extension` is not idempotent in any useful
# sense -- it re-downloads an already-installed extension -- so diff against the
# installed set first, which also keeps a converged machine from hitting the
# marketplace 93 times on every apply.
#
# Extension IDs are case-insensitive and --list-extensions echoes back the
# marketplace's casing, not the casing written here, so both sides are lowercased
# before comparing. Without that, an entry like Catppuccin.catppuccin-vsc-icons
# reinstalls on every run.
pkg::vscode() {
  (($#)) || return 0
  if ! command -v code &>/dev/null; then
    pkg::_fail "vscode:<code not installed>"
    return 0
  fi

  local installed ext log
  installed=$(code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')
  log=$(mktemp)
  for ext in "$@"; do
    if grep -qxF "${ext,,}" <<<"$installed"; then
      continue
    fi
    pkg::log "Installing VS Code extension ${ext}"
    code --install-extension "$ext" >"$log" 2>&1 || {
      sed -e 's/^/      /' -e '/^ *$/d' "$log" | tail -n 4
      pkg::_fail "vscode:${ext}" "$log"
    }
  done
  rm -f "$log"
}

# tenv manages terraform/terragrunt/opentofu versions on every OS.
pkg::tenv() {
  local kind=$1 version=$2
  if ! command -v tenv &>/dev/null; then
    pkg::_fail "tenv:<tenv not installed> (nothing in this host's lists provides it)"
    return 0
  fi
  pkg::log "Installing ${kind} ${version} via tenv"
  tenv "$kind" install "$version" || pkg::_fail "tenv:${kind}@${version}"
}

PKG_REBOOT_REQUIRED=0

# A full -Syu can replace the kernel, which removes the module tree for the kernel
# still running. Anything that has to load modules cannot start until a reboot --
# docker in particular fails setting up its bridge with "failed to add jump rules
# to the ip tables", because it cannot load br_netfilter / iptable_nat.
pkg::kernel_modules_available() {
  [ -d "/lib/modules/$(uname -r)" ]
}

# Enable a systemd unit only if its package actually landed.
pkg::enable_service() {
  local unit=$1
  if ! systemctl list-unit-files "$unit" &>/dev/null; then
    return 0
  fi

  pkg::log "Enabling ${unit}"
  sudo systemctl enable "$unit" || {
    pkg::_fail "service:${unit} (enable)"
    return 0
  }

  if ! pkg::kernel_modules_available; then
    echo "    Not starting it yet: this run upgraded the kernel, so the running one"
    echo "    ($(uname -r)) has no module tree left. It will start after a reboot."
    PKG_REBOOT_REQUIRED=1
    return 0
  fi

  sudo systemctl start "$unit" || pkg::_fail "service:${unit} (start)"
}

# User units need no sudo, but they do need a running user manager. chezmoi can be
# applied over ssh or from a tty before the session bus exists, and there the enable
# is not a failure worth reporting -- the unit is enabled on the next apply from a
# real session.
pkg::enable_user_service() {
  local unit=$1
  if ! systemctl --user list-unit-files "$unit" &>/dev/null; then
    return 0
  fi
  if ! systemctl --user show-environment &>/dev/null; then
    echo "    Skipping ${unit}: no user systemd session on this login."
    return 0
  fi

  pkg::log "Enabling ${unit} (user)"
  systemctl --user enable --now "$unit" || pkg::_fail "user-service:${unit}"
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
  if [ "$PKG_REBOOT_REQUIRED" = 1 ]; then
    printf '\nREBOOT REQUIRED: the kernel was upgraded during this run, so services\n'
    printf 'that load kernel modules (docker) were enabled but not started.\n'
  fi
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
name in .chezmoidata/hosts.yaml.
EOF

  # If any AUR package failed, suggest retrying one by hand: the helper's own
  # output is far more specific than anything captured here. The name comes from
  # the failure list rather than being written in, so this file never has to know
  # what is in hosts.yaml.
  # The <...> entries are placeholders for "the helper is missing entirely", not
  # package names, so they would suggest a command that cannot work.
  local first_aur
  first_aur=$(printf '%s\n' "${PKG_FAILED[@]}" | grep -m1 '^aur:[^<]' | cut -d: -f2-)
  if [ -n "$first_aur" ]; then
    cat <<EOF

If every AUR package failed, the helper itself is the problem, not the names --
check that ${AUR_HELPER} can build at all:

  ${AUR_HELPER} -S --needed --noconfirm --skipreview ${first_aur}
EOF
  fi

  printf '\nThen re-run: chezmoi apply\n'
  return 1
}
