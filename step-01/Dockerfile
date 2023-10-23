FROM bitnami/minideb:bullseye

LABEL org.opencontainers.image.authors="Robert Lemke <robert@flownative.com>"

ARG BUILD_DATE

LABEL com.flownative.base-image-build-date=$BUILD_DATE

ENV FLOWNATIVE_LIB_PATH="/opt/flownative/lib" \
    LOG_DEBUG=true

COPY --from=europe-docker.pkg.dev/flownative/docker/bash-library:1.13.5 /lib $FLOWNATIVE_LIB_PATH

COPY root-files /
RUN /build.sh && rm /build.sh

USER 1000
ENTRYPOINT ["/entrypoint.sh"]
CMD [ "run" ]
