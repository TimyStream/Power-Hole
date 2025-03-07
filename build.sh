#!/usr/bin/env bash

set -e # Stop the script on errors
set -u # Unset variables are an error
set -o pipefail # Piping a failed process into a successful one is an error

# Check the script is run as by a user with docker's rights
if [ "$EUID" -ne 0 ]; then
  if ! id -nGz "$USER" | grep -qzxF docker; then
    echo "Please run with docker's rights (either run as root or add yourself to the docker group)"
    exit 1
  fi
fi

this_script_path=$(dirname "$0")                  # Relative
this_script_path=$(cd "$this_script_path" && pwd) # Absolutized and normalized
if [ -z "$this_script_path" ]; then
  # Error, for some reason, the path is not accessible to the script (e.g. permissions re-evalued after suid)
  exit 1 # Fail
fi

cd "$this_script_path" || exit 1

# Authoritative server's populating script
wget -qO authoritative/init.sql https://raw.githubusercontent.com/PowerDNS/pdns/refs/heads/rel/auth-4.4.x/modules/gmysqlbackend/schema.mysql.sql

# Compose does not allow yet BuildKit secrets
docker build --secret id=db_password,src=secrets/db_password.txt --secret id=api_key,src=secrets/api_key.txt -t powerhole:authoritative authoritative

# Build the recursor, forwarder and nginx
docker compose build powerhole-pdns-recursor powerhole-pdns-forwarder

# Locally build the PowerDNS-Admin image because the Docker Hub does not provide an image for ARM devices
cd /tmp || exit 1
git clone https://github.com/noxPHX/PowerDNS-Admin.git && cd PowerDNS-Admin || exit 1
docker build --no-cache -t powerhole:admin -f docker/Dockerfile .
cd "$this_script_path" || exit 1
rm -r /tmp/PowerDNS-Admin
