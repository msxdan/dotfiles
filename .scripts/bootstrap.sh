#!/usr/bin/env bash
#
# One-shot bootstrap for a fresh Arch/CachyOS machine.
#
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/msxdan/dotfiles/main/.scripts/bootstrap.sh)"
#
# To test a branch:
#
#   BRANCH=cachy-setup bash -c "$(curl -fsSL https://raw.githubusercontent.com/msxdan/dotfiles/cachy-setup/.scripts/bootstrap.sh)"
#
# This installs only what has to exist *before* chezmoi can run, then hands over.
# Everything else is the dotfiles' job. It exists because those prerequisites are
# easy to forget after restoring a VM snapshot, and each one fails in a way that
# looks unrelated to the real cause.
set -euo pipefail

REPO="${REPO:-msxdan/dotfiles}"
BRANCH="${BRANCH:-main}"

if [ -d /run/archiso ]; then
  echo "ERROR: this is an Arch live ISO (/run/archiso exists)." >&2
  echo "Install CachyOS to disk and boot the installed system first." >&2
  exit 1
fi

# Install chezmoi from the repos, not via get.chezmoi.io: that installer drops the
# binary in ./bin relative to the working directory, which is not on PATH on a fresh
# machine, so later `chezmoi` calls from inside the scripts are not found.
#
# ksshaskpass is needed before the first clone: the private submodule is fetched over
# SSH during init, and ssh cannot ask for a key passphrase when it has no controlling
# terminal, which is the case when git is being driven by chezmoi.
echo "==> Installing prerequisites"
sudo pacman -Syu --needed --noconfirm chezmoi git age openssh ksshaskpass

export SSH_ASKPASS=/usr/bin/ksshaskpass

# The private submodule's URL is git@github.com, and the SSH keys it would provide
# live inside it, so a working key has to be in the agent already.
if ! ssh-add -l >/dev/null 2>&1; then
  cat >&2 <<'EOF'

ERROR: no ssh-agent with loaded keys.

The private submodule is cloned over SSH and its own keys live inside it, so a key
with access to the private repo must already be in an agent. Then re-run this script.

  eval "$(ssh-agent -s)"
  ssh-add ~/.ssh/id_ed25519
EOF
  exit 1
fi

# An unknown host key is itself a prompt, and prompts are what break this. Require it
# to be accepted deliberately rather than auto-trusting whatever answers right now.
if ! ssh-keygen -F github.com >/dev/null 2>&1; then
  cat >&2 <<'EOF'

ERROR: github.com is not in ~/.ssh/known_hosts.

Verify and accept its host key, then re-run this script:

  ssh -T git@github.com

Published fingerprints:
  https://docs.github.com/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
EOF
  exit 1
fi

echo "==> chezmoi init (${REPO}, branch ${BRANCH})"
chezmoi init --branch "$BRANCH" "$REPO" --apply --recurse-submodules
