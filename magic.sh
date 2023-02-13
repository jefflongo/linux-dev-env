#!/bin/bash
set -e

workdir=${HOME}/Downloads/.bootstrap
mkdir -p $workdir
cd $workdir

echo "" >> ${HOME}/.bashrc

# install general useful things
apt update
apt upgrade -y
apt install curl build-essential git cmake clang-format python3-pip python-is-python3 libusb-1.0-0-dev libncurses5 srecord -y
pip install virtualenv mypy numpy matplotlib scipy pyserial pyusb cmake-format black

# misc configuration
usermod -aG dialout $USER
echo -e 'set bell-style none' >> ${HOME}/.inputrc

# configure git
git config --global push.autoSetupRemote true
git config --global push.default simple
git config --global alias.st status
git config --global alias.br branch
git config --global alias.f fetch
git config --global alias.update 'submodule update --init --recursive'
git config --global alias.hist 'log --pretty=oneline -n 10'
git config --global alias.oops 'commit --amend'

# install vscode
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
apt install apt-transport-https -y
apt update
apt install code -y

# install arm toolchain
wget https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-rm/10.3-2021.10/gcc-arm-none-eabi-10.3-2021.10-x86_64-linux.tar.bz2
tar -xvf gcc-arm-none-eabi-10.3-2021.10-x86_64-linux.tar.bz2 -C /opt/
echo -e 'export PATH=$PATH:/opt/gcc-arm-none-eabi-10.3-2021.10/bin' >> ${HOME}/.bashrc

# install openocd
apt install libtool pkg-config autoconf automake texinfo -y
git clone https://github.com/openocd-org/openocd.git --recurse-submodules
cd openocd
./bootstrap
./configure --enable-stlink --enable-esp-usb-jtag --enable-jlink
make
make install
cp contrib/60-openocd.rules /etc/udev/rules.d/
cd ..

# configure black magic probe
echo -e 'SUBSYSTEM=="tty", ATTRS{interface}=="Black Magic GDB Server", SYMLINK+="ttyBmpGdb"
SUBSYSTEM=="tty", ATTRS{interface}=="Black Magic UART Port", SYMLINK+="ttyBmpTarg"' > /etc/udev/rules.d/99-blackmagic.rules

# install arduino-cli with ESP32 support
curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | BINDIR=/usr/local/bin sh
arduino-cli config init --additional-urls https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
arduino-cli core update-index
arduino-cli core install esp32:esp32

# reload
cd $HOME
rm -rf $workdir
udevadm control --reload-rules && udevadm trigger
source ${HOME}/.bashrc

echo "All done! Enjoy!"
