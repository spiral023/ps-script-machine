# Skript-Werkstatt – Nutzen und Funktionsweise

> Ein Überblick für VMware-Administratoren und Entscheider: Was das System leistet,
> wie es sich im Alltag anfühlt, welche Qualitätsstandards es garantiert – und warum
> dasselbe Muster auch außerhalb von VMware funktioniert.

---

## Kurzfassung

- **Ein Administrator beschreibt sein Werkzeug in normalem Deutsch** – nicht in Code.
  Der KI-Agent stellt Rückfragen in VMware-Fachsprache und liefert ein fertiges,
  geprüftes PowerShell-Skript.
- **Die Qualität ist nicht Glückssache, sondern erzwungen.** Sicherheits-, Betriebs-
  und Dokumentationsregeln sind schriftlich fixiert und werden bei der Vollvariante
  automatisiert nachgeprüft (Analyzer, Tests, ≥ 80 % Testabdeckung, Secret-Scan).
- **Zwei Ausbaustufen**: die *Vollvariante* im Repository für dauerhaft gepflegte
  Werkzeuge, die *Light-Variante* für schnelle Einzelskripte ohne jede Installation.
- **Die Light-Variante ist portabel.** Sie liegt als fertiges Paket vor
  (`packages/skills/powershell-skript-werkstatt-light.skill` / `.zip`) und lässt sich
  auch in ChatGPT als Skill importieren – dieselben Regeln, dieselbe Ergebnisqualität,
  ohne Zugriff auf das Repository.
- **Das Muster ist übertragbar.** Die Struktur „schriftliche Regelbasis + geführter
  Prozess + Vorlagen + automatische Prüfung" ist nicht VMware-spezifisch. Sie
  funktioniert genauso für SQL-Entwicklung, Active Directory, M365 oder Netzwerk.

---

## Das Problem, das gelöst wird

Automatisierungsskripte entstehen in vielen Betrieben nebenbei: schnell
zusammengeschrieben, auf einem einzigen Rechner erprobt, mit dem Servernamen fest im
Code, ohne Dokumentation, ohne Vorschau vor der Änderung, ohne Test. Sie funktionieren –
bis jemand anderes sie braucht, bis sie unbeaufsichtigt als Dienstkonto laufen sollen
oder bis sie im falschen Cluster etwas verändern.

Dazu kommt: Wer die Skripte gebraucht hätte – der Admin mit dem Fachwissen – kann sie
oft nicht selbst schreiben. Und wer sie schreiben kann, kennt die Umgebung nicht gut
genug.

Genau diese Lücke schließt das System: **Fachwissen beschreibt, der Agent baut, die
Regelbasis garantiert die Qualität.**

---

## So läuft es in der Praxis

### Schritt 1 – Der Wunsch in eigenen Worten

> „Schreibe ein Skript, das die CDP-Daten aller ESXi-Netzwerkinterfaces von allen Hosts
> aus einem oder mehreren vCentern ausliest und als CSV speichert."

Kein Parametertyp, keine Funktionssignatur, keine Zeile Code.

### Schritt 2 – Das geführte Interview

Der Agent fragt nach – **eine Frage pro Nachricht, immer mit sinnvollem Standardwert**,
und ausschließlich in Begriffen, die ein VMware-Admin täglich benutzt:

| Was gefragt wird | Warum es wichtig ist |
| --- | --- |
| Alle Hosts oder gefiltert (Cluster, Name)? Auch Hosts im Wartungsmodus? | Verhindert, dass das Ergebnis am eigentlichen Bedarf vorbeigeht |
| CSV, JSON oder beides? Welcher Ablageort? Welche Spalten? | Legt das Ergebnisformat vorab fest, statt es nachträglich zu reparieren |
| Wenn ein Host nicht antwortet: weitermachen und am Ende ausweisen, oder abbrechen? | Ein einzelner unerreichbarer Host darf keinen Auswertungslauf über 200 Hosts zerstören |
| Interaktiv am Admin-Rechner oder unbeaufsichtigt (Scheduled Task, Softwareverteilung)? Unter welchem Konto? | Ein Skript, das den Desktop des angemeldeten Benutzers erwartet, scheitert als Dienstkonto oder unter SYSTEM |
| Reicht die Laufzusammenfassung, oder ist ein vollständiges Transcript nötig? | Transcripts enthalten potenziell sensible Daten – das wird bewusst entschieden, nicht versehentlich |
| Nur bei verändernden Skripten: Bestätigung pro Objekt oder einmal pro Lauf? | Legt die Sicherheitsschwelle fest, bevor etwas verändert wird |

