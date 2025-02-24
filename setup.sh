#!/bin/bash

# Detect package manager
if command -v yum &> /dev/null; then
    packagesystem="yum"
elif command -v apt-get &> /dev/null; then
    packagesystem="apt"
else
    echo "This script doesn't support your system."
    exit 1
fi

# Update and install basic tools
read -p "Do you want to update and install basic tools before installing Git? (y/n): " update_status

if [[ "$update_status" =~ ^[Yy](es)?$ ]]; then
    if [ "$packagesystem" == "yum" ]; then
        sudo yum update -y
        sudo yum install -y tmux nano htop iotop
    elif [ "$packagesystem" == "apt" ]; then
        apt-get update -y
        apt-get install -y tmux nano htop iotop
    fi
fi

# Install Git
if [ "$packagesystem" == "yum" ]; then
    sudo yum install -y git
elif [ "$packagesystem" == "apt" ]; then
    apt-get install -y git
fi

# Check if Git is installed
if ! command -v git &> /dev/null; then
    echo "Git is not installed. Please install Git manually."
    exit 1
fi

# Ask for username
read -p "Enter the username: " SERVER_USER

# Validate username
if [ -z "$SERVER_USER" ]; then
    echo "Username cannot be empty. Exiting...."
    exit 1
fi

# Clear old authorized_keys file if it exists
if [ -e "/home/$SERVER_USER/.ssh/authorized_keys" ]; then
    if [ "$packagesystem" == "yum" ]; then
        sudo truncate -s 0 "/home/$SERVER_USER/.ssh/authorized_keys"
    elif [ "$packagesystem" == "apt" ]; then
        truncate -s 0 "/home/$SERVER_USER/.ssh/authorized_keys"
    fi
fi

# Define basic variables
GIT_REPO="https://github.com/HD-decor/Linux-login-setup"
TEMP_DIR=$(mktemp -d)

# Check if the user exists and create if not
if id "$SERVER_USER" &>/dev/null; then
    echo "User $SERVER_USER already exists."
    if [ -d "/home/$SERVER_USER/.ssh" ]; then
        echo "Path /home/$SERVER_USER/.ssh already exists."
    else
        echo "Path /home/$SERVER_USER/.ssh is missing."
        sudo mkdir -p "/home/$SERVER_USER/.ssh"
        echo "Path /home/$SERVER_USER/.ssh is now created!"
    fi

else
    if [ "$packagesystem" == "yum" ]; then
        sudo useradd -m -s /bin/bash "$SERVER_USER"
        sudo mkdir -p "/home/$SERVER_USER/.ssh"
        sudo chown -R "$SERVER_USER:$SERVER_USER" "/home/$SERVER_USER/.ssh"
        sudo chmod 700 "/home/$SERVER_USER/.ssh"
    elif [ "$packagesystem" == "apt" ]; then
        useradd -m -s /bin/bash "$SERVER_USER"
        mkdir -p "/home/$SERVER_USER/.ssh"
        chown -R "$SERVER_USER:$SERVER_USER" "/home/$SERVER_USER/.ssh"
        chmod 700 "/home/$SERVER_USER/.ssh"
    fi
fi


# Clone the Git repository containing SSH keys
if git clone "$GIT_REPO" "$TEMP_DIR"; then
    # Append keys to the authorized_keys file
    for keyfile in "$TEMP_DIR"/keys/*.pub; do
        if [[ -f "$keyfile" ]]; then
            if [ "$packagesystem" == "yum" ]; then
                sudo cat "$keyfile" | sudo tee -a "/home/$SERVER_USER/.ssh/authorized_keys" >/dev/null
                sudo echo "" | sudo tee -a "/home/$SERVER_USER/.ssh/authorized_keys" >/dev/null
            elif [ "$packagesystem" == "apt" ]; then
                cat "$keyfile" | tee -a "/home/$SERVER_USER/.ssh/authorized_keys" >/dev/null
                echo "" | tee -a "/home/$SERVER_USER/.ssh/authorized_keys" >/dev/null
            fi
        fi
    done

    if [ "$packagesystem" == "yum" ]; then
        sudo chown "$SERVER_USER:$SERVER_USER" "/home/$SERVER_USER/.ssh/authorized_keys"
        sudo chmod 600 "/home/$SERVER_USER/.ssh/authorized_keys"
    elif [ "$packagesystem" == "apt" ]; then
        chown "$SERVER_USER:$SERVER_USER" "/home/$SERVER_USER/.ssh/authorized_keys"
        chmod 600 "/home/$SERVER_USER/.ssh/authorized_keys"
    fi

    echo "SSH keys added to $SERVER_USER's authorized_keys file."
else
    echo "Failed to fetch SSH keys from the repository."
fi

# Configure SSH
if [ "$packagesystem" == "yum" ]; then
    sudo sed -i '/^PermitRootLogin/s/yes/no/' /etc/ssh/sshd_config
    sudo sed -i '/^PasswordAuthentication/s/yes/no/' /etc/ssh/sshd_config
    sudo sed -i '/^ChallengeResponseAuthentication/s/yes/no/' /etc/ssh/sshd_config
    sudo systemctl restart sshd.service
elif [ "$packagesystem" == "apt" ]; then
    sed -i '/^PermitRootLogin/s/yes/no/' /etc/ssh/sshd_config
    sed -i '/^PasswordAuthentication/s/yes/no/' /etc/ssh/sshd_config
    sed -i '/^ChallengeResponseAuthentication/s/yes/no/' /etc/ssh/sshd_config
    systemctl restart sshd.service
fi

echo "SSH configuration updated: Root login disabled, Password authentication disabled, RSA keys enforced."

# Clean up temp directory
rm -rf "$TEMP_DIR"
