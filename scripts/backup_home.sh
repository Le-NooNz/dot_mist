#!/bin/bash
#	backup_home.sh
#	rsync les configs de /home/noonz vers hera.hex.lan:/mnt/backup/home/noonz

target_user="root"
target_host="hera.hex.lan"
target_dir="/mnt/backup/home/"
# Plus utilise
# excludes="$HOME/.excludes.txt"
include="$HOME/.includes"

echo "+---------------------------------------------+"
echo "|                                             |"
echo "|               Synchronisation               |"
echo "|                                             |"
echo "+---------------------------------------------+"

rsync -az \
--progress \
--delete-during \
--delete-excluded \
--include-from "$include" \
"$HOME" \
"$target_user"@"$target_host":"$target_dir"

echo "+---------------------------------------------+"
echo "|                                             |"
echo "|           Synchronisation Terminee          |"
echo "|                                             |"
echo "+---------------------------------------------+"