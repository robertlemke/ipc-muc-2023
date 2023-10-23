FROM flownative/base:bullseye

LABEL org.opencontainers.image.authors="Robert Lemke <robert@flownative.com>"

# -----------------------------------------------------------------------------
# PHP
# Latest versions: https://www.php.net/downloads.php

ARG PHP_VERSION
ENV PHP_VERSION ${PHP_VERSION}

ENV PHP_BASE_PATH="/opt/flownative/php" \
    PATH="/opt/flownative/php/bin:$PATH" \
    LOG_DEBUG="false"

USER root

COPY root-files /

RUN export FLOWNATIVE_LOG_PATH_AND_FILENAME=/dev/stdout \
    && /build.sh init \
    && /build.sh clean

USER 1000
EXPOSE 9000 9001

WORKDIR ${PHP_BASE_PATH}
ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "run" ]
