#!/bin/bash

if [ "${1}" != "-y" ]; then
  echo "USAGE: $0 -y"
  exit 1
fi

echo "INFO: Destroying all virtual machines..."
if ! vagrant destroy -f; then
  echo "ERROR: Could not destroy vms"
  exit 1
fi

sleep 2

echo "INFO: Bulding all virtual machines..."
if ! vagrant up; then
  echo "ERROR: Could not build vms"
  exit 1
fi

sleep 20

echo "INFO: Trying to ansible -m ping all..."
if ! ansible -m ping all; then
  # Seems like pinging them sometimes helps to
  # bring them up networking-wise...
  ping -c 5 -w 1 10.1.10.11
  ping -c 5 -w 1 10.1.10.12
  ping -c 5 -w 1 10.1.10.21
  sleep 5
  if ! ansible -m ping all; then
    echo "ERROR: Could not ping hosts"
    exit 1
  fi
fi

echo "INFO: Trying to run site.yml..."
if ! ansible-playbook site.yml; then
  echo "ERROR: Could not run site.yml"
  exit 1
fi

echo "Done!"
