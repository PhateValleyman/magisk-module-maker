# Magisk Module Builder Ultimate (MMBU) v2.0

Nástroj pro profesionální tvorbu Magisk modulů s novou modulární architekturou.

## Klíčové vlastnosti (v2.0)
- **Modulární architektura**: Kód rozdělen do logických částí (`lib/build.sh`, `lib/database.sh`, `lib/ui.sh`).
- **Rozšířené CLI**: Podpora pro argumenty (`add`, `remove`, `list`, `build`, `dry-run`) i interaktivní menu.
- **FZF integrace**: Rychlé vyhledávání a výběr typů pomocí `fzf`.
- **Validace**: Přísná kontrola cest a oprávnění (chmod módů).
- **Magisk Standard**: Automatické generování `update-binary`, `updater-script` a detekce ABI.
- **Upgrade skript**: Přibalen `upgrade.sh` pro přechod ze starších verzí.

## Požadavky
- `bash`
- `zip`
- `fzf` (povinné pro v2.0+)
- `tput` (součást ncurses)

## Instalace a spuštění
1. Klonujte repozitář.
2. Udělte práva ke spuštění: `chmod +x magisk-builder.sh lib/*.sh`.
3. Spusťte interaktivně: `./magisk-builder.sh`.
4. Nebo pomocí CLI: `./magisk-builder.sh add system/bin/mytool 0 0 0755 file`.

## Struktura projektu
- `magisk-builder.sh`: Hlavní vstupní bod.
- `lib/`: Knihovny pro UI, DB a Build.
- `db/`: Uložené položky modulu.
- `templates/`: Šablony pro skripty.
- `output/`: Místo pro hotové ZIP archivy.

## Historie verzí
- **v2.0**: Kompletní refaktor, modulární kód, CLI argumenty, vylepšený build.
- **v1.2**: Přidána podpora pro fzf.
- **v1.1**: Oprava shebangu, `update-binary` a mazání v DB.

