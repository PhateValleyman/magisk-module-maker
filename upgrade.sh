#!/bin/bash
set -euo pipefail
echo "🔄 Upgrade Magisk Module Maker na novou verzi..."

# 1. Vytvoření adresářové struktury
mkdir -p lib templates/empty templates/zygisk templates/systemless-host

# 2. Hlavní skript (magisk-builder.sh)
cat > magisk-builder.sh <<'B'
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
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
B
chmod +x magisk-builder.sh

# 3. Knihovna UI (lib/ui.sh)
cat > lib/ui.sh <<'U'
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
safe_input() { local prompt="$1" var="$2" default="$3" validator="$4" value; while true; do read -p "$prompt [$default]: " value; value="${value:-$default}"; if [[ -n "$validator" ]] && ! "$validator" "$value"; then print_error "Neplatná hodnota."; else eval "$var='$value'"; break; fi; done; }
U

# 4. Knihovna databáze (lib/database.sh)
cat > lib/database.sh <<'D'
#!/bin/bash
source "$(dirname "$0")/ui.sh"
DB_HEADER="path,uid,gid,mode,type"
db_init() { local db="$1"; mkdir -p "$(dirname "$db")"; [[ -f "$db" ]] || echo "$DB_HEADER" > "$db"; print_ok "Databáze: $db"; }
db_add_item() {
  local db="$1" path="$2" uid="$3" gid="$4" mode="$5" type="$6"
  validate_path "$path" || { print_error "Neplatná cesta"; return 1; }
  validate_mode "$mode" || { print_error "Neplatný mód"; return 1; }
  grep -q "^$path," "$db" && { print_warn "Duplicita, přeskočeno."; return 0; }
  local tmp=$(mktemp); echo "$path,$uid,$gid,$mode,$type" >> "$tmp"; cat "$db" >> "$tmp"; mv "$tmp" "$db"; print_ok "Přidáno: $path"
}
db_list_items() { tail -n +2 "$1" | cut -d',' -f1; }
db_remove_item() { local db="$1" path="$2"; local tmp=$(mktemp); grep -v "^$path," "$db" > "$tmp"; mv "$tmp" "$db"; print_ok "Smazáno: $path"; }
D

# 5. Build engine (lib/build.sh)
cat > lib/build.sh <<'E'
#!/bin/bash
source "$(dirname "$0")/ui.sh"
source "$(dirname "$0")/database.sh"
build_module() {
  local module_name="$1" output_dir="$2" items_db="$3" config_file="$4"
  source "$config_file"
  print_info "Build spuštěn..."
  local temp_build=$(mktemp -d)
  local module_dir="$temp_build/$module_name"
  mkdir -p "$module_dir"
  cat > "$module_dir/module.prop" <<PROP
id=$module_name
name=$PROJECT_NAME
version=$VERSION
versionCode=$VERSION_CODE
author=$AUTHOR
description=Modul vytvořený pomocí Magisk Module Maker
PROP
  print_ok "module.prop vytvořen"
  local IFS=,
  tail -n +2 "$items_db" | while read path uid gid mode type; do
    local target="$module_dir/$path"
    mkdir -p "$(dirname "$target")"
    if [[ "$type" == "file" ]] && [[ -f "$path" ]]; then
      cp "$path" "$target"; chmod "$mode" "$target"; print_ok "Kopíruji: $path"
    elif [[ "$type" == "dir" ]]; then
      mkdir -p "$target"; chmod "$mode" "$target"; print_ok "Adresář: $path"
    else
      print_warn "Soubor chybí: $path"
    fi
  done
  if find "$module_dir" -name "*.so" | grep -q .; then
    local abi=""
    [[ -d "$module_dir/system/lib64" ]] && abi="arm64-v8a"
    [[ -d "$module_dir/system/lib" ]] && abi="${abi} armeabi-v7a"
    [[ -n "$abi" ]] && echo "ABI: $abi" >> "$module_dir/module.prop" && print_ok "ABI detekováno: $abi"
  fi
  [[ -f "templates/post-fs-data.sh" ]] && cp "templates/post-fs-data.sh" "$module_dir/post-fs-data.sh" && chmod 0755 "$module_dir/post-fs-data.sh"
  [[ -f "templates/service.sh" ]] && cp "templates/service.sh" "$module_dir/service.sh" && chmod 0755 "$module_dir/service.sh"
  cat > "$module_dir/customize.sh" <<'CUS'
#!/system/bin/sh
ui_print "- Instaluji $MODID verze $MODVER"
[[ "$MAGISK_VER_CODE" -lt 20000 ]] && abort "Magisk 20.0+ vyžadován"
CUS
  chmod 0755 "$module_dir/customize.sh"
  mkdir -p "$output_dir"
  local zip_path="$output_dir/$ZIP_NAME"
  cd "$temp_build"; zip -r "$zip_path" "$module_name" >/dev/null; cd - >/dev/null
  rm -rf "$temp_build"
  print_ok "Modul vytvořen: $zip_path"
}
E

# 6. Konfigurace (config.env)
cat > config.env <<'C'
PROJECT_NAME="MyMagiskModule"
AUTHOR="YourName"
VERSION="1.0"
VERSION_CODE=1
BASE_DIR="$(pwd)"
DB_DIR="$BASE_DIR/db"
ITEMS_DB="$DB_DIR/items.db"
MODULES_DB="$DB_DIR/modules.db"
TEMP_DIR="$BASE_DIR/tmp"
OUTPUT_DIR="$BASE_DIR/output"
DEFAULT_MODE="0755"
DEFAULT_UID=0
DEFAULT_GID=0
ZIP_NAME="${PROJECT_NAME}-v${VERSION}.zip"
C

# 7. Prázdné šablony
cat > templates/post-fs-data.sh <<'T1'
#!/system/bin/sh
# Spouští se v post-fs-data
T1
cat > templates/service.sh <<'T2'
#!/system/bin/sh
# Spouští se jako služba na pozadí
T2
cat > templates/empty/post-fs-data.sh <<'T3'
#!/system/bin/sh
# Prázdná šablona
T3

# 8. Nastavení práv
chmod +x lib/*.sh
chmod +x templates/*.sh 2>/dev/null || true

# 9. Smazání starých dočasných souborů (pokud existují)
rm -f db/*.db.tmp 2>/dev/null || true

echo "✅ Upgrade dokončen! Spusťte: ./magisk-builder.sh"
