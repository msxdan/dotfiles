# Dotfiles

Personal dotfiles managed with [chezmoi](https://chezmoi.io). Supports macOS and
Arch-family Linux (CachyOS), with a legacy WSL/Debian path.

## Setup

### macOS

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init msxdan/dotfiles --apply --recurse-submodules
```

### CachyOS / Arch

Must be an **installed** system. Applying on a live ISO is refused: the bootstrap
does a full `pacman -Syu` plus ~110 packages, which on a read-only squashfs with a
tmpfs overlay replaces the running kernel/systemd and exhausts the overlay.

The private submodule (`dot_private`) is cloned over SSH, but the SSH keys live
*inside* it — so a brand-new machine has no key to authenticate with. Get a working
key into an agent **before** running init:

```bash
sudo pacman -S --needed chezmoi git age openssh

# Either copy an existing key across, or make one for this machine and add the
# public half at https://github.com/settings/keys
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub

eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Accept github.com's host key and confirm auth works before involving chezmoi
ssh -T git@github.com

chezmoi init msxdan/dotfiles --apply --recurse-submodules
```

`--recurse-submodules` is not optional: several templates `include` files from
`dot_private`, so without it `chezmoi apply` fails to render.

**If you see `exec(/usr/lib/ssh/ssh-askpass): No such file or directory`**, ssh needed
to prompt — for a passphrase, or to confirm an unknown host key — but `DISPLAY` was
set with no usable TTY, so it tried a graphical prompter that isn't installed yet.
Fixes, in order of preference:

1. Load the key into an agent and run `ssh -T git@github.com` first, as above, so
   nothing needs prompting during init.
2. `export SSH_ASKPASS_REQUIRE=never` (or `unset DISPLAY`) to force the prompt onto
   the terminal.
3. `sudo pacman -S ksshaskpass` for a graphical prompt. This is installed
   automatically on desktop hosts, but that happens *after* the submodule clone, so
   it does not help the first run.

Over SSH into the VM, `ssh -A` forwards your existing agent and avoids putting a key
on a throwaway machine at all.

The bootstrap script does a full `pacman -Syu`, installs `paru` if missing, and sets
zsh as the login shell. `chezmoi apply` then installs everything listed in
`.chezmoidata/packages.yaml`, enables Docker, and wires up the user ssh-agent.

> **Upgrading an existing machine:** the machine facts below are generated into
> `~/.config/chezmoi/chezmoi.toml` at init time. A machine initialised before those
> facts existed must re-run `chezmoi init` once so the config picks them up —
> otherwise every OS branch silently evaluates to false.

> **Testing a branch:** `chezmoi init --branch <name>` is **silently ignored** when
> `~/.local/share/chezmoi` already exists — it keeps whatever branch is checked out
> and exits 0. To actually switch, either wipe and re-init:
>
> ```bash
> rm -rf ~/.local/share/chezmoi ~/.config/chezmoi
> chezmoi init msxdan/dotfiles --branch <name> --apply --recurse-submodules
> ```
>
> or switch the existing clone in place:
>
> ```bash
> chezmoi git -- fetch origin <name>
> chezmoi git -- checkout <name>
> chezmoi init && chezmoi apply
> ```

## Multi-host layout

Templates never branch on a raw hostname. `.chezmoi.toml.tmpl` resolves each machine
to a set of facts, and everything else reads those:

| Fact | Meaning |
| --- | --- |
| `role` | `workstation`, `wsl`, or `server` |
| `isArch` | Arch-family host (matches `ID`/`ID_LIKE` from os-release) |
| `isWSL` | legacy Debian-on-WSL host |
| `isDesktop` | has a graphical session, so GUI packages and configs apply |
| `isKDE` / `desktopEnv` | which desktop, for KWin/KRDP tweaks |
| `aurHelper` | AUR helper used by the install scripts |
| `kubeClusters` | which kubeconfigs to link (prompted at init) |

Adding a machine means adding one branch in `.chezmoi.toml.tmpl`; unknown hosts fall
back to prompts.

Supporting directories:

- `.chezmoidata/packages.yaml` — Arch package lists, split base/desktop and
  pacman/AUR/pipx/mise. macOS keeps using `~/.brewfile`.
- `.chezmoitemplates/{shared,macos,linux}/` — shell fragments. `dot_zshrc.tmpl` and
  friends are thin dispatchers that stitch `shared` + the OS fragment together.
- `.scripts/lib/arch-packages.sh` — install helpers for the Arch path. Failures are
  collected and reported rather than aborting the run.
- `.scripts/shared/functions.sh` — legacy apt/brew helpers, used only by the WSL path.

Note that chezmoi maps every top-level source directory into `$HOME`, so per-OS
top-level directories (`linux/`, `darwin/`) are not usable — `.chezmoiignore` plus
templates does that job instead.

## What's Included

**Terminal**

- Kitty with MSX theme
- Starship prompt
- Tmux configuration
- Modern CLI tools (lsd, bat, yazi, fzf)

**Development**

- Neovim with LSP and Catppuccin theme
- VS Code with extensions
- Language support (Go, Python, Node.js, C#)
- Git with GPG signing

**Cloud & Infrastructure**

- Azure, GCP, AWS CLIs
- Kubernetes tools (kubectl, k9s, helm)
- Terraform and IaC tools
- Docker configuration

**PostgreSQL**

- pgcli configuration
- DataGrip setup
- Encrypted .pgpass for connections

## Security

Everything sensitive is stored in private repo `dotfiles_private` and secrets are encrypted with [age](https://age-encryption.org/). SSH keys, AWS credentials, database passwords - all locked away but automatically available when needed.

Also SSH keys are password protected

## Postgres

### .pgpass and .pg_service.conf

Used to connect to PostgreSQL databases using `psql/pgcli` or `datagrip` using a single file for passwords

## Verifying changes before applying

```bash
chezmoi doctor
chezmoi execute-template < some-file.tmpl   # check a template in isolation
chezmoi data                                # inspect the resolved machine facts
chezmoi apply --dry-run --verbose           # full diff without touching anything
chezmoi diff
```

# TODO

Add instructions to rotate age key
