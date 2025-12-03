# syntax=docker/dockerfile:1

FROM mcr.microsoft.com/devcontainers/base:ubuntu@sha256:8d68bbf458958747a7f41756f60de95d5b404f374f05cd42969957653fad0cfe

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG GOSS_VERSION=v0.3.22

# Install core tooling and CLIs
RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        curl \
        git \
        gnupg \
        lsb-release \
        software-properties-common \
        build-essential \
        wget \
        tmux \
        unzip \
    && mkdir -p /etc/apt/keyrings \
    # GitHub CLI repo
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    # 1Password CLI repo
    && curl -fsSL https://downloads.1password.com/linux/keys/1password.asc | gpg --dearmor -o /etc/apt/keyrings/1password-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/1password-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" > /etc/apt/sources.list.d/1password.list \
    # Fish repo
    && apt-add-repository ppa:fish-shell/release-3 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        fish \
        gh \
        1password-cli \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# AWS CLI v2
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o /tmp/awscliv2.zip \
    && unzip /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update \
    && rm -rf /tmp/aws /tmp/awscliv2.zip

# Install mise and starship
RUN curl https://mise.run | sh \
    && mv /root/.local/bin/mise /usr/local/bin/mise \
    && curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir /usr/local/bin

# Install goss (pinned version)
RUN curl -fsSL https://goss.rocks/install | GOSS_VER="${GOSS_VERSION}" GOSS_DST=/usr/local/bin sh

# Dotfiles setup helper + base post-create entrypoint
COPY docker/base/setup-dotfiles /usr/local/bin/setup-dotfiles
COPY docker/base/devcontainer-post-create /usr/local/bin/devcontainer-post-create
RUN chmod +x /usr/local/bin/setup-dotfiles /usr/local/bin/devcontainer-post-create

USER vscode
WORKDIR /home/vscode
