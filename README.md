# Dotfiles

Personal dotfiles managed with [chezmoi](https://chezmoi.io).

## Setup

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init msxdan/dotfiles --apply --recurse-submodules
```

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

## Postgres

### .pgpass and .pg_service.conf

Used to connect to PostgreSQL databases using `psql/pgcli` or `datagrip` using a single file for passwords

# TODO

Add instructions to rotate age key
