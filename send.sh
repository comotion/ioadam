#!/bin/sh
set -x
addr=10.121.20.30
port=1025
perl -e "print \"$@\\r\"" | nc -q1 -u $addr $port
