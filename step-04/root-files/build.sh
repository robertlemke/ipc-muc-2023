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
# build_get_build_packages() - Returns a list of packages which are only needed for building
#
# @global PHP_BASE_PATH
# @return List of packages
#
build_get_build_packages() {
    local packages="
        autoconf
        bison
        build-essential
        cmake
        curl
        file
        pkg-config
        re2c
        unzip

        libcurl4-openssl-dev
        libfreetype6-dev
        libgmp-dev
        libicu-dev
        libjpeg62-turbo-dev
        libltdl-dev
        libmariadb-dev
        libmcrypt-dev
        libonig-dev
        libpng-dev
        libpspell-dev
        libpq-dev
        libreadline6-dev
        libsqlite3-dev
        libssl-dev
        libwebp-dev
        libxml2-dev
        libzip-dev
        libbz2-dev
    "
    echo $packages
}

# ---------------------------------------------------------------------------------------
# build_get_runtime_packages() - Returns a list of packages which are needed during runtime
#
# @return List of packages
#
build_get_runtime_packages() {
    local packages="
        libcurl4
        libonig5
        libpq5
        libreadline8
        libsodium-dev
        libssl1.1
        libzip4
        libbz2-1.0
        libncurses6
        libsqlite3-0
    "

    echo $packages
}

# ---------------------------------------------------------------------------------------
# build_get_unnecessary_packages() - Not needed packages, can be removed
#
# @return List of packages
#
build_get_unnecessary_packages() {
    local packages="
        cmake
   "
    echo $packages
}

# ---------------------------------------------------------------------------------------
# build_compile_php() -
#
# @global PHP_BASE_PATH
# @return void
#
build_compile_php() {
    local php_source_url

    php_source_url="https://www.php.net/distributions/php-${PHP_VERSION}.tar.gz"
    info "🛠 Downloading source code for PHP ${PHP_VERSION} from ${php_source_url} ..."
    with_backoff "curl -sSL ${php_source_url} -o php.tar.gz" "15" || (
        error "Failed downloading PHP source from ${php_source_url}"
        exit 1
    )

    mkdir -p "${PHP_BASE_PATH}/src"
    tar -xf php.tar.gz -C "${PHP_BASE_PATH}/src" --strip-components=1
    rm php.tar.gz*

    cd "${PHP_BASE_PATH}/src"

    info "🛠 Generating build configuration ..."
    ./buildconf --force >$(debug_device)

    if [[ ! -f configure ]]; then
        error "🛠 Failed generating build configuration, 'configure' not found"
        # shellcheck disable=SC2012
        ls | output
        exit 1
    fi

    # For GCC warning options see: https://gcc.gnu.org/onlinedocs/gcc-3.4.4/gcc/Warning-Options.html
    export CFLAGS='-Wno-deprecated-declarations -Wno-stringop-overflow -Wno-implicit-function-declaration'

    if [[ "${PHP_VERSION}" =~ ^7.4 ]]; then
        info "🛠 Running configure for PHP 7.4 ..."
        ./configure \
            --prefix=${PHP_BASE_PATH} \
            --with-config-file-path="${PHP_BASE_PATH}/etc" \
            --with-config-file-scan-dir="${PHP_BASE_PATH}/etc/conf.d" \
            --enable-bcmath \
            --disable-cgi \
            --enable-calendar \
            --enable-exif \
            --enable-fpm \
            --enable-ftp \
            --enable-gd \
            --enable-intl \
            --enable-mbstring \
            --enable-pcntl \
            --enable-soap \
            --enable-sockets \
            --with-curl \
            --with-freetype \
            --with-gmp \
            --with-jpeg \
            --with-mysqli \
            --with-openssl \
            --with-pdo-pgsql \
            --with-pdo-mysql \
            --with-readline \
            --with-sodium \
            --with-system-ciphers \
            --with-webp \
            --with-zip \
            --with-zlib \
            --with-bz2 \
            --without-pear \
            >$(debug_device)
    elif [[ "${PHP_VERSION}" =~ ^8.[0-2] ]]; then
        ./configure \
            --prefix=${PHP_BASE_PATH} \
            --with-config-file-path="${PHP_BASE_PATH}/etc" \
            --with-config-file-scan-dir="${PHP_BASE_PATH}/etc/conf.d" \
            --enable-bcmath \
            --disable-cgi \
            --enable-calendar \
            --enable-exif \
            --enable-fpm \
            --enable-ftp \
            --enable-gd \
            --enable-intl \
            --enable-mbstring \
            --enable-pcntl \
            --enable-soap \
            --enable-sockets \
            --with-curl \
            --with-freetype \
            --with-gmp \
            --with-jpeg \
            --with-mysqli \
            --with-openssl \
            --with-pdo-pgsql \
            --with-pdo-mysql \
            --with-readline \
            --with-sodium \
            --with-system-ciphers \
            --with-webp \
            --with-zip \
            --with-zlib \
            --with-bz2 \
            --without-pear \
            >$(debug_device)
    else
        error "🛠 No configure call available for PHP version ${PHP_VERSION}"
        exit 1
    fi

    info "🛠 Compiling PHP ..."
    make -j"$(nproc)" >$(debug_device)
    make install >$(debug_device)

    info "🛠 Cleaning up ..."
    make clean >$(debug_device)
    rm -rf /tmp/pear
}

