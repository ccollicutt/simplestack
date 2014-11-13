#!/bin/bash

source adminrc > /dev/null

if [ -z "${OS_PASSWORD}" ]; then
    echo "ERROR: OpenStack environment variables not set, exiting..."
    exit 1
fi

if [ "$1" != "-y" ]; then
    echo "USAGE: $0 -y"
    exit 0
fi

instances=`nova --insecure list | grep "ACTIVE\|ERROR" | cut -f 2 -d "|" | tr -d " "`

for i in ${instances}; do
    nova --insecure delete ${i}
done
