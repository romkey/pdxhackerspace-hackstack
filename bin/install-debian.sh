#!/bin/sh

echo "This script will install and start Docker. After running it you should install"
echo "individual applications by running 'docker compose up -d' in each application's"
echo "directory, or run an install script for a stack of applications."
echo
echo "This script uses `sudo` to run items as root; you'll be prompted at least once at"
echo "the start to enter your password in order to allow this"

sudo apt update && apt upgrade -y
sudo apt install pwgen -y

if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."

    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo tee /etc/apt/trusted.gpg.d/docker.asc
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io

    sudo systemctl start docker
    sudo systemctl enable docker

    if command -v docker &> /dev/null; then
        echo "Docker installed successfully!"
    else
        echo "Docker installation failed."
        exit 1
    fi
else
    echo "Docker is already installed."
fi
