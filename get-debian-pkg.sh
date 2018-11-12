#!/bin/bash



URL="https://packages.debian.org/source/sid"
PKG_NAME=libmad


arch_ext=".tar.gz"
#arch_ext=".tar.xz"
diff_ext=".diff.gz"
#diff_ext=".diff.xz"

file_dsc=$(curl $URL/$PKG_NAME|grep ".dsc"|awk -F"href=" '{print $2}'|awk -F'"' '{print $2}')
file_diff=$(curl $URL/$PKG_NAME|grep "$diff_ext"|awk -F"href=" '{print $2}'|awk -F'"' '{print $2}')
file_arch=$(curl $URL/$PKG_NAME|grep ".tar.gz"|awk -F"href=" '{print $2}'|awk -F'"' '{print $2}')


echo -----------

echo $file_dsc
echo $file_diff
echo $file_arch

wget $file_dsc
wget $file_diff
wget $file_arch


dpkg-source -x *.dsc
