FROM flownative/base:bullseye

LABEL org.opencontainers.image.authors="Robert Lemke <robert@flownative.com>"

USER root

COPY root-files /

RUN export FLOWNATIVE_LOG_PATH_AND_FILENAME=/dev/stdout \
    && /build.sh init \
    && /build.sh clean

USER 1000

WORKDIR ${PHP_BASE_PATH}
ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "run" ]
