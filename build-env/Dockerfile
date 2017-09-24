FROM ubuntu:16.04

# Environment variables
ENV \
    LANG="en_US.UTF-8"

# Volume
VOLUME /var/lib/docker

# Workdir
WORKDIR /docker

# Entrypoint 
ENTRYPOINT [ "/usr/bin/build.sh" ]

# Copy root filesystem
COPY rootfs /

# Install base system
RUN \
    apt-get update \
    \
    && apt-get install -y --no-install-recommends \
        locales \
    \
    && locale-gen en_US.UTF-8 \
    \
    && apt-get install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        curl \
        git \
        iproute2 \
        jq \
        python3 \
        python3-pip \
        python3-setuptools \
        software-properties-common \
    \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - \
    \
    && add-apt-repository \
        "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    \
    && apt-get update \
    \
    && apt-get install -y --no-install-recommends \
        docker-ce \
        qemu-user-static \
        binfmt-support \
    \
    && pip3 install \
        docker-context-streamer \
        dockerfile2json \
    \
    && apt-get remove -y --purge \
        apt-transport-https \
        curl \
        python3-pip \
        software-properties-common \
    && chmod a+x /usr/bin/build.sh \
    && apt-get -y autoremove \
    && apt-get -y purge \
    && apt-get -y clean \
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