### Schritt 3 – Die Freigabe

Vor dem Bauen fasst der Agent in wenigen Sätzen zusammen, was entstehen wird:
Geltungsbereich, Ausgabeformat und -ort, Verhalten bei Fehlern, Betriebsprofil,
Protokollierung, Exitcodes.

**Diese Zusammenfassung ist die Vertragsstelle.** Erst nach ausdrücklicher Bestätigung
wird gebaut – und am Ende wird das Ergebnis Satz für Satz gegen genau diese Zusage
geprüft. Jede Abweichung, auch eine gut gemeinte Zusatzspalte, muss behoben oder
abgestimmt werden.

### Schritt 4 – Bauen, Prüfen, Übergeben

Der Agent erzeugt Fachlogik, Bedienoberfläche und Tests aus geprüften Vorlagen, lässt
den vollständigen Build durchlaufen und **behebt Build-Fehler selbst** – davon sieht der
Administrator nichts. Übergeben wird mit einer kurzen deutschen Anleitung: wo das Skript
liegt, wie man es startet, was es fragt, wo die Ausgabe landet, welche Exitcodes ein
automatischer Aufrufer auswerten kann.

### Schritt 5 – Weitergeben

Der Build bündelt jedes Werkzeug zusätzlich zu einer **eigenständigen Einzeldatei**
(`build/standalone/`). Die läuft auf jedem Rechner mit PowerShell 7.4 und PowerCLI –
ohne Repository, ohne Modulinstallation. Ein Kollege bekommt eine Datei und kann
arbeiten.

---

## Die zwei Ausbaustufen

|  | **Vollvariante** (Repository) | **Light-Variante** (Skill-Paket) |
| --- | --- | --- |
| **Ergebnis** | Modul-Funktion + Bedienoberfläche + Tests + Dokumentation | Eine einzelne, eigenständige `.ps1`-Datei |
| **Voraussetzungen** | Repository, Pester, PSScriptAnalyzer, Build | Keine – nur PowerShell selbst |
| **Qualitätsprüfung** | Automatisiert: Analyzer, Pester-Tests, ≥ 80 % Abdeckung, Secret-Scan | Selbstprüfung mit Bordmitteln: Syntax-Parser, Trockenlauf mit `-WhatIf`, Grenzfälle von Hand durchgespielt, Checkliste |
| **Ideal für** | Werkzeuge, die bleiben und wachsen | Der konkrete Einzelfall, der heute gebraucht wird |
| **Domäne** | VMware / vSphere | Domänenneutral: Dateisystem, AD, Netzwerk, Cloud, Datenbanken, REST-APIs, VMware |
| **Wo nutzbar** | Claude Code / Copilot im Repository | Claude Code **und ChatGPT** (Skill-Import) |

Entscheidend: **Die Light-Variante senkt die Einstiegshürde, nicht den Anspruch.** Ohne
Testframework gelten dieselben Sicherheitsregeln, dieselbe Struktur, derselbe
Betriebsvertrag. Was wegfällt, ist die Werkzeugkette – nicht die Sorgfalt. Der Skill
benennt diese Versuchung ausdrücklich als Warnsignal: „Kein Pester installiert, dann
spar ich mir auch die Sorgfalt" ist keine erlaubte Abkürzung.

### Import in ChatGPT

Das fertige Paket liegt im Repository bereit:
`packages/skills/powershell-skript-werkstatt-light.zip`. Es wird in ChatGPT als Skill
hochgeladen und steht danach in jeder Unterhaltung zur Verfügung. Damit können auch
Kollegen ohne Repository-Zugang und ohne Entwicklungsumgebung Skripte nach Hausstandard
erzeugen – der Standard reist im Paket mit.

---

## Was das für die Qualität konkret bedeutet

Die Regeln sind keine Empfehlung in einem Wiki, sondern schriftlich fixierte Vorgaben
(`AGENTS.md`), an die jeder KI-Agent gebunden ist. Der Betriebs- und Laufzeitvertrag ist
aus den RAITEC-Betriebsvorgaben abgeleitet und wird durch eigene Vertragstests
abgesichert.

### Sicherheit

