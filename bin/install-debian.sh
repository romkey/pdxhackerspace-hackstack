#!/bin/sh

echo "This script will install and start Docker. After running it you should install"
echo "individual applications by running 'docker compose up -d' in each application's"
echo "directory, or run an install script for a stack of applications."
echo
echo "This script uses `sudo` to run items as root; you'll be prompted at least once at"
echo "the start to enter your password in order to allow this"

sudo apt update && apt upgrade -y
sudo apt install pwgen curl software-properties-common -y

if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."

#    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
    sudo apt install -y apt-transport-https ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

#    sudo add-apt-repository "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
    sudo echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt update
#    sudo apt install -y docker-ce docker-ce-cli containerd.io
    sudo apt install -y docker-ce docker-ce-cli 

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
