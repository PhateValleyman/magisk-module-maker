#!/data/data/com.termux/files/usr/bin/bash
# Magisk Module Builder Ultimate
# Verze 1.0
# Autor: Váš projekt

set -euo pipefail
IFS=$'\n\t'

# -------------------- KONFIGURACE --------------------
BASE_DIR="${HOME}/magisk_build"
DIALOG="${DIALOG:-dialog}"
WHIPTAIL="${WHIPTAIL:-whiptail}"

# Pokus o detekci dostupného TUI nástroje
if command -v dialog &>/dev/null; then
    TUI="dialog"
elif command -v whiptail &>/dev/null; then
    TUI="whiptail"
else
    echo "ERROR: Ani dialog ani whiptail není nainstalován."
    echo "Nainstalujte: pkg install dialog"
    exit 1
fi

# -------------------- POMOCNÉ FUNKCE --------------------
die() {
    echo "CHYBA: $*" >&2
    exit 1
}

msgbox() {
    local title="$1"
    local text="$2"
    if [[ "$TUI" == "dialog" ]]; then
        dialog --title "$title" --msgbox "$text" 10 60
    else
        whiptail --title "$title" --msgbox "$text" 10 60
    fi
}

inputbox() {
    local title="$1"
    local prompt="$2"
    local default="${3:-}"
    local output
    if [[ "$TUI" == "dialog" ]]; then
        output=$(dialog --title "$title" --inputbox "$prompt" 10 60 "$default" 3>&1 1>&2 2>&3)
    else
        output=$(whiptail --title "$title" --inputbox "$prompt" 10 60 "$default" 3>&1 1>&2 2>&3)
    fi
    echo "$output"
}

yesno() {
    local title="$1"
    local text="$2"
    if [[ "$TUI" == "dialog" ]]; then
        dialog --title "$title" --yesno "$text" 10 60
    else
        whiptail --title "$title" --yesno "$text" 10 60
    fi
}

menu() {
    local title="$1"
    local prompt="$2"
    shift 2
    local args=("$@")
    local output
    if [[ "$TUI" == "dialog" ]]; then
        output=$(dialog --title "$title" --menu "$prompt" 20 60 10 "${args[@]}" 3>&1 1>&2 2>&3)
    else
        output=$(whiptail --title "$title" --menu "$prompt" 20 60 10 "${args[@]}" 3>&1 1>&2 2>&3)
    fi
    echo "$output"
}

inputbox_pass() {
    # Pro zadání hesla (nebo skrytý vstup) - pro jednoduchost používáme stejné
    inputbox "$@"
}

# -------------------- SPRÁVA PROJEKTU --------------------
PROJECT_DIR=""
PROJECT_NAME=""

init_project() {
    PROJECT_NAME=$(inputbox "Nový projekt" "Zadejte název projektu (např. mymodule):")
    [[ -z "$PROJECT_NAME" ]] && return
    PROJECT_DIR="${BASE_DIR}/${PROJECT_NAME}"
    if [[ -d "$PROJECT_DIR" ]]; then
        msgbox "Chyba" "Projekt již existuje."
        return
    fi
    mkdir -p "$PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"/{system,system_ext,product,vendor,zygisk,META-INF}
    # Vytvoření databází
    touch "$PROJECT_DIR/.permissions.db"
    touch "$PROJECT_DIR/.contexts.db"
    touch "$PROJECT_DIR/.replace.db"
    touch "$PROJECT_DIR/.items.db"
    # Základní module.prop
    cat > "$PROJECT_DIR/module.prop" <<EOF
id=${PROJECT_NAME}
name=${PROJECT_NAME}
version=1.0
versionCode=1
author=Unknown
description=Magisk module built with MMBU
EOF
    # Základní prázdné skripty
    touch "$PROJECT_DIR/service.sh"
    touch "$PROJECT_DIR/post-fs-data.sh"
    touch "$PROJECT_DIR/uninstall.sh"
    # README
    echo "# ${PROJECT_NAME}" > "$PROJECT_DIR/README.md"
    msgbox "Hotovo" "Projekt ${PROJECT_NAME} byl vytvořen."
}

