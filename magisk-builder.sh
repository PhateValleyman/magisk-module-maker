#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
export LIB_DIR
CONFIG_FILE="$SCRIPT_DIR/config.env"
source "$LIB_DIR/ui.sh"
source "$LIB_DIR/database.sh"
source "$LIB_DIR/build.sh"
[[ -f "$CONFIG_FILE" ]] || { echo "❌ Chybí config.env!"; exit 1; }
source "$CONFIG_FILE"
db_init "$ITEMS_DB"
if [[ $# -gt 0 ]]; then
  case "$1" in
    --help|-h) cat <<HELP
Použití: $0 [PŘÍKAZ]
  add <cesta> [uid] [gid] [mode] [type]   Přidá položku
  remove <cesta>                          Odebere položku
  list                                    Výpis položek
  build                                   Sestaví modul
  dry-run                                 Simulace buildu
  menu                                    Interaktivní menu (výchozí)
HELP
    exit 0 ;;
    add) shift; db_add_item "$ITEMS_DB" "$1" "${2:-0}" "${3:-0}" "${4:-$DEFAULT_MODE}" "${5:-file}"; exit $? ;;
    remove) shift; db_remove_item "$ITEMS_DB" "$1"; exit $? ;;
    list) db_list_items "$ITEMS_DB"; exit 0 ;;
    build) build_module "$PROJECT_NAME" "$OUTPUT_DIR" "$ITEMS_DB" "$CONFIG_FILE"; exit $? ;;
    dry-run) print_info "Suchý běh:"; tail -n +2 "$ITEMS_DB" | while IFS=, read p u g m t; do echo "  - $p ($t) mód=$m"; done; exit 0 ;;
    menu) ;; *) echo "Neznámý příkaz: $1"; exit 1 ;;
  esac
fi
while true; do
  clear
  echo "${BOLD}=== Magisk Module Builder ===${RESET}"
  echo "1) Přidat soubor/adresář"
  echo "2) Odebrat položku"
  echo "3) Zobrazit seznam"
  echo "4) Build modulu"
  echo "5) Suchý běh"
  echo "6) Konec"
  read -p "Vyberte [1-6]: " volba
  case "$volba" in
    1) safe_input "Cesta" path ""; safe_input "UID" uid 0; safe_input "GID" gid 0; safe_input "Mód" mode "$DEFAULT_MODE" validate_mode; safe_input "Typ" type file; db_add_item "$ITEMS_DB" "$path" "$uid" "$gid" "$mode" "$type"; read -p "Enter..." ;;
    2) polozky=$(db_list_items "$ITEMS_DB"); [[ -z "$polozky" ]] && { print_warn "Prázdné."; read -p "Enter..."; continue; }; vybrana=$(echo "$polozky" | fzf --prompt="Smazat: "); [[ -n "$vybrana" ]] && db_remove_item "$ITEMS_DB" "$vybrana"; read -p "Enter..." ;;
    3) db_list_items "$ITEMS_DB" | nl; read -p "Enter..." ;;
    4) build_module "$PROJECT_NAME" "$OUTPUT_DIR" "$ITEMS_DB" "$CONFIG_FILE"; read -p "Enter..." ;;
    5) print_info "Suchý běh:"; tail -n +2 "$ITEMS_DB" | while IFS=, read p u g m t; do echo "  - $p ($t) mód=$m"; done; read -p "Enter..." ;;
    6) print_ok "Nashledanou!"; exit 0 ;;
    *) print_error "Neplatná volba."; read -p "Enter..." ;;
  esac
done
