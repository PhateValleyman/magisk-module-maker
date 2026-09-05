#!/bin/bash
source "$LIB_DIR/ui.sh"
DB_HEADER="path,uid,gid,mode,type"
db_init() { local db="$1"; mkdir -p "$(dirname "$db")"; [[ -f "$db" ]] || echo "$DB_HEADER" > "$db"; print_ok "Databáze: $db"; }
db_add_item() {
  local db="$1" path="$2" uid="$3" gid="$4" mode="$5" type="$6"
  validate_path "$path" || { print_error "Neplatná cesta"; return 1; }
  validate_mode "$mode" || { print_error "Neplatný mód"; return 1; }
  grep -q "^$path," "$db" && { print_warn "Duplicita, přeskočeno."; return 0; }
  local tmp=$(mktemp)
  echo "$DB_HEADER" > "$tmp"
  echo "$path,$uid,$gid,$mode,$type" >> "$tmp"
  tail -n +2 "$db" >> "$tmp"
  mv "$tmp" "$db"
  print_ok "Přidáno: $path"
}
db_list_items() { tail -n +2 "$1" | cut -d',' -f1; }
db_remove_item() { local db="$1" path="$2"; local tmp=$(mktemp); grep -v "^$path," "$db" > "$tmp"; mv "$tmp" "$db"; print_ok "Smazáno: $path"; }
