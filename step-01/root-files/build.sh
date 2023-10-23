#!/bin/bash
# Load helper libraries

. "${FLOWNATIVE_LIB_PATH}/log.sh"
. "${FLOWNATIVE_LIB_PATH}/banner.sh"
. "${FLOWNATIVE_LIB_PATH}/packages.sh"

set -o errexit
set -o nounset
set -o pipefail

# ---------------------------------------------------------------------------------------
# Main routine

export FLOWNATIVE_LOG_PATH_AND_FILENAME=/dev/stdout

banner_flownative 'Demo Base Image'

packages_install dpkg apt-utils ca-certificates syslog-ng logrotate

# Clean up
rm -rf \
    /var/cache/* \
    /var/log/*
