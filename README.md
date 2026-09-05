# Magisk Module Maker (Standalone Tasker App)

Tento projekt byl transformován z CLI nástroje na plnohodnotnou Android aplikaci (APK) vytvořenou pomocí **Tasker App Factory**.

## Rychlý start (APK verze)
1. Stáhněte soubor `magisk-module-maker.prj.xml`.
2. V aplikaci **Tasker** dlouze podržte ikonu "domů" (Home) a vyberte **Import Project**.
3. Vyberte stažený `.prj.xml` soubor.
4. Nyní máte v Taskeru projekt se scénami (GUI) a úkoly (Logic).
5. Pro vytvoření samostatné aplikace (.apk):
   - Ujistěte se, že máte nainstalován **Tasker App Factory**.
   - Dlouze podržte název projektu "Magisk Module Maker" a vyberte **Export -> As App**.

## Funkce aplikace
- **Dashboard (Scene: Main)**: Centrální ovládání, tlačítko pro sestavení a přidávání položek.
- **Editor (Scene: Editor)**: Vizuální formulář pro nastavení cest a oprávnění.
- **Terminal (Scene: Terminal)**: Průhledné překryvné okno s reálným výstupem z build procesu.
- **Logic**: Všechny operace (vytváření složek, generování `module.prop`, zipování) probíhají nativně v Androidu bez nutnosti Termuxu.

## CLI Verze (Legacy)
Původní skript `magisk-builder.sh` a jeho modulární knihovny jsou stále k dispozici v adresáři `lib/` pro pokročilé uživatele v prostředí Termux.

## Požadavky pro vývoj
- **Tasker** (pro import projektu)
- **Tasker App Factory** (pro export APK)
- **Root** (doporučeno pro plnou funkčnost při manipulaci se systémovými soubory)

