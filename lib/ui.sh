#!/bin/bash
if [[ -t 1 ]]; then
  BOLD=$(tput bold); RED=$(tput setaf 1); GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3); BLUE=$(tput setaf 4); RESET=$(tput sgr0)
else
  BOLD=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; RESET=""
fi
print_info()  { echo "${BLUE}ℹ${RESET} $*"; }
print_ok()    { echo "${GREEN}✔${RESET} $*"; }
print_warn()  { echo "${YELLOW}⚠${RESET} $*" >&2; }
print_error() { echo "${RED}✘${RESET} $*" >&2; }
fzf_menu() { local prompt="$1"; shift; local list=""; for item in "$@"; do key="${item%%:*}"; label="${item#*:}"; list+="${key}:${label}\n"; done; echo -e "$list" | fzf --prompt="$prompt " --with-nth=2 --delimiter=':' --preview='echo {2}' | cut -d: -f1; }
validate_path() { [[ "$1" =~ ^[a-zA-Z0-9_./-]+$ ]] && return 0 || return 1; }
validate_mode() { [[ "$1" =~ ^0[0-7]{3}$ ]] && return 0 || return 1; }
safe_input() {
  local prompt="$1"
  local var_name="$2"
  local default="$3"
  local validator="${4:-}"   # bezpečně – pokud není zadán, je prázdný
  local value
  while true; do
    read -p "$prompt [$default]: " value
    value="${value:-$default}"
    if [[ -n "$validator" ]] && ! "$validator" "$value"; then
      print_error "Neplatná hodnota."
    else
      eval "$var_name='$value'"
      break
    fi
  done
}
