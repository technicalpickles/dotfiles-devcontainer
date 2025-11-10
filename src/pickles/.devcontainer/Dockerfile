FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Install basic dependencies
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    build-essential \
    curl \
    git \
    wget \
    ca-certificates \
    gnupg \
    lsb-release \
    tmux \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install fish shell
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends software-properties-common \
    && apt-add-repository ppa:fish-shell/release-3 \
    && apt-get update \
    && apt-get -y install --no-install-recommends fish \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get -y install --no-install-recommends gh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install mise
RUN curl https://mise.run | sh

# Install starship
RUN curl -sS https://starship.rs/install.sh | sh -s -- --force

# Set role for dotfiles installation
ARG DOTPICKLES_ROLE=devcontainer
ENV DOTPICKLES_ROLE=${DOTPICKLES_ROLE}

# Switch to vscode user
USER vscode
WORKDIR /home/vscode

# Clone dotfiles repository
ARG DOTFILES_REPO=https://github.com/technicalpickles/dotfiles.git
ARG DOTFILES_BRANCH=main
RUN git clone --branch ${DOTFILES_BRANCH} ${DOTFILES_REPO} /home/vscode/.pickles

# Run dotfiles installation
RUN cd /home/vscode/.pickles && bash install.sh

# Set fish as default shell for vscode user
USER root
RUN chsh -s /usr/bin/fish vscode
USER vscode
