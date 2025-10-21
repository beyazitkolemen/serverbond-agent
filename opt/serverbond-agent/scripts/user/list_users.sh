#!/usr/bin/env bash
set -euo pipefail

printf "%-20s %-30s %-10s\n" "KULLANICI" "HOME" "SHELL"
printf '%*s\n' 70 '' | tr ' ' '-'
getent passwd | awk -F: '{printf "%-20s %-30s %-10s\n", $1, $6, $7}'

