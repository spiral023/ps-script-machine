# Connect-MultiVIServer akzeptiert explizites $null als -Credential

Der Parameter `-Credential` von `Connect-MultiVIServer` trägt bewusst
**kein** `[ValidateNotNull()]` mehr (entfernt 2026-07-18). Grund: Das
generierte `InteractiveWrapper.ps1`-Muster übergibt `-Credential
$Credential` immer explizit, auch wenn die Variable (noch) `$null` ist
- in diesem Fall soll `Connect-MultiVIServer` interaktiv per
`Get-Credential` nachfragen statt mit einem Validierungsfehler
abzubrechen. Mit `[ValidateNotNull()]` scheiterte dieser - im Wrapper
nicht ungewöhnliche - Aufrufstil hart, obwohl das gewünschte Verhalten
(interaktive Nachfrage) korrekt implementiert war.

**Status:** akzeptiert.
**Konsequenz:** Wer diese Validierung aus Gewohnheit wieder ergänzt,
bricht den Wrapper-Aufrufstil. Ein Regressionstest dafür existiert in
`tests/Unit/Connect-MultiVIServer.Tests.ps1` ("prompts instead of
throwing when -Credential is explicitly $null").
