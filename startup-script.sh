#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

retry() {
  for i in 1 2 3 4 5; do
    "$@" && return 0
    echo "Retry $i failed... retrying in 5s"
    sleep 5
  done
  return 1
}

# Wait for network to stabilize
sleep 10

# Clean any partial apt state
apt-get clean
rm -rf /var/lib/apt/lists/*

# First update (with retry)
retry apt-get update -o Acquire::Retries=3

retry apt-get install -y ca-certificates curl gnupg lsb-release

install -m 0755 -d /etc/apt/keyrings

# Retry curl too (network can fail here as well)
retry curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Second update (this is where your failure happened)
retry apt-get update -o Acquire::Retries=3

retry apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker

docker run -d -p 3000:3000 -p 3001:3001 \
  -e SECURE_CONNECTION=0 \
  -e WEBUI_PORT=3000 \
  --name antigravity \
  --restart unless-stopped \
  --shm-size=10g \
  -v $(pwd)/webtop-config:/config \
  us-docker.pkg.dev/qwiklabs-resources/lfs-images/vm-antigravity/build-with-google:07222026-all

# Wait a moment for the container to initialize
sleep 15
