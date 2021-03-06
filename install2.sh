#!/bin/bash
#===================================================================================
#
# Installs Basic System Software for Linux From Scratch 9.0 on a Red Hat based distribution of linux, such as Fedora, CentOS, or RHEL.
# Copyright (C) 2019

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>
#
#===================================================================================
set +e

MAKEFLAGS="-j$(nproc)"
export MAKEFLAGS

touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664 /var/log/lastlog
chmod -v 600 /var/log/btmp
read -r -p "Press [Enter] key to resume..."

cd /sources || exit 1
# Linux-5.5.3 || Linux API Headers expose the kernel's API for use by Glibc || 0.1 SBU
tar xvf linux-5.5.3.tar.xz
(
  cd linux-5.5.3 || exit 1
  make mrproper
  read -r -p "Press [Enter] key to resume..."
  make headers
  find usr/include -name '.*' -delete
  rm usr/include/Makefile
  cp -rv usr/include/* /usr/include
  read -r -p "Press [Enter] key to resume..."
)
rm -Rf linux-5.5.3

# Man-pages-5.02 || contains over 2,200 man pages || less than 0.1 SBU
tar xvf man-pages-5.02.tar.xz
(
  cd man-pages-5.02 || exit 1
  make install
)
rm -Rf man-pages-5.02

# Glibc-2.31 || contains main C library || 19 SBU
tar xvf glibc-2.31.tar.xz
(
  cd glibc-2.31 || exit 1
  patch -Np1 -i ../glibc-2.31-fhs-1.patch
  case $(uname -m) in
  i?86)
    ln -sfv ld-linux.so.2 /lib/ld-lsb.so.3
    ;;
  x86_64)
    ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64
    ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64/ld-lsb-x86-64.so.3
    ;;
  esac
  read -r -p "Press [Enter] key to resume..."
  mkdir -v build
  cd build || exit 1
  CC="gcc -ffile-prefix-map=/tools=/usr" \
    ../configure --prefix=/usr \
    --disable-werror \
    --enable-kernel=3.2 \
    --enable-stack-protector=strong \
    --with-headers=/usr/include \
    libc_cv_slibdir=/lib
  read -r -p "Press [Enter] key to resume..."
  make
  read -r -p "Press [Enter] key to resume..."
  case $(uname -m) in
  i?86) ln -sfnv "$PWD/elf/ld-linux.so.2" /lib ;;
  x86_64) ln -sfnv "$PWD/elf/ld-linux-x86-64.so.2" /lib ;;
  esac
  make check
  read -r -p "Press [Enter] key to resume..."
  touch /etc/ld.so.conf
  sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
  make install
  read -r -p "Press [Enter] key to resume..."
  cp -v ../nscd/nscd.conf /etc/nscd.conf
  mkdir -pv /var/cache/nscd
  mkdir -pv /usr/lib/locale
  make localedata/install-locales
  read -r -p "Press [Enter] key to resume..."
  cat >/etc/nsswitch.conf <<"EOF"
# Begin /etc/nsswitch.conf

passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF
  tar -xf ../../tzdata2019c.tar.gz

  ZONEINFO=/usr/share/zoneinfo
  mkdir -pv $ZONEINFO/{posix,right}

  for tz in etcetera southamerica northamerica europe africa antarctica \
    asia australasia backward pacificnew systemv; do
    zic -L /dev/null -d $ZONEINFO ${tz}
    zic -L /dev/null -d $ZONEINFO/posix ${tz}
    zic -L leapseconds -d $ZONEINFO/right ${tz}
  done

  cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
  zic -d $ZONEINFO -p America/New_York
  unset ZONEINFO
  read -r -p "Press [Enter] key to resume..."
  CTIME=$(tzselect)
  echo "Your local time zone was detected to be $CTIME"
  read -r -p "Press [Enter] key to resume..."
  ln -sfv "/usr/share/zoneinfo/${CTIME}" /etc/localtime
  cat >/etc/ld.so.conf <<"EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib
EOF
  cat >>/etc/ld.so.conf <<"EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf
EOF
  mkdir -pv /etc/ld.so.conf.d
)
rm -Rf glibc-2.31

# Adjusting the Toolchain
mv -v /tools/bin/{ld,ld-old}
mv -v /tools/"$(uname -m)"-pc-linux-gnu/bin/{ld,ld-old}
mv -v /tools/bin/{ld-new,ld}
ln -sv /tools/bin/ld /tools/"$(uname -m)"-pc-linux-gnu/bin/ld
gcc -dumpspecs | sed -e 's@/tools@@g' \
  -e '/\*startfile_prefix_spec:/{n;s@.*@/usr/lib/ @}' \
  -e '/\*cpp:/{n;s@$@ -isystem /usr/include@}' > \
  "$(dirname $(gcc --print-libgcc-file-name))"/specs
read -r -p "Press [Enter] key to resume..."
echo 'int main(){}' >dummy.c
cc dummy.c -v -Wl,--verbose &>dummy.log
readelf -l a.out | grep ': /lib'
read -r -p "Press [Enter] key to resume..."
grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log
read -r -p "Press [Enter] key to resume..."
grep -B1 '^ /usr/include' dummy.log
read -r -p "Press [Enter] key to resume..."
grep 'SEARCH.*/usr/lib' dummy.log | sed 's|; |\n|g'
read -r -p "Press [Enter] key to resume..."
grep "/lib.*/libc.so.6 " dummy.log
read -r -p "Press [Enter] key to resume..."
grep found dummy.log
read -r -p "Press [Enter] key to resume..."
rm -v dummy.c a.out dummy.log

# Zlib-1.2.11 || Contains compression and decompression functions used by some programs || less than 0.1 SBU
tar xvf zlib-1.2.11.tar.xz
(
  cd zlib-1.2.11 || exit 1
  ./configure --prefix=/usr
  read -r -p "Press [Enter] key to resume..."
  make
  read -r -p "Press [Enter] key to resume..."
  make install
  read -r -p "Press [Enter] key to resume..."
  mv -v /usr/lib/libz.so.* /lib
  ln -sfv "../../lib/$(readlink /usr/lib/libz.so)" /usr/lib/libz.so
)
rm -Rf zlib-1.2.11

# Bzip2-1.0.8 || Contains programs for compressing and decompressing files|| less than 0.1 SBU
tar xvf bzip2-1.0.8.tar.gz
(
  cd bzip2-1.0.8 || exit 1
  patch -Np1 -i ../bzip2-1.0.8-install_docs-1.patch
  sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
  sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
  make -f Makefile-libbz2_so
  make clean
  read -r -p "Press [Enter] key to resume..."
  make
  read -r -p "Press [Enter] key to resume..."
  make PREFIX=/usr install
  cp -v bzip2-shared /bin/bzip2
  cp -av libbz2.so* /lib
  ln -sv ../../lib/libbz2.so.1.0 /usr/lib/libbz2.so
  rm -v /usr/bin/{bunzip2,bzcat,bzip2}
  ln -sv bzip2 /bin/bunzip2
  ln -sv bzip2 /bin/bzcat
  read -r -p "Press [Enter] key to resume..."
)
rm -Rf bzip2-1.0.8

# Xz-5.2.4 || Contains programs for compressing and decompressing files || 0.2 SBU
tar xvf xz-5.2.4.tar.xz
(
  cd xz-5.2.4 || exit 1
  ./configure --prefix=/usr \
    --disable-static \
    --docdir=/usr/share/doc/xz-5.2.4
  read -r -p "Press [Enter] key to resume..."
  make
  read -r -p "Press [Enter] key to resume..."
  make check
  read -r -p "Press [Enter] key to resume..."
  make install
  mv -v /usr/bin/{lzma,unlzma,lzcat,xz,unxz,xzcat} /bin
  mv -v /usr/lib/liblzma.so.* /lib
  ln -svf "../../lib/$(readlink /usr/lib/liblzma.so)" /usr/lib/liblzma.so
)
rm -Rf xz-5.2.4

# File-5.38 || Determine the type of a given file || 0.1 SBU
tar xvf file-5.38.tar.gz
(
  cd file-5.38 || exit 1
  ./configure --prefix=/usr
  read -r -p "Press [Enter] key to resume..."
  make
  read -r -p "Press [Enter] key to resume..."
  make check
  read -r -p "Press [Enter] key to resume..."
  make install
  read -r -p "Press [Enter] key to resume..."
)
rm -Rf file-5.38

cd /shdir || exit 1

bash install3.sh
