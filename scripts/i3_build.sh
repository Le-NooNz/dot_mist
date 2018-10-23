#!/bin/bash
cd /opt/i3

# compile & install
autoreconf --force --install
rm -rf build/
mkdir -p build && cd build/

# Disabling sanitizers is important for release versions!
# The prefix and sysconfdir are, obviously, dependent on the distribution.
../configure --prefix=/usr --sysconfdir=/etc --disable-sanitizers
make
sudo make install

# Polybar
cd /opt/polybar

rm -rf build/
mkdir build
cd build/

cmake -DENABLE_I3=ON -DCMAKE_BUILD_TYPE=Release ..
sudo make install

# I3lock-color

cd /opt/i3lock-color
make
sudo make install
