#!/usr/bin/env bash

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

# Compose does not allow yet BuildKit secrets
export DOCKER_BUILDKIT=1
docker build --secret id=db_password,src=secrets/db_password.txt --secret id=api_key,src=secrets/api_key.txt -t powerhole:authoritative authoritative

docker-compose build powerhole_pdns_recursor powerhole_pdns_forwarder powerhole_nginx

cd /tmp || exit 1
git clone --depth 1 https://github.com/ngoduykhanh/PowerDNS-Admin.git && cd PowerDNS-Admin || exit 1
docker build --no-cache -t powerhole:admin -f docker/Dockerfile .
cd "$this_script_path" || exit 1
rm -r /tmp/PowerDNS-Admin
