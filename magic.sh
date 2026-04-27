#!/bin/bash
set -eu

if [ $(id -u) -ne 0 ]
then
    echo "this script must be executed as root"
    exit 1
fi

USER_HOME=$(eval echo ~${SUDO_USER})

workdir=${USER_HOME}/Downloads/.bootstrap
sudo -u $SUDO_USER mkdir -p $workdir
cd $workdir

# install general useful things
apt update
apt upgrade -y
apt install bat black build-essential clang-format cmake cmake-format curl dbus-x11 default-jdk git libncurses-dev libncursesw6 libusb-1.0-0-dev micro ninja-build python-is-python3 python3 python3-matplotlib python3-mypy python3-numpy python3-pip python3-scipy python3-serial python3-usb python3-virtualenv srecord xclip -y

configure_gnome() {
    if command -v gsettings &> /dev/null; then
        if gsettings list-schemas | grep -q "org.gnome.shell.app-switcher"; then
            echo "Configuring app switcher..."
            sudo -u $SUDO_USER dbus-launch gsettings set org.gnome.shell.app-switcher current-workspace-only true
        else
            echo "Schema org.gnome.shell.app-switcher does not exist"
        fi
    
        if gsettings list-schemas | grep -q "org.gnome.shell.extensions.dash-to-dock"; then
            echo "Configuring dock..."
            sudo -u $SUDO_USER dbus-launch gsettings set org.gnome.shell.extensions.dash-to-dock isolate-workspaces true
        else
            echo "Schema org.gnome.shell.extensions.dash-to-dock does not exist"
        fi
    
        if gsettings list-schemas | grep -q "org.gnome.desktop.interface"; then
            echo "Configuring UI..."
            sudo -u $SUDO_USER dbus-launch gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
            sudo -u $SUDO_USER dbus-launch gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-purple-dark'
            sudo -u $SUDO_USER dbus-launch gsettings set org.gnome.desktop.interface icon-theme 'Yaru-purple-dark'
        else
            echo "Schema org.gnome.desktop.interface does not exist"
        fi
    fi
}

configure_shell() {
    echo "" | sudo -u $SUDO_USER tee -a ${USER_HOME}/.bashrc
    echo 'export EDITOR=micro' | sudo -u $SUDO_USER tee -a ${USER_HOME}/.bashrc
    echo "" | sudo -u $SUDO_USER tee -a ${USER_HOME}/.bashrc
    echo 'alias bat="batcat -pp"' | sudo -u $SUDO_USER tee -a ${USER_HOME}/.bashrc
    echo 'alias copy="xclip -selection clipboard"' | sudo -u $SUDO_USER tee -a ${USER_HOME}/.bashrc
    echo "" | sudo -u $SUDO_USER tee -a ${USER_HOME}/.bashrc
    sed -i '/^#force_color_prompt=yes/s/^#//' ${USER_HOME}/.bashrc
    sed -i '/^if \[ "$color_prompt" = yes \]; then$/i\
parse_git_branch() {\
    git branch 2> /dev/null | sed -e "/^[^*]/d" -e "s/* \\(.*\\)/(\\1)/"\
}\n' ${USER_HOME}/.bashrc
    sed -i '/^if \[ "$color_prompt" = yes \]; then$/!b;n;s/^\([[:space:]]*\)PS1=/\1# PS1=/;a\
    PS1='\''${debian_chroot:+($debian_chroot)}\\\[\\033[38;2;119;100;216m\\\]\\\[\\033[1m\\\]\\w\\\[\\033[38;2;173;162;231m\\\] $(parse_git_branch)\\\[\\033[0m\\\]\\$ '\''
' ${USER_HOME}/.bashrc
    echo -e 'set bell-style none' | sudo -u $SUDO_USER tee -a ${USER_HOME}/.inputrc
}

configure_udev() {
    usermod -aG dialout,plugdev $SUDO_USER
    echo -e 'SUBSYSTEM=="tty", ATTRS{interface}=="Black Magic GDB Server", SYMLINK+="ttyBmpGdb"
    SUBSYSTEM=="tty", ATTRS{interface}=="Black Magic UART Port", SYMLINK+="ttyBmpTarg"' > /etc/udev/rules.d/99-blackmagic.rules
}

configure_git() {
    sudo -u $SUDO_USER git config --global alias.br branch
    sudo -u $SUDO_USER git config --global alias.f fetch
    sudo -u $SUDO_USER git config --global alias.hist 'log --pretty=oneline -n 10'
    sudo -u $SUDO_USER git config --global alias.oops 'commit --amend --no-edit'
    sudo -u $SUDO_USER git config --global alias.st status
    sudo -u $SUDO_USER git config --global alias.update 'submodule update --init --recursive'
    sudo -u $SUDO_USER git config --global core.editor "micro"
    sudo -u $SUDO_USER git config --global pull.rebase true
    sudo -u $SUDO_USER git config --global push.autoSetupRemote true
    sudo -u $SUDO_USER git config --global push.default simple
    sudo -u $SUDO_USER git config --global rebase.autoStash true
    sudo -u $SUDO_USER git config --global rerere.enabled true
    sudo -u $SUDO_USER git config --global submodule.recurse true
}

install_code() {
    if command -v snap &> /dev/null; then
        snap install --classic code
    else
        apt install wget gpg apt-transport-https -y
        sudo -u $SUDO_USER wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
        install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
        sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
        apt update
        apt install code -y
    fi
}

install_rust() {
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
}

install_arm_toolchain() {
    local VERSION
    VERSION=$(sudo -u $SUDO_USER wget -qO- "https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads" | grep -oP '(?<=downloads/gnu/)[^/"]+' | sort -Vu | tail -1)
    sudo -u $SUDO_USER wget -O- "https://developer.arm.com/-/media/Files/downloads/gnu/${VERSION}/binrel/arm-gnu-toolchain-${VERSION}-x86_64-arm-none-eabi.tar.xz" | tar -xJ -C /opt
    echo 'export PATH="/opt/arm-gnu-toolchain-'"${VERSION}"'-x86_64-arm-none-eabi/bin:$PATH"' | sudo -u $SUDO_USER tee -a ${USER_HOME}/.bashrc
}

install_openocd() {
    apt install libtool pkg-config autoconf automake texinfo libjaylink-dev libjim-dev -y
    sudo -u $SUDO_USER git clone https://github.com/openocd-org/openocd.git --recurse-submodules
    cd openocd
    sudo -u $SUDO_USER ./bootstrap
    sudo -u $SUDO_USER ./configure --enable-stlink --enable-esp-usb-jtag --enable-jlink
    sudo -u $SUDO_USER make
    make install
    cp contrib/60-openocd.rules /etc/udev/rules.d/
    cd ..
}

configure_gnome
configure_shell
configure_udev
configure_git
install_code
install_rust
install_arm_toolchain
install_openocd

# reload
cd $USER_HOME
sudo -u $SUDO_USER rm -rf $workdir
udevadm control --reload-rules && udevadm trigger
source ${USER_HOME}/.bashrc

echo "All done! Enjoy!"
