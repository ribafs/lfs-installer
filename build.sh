#!/bin/bash  
#=================================================================================== 
# 
# Builds first part of first toolchain pass for Linux From Scratch 8.4 on a Red Hat based distribution of linux, such as Fedora, CentOS, or RHEL. 
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
#===================================================================================

# Enter previous password set
whoami 
if [ -z "$shdir" ]; then echo "\$shdir is blank"; else echo "\$shdir is set to $shdir"; fi

if [ $LFS != /mnt/lfs ]
then
  export LFS=/mnt/lfs
fi
read -p "Press [Enter] key to resume..."

#Build 

# Binutils-2.32 || Contains a linker, an assembler, and other tools for handling object files || 7.4 SBUs
tar xvf binutils-2.32.tar.xz
cd binutils-2.32
target_triplet=`./config.guess`
export target_triplet
echo $target_triplet
read -p "Press [Enter] key to resume..."
mkdir -v build; cd build
../configure --prefix=/tools --with-sysroot=$LFS --with-lib-path=/tools/lib --target=$LFS_TGT --disable-nls --disable-werror
case $(uname -m) in
  x86_64) mkdir -v /tools/lib && ln -sv lib /tools/lib64 ;;
esac
time make -j4
read -p "Real Time is 1 SBU"
read -p "Press [Enter] key to resume..."
# real is 1 SBU
make install
read -p "Press [Enter] key to resume..."
cd ..
rm -Rf build
rm -Rf binutils-2.32
cd /mnt/lfs/sources

# Install Gcc
tar xvf gcc-9.2.0.tar.xz
cd gcc-9.2.0

# tar -xf ../mpfr-4.0.2.tar.xz
# mv -v mpfr-4.0.2 mpfr
# tar -xf ../gmp-6.1.2.tar.xz
# mv -v gmp-6.1.2 gmp
# tar -xf ../mpc-1.1.0.tar.gz
# mv -v mpc-1.1.0 mpc

./contrib/download_prerequisites
for file in gcc/config/{linux,i386/linux{,64}}.h
do
 cp -uv $file{,.orig}
 sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
 -e 's@/usr@/tools@g' $file.orig > $file
 echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
 touch $file.orig
done

case $(uname -m) in
 x86_64)
 sed -e '/m64=/s/lib64/lib/' \
 -i.orig gcc/config/i386/t-linux64
 ;;
esac
cd ..
mkdir -v objdir
cd objdir
../configure                                       \
    --target=$LFS_TGT                              \
    --prefix=/tools                                \
    --with-glibc-version=2.11                      \
    --with-sysroot=$LFS                            \
    --with-newlib                                  \
    --without-headers                              \
    --with-local-prefix=/tools                     \
    --with-native-system-header-dir=/tools/include \
    --disable-nls                                  \
    --disable-shared                               \
    --disable-multilib                             \
    --disable-decimal-float                        \
    --disable-threads                              \
    --disable-libatomic                            \
    --disable-libgomp                              \
    --disable-libquadmath                          \
    --disable-libssp                               \
    --disable-libvtv                               \
    --disable-libstdcxx                            \
    --enable-languages=c,c++
read -p "Press [Enter] key to resume..."
make -j4
read -p "Press [Enter] key to resume..."
make install
read -p "Press [Enter] key to resume..."
rm -Rf gcc-9.2.0
cd $shdir
bash build2.sh
