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
    # Base essentials
    locales \
    ca-certificates \
    bash \
    bash-completion \
    gpg \
    less \
    sudo \
    nano \
    mousepad \
    chromium \
    curl \
    wget \
    git \
    git-cola \
    iproute2 \
    net-tools \
    iputils-ping \
    \
    # C/C++ build essentials
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    gdb \
    \
    # Python development environment
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    libssl-dev \
    libffi-dev \
    pkg-config\
    \
    # Windows development environment
    binutils-mingw-w64 \
    mingw-w64 \
    mingw-w64-tools \
    \
    # GUI Desktop Environment (XFCE4 - lightweight)
    dbus-x11 \
    x11-xserver-utils \
    xorgxrdp \
    xrdp \
    tigervnc-standalone-server \
    tigervnc-common \
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
ENV PATH="/usr/local/sbin:/usr/sbin:/sbin:${PATH}"

# Accept build arguments for user credentials
ARG DOCKER_USERNAME=dev
ARG DOCKER_PASSWORD=dev
ARG VNC_PASSWORD=password

# Set up VNC environment
ENV VNC_RESOLUTION=1920x1080
ENV VNC_PASSWORD=${VNC_PASSWORD}

# Create User and set password
# add git config to allow access to not owned git repositories
RUN \
  useradd --create-home --shell /bin/bash --comment "defaultuser" --groups sudo,adm ${DOCKER_USERNAME} \
  && echo "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" | chpasswd \
  && git config --system --add safe.directory '*' \
  && /bin/dbus-uuidgen > /etc/machine-id # XFCE Config

# Add common aliases to user's bash configuration files
# Also fix PATH to include /usr/sbin and /sbin for system tools like ifconfig
RUN \
  echo "export PATH=\"/usr/local/sbin:/usr/sbin:/sbin:\$PATH\"" >> /home/${DOCKER_USERNAME}/.bashrc \
  && echo "alias ll='ls -l'" >> /home/${DOCKER_USERNAME}/.bashrc \
  && echo "shopt -s expand_aliases" > /home/${DOCKER_USERNAME}/.bash_profile \
  && echo "export PATH=\"/usr/local/sbin:/usr/sbin:/sbin:\$PATH\"" >> /home/${DOCKER_USERNAME}/.bash_profile \
  && echo "alias ll='ls -l'" >> /home/${DOCKER_USERNAME}/.bash_profile \
  && echo "[ -f ~/.bashrc ] && . ~/.bashrc" >> /home/${DOCKER_USERNAME}/.bash_profile \
  && chown ${DOCKER_USERNAME}:${DOCKER_USERNAME} /home/${DOCKER_USERNAME}/.bashrc \
  && chown ${DOCKER_USERNAME}:${DOCKER_USERNAME} /home/${DOCKER_USERNAME}/.bash_profile

# Install and configure SSH server
RUN \
  --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  apt-get -y update \
  && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install openssh-server \
  && mkdir -p /var/run/sshd \
  && ssh-keygen -A \
  && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
  && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config \
  && sed -i 's/#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config \
  && sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config \
  && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
  && if ! grep -q "^PasswordAuthentication" /etc/ssh/sshd_config; then echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config; fi \
  && if ! grep -q "^PermitRootLogin" /etc/ssh/sshd_config; then echo "PermitRootLogin no" >> /etc/ssh/sshd_config; fi \
  && if ! grep -q "^PubkeyAuthentication" /etc/ssh/sshd_config; then echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config; fi \
  && rm -rf /var/lib/apt/lists/*


COPY start_rdp.sh /usr/bin/start_rdp.sh
RUN sed -i 's/\r$//' /usr/bin/start_rdp.sh && chmod +x /usr/bin/start_rdp.sh

COPY start_vnc.sh /usr/bin/start_vnc.sh
RUN sed -i 's/\r$//' /usr/bin/start_vnc.sh && chmod +x /usr/bin/start_vnc.sh

COPY configure-vpn-routing.sh /usr/bin/configure-vpn-routing.sh
RUN sed -i 's/\r$//' /usr/bin/configure-vpn-routing.sh && chmod +x /usr/bin/configure-vpn-routing.sh

USER ${DOCKER_USERNAME}
WORKDIR /home/${DOCKER_USERNAME}

EXPOSE 3389/tcp
EXPOSE 5901/tcp
EXPOSE 22/tcp

ENTRYPOINT [ "/usr/bin/start_rdp.sh" ]

