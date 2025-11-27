FROM ghcr.io/technicalpickles/dotfiles-devcontainer/base:latest

ARG DOTFILES_REPO=https://github.com/technicalpickles/dotfiles.git
ARG DOTFILES_BRANCH=main
ARG DOCKER_BUILD=true

USER vscode
WORKDIR /home/vscode

RUN setup-dotfiles --repo "${DOTFILES_REPO}" --branch "${DOTFILES_BRANCH}" --env "DOCKER_BUILD=${DOCKER_BUILD}"

USER root
RUN chsh -s /usr/bin/fish vscode
USER vscode
