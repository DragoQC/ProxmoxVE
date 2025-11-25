#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: DragoQC
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/DragoQC/DiscoPanel-PVEHS/blob/main/discopanel-install.sh

# Import Functions und Setup
source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# Installing Dependencies
msg_info "Installing Dependencies"
$STD apt-get install -y \
  ca-certificates \
  git \
  curl \
  npm \
  golang
msg_ok "Installed Dependencies"

# Install Docker Engine
msg_info "Installing Docker Engine"

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

$STD apt-get update
$STD apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

msg_ok "Installed Docker Engine"

# Setup App
msg_info "Setup ${APPLICATION}"

# Clone repository
git clone https://github.com/nickheyer/discopanel /opt/${APPLICATION}

# Build frontend
cd /opt/${APPLICATION}/web/discopanel
npm install
npm run build

# Build backend
cd /opt/${APPLICATION}
go build -o discopanel cmd/discopanel/main.go

# Version tracking (optional)
git -C /opt/${APPLICATION} describe --tags --always >/opt/"${APPLICATION}"_version.txt

msg_ok "Setup ${APPLICATION}"



# Creating Service
msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/${APPLICATION}.service
[Unit]
Description=${APPLICATION} Service
After=network.target

[Service]
WorkingDirectory=/opt/${APPLICATION}
ExecStart=/opt/${APPLICATION}/discopanel
Restart=always
User=root
Environment=PORT=8080

[Install]
WantedBy=multi-user.target
EOF

systemctl enable -q --now ${APPLICATION}
msg_ok "Created Service"

motd_ssh
customize

# Cleanup
msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
