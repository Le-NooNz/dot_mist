#!/bin/bash
#
# ./b00b.sh
#
# Truc de geek

cat /dev/urandom | hexdump -C | grep --color=auto "b0 0b"
