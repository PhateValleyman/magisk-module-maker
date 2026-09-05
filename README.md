# Magisk Module Builder Ultimate (MMBU)

Nástroj pro snadnou tvorbu a správu Magisk modulů přímo v CLI (optimalizováno pro Termux a Linux).

## Klíčové vlastnosti
- **TUI rozhraní**: Přehledné menu založené na **fzf** (s interaktivním vyhledáváním), `dialog` nebo `whiptail`.
- **Správa projektů**: Inicializace, načítání, export a import projektů.
- **Databáze oprávnění a kontextů**: Snadné přidávání i **mazání** oprávnění (UID/GID/Mode) a SELinux kontextů.
- **Build Engine**: Automatické generování flashovatelných ZIP archivů včetně `customize.sh`, `update-binary` a `updater-script`.
- **Zygisk Support**: Podpora pro přidávání Zygisk knihoven s automatickou detekcí ABI.
- **Bezpečnost**: Používá `set -euo pipefail` pro robustní běh skriptu.

## Požadavky
- `bash`
- `zip`
- `fzf` (doporučeno pro vyhledávání v menu), `dialog` nebo `whiptail`
- (volitelně) `tree` pro hezčí zobrazení struktury

## Instalace a spuštění
1. Klonujte repozitář.
2. Udělte práva ke spuštění: `chmod +x magisk-builder.sh`.
3. Spusťte: `./magisk-builder.sh`.

## Provedené vylepšení (v1.2)
- Přidána podpora pro **fzf** (pokud je nainstalováno, použije se primárně).
- Opravena přenositelnost shebangu.
- Přidána kontrola závislostí (`zip`).
- Implementováno generování `update-binary`.
- Přidána funkce pro mazání záznamů v databázích.
- Vylepšen fallback pro zobrazení stromu projektu.
