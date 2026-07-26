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
sudo pacman -S --needed chezmoi
ssh-add ~/.ssh/id_ed25519      # a key with access to the private repo
chezmoi init msxdan/dotfiles --apply --recurse-submodules
```

Init handles everything from there: full `pacman -Syu`, `paru`, zsh as the login
shell, the per-host package list, Docker, the user ssh-agent, and the KDE tweaks.

Only the two lines above are manual, and both are irreducible — you need chezmoi
installed to run chezmoi, and the `dot_private` submodule is cloned over SSH while
the keys it would give you live *inside* it, so a key has to be in the agent first.
With one loaded, ssh never has to prompt and nothing else is needed. Over SSH into
the machine, `ssh -A` forwards your existing agent instead.

`--recurse-submodules` is not optional: several templates `include` files from
`dot_private`, so without it `chezmoi apply` fails to render.

**If you see `exec(/usr/lib/ssh/ssh-askpass): No such file or directory`**, the key
isn't in the agent, so ssh tried to ask for its passphrase — and with `DISPLAY` set
but no usable TTY it reached for a graphical prompter. `ssh-add` first, as above.
Failing that, `export SSH_ASKPASS_REQUIRE=never` forces the prompt onto the
terminal. `ksshaskpass` is installed by the bootstrap and remembers passphrases in
KWallet, but that happens after the submodule clone, so it can't rescue the first
run.

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
| `profiles` | which identities this machine serves: `personal`, `work` |
| `isWork` / `isPersonal` | derived from `profiles`, used to gate files |
| `kubeClusters` | which kubeconfigs to link (`homelab`, `ec`, `mm`) |

### Profiles

A machine declares which identities it serves, and `.chezmoiignore` skips whatever
belongs to the others. `work` covers both work clusters (`ec` and `mm`) — they are
not split, since they are the same job.

| Profile | Gets |
| --- | --- |
| `personal` | `homelab` kubeconfig, DataGrip `marvin-cloud` |
| `work` | `ec` + `mm` kubeconfigs, `~/.pgpass`, `~/.pg_service.conf`, `~/.databrickscfg`, DataGrip `ec`, infracost credentials, `~/.ssh/config.d/mm`, and the `sc mm` context switch in `.zshrc` |

Both prompts run at init. `kubeClusters` is pre-selected from the chosen profiles but
stays overridable, so a personal machine can still pull in a work cluster ad hoc
without taking the work credentials with it. `chezmoi init --promptDefaults` accepts
every default, so unattended runs don't hang.

The default is whatever preserves the machine's existing behaviour: macOS defaults to
`personal` + `work`, everything else to `personal` alone. Changing profiles later
means editing `profiles` in `~/.config/chezmoi/chezmoi.toml`, or re-running
`chezmoi init`.

Adding a machine means adding one branch in `.chezmoi.toml.tmpl`; unknown hosts fall
back to prompts.

Supporting directories:

- `.chezmoidata/hosts.yaml` — per-host package lists, keyed by lowercased hostname.
  **Machines do not share packages**: each host names exactly what it wants and
  inherits nothing from another host. An unlisted host falls back to `default`, and
  the install script prints which key it matched so a hostname typo is visible.
  Packages ported from the Brewfile but not yet wanted by any host sit in a
  commented catalogue at the bottom of that file — move a line into a host to enable
  it. macOS is deliberately absent and keeps using `~/.brewfile`.
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
