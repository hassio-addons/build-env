
ARG BUILD_FROM=ubuntu:xenial
# hadolint ignore=DL3006
FROM ${BUILD_FROM}

# Environment variables
ENV \
    LANG="en_US.UTF-8" \
    DEBIAN_FRONTEND="noninteractive"

# Volume
VOLUME /var/lib/docker

# Workdir
WORKDIR /docker

# Entrypoint
ENTRYPOINT [ "/usr/bin/build.sh" ]

# Copy root filesystem
COPY rootfs /

# Install base system
ARG BUILD_ARCH=amd64
RUN \
    apt-get update \
    \
    && apt-get install -y --no-install-recommends \
        locales=2.23-0ubuntu10 \
    \
    && locale-gen en_US.UTF-8 \
    \
    && apt-get install -y --no-install-recommends \
        apt-transport-https=1.2.26 \
        ca-certificates=20170717~16.04.1 \
        curl=7.47.0-1ubuntu2.8 \
        git=1:2.7.4-0ubuntu1.3 \
        iproute2=4.3.0-1ubuntu3 \
        jq=1.5+dfsg-1 \
        python3=3.5.1-3 \
        python3-pip=8.1.1-2ubuntu0.4 \
        python3-setuptools=20.7.0-1 \
        software-properties-common=0.96.20.7 \
    \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - \
    \
    && add-apt-repository \
        "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    \
    && apt-get update \
    \
    && apt-get install -y --no-install-recommends \
        docker-ce=18.03.1~ce-0~ubuntu \
        binfmt-support=2.1.6-1 \
    \
    && pip3 install \
        docker-context-streamer==0.1.1 \
        dockerfile2json==0.1.1 \
    \
    && apt-get remove -y --purge \
        apt-transport-https \
        curl \
        python3-pip \
        software-properties-common \
    \
    && chmod a+x /usr/bin/build.sh \
    \
    && \
        if [ "${BUILD_ARCH}" != "arm" ]; then \
            rm -f /usr/bin/qemu-arm-static; \
        fi \
    \
    && \
        if [ "${BUILD_ARCH}" != "arm64" ]; then \
            rm -f /usr/bin/qemu-aarch64-static; \
        fi \
    \
    && apt-get -y autoremove \
    && apt-get -y purge \
    && apt-get -y clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/lib/{apt,dpkg,cache,log}/* \
    && rm -rf /var/{cache,log}/* \
    && rm -rf /usr/share/{doc,man}/*

# Build arugments
ARG BUILD_DATE
ARG BUILD_REF
ARG BUILD_VERSION

# Labels
LABEL \
    maintainer="Franck Nijhof <frenck@addons.community>" \
    org.label-schema.description="Docker build environment for Community Hass.io Add-ons" \
    org.label-schema.build-date=${BUILD_DATE} \
    org.label-schema.name="Addon build environment" \
    org.label-schema.schema-version="1.0" \
    org.label-schema.url="http://addons.community" \
    org.label-schema.usage="https://github.com/hassio-addons/build-env/blob/master/README.md" \
    org.label-schema.vcs-ref=${BUILD_REF} \
    org.label-schema.vcs-url="https://github.com/hassio-addons/build-env" \
    org.label-schema.vendor="Franck Nijhof" \
    org.label-schema.version=${BUILD_VERSION}
