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

sudo -u $SUDO_USER echo "" >> ${USER_HOME}/.bashrc

# setup GNOME
if command -v gsettings &> /dev/null
then
    # Check if the schemas exist
    if gsettings list-schemas | grep -q "org.gnome.shell.app-switcher"; then
        gsettings set org.gnome.shell.app-switcher current-workspace-only true
    else
        echo "Schema org.gnome.shell.app-switcher does not exist"
    fi

    if gsettings list-schemas | grep -q "org.gnome.shell.extensions.dash-to-dock"; then
        gsettings set org.gnome.shell.extensions.dash-to-dock isolate-workspaces true
    else
        echo "Schema org.gnome.shell.extensions.dash-to-dock does not exist"
    fi

    if gsettings list-schemas | grep -q "org.gnome.desktop.interface"; then
        gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-purple-dark'
        gsettings set org.gnome.desktop.interface icon-theme 'Yaru-purple-dark'
    else
        echo "Schema org.gnome.desktop.interface does not exist"
    fi
fi

# configure shell colors
sed -i '/^#force_color_prompt=yes/s/^#//' ${USER_HOME}/.bashrc
sed -i '/^if \[ "$color_prompt" = yes \]; then$/i\
parse_git_branch() {\
    git branch 2> /dev/null | sed -e "/^[^*]/d" -e "s/* \(.*\)/(\1)/"\
}\

' ${USER_HOME}/.bashrc
sed -i '/^if \[ "$color_prompt" = yes \]; then$/!b;n;s/^\([[:space:]]*\)PS1=/\1# PS1=/;a\
    PS1='\''${debian_chroot:+($debian_chroot)}\\\[\\033[38;2;119;100;216m\\\]\\\[\\033[1m\\\]\\w\\\[\\033[38;2;173;162;231m\\\] $(parse_git_branch)\\\[\\033[0m\\\]\\$ '\''
' ${USER_HOME}/.bashrc

# install general useful things
apt update
apt upgrade -y
apt install curl build-essential git cmake clang-format python3-pip python-is-python3 libusb-1.0-0-dev libncurses5 libncursesw5 srecord -y
sudo -u $SUDO_USER pip install --user virtualenv mypy numpy matplotlib scipy pyserial pyusb cmake-format black

# misc configuration
usermod -aG dialout,plugdev $SUDO_USER
sudo -u $SUDO_USER echo -e 'set bell-style none' >> ${USER_HOME}/.inputrc

# configure git
sudo -u $SUDO_USER git config --global push.autoSetupRemote true
sudo -u $SUDO_USER git config --global push.default simple
sudo -u $SUDO_USER git config --global alias.st status
sudo -u $SUDO_USER git config --global alias.br branch
sudo -u $SUDO_USER git config --global alias.f fetch
sudo -u $SUDO_USER git config --global alias.update 'submodule update --init --recursive'
sudo -u $SUDO_USER git config --global alias.hist 'log --pretty=oneline -n 10'
sudo -u $SUDO_USER git config --global alias.oops 'commit --amend'

# install vscode
sudo -u $SUDO_USER wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
apt install apt-transport-https -y
apt update
apt install code -y

# install arm toolchain
sudo -u $SUDO_USER wget https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu/13.2.rel1/binrel/arm-gnu-toolchain-13.2.rel1-x86_64-arm-none-eabi.tar.xz
tar -xvf arm-gnu-toolchain-13.2.rel1-x86_64-arm-none-eabi.tar.xz -C /opt/
sudo -u $SUDO_USER echo -e 'export PATH=$PATH:/opt/arm-gnu-toolchain-13.2.Rel1-x86_64-arm-none-eabi/bin' >> ${USER_HOME}/.bashrc

# install openocd
apt install libtool pkg-config autoconf automake texinfo libjaylink-dev -y
sudo -u $SUDO_USER git clone https://github.com/openocd-org/openocd.git --recurse-submodules
cd openocd
sudo -u $SUDO_USER ./bootstrap
sudo -u $SUDO_USER ./configure --enable-stlink --enable-esp-usb-jtag --enable-jlink
sudo -u $SUDO_USER make
make install
cp contrib/60-openocd.rules /etc/udev/rules.d/
cd ..

# configure black magic probe
echo -e 'SUBSYSTEM=="tty", ATTRS{interface}=="Black Magic GDB Server", SYMLINK+="ttyBmpGdb"
SUBSYSTEM=="tty", ATTRS{interface}=="Black Magic UART Port", SYMLINK+="ttyBmpTarg"' > /etc/udev/rules.d/99-blackmagic.rules

# install arduino-cli with ESP32 support
curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | BINDIR=/usr/local/bin sh
sudo -u $SUDO_USER arduino-cli config init --additional-urls https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
sudo -u $SUDO_USER arduino-cli core update-index
sudo -u $SUDO_USER arduino-cli core install esp32:esp32

# reload
cd $USER_HOME
sudo -u $SUDO_USER rm -rf $workdir
udevadm control --reload-rules && udevadm trigger
source ${USER_HOME}/.bashrc

sudo -u $SUDO_USER echo "All done! Enjoy!"
