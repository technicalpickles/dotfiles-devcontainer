FROM ghcr.io/technicalpickles/dotfiles-devcontainer/base:latest

ARG DOTFILES_REPO=${templateOption:dotfilesRepo}
ARG DOTFILES_BRANCH=${templateOption:dotfilesBranch}
ARG USER_SHELL=${templateOption:userShell}
ARG DOCKER_BUILD=true

USER vscode
WORKDIR /home/vscode/.dotfiles

RUN setup-dotfiles --repo "${DOTFILES_REPO}" --branch "${DOTFILES_BRANCH}" --env "DOCKER_BUILD=${DOCKER_BUILD}"

WORKDIR /home/vscode
USER root
RUN chsh -s "${USER_SHELL}" vscode
USER vscode
