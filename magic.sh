#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Do not run this script with sudo." >&2
    echo "Run it as your normal user: $0" >&2
    exit 1
fi

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR; popd > /dev/null"' EXIT
pushd $WORKDIR > /dev/null

# install general useful things
sudo apt update -q
sudo apt upgrade -qy
sudo apt install bat black build-essential clang-format cmake cmake-format curl default-jdk git \
     libncurses-dev libncursesw6 libusb-1.0-0-dev micro ninja-build openocd python-is-python3 \
     python3 python3-matplotlib python3-mypy python3-numpy python3-pip python3-scipy \
     python3-serial python3-usb srecord wl-clipboard -y

configure_gnome() {
    echo "Configuring GNOME"
    if command -v gsettings &> /dev/null; then
        if gsettings list-schemas | grep -q "org.gnome.shell.app-switcher"; then
            echo "Configuring app switcher..."
            gsettings set org.gnome.shell.app-switcher current-workspace-only true
        else
            echo "Schema org.gnome.shell.app-switcher does not exist"
        fi

        if gsettings list-schemas | grep -q "org.gnome.shell.extensions.dash-to-dock"; then
            echo "Configuring dock..."
            gsettings set org.gnome.shell.extensions.dash-to-dock isolate-workspaces true
        else
            echo "Schema org.gnome.shell.extensions.dash-to-dock does not exist"
        fi

        if gsettings list-schemas | grep -q "org.gnome.desktop.interface"; then
            echo "Configuring UI..."
            gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
            gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-purple-dark'
            gsettings set org.gnome.desktop.interface icon-theme 'Yaru-purple-dark'
        else
            echo "Schema org.gnome.desktop.interface does not exist"
        fi
    else
        echo "gsettings not installed, skipping GNOME configuration"
    fi
}

configure_shell() {
    echo "Configuring shell"
    echo "" >> $HOME/.bashrc
    echo 'export EDITOR=micro' >> $HOME/.bashrc
    echo "" >> $HOME/.bashrc
    echo 'alias bat="batcat -pp"' >> $HOME/.bashrc
    echo 'alias copy="wl-copy"' >> $HOME/.bashrc
    echo "" >> $HOME/.bashrc
    sed -i '/^#force_color_prompt=yes/s/^#//' $HOME/.bashrc
    sed -i '/^if \[ "$color_prompt" = yes \]; then$/i\
parse_git_branch() {\
    git branch 2> /dev/null | sed -e "/^[^*]/d" -e "s/* \\(.*\\)/(\\1)/"\
}\n' $HOME/.bashrc
    sed -i '/^if \[ "$color_prompt" = yes \]; then$/!b;n;s/^\([[:space:]]*\)PS1=/\1# PS1=/;a\
    PS1='\''${debian_chroot:+($debian_chroot)}\\\[\\033[38;2;119;100;216m\\\]\\\[\\033[1m\\\]\\w\\\[\\033[38;2;173;162;231m\\\] $(parse_git_branch)\\\[\\033[0m\\\]\\$ '\''
' $HOME/.bashrc
    echo 'set bell-style none' >> $HOME/.inputrc
    echo '"\C-h": backward-kill-word' >> $HOME/.inputrc
}

configure_udev() {
    echo "Configuring udev"
    sudo usermod -aG dialout,plugdev $USER
    echo 'SUBSYSTEM=="tty", ATTRS{interface}=="Black Magic GDB Server", SYMLINK+="ttyBmpGdb"
    SUBSYSTEM=="tty", ATTRS{interface}=="Black Magic UART Port", SYMLINK+="ttyBmpTarg"' | sudo tee /etc/udev/rules.d/99-blackmagic.rules
}

configure_git() {
    echo "Configuring git"
    git config --global alias.br branch
    git config --global alias.f fetch
    git config --global alias.hist 'log --pretty=oneline --abbrev-commit -n 10'
    git config --global alias.oops 'commit --amend --no-edit'
    git config --global alias.st status
    git config --global alias.update 'submodule update --init --recursive'
    git config --global core.editor "micro"
    git config --global pull.rebase true
    git config --global push.autoSetupRemote true
    git config --global push.default simple
    git config --global rebase.autoStash true
    git config --global rerere.enabled true
    git config --global submodule.recurse true
}

install_code() {
    echo "Installing VS Code"
    sudo apt install wget gpg apt-transport-https -y
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
    sudo tee /etc/apt/sources.list.d/vscode.sources > /dev/null <<'EOF'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF
    sudo apt update -q
    sudo apt install code -y
}

install_rust() {
    echo "Installing Rust"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
}

install_arm_toolchain() {
    local VERSION
    echo "Installing ARM toolchain"
    VERSION=$(wget -qO- "https://gitlab.arm.com/api/v4/projects/tooling%2Fgnu-toolchains-for-arm/packages?package_type=generic&package_name=gnu-toolchain&per_page=100" | jq -r '.[].version' | sort -Vu | tail -1)
    wget -qO- "https://gitlab.arm.com/api/v4/projects/tooling%2Fgnu-toolchains-for-arm/packages/generic/gnu-toolchain/${VERSION}/arm-gnu-toolchain-${VERSION}-x86_64-arm-none-eabi.tar.xz" | sudo tar -xJ -C /opt
    echo 'export PATH="/opt/arm-gnu-toolchain-'"${VERSION}"'-x86_64-arm-none-eabi/bin:$PATH"' >> $HOME/.bashrc
}

configure_gnome
configure_shell
configure_udev
configure_git
install_code
install_rust
install_arm_toolchain

# reload
sudo udevadm control --reload-rules
sudo udevadm trigger
source $HOME/.bashrc

echo "All done! Enjoy!"
