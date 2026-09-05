#!/bin/bash
source "$LIB_DIR/ui.sh"
source "$LIB_DIR/database.sh"
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
    if [[ "$type" == "file" ]]; then
      mkdir -p "$(dirname "$target")"
      if [[ -f "$path" ]]; then
        cp "$path" "$target"; chmod "$mode" "$target"; print_ok "Kopíruji: $path"
      else
        touch "$target"; chmod "$mode" "$target"; print_warn "Vytvářím prázdný: $path"
      fi
    elif [[ "$type" == "dir" ]] || [[ "$type" == "directory" ]]; then
      mkdir -p "$target"; chmod "$mode" "$target"; print_ok "Adresář: $path"
    fi
  done

  # Magisk specifikace
  local meta_dir="$module_dir/META-INF/com/google/android"
  mkdir -p "$meta_dir"
  cat > "$meta_dir/updater-script" <<'EOF'
#MAGISK
EOF
  cat > "$meta_dir/update-binary" <<'EOF'
#!/system/bin/sh
MODPATH=${0%/*}
EOF
  chmod 0755 "$meta_dir/update-binary"
  print_ok "Meta-inf vytvořen"

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
