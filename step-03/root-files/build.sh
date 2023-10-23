#!/bin/bash
# shellcheck disable=SC1090
# shellcheck disable=SC2086
# shellcheck disable=SC2046

# Load helper libraries

. "${FLOWNATIVE_LIB_PATH}/banner.sh"
. "${FLOWNATIVE_LIB_PATH}/log.sh"
. "${FLOWNATIVE_LIB_PATH}/packages.sh"

set -o errexit
set -o nounset
set -o pipefail

# ---------------------------------------------------------------------------------------
# build_create_directories() - Create directories and set access rights accordingly
#
# @global PHP_BASE_PATH
# @global BEACH_APPLICATION_PATH
# @return void
#
build_create_directories() {
    mkdir -p \
        "${PHP_BASE_PATH}/bin" \
        "${PHP_BASE_PATH}/etc/conf.d" \
        "${PHP_BASE_PATH}/ext" \
        "${PHP_BASE_PATH}/tmp" \
        "${PHP_BASE_PATH}/log"

    # Activate freetype-config-workaround (see freetype-config.sh):
    ln -s ${PHP_BASE_PATH}/bin/freetype-config.sh /usr/local/bin/freetype-config
}

# ---------------------------------------------------------------------------------------
# build_adjust_permissions() - Adjust permissions for a few paths and files
#
# @global PHP_BASE_PATH
# @return void
#
build_adjust_permissions() {
    chown -R root:root "${PHP_BASE_PATH}"
    chmod -R g+rwX "${PHP_BASE_PATH}"

    chown -R 1000 \
        "${PHP_BASE_PATH}/etc" \
        "${PHP_BASE_PATH}/tmp"
}

# ---------------------------------------------------------------------------------------
# Main routine

case $1 in
init)
    banner_flownative 'PHP'

    build_create_directories
    ;;
clean)
    build_adjust_permissions
    ;;
esac