load_project() {
    local projects=()
    if [[ -d "$BASE_DIR" ]]; then
        for d in "$BASE_DIR"/*/; do
            [[ -d "$d" ]] && projects+=("$(basename "$d")")
        done
    fi
    if [[ ${#projects[@]} -eq 0 ]]; then
        msgbox "Info" "Žádné projekty nebyly nalezeny."
        return
    fi
    local menu_args=()
    for p in "${projects[@]}"; do
        menu_args+=("$p" "")
    done
    local chosen=$(menu "Načíst projekt" "Vyberte projekt:" "${menu_args[@]}")
    if [[ -n "$chosen" ]]; then
        PROJECT_NAME="$chosen"
        PROJECT_DIR="${BASE_DIR}/${PROJECT_NAME}"
        msgbox "Načteno" "Projekt ${PROJECT_NAME} byl načten."
    fi
}

# -------------------- PRÁCE S DATABÁZEMI --------------------
db_add_perm() {
    local path uid gid mode type
    path=$(inputbox "Přidat oprávnění" "Cesta (např. system/bin/tool):")
    [[ -z "$path" ]] && return
    uid=$(inputbox "UID" "UID (např. 0):" "0")
    gid=$(inputbox "GID" "GID (např. 0):" "0")
    mode=$(inputbox "Mód" "Mód (např. 0755):" "0755")
    type=$(inputbox "Typ" "Typ: file, directory, recursive" "file")
    echo "${path}|${uid}|${gid}|${mode}|${type}" >> "$PROJECT_DIR/.permissions.db"
    # Přidat do items.db
    echo "$path" >> "$PROJECT_DIR/.items.db"
    msgbox "OK" "Oprávnění přidáno."
}

db_list_perms() {
    if [[ ! -s "$PROJECT_DIR/.permissions.db" ]]; then
        msgbox "Info" "Žádná oprávnění."
        return
    fi
    local content=$(cat "$PROJECT_DIR/.permissions.db" | column -t -s '|')
    msgbox "Seznam oprávnění" "$content"
}

db_add_context() {
    local path context
    path=$(inputbox "Přidat SELinux kontext" "Cesta (např. system/bin/tool):")
    [[ -z "$path" ]] && return
    context=$(inputbox "Kontext" "Kontext (např. u:object_r:system_file:s0):")
    [[ -z "$context" ]] && return
    echo "${path}|${context}" >> "$PROJECT_DIR/.contexts.db"
    msgbox "OK" "Kontext přidán."
}

db_list_contexts() {
    if [[ ! -s "$PROJECT_DIR/.contexts.db" ]]; then
        msgbox "Info" "Žádné kontexty."
        return
    fi
    local content=$(cat "$PROJECT_DIR/.contexts.db" | column -t -s '|')
    msgbox "Seznam kontextů" "$content"
}

db_add_replace() {
    local path=$(inputbox "Přidat REPLACE" "Zadejte cestu (např. /system/app/Foo):")
    [[ -z "$path" ]] && return
    echo "$path" >> "$PROJECT_DIR/.replace.db"
    msgbox "OK" "Položka REPLACE přidána."
}

db_list_replace() {
    if [[ ! -s "$PROJECT_DIR/.replace.db" ]]; then
        msgbox "Info" "Žádné REPLACE položky."
        return
    fi
    msgbox "REPLACE seznam" "$(cat "$PROJECT_DIR/.replace.db")"
}

# -------------------- SPRÁVA SOUBORŮ / ADRESÁŘŮ --------------------
add_item() {
    local type=$1  # file nebo directory
    local path=$(inputbox "Přidat ${type}" "Zadejte cestu (např. system/bin/tool):")
    [[ -z "$path" ]] && return
    # Vytvoříme prázdný soubor nebo adresář
    local fullpath="${PROJECT_DIR}/${path}"
    if [[ "$type" == "file" ]]; then
        mkdir -p "$(dirname "$fullpath")"
        touch "$fullpath"
        # Automatické oprávnění
        local mode=0644
        if [[ -x "$fullpath" ]] || [[ "$fullpath" == *.sh ]] || [[ "$fullpath" == *bin/* ]]; then
            mode=0755
        fi
        # Přidat do permissions
        echo "${path}|0|0|${mode}|file" >> "$PROJECT_DIR/.permissions.db"
    else
        mkdir -p "$fullpath"
        echo "${path}|0|0|0755|recursive" >> "$PROJECT_DIR/.permissions.db"
    fi
    echo "$path" >> "$PROJECT_DIR/.items.db"
    msgbox "OK" "${type} přidán."
}

add_zygisk_lib() {
    local libpath=$(inputbox "Cesta k .so knihovně" "Zadejte cestu k .so souboru (v rámci projektu):" "zygisk/arm64-v8a.so")
    [[ -z "$libpath" ]] && return
    # Zkusíme zjistit ABI podle názvu nebo readelf
    local abi=""
    if [[ -f "$PROJECT_DIR/$libpath" ]]; then
        if command -v readelf &>/dev/null; then
            local arch=$(readelf -h "$PROJECT_DIR/$libpath" 2>/dev/null | grep -i "Machine" | awk '{print $2}')
            case "$arch" in
                AArch64) abi="arm64-v8a" ;;
                ARM) abi="armeabi-v7a" ;;
                X86-64) abi="x86_64" ;;
                Intel80386) abi="x86" ;;
                *) abi="unknown" ;;
            esac
        else
            abi="unknown"
        fi
    else
        # Pokud soubor neexistuje, vytvoříme prázdný placeholder?
        touch "$PROJECT_DIR/$libpath"
        abi="unknown"
    fi
    # Přidat oprávnění
    echo "${libpath}|0|0|0755|file" >> "$PROJECT_DIR/.permissions.db"
    echo "$libpath" >> "$PROJECT_DIR/.items.db"
    msgbox "Zygisk" "Knihovna přidána (ABI: ${abi})"
}

list_items() {
    if [[ ! -s "$PROJECT_DIR/.items.db" ]]; then
        msgbox "Info" "Žádné položky."
        return
    fi
    msgbox "Staged items" "$(cat "$PROJECT_DIR/.items.db")"
}

show_tree() {
    if [[ -z "$PROJECT_DIR" ]]; then
        msgbox "Chyba" "Není načten žádný projekt."
        return
    fi
    if command -v tree &>/dev/null; then
        # Použijeme -n pro vypnutí barev
        local output=$(tree -n "$PROJECT_DIR" 2>/dev/null || echo "tree není k dispozici")
        msgbox "Strom projektu" "$output"
    else
        local output=$(find "$PROJECT_DIR" -type d | sed "s|$PROJECT_DIR/||" | sort)
        msgbox "Strom projektu (find)" "$output"
    fi
}

# -------------------- EDITORY SKRIPTŮ --------------------
edit_script() {
    local script_name="$1"
    local file="${PROJECT_DIR}/${script_name}"
    if [[ ! -f "$file" ]]; then
        touch "$file"
    fi
    # Použijeme nano nebo vi, pokud je k dispozici
    local editor="${EDITOR:-nano}"
    if command -v "$editor" &>/dev/null; then
        $editor "$file"
    else
        msgbox "Info" "Editor nenalezen, použijte nano/vi ručně."
    fi
}

edit_module_prop() {
    local file="${PROJECT_DIR}/module.prop"
    if [[ ! -f "$file" ]]; then
        msgbox "Chyba" "module.prop neexistuje."
        return
    fi
    # Jednoduchý formulář pro editaci klíčových položek
    local id=$(grep '^id=' "$file" | cut -d= -f2-)
    local name=$(grep '^name=' "$file" | cut -d= -f2-)
    local version=$(grep '^version=' "$file" | cut -d= -f2-)
    local versionCode=$(grep '^versionCode=' "$file" | cut -d= -f2-)
    local author=$(grep '^author=' "$file" | cut -d= -f2-)
    local description=$(grep '^description=' "$file" | cut -d= -f2-)

    local new_id=$(inputbox "ID" "Zadejte ID modulu:" "$id")
    local new_name=$(inputbox "Název" "Zadejte název modulu:" "$name")
    local new_version=$(inputbox "Verze" "Verze modulu:" "$version")
    local new_versionCode=$(inputbox "VersionCode" "Číslo verze:" "$versionCode")
    local new_author=$(inputbox "Autor" "Autor:" "$author")
    local new_description=$(inputbox "Popis" "Popis modulu:" "$description")

    # Aktualizace souboru
    cat > "$file" <<EOF
id=${new_id}
name=${new_name}
version=${new_version}
versionCode=${new_versionCode}
author=${new_author}
description=${new_description}
EOF
    msgbox "OK" "module.prop aktualizován."
}

# -------------------- GENEROVÁNÍ customize.sh --------------------
generate_customize() {
    local file="${PROJECT_DIR}/customize.sh"
    cat > "$file" <<'EOF'
#!/system/bin/sh
# Magisk Module Customize Script

# This script will be executed in late_start service mode
# More info in the official Magisk documentation

MODPATH=${0%/*}

# Set permissions
EOF

    # Přidat set_perm a set_perm_recursive z databáze
    if [[ -f "$PROJECT_DIR/.permissions.db" ]]; then
        while IFS='|' read -r path uid gid mode type; do
            [[ -z "$path" ]] && continue
            case "$type" in
                file)
                    echo "set_perm \$MODPATH/${path} ${uid} ${gid} ${mode}" >> "$file"
                    ;;
                directory)
                    echo "set_perm \$MODPATH/${path} ${uid} ${gid} ${mode}" >> "$file"
                    ;;
                recursive)
                    echo "set_perm_recursive \$MODPATH/${path} ${uid} ${gid} ${mode} ${mode}" >> "$file"
                    ;;
                *)
                    echo "set_perm \$MODPATH/${path} ${uid} ${gid} ${mode}" >> "$file"
                    ;;
            esac
        done < "$PROJECT_DIR/.permissions.db"
    fi

    # Přidat SELinux kontexty
    if [[ -f "$PROJECT_DIR/.contexts.db" ]]; then
        echo "# SELinux contexts" >> "$file"
        while IFS='|' read -r path context; do
            [[ -z "$path" ]] && continue
            echo "chcon ${context} \$MODPATH/${path}" >> "$file"
        done < "$PROJECT_DIR/.contexts.db"
    fi

    # REPLACE položky
    if [[ -f "$PROJECT_DIR/.replace.db" ]]; then
        echo "# REPLACE" >> "$file"
        echo "REPLACE=\"" >> "$file"
        while read -r line; do
            [[ -z "$line" ]] && continue
            echo "  ${line}" >> "$file"
        done < "$PROJECT_DIR/.replace.db"
        echo "\"" >> "$file"
    fi

    chmod +x "$file"
}

# -------------------- BUILD ENGINE --------------------
build_module() {
    if [[ -z "$PROJECT_DIR" ]]; then
        msgbox "Chyba" "Není načten žádný projekt."
        return
    fi
    # Generovat customize.sh
    generate_customize

    # Generovat updater-script (minimální)
    local meta_dir="${PROJECT_DIR}/META-INF/com/google/android"
    mkdir -p "$meta_dir"
    cat > "${meta_dir}/updater-script" <<'EOF'
#MAGISK
# This is a dummy updater-script for Magisk modules
EOF

    # Vytvoření ZIP
    local version=$(grep '^version=' "$PROJECT_DIR/module.prop" | cut -d= -f2- | tr -d ' ')
    local zipname="${PROJECT_NAME}-v${version}.zip"
    cd "$PROJECT_DIR"
    if yesno "Build" "Chcete zabalit modul do ${zipname}?"; then
        # Vyloučíme databáze a .git
        zip -rq "$zipname" . -x ".permissions.db" ".contexts.db" ".replace.db" ".items.db" "*.git*"
        mv "$zipname" "${BASE_DIR}/"
        msgbox "Hotovo" "Modul byl vytvořen: ${BASE_DIR}/${zipname}"
    fi
    cd - >/dev/null
}

# -------------------- EXPORT / IMPORT --------------------
export_project() {
    if [[ -z "$PROJECT_DIR" ]]; then
        msgbox "Chyba" "Není načten žádný projekt."
        return
    fi
    local tarname="${PROJECT_NAME}.project.tar.gz"
    cd "$BASE_DIR"
    tar czf "$tarname" "$PROJECT_NAME"
    cd - >/dev/null
    msgbox "Export" "Projekt exportován do ${BASE_DIR}/${tarname}"
}

import_project() {
    local archives=()
    for f in "$BASE_DIR"/*.project.tar.gz; do
        [[ -f "$f" ]] && archives+=("$(basename "$f")")
    done
    if [[ ${#archives[@]} -eq 0 ]]; then
        msgbox "Info" "Žádné archivy projektu nenalezeny (*.project.tar.gz)."
        return
    fi
    local menu_args=()
    for a in "${archives[@]}"; do
        menu_args+=("$a" "")
    done
    local chosen=$(menu "Import projektu" "Vyberte archiv:" "${menu_args[@]}")
    if [[ -n "$chosen" ]]; then
        cd "$BASE_DIR"
        tar xzf "$chosen"
        cd - >/dev/null
        # Načíst projekt
        local proj_name=$(basename "$chosen" .project.tar.gz)
        PROJECT_NAME="$proj_name"
        PROJECT_DIR="${BASE_DIR}/${PROJECT_NAME}"
        msgbox "Import" "Projekt byl importován."
    fi
}

# -------------------- HLAVNÍ MENU --------------------
main_menu() {
    while true; do
        local current=""
        if [[ -n "$PROJECT_NAME" ]]; then
            current=" [${PROJECT_NAME}]"
        fi
        local choice=$(menu "Magisk Module Builder${current}" \
            "Vyberte akci:" \
            "1" "Přidat soubor" \
            "2" "Přidat adresář" \
            "3" "Přidat Zygisk knihovnu" \
            "4" "Zobrazit staged items" \
            "5" "Strom projektu" \
            "6" "Spravovat oprávnění" \
            "7" "Spravovat SELinux" \
            "8" "Spravovat REPLACE" \
            "9" "Editovat module.prop" \
            "10" "Editovat service.sh" \
            "11" "Editovat post-fs-data.sh" \
            "12" "Editovat uninstall.sh" \
            "13" "Export projektu" \
            "14" "Import projektu" \
            "15" "Build modulu" \
            "16" "Nový projekt" \
            "17" "Načíst projekt" \
            "18" "Konec")
        case "$choice" in
            1) add_item "file" ;;
            2) add_item "directory" ;;
            3) add_zygisk_lib ;;
            4) list_items ;;
            5) show_tree ;;
            6) perm_menu ;;
            7) selinux_menu ;;
            8) replace_menu ;;
            9) edit_module_prop ;;
            10) edit_script "service.sh" ;;
            11) edit_script "post-fs-data.sh" ;;
            12) edit_script "uninstall.sh" ;;
            13) export_project ;;
            14) import_project ;;
            15) build_module ;;
            16) init_project ;;
            17) load_project ;;
            18|"") echo "Konec."; break ;;
            *) msgbox "Chyba" "Neplatná volba." ;;
        esac
    done
}

# -------------------- DILČÍ MENU --------------------
perm_menu() {
    while true; do
        local choice=$(menu "Správa oprávnění" \
            "Vyberte akci:" \
            "1" "Přidat oprávnění" \
            "2" "Vypsat oprávnění" \
            "3" "Zpět")
        case "$choice" in
            1) db_add_perm ;;
            2) db_list_perms ;;
            3|"") break ;;
            *) msgbox "Chyba" "Neplatná volba." ;;
        esac
    done
}

selinux_menu() {
    while true; do
        local choice=$(menu "Správa SELinux" \
            "Vyberte akci:" \
            "1" "Přidat kontext" \
            "2" "Vypsat kontexty" \
            "3" "Zpět")
        case "$choice" in
            1) db_add_context ;;
            2) db_list_contexts ;;
            3|"") break ;;
            *) msgbox "Chyba" "Neplatná volba." ;;
        esac
    done
}

replace_menu() {
    while true; do
        local choice=$(menu "Správa REPLACE" \
            "Vyberte akci:" \
            "1" "Přidat REPLACE položku" \
            "2" "Vypsat REPLACE položky" \
            "3" "Zpět")
        case "$choice" in
            1) db_add_replace ;;
            2) db_list_replace ;;
            3|"") break ;;
            *) msgbox "Chyba" "Neplatná volba." ;;
        esac
    done
}

# -------------------- SPUŠTĚNÍ --------------------
# Vytvoření základního adresáře
mkdir -p "$BASE_DIR"

# Spuštění hlavního menu
main_menu
