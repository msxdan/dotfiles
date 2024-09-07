#!/bin/bash
function install_package
{
    if ! command -v $2 &> /dev/null; then
        case $1 in
            "pipx")
                echo "Installing $2..."
                pipx install "$3" --quiet
                ;;
            "brew")
                echo "Installing $2..."
                brew install "$2" --quiet
                ;;
            "apt")
                echo "Installing $2..."
                sudo apt-get install "$3" -y > /dev/null
                ;;
            "dnf")
                echo "Installing $2..."
                sudo dnf install "$3" -y > /dev/null
                ;;
            *)
                echo "Not valid option"
                exit 1
                ;;
        esac
    else
        echo "$2 already installed"
    fi
}

function install_pipx_package 
{
    install_package pipx $1 $2
}

function install_brew_package 
{
    install_package brew $1 $2
}

function install_apt_package 
{
    install_package apt $1 $2
}

function install_dotnet_version() 
{
    wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh --quiet
    chmod +x ./dotnet-install.sh
    versions=("$@")
    for i in "${versions[@]}";
        do
            ./dotnet-install.sh --version "$i"
        done
    rm ./dotnet-install.sh
}

function install_docker()
{
    # Add Docker's official GPG key:
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}
function install_nvm() {
    wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
}

function update_packages
{
    echo "Updating packages..."
    sudo apt-get update > /dev/null
}