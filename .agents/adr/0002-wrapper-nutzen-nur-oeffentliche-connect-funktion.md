# Wrapper rufen ausschließlich die öffentliche Connect-MultiVIServer auf

Skripte in `scripts/tools/` und `examples/` verbinden sich immer über
die exportierte `Connect-MultiVIServer`, niemals über die private
Helper-Funktion `Connect-VIServerSession`. Ein direkter Aufruf der
privaten Funktion von außerhalb des Moduls scheitert zur Laufzeit mit
"term not recognized", da Private-Funktionen nicht exportiert werden -
das wurde am 2026-07-18 in `Get-CdpNetworkInfo.ps1` (Root-Legacy-Wrapper,
seither entfernt) und `examples/Get-CdpInfoExample.ps1` als kaputter
Aufruf gefunden und auf `Connect-MultiVIServer` umgestellt.

**Status:** akzeptiert.
**Konsequenz:** Neue Wrapper/Beispiele imitieren `Connect-MultiVIServer`
(liefert ein Objekt mit `.Sessions`-Array), nicht die private Funktion.
Bei einem "term not recognized"-Fehler in einem Wrapper zuerst prüfen,
ob eine Private-Funktion direkt statt der öffentlichen aufgerufen wird.
