#!/bin/bash

# Install git on server

# Detect install software
if command -v yum &> /dev/null; then
    packagesystem="yum"
elif command -v apt-get &> /dev/null; then
    packagesystem="apt"
else
    echo "This script don't support your system."
    exit 1
fi

# Update status
read -p "Do you want run yum/apt update and install basic stuff before install git? (y/n): " update_status


# Install git on server
if [ "$packagesystem" == "yum" ]; then
    if [ "$update_status" == "y" ] || [ "$update_status" == "yes" ]; then
        yum update -y
        yum install tmux nano htop iotop -y
    fi
    yum install -y git
elif [ "$packagesystem" == "apt" ]; then
    if [ "$update_status" == "y" ] || [ "$update_status" == "yes" ]; then
        apt-get install tmux nano htop iotop -y
        apt-get update -y
    fi
    apt-get install -y git
fi

# Ask username from user
read -p "Enter the username: " SERVER_USER

# Define basic variables
GIT_REPO="https://github.com/HD-decor/Linux-login-setup"
TEMP_DIR=$(mktemp -d)

# Check if the user exists
if id "$SERVER_USER" &>/dev/null; then
    echo "User $SERVER_USER already exists."
else
    sudo useradd -m -s /bin/bash "$SERVER_USER"
    sudo mkdir -p /home/"$SERVER_USER"/.ssh
    sudo chown -R "$SERVER_USER":"$SERVER_USER" /home/"$SERVER_USER"/.ssh
    sudo chmod 700 /home/"$SERVER_USER"/.ssh
fi

# Clone the Git repository containing SSH keys
git clone "$GIT_REPO" "$TEMP_DIR"

# Check if the directory exists and contains files
if [ -d "$TEMP_DIR" ] && [ "$(ls -A "$TEMP_DIR")" ]; then
    # Copy keys to the user's authorized_keys file
    cat "$TEMP_DIR"/keys/*.pub | sudo tee -a /home/"$SERVER_USER"/.ssh/authorized_keys > /dev/null
    sudo chown "$SERVER_USER":"$SERVER_USER" /home/"$SERVER_USER"/.ssh/authorized_keys
    sudo chmod 600 /home/"$SERVER_USER"/.ssh/authorized_keys

    echo "SSH keys added to $SERVER_USER's authorized_keys file."
else
    echo "Failed to fetch SSH keys from the repository."
fi

# Configure SSH to only allow RSA keys and disable root login
sudo sed -i '/^PermitRootLogin/s/yes/no/' /etc/ssh/sshd_config
sudo sed -i '/^PasswordAuthentication/s/yes/no/' /etc/ssh/sshd_config
sudo sed -i '/^ChallengeResponseAuthentication/s/yes/no/' /etc/ssh/sshd_config
sudo systemctl restart sshd.service

echo "SSH configuration updated: Root login disabled, Password authentication disabled, RSA keys enforced."

# Clean up temporary directory
rm -rf "$TEMP_DIR"