# ---------------------------------------------------------------------------------------
# build_php_extension() - Download, move and compile PHP extension source code
#
# @global PHP_BASE_PATH
# @arg Extension name, e.g. "yaml"
# @return void
#
build_php_extension() {

    # -----------------------------------------------------------------------------------
    # Prepare variables

    local -r extension_name="${1:-missing extension name}"
    local -r extension_build_configuration_script="${PHP_BASE_PATH}/build/extensions/${extension_name}/${extension_name}.sh"

    . "${extension_build_configuration_script}" || (
        error "Failed sourcing extension build configuration script from ${extension_build_configuration_script}"
        exit 1
    )

    local -r extensions_dir="${PHP_BASE_PATH}/src/ext"
    local -r extension_dir="${extensions_dir}/${extension_name}"
    local -r extension_url=$(eval "extensions_${extension_name}_url")
    local -r extension_configure_arguments=$(eval "extensions_${extension_name}_configure_arguments")
    local -r extension_ini_path_and_filename="${PHP_BASE_PATH}/etc/conf.d/php-ext-${extension_name}.ini"
    local -r extension_build_packages=$(eval "extensions_${extension_name}_build_packages")
    local -r extension_runtime_packages=$(eval "extensions_${extension_name}_runtime_packages")

    eval "extensions_${extension_name}_prepare"

    # -----------------------------------------------------------------------------------
    # Install packages
    if [[ "${extension_runtime_packages}" != "" ]]; then
        info "🔌 ${extension_name}: Installing runtime packages required by extension"
        packages_install ${extension_runtime_packages} 1>$(debug_device)
    else
        info "🔌 ${extension_name}: No additional runtime packages to install"
    fi

    if [[ "${extension_build_packages}" != "" ]]; then
        info "🔌 ${extension_name}: Installing build packages required by extension"
        packages_install ${extension_build_packages} 1>$(debug_device)
    else
        info "🔌 ${extension_name}: No additional build packages to install"
    fi

    if [[ "${extension_url}" != "" ]]; then
        # ---------------------------------------------------------------------------------
        # Download and extract source code
        info "🔌 ${extension_name}: Downloading extension source code from ${extension_url} ..."

        with_backoff "curl -sSL ${extension_url} -o ${extension_name}.tar.gz" "15" || (
            error "Failed downloading extension ${extension_name}"
            exit 1
        )
        tar -xf ${extension_name}.tar.gz -C ${extensions_dir} 2>/dev/null || (
            error "Tar failed extracting the archive downloaded from ${extension_url}, returned exit code $?"
            exit 1
        )

        mv "${extensions_dir}/${extension_name}"-* "${extension_dir}"
        rm -f ${extension_name}.tar.gz "${extensions_dir}/package.xml"
    else
        info "🔌 ${extension_name}: No download URL specified, so not downloading extension source code"
    fi

    # ---------------------------------------------------------------------------------
    # Configure

    cd "${extension_dir}"
    test -f config.m4 || (
        error "No config.m4 file found in extension directory ${extension_dir}"
        exit 1
    )

    info "🔌 ${extension_name}: Running phpize ..."
    phpize 1>$(debug_device)

    if [[ ${extension_configure_arguments} == "" ]]; then
        info "🔌 ${extension_name}: Running configure without additional arguments ..."
    else
        info "🔌 ${extension_name}: Running configure ${extension_configure_arguments} ..."
    fi

    # For GCC warning options see: https://gcc.gnu.org/onlinedocs/gcc-3.4.4/gcc/Warning-Options.html
    export CFLAGS='-Wno-deprecated-declarations -Wno-stringop-overflow -Wno-implicit-function-declaration'

    ./configure ${extension_configure_arguments} 1>$(debug_device) || (
        error "Configure failed for extension ${extension_name}"
        exit 1
    )

    # ---------------------------------------------------------------------------------
    # Compile
    info "🔌 ${extension_name}: Compiling extension ..."

    make 1>$(debug_device)
    make install 1>$(debug_device)

    # -----------------------------------------------------------------------------------
    # Write extension's .ini file
    info "🔌 ${extension_name}: Writing ini-file ..."

    if [[ "${extension_url}" != "" ]]; then
        for module in "${extension_dir}"/modules/*.so; do
            if [ -f "$module" ]; then
                if grep -q zend_extension_entry "${module}"; then
                    line="zend_extension=$(basename "$module")"
                else
                    line="extension=$(basename "${module}")"
                fi
                if ! grep -q "${line}" "${extension_ini_path_and_filename}" &>/dev/null; then
                    echo "$line" >>${extension_ini_path_and_filename}
                fi
            fi
        done
    fi

    # -----------------------------------------------------------------------------------
    # Clean up

    info "🔌 ${extension_name}: Cleaning up ..."

    make clean 1>$(debug_device)
    make distclean 1>$(debug_device)

    if [[ "${extension_build_packages}" != "" ]]; then
        info "🔌 ${extension_name}: Removing build packages"
        packages_remove ${extension_build_packages} 1>$(debug_device)
    fi
}

# ---------------------------------------------------------------------------------------
# build_php_disable_extension() - Disable a previously installed extension
#
# @global PHP_BASE_PATH
# @arg Extension name, e.g. "xdebug"
# @return void
#
build_disable_php_extension() {

    # -----------------------------------------------------------------------------------
    # Prepare variables

    local -r extension_name="${1:-missing extension name}"
    local -r extension_build_configuration_script="${PHP_BASE_PATH}/build/extensions/${extension_name}/${extension_name}.sh"

    . "${extension_build_configuration_script}" || (
        error "Failed sourcing extension build configuration script from ${extension_build_configuration_script}"
        exit 1
    )

    local -r extensions_dir="${PHP_BASE_PATH}/src/ext"
    local -r extension_dir="${extensions_dir}/${extension_name}"
    local -r extension_ini_path_and_filename="${PHP_BASE_PATH}/etc/conf.d/php-ext-${extension_name}.ini"

    # -----------------------------------------------------------------------------------
    # Deactivate extension's .ini file
    info "🔌 ${extension_name}: Deactivating extension ..."

    if [ -f "${extension_ini_path_and_filename}" ]; then
        mv "${extension_ini_path_and_filename}" "${extension_ini_path_and_filename}.inactive"
    else
        error "🔌 ${extension_name}: ${extension_ini_path_and_filename} not found"
    fi
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
# build_clean() - Clean up obsolete building artifacts and temporary files
#
# @global PHP_BASE_PATH
# @return void
#
build_clean() {
    rm -rf \
        /etc/emacs \
        /usr/include \
        /var/cache/* \
        /var/log/* \
        "${PHP_BASE_PATH}/include" \
        "${PHP_BASE_PATH}/php/man" \
        "${PHP_BASE_PATH}/src"
}

# ---------------------------------------------------------------------------------------
# Main routine

case $1 in
init)
    banner_flownative 'PHP'

    if [[ ! "${PHP_VERSION}" =~ ^7.[1-4]|^8.[0-2] ]]; then
        error "🛠 Unsupported PHP version '${PHP_VERSION}'"
        exit 1
    fi

    build_create_directories
    ;;
prepare)
    packages_install $(build_get_runtime_packages) 1>$(debug_device)
    packages_install $(build_get_build_packages) 1>$(debug_device)
    ;;
build)
    build_compile_php
    ;;
build_extension)
    build_php_extension $2
    ;;
disable_extension)
    build_disable_php_extension $2
    ;;
clean)
    build_adjust_permissions

    packages_remove $(build_get_build_packages) 1>$(debug_device)
    packages_remove $(build_get_unnecessary_packages) 1>$(debug_device)
    packages_remove_docs_and_caches 1>$(debug_device)
    build_clean
    ;;
esac
