# Modul-Funktionen nehmen VIServer-Sessions entgegen, nicht Server+Credential

Öffentliche Funktionen in `src/ps-script-machine/Public/` erhalten eine
bereits verbundene VIServer-Session über den Parameter `-VIServer`
(siehe `Get-CdpNetworkInfo`), nicht einen Server-String plus
`PSCredential`. Verbindungsaufbau und Mehrfach-vCenter-Handling sind
allein Aufgabe von `Connect-MultiVIServer`; das hält Fachfunktionen
testbar (Mock der Session statt Mock von `Connect-VIServer`) und
verhindert, dass jede Funktion ihre eigene Verbindungslogik mitbringt.

**Status:** akzeptiert.
**Konsequenz:** Ein Wrapper oder eine neue Funktion, die stattdessen
`-Server`/`-Credential` direkt entgegennimmt, weicht von der Konvention
ab und muss selbst verbinden/trennen - vor dem Schreiben neuer
Funktionen prüfen, ob eine Session bereits vorhanden ist statt selbst
zu verbinden.
