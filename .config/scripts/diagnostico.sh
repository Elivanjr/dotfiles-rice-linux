#!/usr/bin/env bash

# Diagnostico inicial do NixOS Live
# Somente leitura: nao modifica o sistema.

set -u

separador() {
  printf '\n%s\n' "========================================"
}

executar() {
  separador
  printf '=== %s ===\n' "$1"
  shift
  "$@" 2>&1 || true
}

printf 'DIAGNOSTICO DO NIXOS\n'
printf 'Data: %s\n' "$(date '+%d/%m/%Y %H:%M:%S')"

executar "SISTEMA" uname -a
executar "DISTRIBUICAO" cat /etc/os-release
executar "CPU" lscpu
executar "NUCLEOS" nproc
executar "MEMORIA" free -h
executar "DISCOS E PARTICOES" \
  lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
executar "ESPACO EM DISCO" df -h
executar "DISPOSITIVOS PCI" lspci
executar "REDE" ip -brief address

separador
printf 'FIM DO DIAGNOSTICO\n'
