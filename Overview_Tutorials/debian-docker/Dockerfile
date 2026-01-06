# SPDX-License-Identifier: BSD-3-Clause

# This Source Code Form is subject to the terms of the BSD-3-Clause License.
# If a copy of the BSD-3-Clause License was not distributed with this file, You can obtain one at https://opensource.org/licenses/BSD-3-Clause.
#
# Stefan Zintgraf, stefan@zintgraf.de

# Docker Image for AI ready C/C++ and Python Development

FROM debian:latest

# Update and install packages
RUN \
  --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  apt-get -y update \
  && DEBIAN_FRONTEND=noninteractive apt-get -y upgrade \
  && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
    locales \
    ca-certificates \
    bash \
    bash-completion \
    gpg \
    less \
    sudo \
    nano \
    mousepad \
    curl \
    git \
    iproute2 \
    net-tools \
    \
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    gdb \
    \
    binutils-mingw-w64 \
    mingw-w64 \
    mingw-w64-tools \
    \
    dbus-x11 \
    x11-xserver-utils \
    xorgxrdp \
    xrdp \
    xfce4 \
    xfce4-goodies \
    xfce4-clipman-plugin \
    xfce4-cpugraph-plugin \
    xfce4-netload-plugin \
    xfce4-screenshooter \
    xfce4-taskmanager \
    xfce4-terminal \
    xfce4-xkb-plugin \
    xfwm4-theme-breeze \
    gvfs \
    libglib2.0-bin \
    \
    # Clean up to reduce image size
    && rm -rf /var/lib/apt/lists/*

# Set locales
RUN \
     sed -i -e 's/# \(en_US\.UTF-8 .*\)/\1/' /etc/locale.gen \
  && sed -i -e 's/# \(de_DE\.UTF-8 .*\)/\1/' /etc/locale.gen \
  && dpkg-reconfigure --frontend=noninteractive locales

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Accept build arguments for user credentials
ARG DOCKER_USERNAME=dev
ARG DOCKER_PASSWORD=dev

# Create User and set password
# add git config to allow access to not owned git repositories
RUN \
  useradd --create-home --shell /bin/bash --comment "defaultuser" --groups sudo,adm ${DOCKER_USERNAME} \
  && echo "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" | chpasswd \
  && git config --system --add safe.directory '*' \
  && /bin/dbus-uuidgen > /etc/machine-id # XFCE Config

COPY start_rdp.sh /usr/bin/start_rdp.sh
RUN sed -i 's/\r$//' /usr/bin/start_rdp.sh && chmod +x /usr/bin/start_rdp.sh

USER ${DOCKER_USERNAME}
WORKDIR /home/${DOCKER_USERNAME}

EXPOSE 3389/tcp

ENTRYPOINT [ "/usr/bin/start_rdp.sh" ]

