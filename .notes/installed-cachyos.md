wine-mono

# Install bottles and install Fork

# Set Windows 7 version
WINEPREFIX=~/.local/share/bottles/bottles/Fork winecfg
# Set DPI to 104

WINEPREFIX=~/.local/share/bottles/bottles/Fork winetricks allfonts



# Install Docker on arch/cachyos

sudo pacman -Syu docker docker-compose containerd
sudo systemctl enable --now docker  #incase the services is not enabled and not running after you install
sudo usermod -aG docker $USER


sudo pacman -S mise
curl -fsSL https://gh.io/copilot-install | bash

pacman -S flameshot mise github-cli starship zoxide lsd



# Fix KRDP 3389
# /home/nyx/.config/systemd/user/app-org.kde.krdpserver.service.d/override.conf
[Service]
NoNewPrivileges=no