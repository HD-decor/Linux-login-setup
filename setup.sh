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
    case "$ID" in
    ubuntu)
        echo "[INFO] Ubuntu detected, restarting ssh service..."
        systemctl restart ssh 
        ;;
    debian)
        echo "[INFO] Debian detected, restarting sshd service..."
        systemctl restart sshd.service
        ;;
    *)

        echo "[ERROR] Unsupported OS, cannot restart SSH or SSHD service."
        exit 1
        ;;

    esac
fi

echo "SSH configuration updated: Root login disabled, Password authentication disabled, RSA keys enforced."

# Clean up temp directory
rm -rf "$TEMP_DIR"




















#
# ZABBIX START
#

# Update and install basic tools
read -p "Do you want to install and setup Zabbix? (y/n): " zabbix_status

if [[ "$zabbix_status" == "y" || "$zabbix_status" == "Y" || "$zabbix_status" == "yes" || "$zabbix_status" == "Yes" ]]; then
    . /etc/os-release

    echo "DEBUG: ID=$ID"
    echo "DEBUG: VERSION_ID=$VERSION_ID"

    case "${ID}:${VERSION_ID}" in


        almalinux:8*)
            echo "AlmaLinux 8"

            # Get system hostname
            HOSTNAME=$(hostname)

            echo "[INFO] Installing Zabbix repository..."
            rpm -Uvh https://repo.zabbix.com/zabbix/7.2/release/alma/8/noarch/zabbix-release-latest-7.2.el8.noarch.rpm

            echo "[INFO] Cleaning dnf cache..."
            dnf clean all

            echo "[INFO] Installing Zabbix agent2 and plugins..."
            dnf install -y zabbix-agent2 \
                        zabbix-agent2-plugin-mongodb \
                        zabbix-agent2-plugin-mssql \
                        zabbix-agent2-plugin-postgresql

            echo "[INFO] Configuring Zabbix agent..."
            ZABBIX_CONFIG="/etc/zabbix/zabbix_agent2.conf"

            # Backup original config
            cp $ZABBIX_CONFIG ${ZABBIX_CONFIG}.bak

            # Replace Server and Hostname entries
            sed -i "s|^Server=.*|Server=zabbix.tietokettu.net|" $ZABBIX_CONFIG
            sed -i "s|^ServerActive=.*|ServerActive=zabbix.tietokettu.net|" $ZABBIX_CONFIG
            sed -i "s|^Hostname=.*|Hostname=${HOSTNAME}|" $ZABBIX_CONFIG

            echo "[INFO] Enabling and starting Zabbix agent2..."
            systemctl enable --now zabbix-agent2

            echo "[SUCCESS] Zabbix Agent 2 installed and configured for $HOSTNAME."
            exit 0
            ;;




        almalinux:9*)
            echo "AlmaLinux 9"

            echo "[INFO] Disabling Zabbix packages from EPEL if present..."
            EPEL_REPO="/etc/yum.repos.d/epel.repo"
            if [ -f "$EPEL_REPO" ]; then
                if ! grep -q "excludepkgs=zabbix*" "$EPEL_REPO"; then
                    echo "excludepkgs=zabbix*" >> "$EPEL_REPO"
                    echo "[INFO] Added 'excludepkgs=zabbix*' to $EPEL_REPO"
                else
                    echo "[INFO] EPEL already excludes Zabbix packages"
                fi
            else
                echo "[WARN] EPEL repo not found, skipping exclusion."
            fi

            echo "[INFO] Installing Zabbix repo for AlmaLinux 9..."
            rpm -Uvh https://repo.zabbix.com/zabbix/7.2/release/alma/9/noarch/zabbix-release-latest-7.2.el9.noarch.rpm

            echo "[INFO] Cleaning DNF cache..."
            dnf clean all

            echo "[INFO] Installing Zabbix agent2 and plugins..."
            dnf install -y zabbix-agent2 \
                        zabbix-agent2-plugin-mongodb \
                        zabbix-agent2-plugin-mssql \
                        zabbix-agent2-plugin-postgresql

            echo "[INFO] Configuring Zabbix agent2..."
            ZABBIX_CONFIG="/etc/zabbix/zabbix_agent2.conf"
            cp "$ZABBIX_CONFIG" "$ZABBIX_CONFIG.bak"

            HOSTNAME=$(hostname)

            sed -i "s|^Server=.*|Server=zabbix.tietokettu.net|" "$ZABBIX_CONFIG"
            sed -i "s|^ServerActive=.*|ServerActive=zabbix.tietokettu.net|" "$ZABBIX_CONFIG"
            sed -i "s|^Hostname=.*|Hostname=${HOSTNAME}|" "$ZABBIX_CONFIG"

            echo "[INFO] Enabling and starting Zabbix agent2..."
            systemctl enable --now zabbix-agent2

            echo "[SUCCESS] Zabbix Agent 2 installed and configured for host: $HOSTNAME"
            exit 0
            ;;





        debian:9*)
            echo "Debian 9"
            ZBX_VER=6.0
            wget -q https://repo.zabbix.com/zabbix/${ZBX_VER}/debian/pool/main/z/zabbix-release/zabbix-release_${ZBX_VER}-1+debian9_all.deb
            dpkg -i zabbix-release_${ZBX_VER}-1+debian9_all.deb
            apt update
            apt install -y zabbix-agent2

            HOSTNAME=$(hostname)
            echo "[INFO] Configuring Zabbix agent..."
            ZABBIX_CONFIG="/etc/zabbix/zabbix_agent2.conf"
            cp $ZABBIX_CONFIG ${ZABBIX_CONFIG}.bak
            sed -i "s|^Server=.*|Server=zabbix.tietokettu.net|" $ZABBIX_CONFIG
            sed -i "s|^ServerActive=.*|ServerActive=zabbix.tietokettu.net|" $ZABBIX_CONFIG
            sed -i "s|^Hostname=.*|Hostname=${HOSTNAME}|" $ZABBIX_CONFIG

            systemctl enable zabbix-agent2
            systemctl restart zabbix-agent2

            echo "[SUCCESS] Zabbix Agent 2 installed and configured for $HOSTNAME."
            exit 0
            ;;
        debian:10*)
            echo "Debian 10"
            ZBX_VER=6.0
            wget -q https://repo.zabbix.com/zabbix/${ZBX_VER}/debian/pool/main/z/zabbix-release/zabbix-release_${ZBX_VER}-1+debian10_all.deb
            dpkg -i zabbix-release_${ZBX_VER}-1+debian10_all.deb
            apt update
            apt install -y zabbix-agent2

            echo "[INFO] Configuring Zabbix agent..."
            ZABBIX_CONFIG="/etc/zabbix/zabbix_agent2.conf"
            cp $ZABBIX_CONFIG ${ZABBIX_CONFIG}.bak
            sed -i "s|^Server=.*|Server=zabbix.tietokettu.net|" $ZABBIX_CONFIG
            sed -i "s|^ServerActive=.*|ServerActive=zabbix.tietokettu.net|" $ZABBIX_CONFIG
            sed -i "s|^Hostname=.*|Hostname=${HOSTNAME}|" $ZABBIX_CONFIG

            systemctl enable zabbix-agent2
            systemctl restart zabbix-agent2

            echo "[SUCCESS] Zabbix Agent 2 installed and configured for $HOSTNAME."
            exit 0
            ;;
        debian:11*)
            echo "Debian 11"
            ZBX_VER=6.0
            wget -q https://repo.zabbix.com/zabbix/${ZBX_VER}/debian/pool/main/z/zabbix-release/zabbix-release_${ZBX_VER}-1+debian11_all.deb
            dpkg -i zabbix-release_${ZBX_VER}-1+debian11_all.deb
            apt update
            apt install -y zabbix-agent2

            HOSTNAME=$(hostname)
            echo "[INFO] Configuring Zabbix agent..."
            ZABBIX_CONFIG="/etc/zabbix/zabbix_agent2.conf"
            cp $ZABBIX_CONFIG ${ZABBIX_CONFIG}.bak
            sed -i "s|^Server=.*|Server=zabbix.tietokettu.net|" $ZABBIX_CONFIG
            sed -i "s|^ServerActive=.*|ServerActive=zabbix.tietokettu.net|" $ZABBIX_CONFIG
            sed -i "s|^Hostname=.*|Hostname=${HOSTNAME}|" $ZABBIX_CONFIG

            systemctl enable zabbix-agent2
            systemctl restart zabbix-agent2

            echo "[SUCCESS] Zabbix Agent 2 installed and configured for $HOSTNAME."
            exit 0
            ;;
        debian:12*)
            echo "Debian 12"
            ZBX_VER=6.0
            wget -q https://repo.zabbix.com/zabbix/${ZBX_VER}/debian/pool/main/z/zabbix-release/zabbix-release_${ZBX_VER}-1+debian12_all.deb
            dpkg -i zabbix-release_${ZBX_VER}-1+debian12_all.deb
            apt update
            apt install -y zabbix-agent2

            HOSTNAME=$(hostname)
            echo "[INFO] Configuring Zabbix agent..."
            ZABBIX_CONFIG="/etc/zabbix/zabbix_agent2.conf"
            cp $ZABBIX_CONFIG ${ZABBIX_CONFIG}.bak
            sed -i "s|^Server=.*|Server=zabbix.tietokettu.net|" $ZABBIX_CONFIG
            sed -i "s|^ServerActive=.*|ServerActive=zabbix.tietokettu.net|" $ZABBIX_CONFIG
            sed -i "s|^Hostname=.*|Hostname=${HOSTNAME}|" $ZABBIX_CONFIG

            systemctl enable zabbix-agent2
            systemctl restart zabbix-agent2

            echo "[SUCCESS] Zabbix Agent 2 installed and configured for $HOSTNAME."
            exit 0
            ;;
        ubuntu:20.04)
            echo "Ubuntu 20.04"
            ZBX_VER=6.0
            wget -q https://repo.zabbix.com/zabbix/${ZBX_VER}/ubuntu/pool/main/z/zabbix-release/zabbix-release_${ZBX_VER}-1+ubuntu20.04_all.deb
            dpkg -i zabbix-release_${ZBX_VER}-1+ubuntu20.04_all.deb
            apt update
            apt install -y zabbix-agent2

            HOSTNAME=$(hostname)
            echo "[INFO] Configuring Zabbix agent..."
            ZABBIX_CONFIG="/etc/zabbix/zabbix_agent2.conf"
            cp $ZABBIX_CONFIG ${ZABBIX_CONFIG}.bak
            sed -i "s|^Server=.*|Server=zabbix.tietokettu.net|" $ZABBIX_CONFIG
            sed -i "s|^ServerActive=.*|ServerActive=zabbix.tietokettu.net|" $ZABBIX_CONFIG
            sed -i "s|^Hostname=.*|Hostname=${HOSTNAME}|" $ZABBIX_CONFIG

            systemctl enable zabbix-agent2
            systemctl restart zabbix-agent2

            echo "[SUCCESS] Zabbix Agent 2 installed and configured for $HOSTNAME."
            exit 0
            ;;
        ubuntu:22.04)
            echo "Ubuntu 22.04"
            ZBX_VER=6.0
            wget -q https://repo.zabbix.com/zabbix/${ZBX_VER}/ubuntu/pool/main/z/zabbix-release/zabbix-release_${ZBX_VER}-1+ubuntu22.04_all.deb
            dpkg -i zabbix-release_${ZBX_VER}-1+ubuntu22.04_all.deb
            apt update
            apt install -y zabbix-agent2

            HOSTNAME=$(hostname)
            echo "[INFO] Configuring Zabbix agent..."
            ZABBIX_CONFIG="/etc/zabbix/zabbix_agent2.conf"
            cp $ZABBIX_CONFIG ${ZABBIX_CONFIG}.bak
            sed -i "s|^Server=.*|Server=zabbix.tietokettu.net|" $ZABBIX_CONFIG
            sed -i "s|^ServerActive=.*|ServerActive=zabbix.tietokettu.net|" $ZABBIX_CONFIG
            sed -i "s|^Hostname=.*|Hostname=${HOSTNAME}|" $ZABBIX_CONFIG

            systemctl enable zabbix-agent2
            systemctl restart zabbix-agent2

            echo "[SUCCESS] Zabbix Agent 2 installed and configured for $HOSTNAME."
            exit 0
            ;;
        ubuntu:24.04)
            echo "[INFO] Ubuntu 24.04 detected"
            ZBX_VER=6.0
            wget -q https://repo.zabbix.com/zabbix/${ZBX_VER}/ubuntu/pool/main/z/zabbix-release/zabbix-release_${ZBX_VER}-6+ubuntu24.04_all.deb
            dpkg -i zabbix-release_${ZBX_VER}-6+ubuntu24.04_all.deb
            apt update
            apt install -y zabbix-agent2

            echo "[INFO] Configuring Zabbix agent..."
            ZABBIX_CONFIG="/etc/zabbix/zabbix_agent2.conf"
            cp $ZABBIX_CONFIG ${ZABBIX_CONFIG}.bak

            sed -i "s|^Server=.*|Server=zabbix.tietokettu.net|" $ZABBIX_CONFIG
            sed -i "s|^ServerActive=.*|ServerActive=zabbix.tietokettu.net|" $ZABBIX_CONFIG
            sed -i "s|^Hostname=.*|Hostname=${HOSTNAME}|" $ZABBIX_CONFIG

            systemctl enable zabbix-agent2
            systemctl restart zabbix-agent2

            echo "[SUCCESS] Zabbix Agent 2 installed and configured for ${HOSTNAME}"
            exit 0
            ;;
        *)
            echo "Unsupported OS or version | Zabbix"
            exit 1
            ;;
    esac
fi

#
# ZABBIX END
#