| Regel | Was sie verhindert |
| --- | --- |
| Keine fest codierten Zugangsdaten – `PSCredential` und `SecretManagement` | Passwörter im Skript, die per Dateifreigabe oder Git weiterwandern |
| Keine Klartextpasswörter, keine Secrets in Logs | Zugangsdaten, die über Protokolldateien abfließen |
| `Invoke-Expression` verboten | Die häufigste Einladung zur Codeeinschleusung in PowerShell |
| Keine fest codierten Servernamen, IP-Adressen, Umgebungspfade | Skripte, die nur auf dem Rechner ihres Erfinders funktionieren |
| Zertifikatsprüfung nie stillschweigend deaktivieren | Unbemerkt aufgeweichte Transportsicherheit |
| Least Privilege – benötigte vCenter-Rechte dokumentiert | Automatisierung, die aus Bequemlichkeit mit Administratorrechten läuft |
| Secret-Scan als Teil des Builds | Dass eine dieser Regeln unbemerkt gebrochen wird |

### Betrieb und Nachvollziehbarkeit

| Regel | Nutzen im Alltag |
| --- | --- |
| Betriebsprofil vorab geklärt (interaktiv/unbeaufsichtigt, Konto, Verteilweg, Arbeitsverzeichnis, Proxy, Exitcodes) | Das Skript funktioniert auch dort, wo es später wirklich läuft – nicht nur in der Admin-Sitzung |
| Abhängigkeits-Vorprüfung (PowerShell- und PowerCLI-Mindestversion) vor der Fachlogik | Eine verständliche Meldung statt eines Absturzes mitten im Lauf |
| Genau ein äußerer Lebenszyklus und genau ein Ausstiegspunkt | Verbindungen und Protokolle werden auch im Fehlerfall zuverlässig geschlossen |
| Definierter Exitcode-Vertrag (`0` Erfolg/behandelter Teilerfolg, `1` fataler Fehler) | Softwareverteilung und Aufgabenplanung können das Ergebnis maschinell auswerten |
| Laufzusammenfassung mit `RunId`, UTC-Start/Ende, Dauer, Status, Zählwerten und erzeugten Dateien | „Was ist gestern Nacht gelaufen?" ist in Sekunden beantwortet |
| Transcripts nur auf Wunsch, ausdrücklich als sensibel gekennzeichnet | Kein versehentliches Weitergeben von Konsoleninhalten |
| Log-Aufräumung nur im werkzeugeigenen Verzeichnis | Kein Skript, das allgemeine Log- oder Benutzerordner rekursiv leert |

### Verändernde Eingriffe – die wichtigste Schutzschicht

Lesende und verändernde Werkzeuge werden strikt getrennt. Jedes verändernde Skript
bekommt verpflichtend:

- **Vorschau-Lauf (`-WhatIf`)** – zeigen, was passieren *würde*, ohne etwas zu tun.
  Nicht optional, unabhängig vom Zeitdruck.
- **Bestätigung (`-Confirm`)** – pro Objekt oder einmal pro Lauf, wie vereinbart.
- **Vorprüfung** – existiert das Ziel, ist es erreichbar, ist es im erwarteten Zustand?
- **Eindeutige Zielvalidierung** – nie „irgendein passendes Objekt" treffen.
- **Nachprüfung** – hat die Änderung tatsächlich gewirkt, nicht nur „kein Fehler
  gemeldet"?
- **Vorher-/Nachher-Werte im Ergebnis** – sichtbar, was sich geändert hat, ohne
  Logdatei.
- **Idempotenz** – ein zweiter Lauf ändert nichts mehr und sagt das auch.

### Verständlichkeit und Wissenstransfer

Vollständige eingebaute Hilfe (Zweck, Beschreibung, jeder Parameter, Beispiele,
Rückgabe, benötigte Rechte), einheitliche Namens- und Formatierungsregeln, strukturierte
Ergebnisobjekte statt formatierter Textausgabe, und eine saubere Trennung der vier
Ausgabekanäle: Ergebnis, Diagnose, Export, Protokoll.

**Wirkung**: Jedes Skript ist auch für den Kollegen lesbar, der es nicht gebaut hat.
Die Ergebnisse sind maschinell weiterverwendbar – sie lassen sich sortieren, filtern und
in Berichte übernehmen, statt nur „schön auszusehen".

### Nachvollziehbare Herkunft

