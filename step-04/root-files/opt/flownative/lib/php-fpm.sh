#!/bin/bash
# shellcheck disable=SC1090

# =======================================================================================
# LIBRARY: PHP
# =======================================================================================

# Load helper lib

. "${FLOWNATIVE_LIB_PATH}/log.sh"
. "${FLOWNATIVE_LIB_PATH}/files.sh"
. "${FLOWNATIVE_LIB_PATH}/validation.sh"
. "${FLOWNATIVE_LIB_PATH}/os.sh"
. "${FLOWNATIVE_LIB_PATH}/process.sh"

# ---------------------------------------------------------------------------------------
# php_fpm_env() - Load global environment variables for configuring PHP
#
# @global PHP_* The PHP_ environment variables
# @return "export" statements which can be passed to eval()
#
php_fpm_env() {
    cat <<"EOF"
export PHP_BASE_PATH="${PHP_BASE_PATH}"
export PHP_CONF_PATH="${PHP_CONF_PATH:-${PHP_BASE_PATH}/etc}"
export PHP_TMP_PATH="${PHP_TMP_PATH:-${PHP_BASE_PATH}/tmp}"
export PHP_LOG_PATH="${PHP_LOG_PATH:-${PHP_BASE_PATH}/log}"

export PHP_MEMORY_LIMIT="${PHP_MEMORY_LIMIT:-750M}"
export PHP_DATE_TIMEZONE="${PHP_DATE_TIMEZONE:-UTC}"
export PHP_DISPLAY_ERRORS="${PHP_DISPLAY_ERRORS:-off}"
export PHP_ERROR_REPORTING="${PHP_ERROR_REPORTING:-2147483647}"
export PHP_ERROR_LOG="${PHP_ERROR_LOG:-/dev/stderr}"
export PHP_OPCACHE_PRELOAD="${PHP_OPCACHE_PRELOAD:-}"

export PHP_XDEBUG_ENABLE="${PHP_XDEBUG_ENABLE:-false}"
export PHP_XDEBUG_MODE="${PHP_XDEBUG_MODE:-develop}"
export PHP_XDEBUG_DISCOVER_CLIENT_HOST="${PHP_XDEBUG_DISCOVER_CLIENT_HOST:-false}"
export PHP_XDEBUG_CLIENT_HOST="${PHP_XDEBUG_CLIENT_HOST:-}"
export PHP_XDEBUG_CONFIG="${PHP_XDEBUG_CONFIG:-}"
export XDEBUG_CONFIG="${XDEBUG_CONFIG:-${PHP_XDEBUG_CONFIG}}"
export PHP_XDEBUG_MAX_NESTING_LEVEL="${PHP_XDEBUG_MAX_NESTING_LEVEL:-512}"

export PHP_IGBINARY_ENABLE="${PHP_IGBINARY_ENABLE:-false}"

export PHP_FPM_USER="1000"
export PHP_FPM_GROUP="1000"
export PHP_FPM_PORT="${PHP_FPM_PORT:-9000}"
export PHP_FPM_PM_MODE="${PHP_FPM_PM_MODE:-ondemand}"
export PHP_FPM_MAX_CHILDREN="${PHP_FPM_MAX_CHILDREN:-20}"
export PHP_FPM_ERROR_LOG_PATH="${PHP_FPM_ERROR_LOG_PATH:-/opt/flownative/log/php-fpm-error.log}"
export PHP_FPM_ACCESS_LOG_PATH="${PHP_FPM_ACCESS_LOG_PATH:-/opt/flownative/log/php-fpm-access.log}"
EOF
}

# ---------------------------------------------------------------------------------------
# php_fpm_conf_validate() - Validates configuration options passed as PHP_* env vars
#
# @global PHP_* The PHP_* environment variables
# @return void
#
#php_fpm_conf_validate() {
#    echo ""
#}

# ---------------------------------------------------------------------------------------
# php_fpm_initialize() - Initialize PHP configuration and check required files and dirs
#
# @global PHP_* The PHP_* environment variables
# @return void
#
php_fpm_initialize() {
    if [[ $(id --user) == 0 ]]; then
        error "PHP-FPM: Container is running as root, but only unprivileged users are supported"
        exit 1
    fi;

    info "PHP-FPM: Initializing configuration ..."
    envsubst < "${PHP_CONF_PATH}/php-fpm.conf.template" > "${PHP_CONF_PATH}/php-fpm.conf"

    if is_boolean_yes "${PHP_XDEBUG_ENABLE}"; then
        info "PHP-FPM: Xdebug is enabled"
        mv "${PHP_CONF_PATH}/conf.d/php-ext-xdebug.ini.inactive" "${PHP_CONF_PATH}/conf.d/php-ext-xdebug.ini"
    else
        info "PHP-FPM: Xdebug is disabled"
        export PHP_XDEBUG_MODE="off"
    fi

    if is_boolean_yes "${PHP_IGBINARY_ENABLE}"; then
        # igbinary might have been enabled already by scripts in an Docker image which is based on this one
        if [ -f "${PHP_CONF_PATH}/conf.d/php-ext-igbinary.ini.inactive" ]; then
            info "PHP-FPM: igbinary is enabled"
            mv -f "${PHP_CONF_PATH}/conf.d/php-ext-igbinary.ini.inactive" "${PHP_CONF_PATH}/conf.d/php-ext-igbinary.ini"
        fi
    else
        info "PHP-FPM: igbinary is disabled"
    fi

    # Create a file descriptor for the PHP-FPM log output and clean up the log lines a bit:
    exec 4> >(sed -e "s/^\([0-9\/-]* [0-9:,]*\)/\1     OUTPUT PHP-FPM:/")
 }
