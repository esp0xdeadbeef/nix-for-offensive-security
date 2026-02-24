#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="test-container"
DISTRO="archlinux"
RELEASE="current"
ARCH="amd64"
FLAKE="github:esp0xdeadbeef/nix-for-offensive-security"

print_cleanup_notice() {
    echo "============================================================"
    echo "After the demo, remove the container with:"
    echo "  lxc-destroy ${CONTAINER_NAME}"
    echo "============================================================"
    echo
}

create_container() {
    echo "[*] Creating ${DISTRO} container: ${CONTAINER_NAME}"
    lxc-create -t download -n "${CONTAINER_NAME}" -- \
        -d "${DISTRO}" -r "${RELEASE}" -a "${ARCH}"
    echo "[*] Starting ${CONTAINER_NAME}"
    lxc-start -n "${CONTAINER_NAME}"
}

install_nix() {
    echo "[*] Updating system and installing Nix inside container..."

    lxc-attach -n "${CONTAINER_NAME}" --clear-env -- bash -c '
        set -e
        pacman -Syu --noconfirm
        pacman -S --noconfirm nix
    '
}

configure_nix() {
    echo "[*] Enabling nix-command and flakes..."

    lxc-attach -n "${CONTAINER_NAME}" --clear-env -- bash -c '
        mkdir -p ~/.config/nix
        echo "experimental-features = nix-command flakes" \
            > ~/.config/nix/nix.conf
    '

    echo
    echo "If you do NOT configure this globally, you must use:"
    echo "  nix <cmd> --extra-experimental-features nix-command \\"
    echo "      --extra-experimental-features flakes"
    echo
}

build_flake() {
    echo "[*] Building flake (first run may take 10-15 minutes, coffee?)..."

    lxc-attach -n "${CONTAINER_NAME}" --clear-env -- \
        nix develop "${FLAKE}"
}

enter_container() {
    echo "[*] Attaching to container..."
    lxc-attach -n "${CONTAINER_NAME}" --clear-env
}

main() {
    print_cleanup_notice
    create_container || true
    install_nix
    configure_nix
    build_flake
    enter_container
}

main