Keine handgepflegte Versionshistorie im Skriptkopf – Git ist die Historie.
Architekturentscheidungen sind einzeln dokumentiert, damit ein späterer Agent eine
bewusst getroffene Entscheidung nicht versehentlich zurückdreht. Änderungen landen
verpflichtend im Changelog.

---

## Warum das Muster über VMware hinaus trägt

Der eigentliche Wert liegt nicht in den PowerCLI-Funktionen, sondern in der
**Architektur des Vorgehens**. Sie besteht aus vier Bausteinen:

1. **Eine schriftliche Regelbasis** – eine Quelle je Thema, verbindlich, versioniert.
2. **Ein geführter Prozess** – Einordnen, Interview, Freigabe, Bauen, Prüfen, Übergeben.
3. **Geprüfte Vorlagen** – der Startpunkt ist schon regelkonform.
4. **Automatische Prüfpunkte** – was zählt, wird gemessen und blockiert im Fehlerfall.

Keiner dieser vier Bausteine ist an VMware gebunden. Nur die *Inhalte* wechseln:

| Baustein | VMware / PowerCLI (heute) | SQL-Entwicklung (Beispiel) |
| --- | --- | --- |
| Fachsprache im Interview | Hosts, Cluster, Portgroups, Datastores | Tabellen, Indizes, Ausführungspläne, Migrationen |
| Kernregeln | Explizite Serverübergabe, kein globaler Standard-vCenter | Kein `SELECT *`, explizite Transaktionsgrenzen, parametrisierte Abfragen statt Zeichenkettenverkettung |
| Schutz vor Eingriffen | Vorschau-Lauf, Vorher-/Nachher-Werte | Trockenlauf des Migrationsskripts, Rückrollplan, Wirkungsabschätzung vor dem Ausrollen |
| Prüfpunkte | PSScriptAnalyzer, Pester, Abdeckung, Secret-Scan | SQL-Linter, Datenbank-Unittests, Migrationsprüfung in der Pipeline |
| Ergebnis | Modul-Funktion + Bedienoberfläche + Einzeldatei | Versioniertes Migrationsskript + Test + Rückrollpfad |

Die Light-Variante ist dabei bereits heute ausdrücklich domänenneutral gebaut –
Dateisystem, Active Directory, Netzwerk, Cloud, **Datenbanken** und REST-APIs sind
gleichwertig abgedeckt. Für eine eigene Fachdomäne braucht es keinen Neubau, sondern
eine fachspezifische Regelbasis nach demselben Schema.

**Für Entscheider heißt das**: Die Investition liegt im Muster, nicht im Einzelfall.
Was hier für VMware aufgebaut wurde, ist die Vorlage für jedes weitere Team, das
Automatisierung nach Hausstandard braucht.

---

## Was das System nicht ist

Fairness gehört zur Bewertung dazu:

- **Kein Ersatz für Fachwissen.** Der Agent stellt die richtigen Fragen – die richtigen
  Antworten kommen aus der Umgebungskenntnis des Administrators.
- **Kein Ersatz für Abnahme.** Die Freigabe in der Zusammenfassung und ein Testlauf in
  einer nicht produktiven Umgebung bleiben Aufgabe des Menschen.
- **Die Light-Variante baut keine Modularchitektur.** Wer ein gepflegtes Modul mit
  mehreren Dateien braucht, nutzt die Vollvariante – das ist ausdrücklich so gewollt.
- **Voraussetzungen bleiben Voraussetzungen.** PowerShell 7.4 und PowerCLI 13.2 müssen
  vorhanden sein; für VMware gilt vCenter/ESXi 7.0 oder 8.0.

---

## Der Einstieg

**Als VMware-Admin, sofort:** Beschreiben, was gebraucht wird. In eigenen Worten, in
einem Satz. Die Fragen kommen von selbst.

**Als Team ohne Repository:** `packages/skills/powershell-skript-werkstatt-light.zip`
in ChatGPT als Skill importieren – der Hausstandard ist damit verfügbar.

**Als Entscheider:** Das Muster auf eine zweite Domäne anwenden. Die Regelbasis in
`AGENTS.md` ist die Vorlage, der geführte Prozess bleibt identisch, nur Fachsprache und
Prüfpunkte werden ausgetauscht.

---

*Weiterführend: `AGENTS.md` (Regelbasis), `README.md` (Installation und Nutzung),
`docs/ARCHITECTURE.md` (Architektur), `SECURITY.md` (Sicherheitsrichtlinie).*
