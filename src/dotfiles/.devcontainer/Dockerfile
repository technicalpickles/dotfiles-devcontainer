FROM ghcr.io/technicalpickles/dotfiles-devcontainer/base:latest

ARG DOTFILES_REPO=${templateOption:dotfilesRepo}
ARG DOTFILES_BRANCH=${templateOption:dotfilesBranch}
ARG DOTFILES_INSTALL_ARGS_B64=${templateOption:dotfilesInstallArgsB64}
ARG USER_SHELL=${templateOption:userShell}
ARG DOCKER_BUILD=true

USER vscode
WORKDIR /home/vscode/.dotfiles

RUN if [ -n "${DOTFILES_INSTALL_ARGS_B64}" ]; then \
      setup-dotfiles --repo "${DOTFILES_REPO}" --branch "${DOTFILES_BRANCH}" --env "DOCKER_BUILD=${DOCKER_BUILD}" --install-args-b64 "${DOTFILES_INSTALL_ARGS_B64}"; \
    else \
      setup-dotfiles --repo "${DOTFILES_REPO}" --branch "${DOTFILES_BRANCH}" --env "DOCKER_BUILD=${DOCKER_BUILD}"; \
    fi

WORKDIR /home/vscode
USER root
RUN chsh -s "${USER_SHELL}" vscode
USER vscode
