# Dotfiles

Personal dotfiles managed with [chezmoi](https://chezmoi.io). Supports macOS and
Arch-family Linux (CachyOS), with a legacy WSL/Debian path.

## Setup

### macOS

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init msxdan/dotfiles --apply --recurse-submodules
```

### CachyOS / Arch

```bash
sudo pacman -S --needed chezmoi git age
chezmoi init msxdan/dotfiles --apply --recurse-submodules
```

The bootstrap script does a full `pacman -Syu`, installs `paru` if missing, and sets
zsh as the login shell. `chezmoi apply` then installs everything listed in
`.chezmoidata/packages.yaml`, enables Docker, and wires up the user ssh-agent.

> **Upgrading an existing machine:** the machine facts below are generated into
> `~/.config/chezmoi/chezmoi.toml` at init time. A machine initialised before those
> facts existed must re-run `chezmoi init` once so the config picks them up —
> otherwise every OS branch silently evaluates to false.

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
