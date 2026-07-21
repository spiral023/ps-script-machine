# Keine Wrapper-Skripte im Repo-Root

Ausführbare Wrapper-Skripte leben ausschließlich in `scripts/tools/`,
nie im Repo-Root. Der Root-Wrapper `Get-CdpNetworkInfo.ps1` (legacy,
rief zudem eine private Modul-Funktion direkt auf, siehe
[[0002-wrapper-nutzen-nur-oeffentliche-connect-funktion]]) wurde am
2026-07-18 entfernt, da er außerhalb der in `AGENTS.md` definierten
Verzeichnisstruktur lag und bereits vollständiger durch
`scripts/tools/Export-CdpInformation.ps1` abgedeckt war.

**Status:** akzeptiert.
**Konsequenz:** Ein neuer Wrapper gehört immer nach `scripts/tools/`
und entsteht aus `templates/InteractiveWrapper.ps1` (siehe
`script-werkstatt`-Skill) - nicht als eigenständiges Skript im Root.
