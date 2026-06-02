# Codex Setup

Setup-Skripte fuer macOS und Windows, um eine Arbeitsumgebung fuer Codex, Composio, Remotion, Meta Ads und typische Medien-/Automations-Tools einzurichten.

## Inhalt

- `setup-mac.sh`: Installation ueber Homebrew auf macOS, inklusive macOS-only MCP-Servern.
- `setup-windows.ps1`: Installation ueber `winget`, `npm`, `pip` und Git Bash auf Windows.

## Was installiert wird

Die Skripte installieren bzw. konfigurieren:

- Python 3
- Node.js LTS und npm
- FFmpeg
- ImageMagick
- Ghostscript
- Git bzw. Git Bash
- OpenAI Codex CLI
- Memory MCP Server fuer Codex
- Meta Ads MCP Endpoint fuer Codex
- MarkItDown MCP Server fuer Codex
- Apple Mail MCP Server fuer Codex (nur macOS)
- Apple Music MCP Server fuer Codex (nur macOS)
- Apple Calendar MCP Server fuer Codex (nur macOS)
- ChatGPT Desktop App, sofern unterstuetzt
- pnpm fuer lokale Node-basierte MCP-Server
- Python-Pakete: `holidays`, `pillow`, `rembg`, `markitdown-mcp` (unter macOS in `~/.codex/venvs/python-tools`)
- Composio CLI
- Meta Ads CLI global via `pipx install meta-ads`
- mehrere Codex Skills, unter anderem Remotion-, Composio-, Brand-Guidelines- und Design-Asset-Skills
- Bild- und Vision-Skills: Remove.bg und Google Cloud Vision fuer Face Detection

Am Ende zeigen die Skripte die wichtigsten Versionen an. Danach Codex neu starten, damit neu installierte Skills erkannt werden.

## Windows Setup

### Voraussetzung

Windows braucht `winget`. Falls `winget` fehlt, installiere zuerst **App Installer** aus dem Microsoft Store und starte PowerShell danach neu.

### Skript starten

Oeffne PowerShell im Ordner mit diesem Projekt und fuehre aus:

```powershell
.\setup-windows.ps1
```

Falls Windows meldet, dass PowerShell-Skripte auf deinem System nicht ausgefuehrt werden duerfen, liegt das an der `ExecutionPolicy`. Nutze eine der folgenden Optionen.

### Option A: Nur fuer dieses PowerShell-Fenster erlauben

Empfohlen, wenn du die Policy nur temporaer fuer diese Sitzung umgehen willst:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\setup-windows.ps1
```

Das gilt nur fuer das aktuelle PowerShell-Fenster. Nach dem Schliessen ist die Einstellung wieder weg.

### Option B: Fuer deinen Benutzer dauerhaft erlauben

Ueblich, wenn du lokal haeufig eigene Skripte ausfuehrst:

```powershell
Unblock-File .\setup-windows.ps1
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
.\setup-windows.ps1
```

`RemoteSigned` erlaubt lokale Skripte und verlangt bei aus dem Internet geladenen Skripten eine vertrauenswuerdige Signatur bzw. vorheriges Entsperren.

### Option C: Direkt mit Bypass starten

Praktisch fuer einen einmaligen Lauf ohne vorherige Policy-Aenderung:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\setup-windows.ps1
```

### Sicherheitshinweis

Fuehre `Bypass`, `Unblock-File` oder `RemoteSigned` nur aus, wenn du der Quelle des Skripts vertraust. Wenn du das Skript aus Downloads, einem Chat oder einem fremden Repository bekommen hast, pruefe es vorher.

Zur Diagnose der aktuellen PowerShell-Richtlinien:

```powershell
Get-ExecutionPolicy -List
```

## macOS Setup

Oeffne Terminal im Projektordner und fuehre aus:

```bash
chmod +x ./setup-mac.sh
./setup-mac.sh
```

Falls Homebrew fehlt, installiert das Skript Homebrew automatisch.

## Composio

Das Setup installiert die Composio CLI. Danach in einem neuen Terminal anmelden und pruefen:

```bash
composio login
composio whoami
```

Composio stellt Toolkits fuer externe Dienste bereit, zum Beispiel GitHub, Gmail, Slack, Notion, Google Sheets, Shopify, Google Drive, Supabase und HubSpot. Die aktuelle Liste findest du in den offiziellen Docs:

https://docs.composio.dev/toolkits

Die Setup-Skripte installieren Composio bewusst frisch: Vor dem Installer werden nur das lokale Composio-Binary und die Versionsmarker in `~/.composio` entfernt. Login-, User- und Konfigurationsdateien bleiben erhalten. Das vermeidet lokale Updater-Zustandsfehler, in denen ein alter Binary-Stand mit einem neuen `release-tag.txt` kollidiert. Falls das frisch heruntergeladene Upstream-Binary selbst noch eine alte Version meldet, liegt das am veroeffentlichten Composio-Release und nicht an der lokalen Installation.

Typischer CLI-Workflow:

```bash
composio search "gmail"
composio link gmail
composio execute "<TOOL_SLUG>" -d '{"key":"value"}'
```

In einem Projekt, das Composio per SDK nutzt, zuerst initialisieren:

```bash
composio init
```

## Remotion

Remotion wird normalerweise pro Projekt angelegt. Nach dem Setup kannst du ein neues Remotion-Projekt starten mit:

```bash
npx create-video@latest
```

Docs: https://www.remotion.dev/docs

## Design- und Asset-Skills

Das Setup installiert zusaetzlich zu `ui-ux-pro-max` zwei fokussierte Skills aus `nextlevelbuilder/ui-ux-pro-max-skill`:

- `ckm:design`: fuer Brand Identity, Logos, Icons, CIP-Mockups, Social Media Assets, Google Ads, X/Instagram-Bilder und Design-System-Routing.
- `ckm:banner-design`: fuer mehrformatige Banner, Social Header, Ad-Banner und Website-Hero-Visuals mit Plattformgroessen, Safe Zones und Export-Workflows.

Damit bleiben UI/UX-Entscheidungen, Brand-Assets und konkrete Post-/Banner-Produktion getrennt. Publishing/Scheduling laeuft weiterhin ueber den bereits installierten Postiz-Skill.

## MarkItDown MCP

Das Setup installiert `markitdown-mcp` und traegt den Server in `~/.codex/config.toml` ein. Unter macOS nutzt das Skript dafuer eine eigene virtuelle Umgebung, damit Homebrew Python nicht durch systemweite `pip`-Installationen veraendert wird:

```toml
[mcp_servers.markitdown]
command = "/Users/deinname/.codex/venvs/python-tools/bin/markitdown-mcp"
enabled = true
```

Der Server laeuft als lokaler STDIO-MCP und stellt `convert_to_markdown(uri)` bereit. Damit kann Codex Dateien, Webseiten oder Data-URIs in Markdown umwandeln, sofern der laufende Benutzer darauf Zugriff hat. Nach der Installation Codex neu starten.

## Meta Ads

Das Setup traegt zusaetzlich einen Remote-MCP fuer Meta Ads in `~/.codex/config.toml` ein:

```toml
[mcp_servers.meta_ads]
url = "https://mcp.facebook.com/ads"
```

Damit kann ein kompatibler Codex-/MCP-Client die OAuth-Verbindung zu Meta Ads aufbauen, ohne dass du lokal einen eigenen Meta-Ads-MCP hosten musst. Nach dem Setup Codex neu starten und dann den OAuth-Flow fuer den neuen Server abschliessen, sobald dein Client ihn anbietet.

Das Setup versucht standardmaessig, die Meta Ads CLI global ueber `pipx install meta-ads` zu installieren. Das ist der saubere Weg fuer eine globale Python-CLI auf macOS mit Homebrew-Python, weil `pip install` dort wegen PEP 668 haeufig blockiert wird.

Wichtig: Laut PyPI ist `meta-ads` das offizielle Paket, Release `1.0.1` vom 29. April 2026, mit `Requires: Python >=3.12`. Aktuell sind dort Wheels fuer CPython 3.12 und 3.13 veroeffentlicht. Fuer Apple Silicon ist auf PyPI unter anderem ein `cp313`-Wheel fuer `macOS 11.0+ ARM64` und ein `cp312`-Wheel fuer `macOS 15.0+ ARM64` gelistet. Deshalb installiert das macOS-Setup gezielt `python@3.13` und nutzt fuer `pipx` explizit Python 3.13.

Falls fuer deine Plattform oder Python-Version keine kompatible Distribution verfuegbar ist, ueberspringt das Setup die CLI sauber und laesst den Meta-Ads-MCP-Zugang aktiv. Dieser Check wurde im Projekt zuletzt am 2. Juni 2026 beruecksichtigt.

Als zusaetzliche externe Einordnung kannst du auch diesen Guide lesen:

https://www.get-ryze.ai/blog/meta-cli-command-line-tool-for-meta-ads-automation

Wichtig: Der Ryze-Artikel vom 9. Mai 2026 ist eine Drittquelle, keine offizielle Meta-Dokumentation. Er ist nuetzlich fuer Workflows, Beispielkommandos und AI-Agent-Ideen, nutzt bei der Installation aber teilweise andere Bezeichnungen als unser offizieller Setup-Pfad. Fuer dieses Projekt bleiben deshalb die offizielle Meta-Doku und das offizielle PyPI-Paket `meta-ads` die Referenz.

macOS:

```bash
chmod +x ./setup-mac.sh
./setup-mac.sh
```

Windows:

```powershell
.\setup-windows.ps1
```

Wenn die CLI-Installation fehlschlaegt, bleibt der MCP-Eintrag trotzdem erhalten. In dem Fall kannst du Ads bereits ueber den MCP-Weg verbinden und spaeter erneut pruefen, ob Meta die CLI in deiner Umgebung freigibt oder den Installationspfad aendert.

## macOS-only MCP Server

Auf macOS installiert das Setup zusaetzlich Apple Mail MCP, Apple Music MCP und Apple Calendar MCP unter `~/.codex/mcp/` und traegt sie in `~/.codex/config.toml` ein. Das Skript schreibt dabei absolute Pfade; sinngemaess sieht die Config so aus:

```toml
[mcp_servers.apple_mail]
command = "/Users/deinname/.codex/mcp/apple-mail-mcp/venv/bin/mcp-apple-mail"
enabled = true

[mcp_servers.apple_music]
command = "/Users/deinname/.codex/mcp/applemusic-mcp/venv/bin/python"
args = ["-m", "applemusic_mcp"]
enabled = true

[mcp_servers.apple_calendar]
command = "/Users/deinname/.codex/mcp/apple-calendar-mcp/run-apple-calendar-mcp.sh"
enabled = true
```

Apple Mail MCP braucht Apple Mail mit eingerichteten Accounts und macOS-Berechtigungen fuer Automation bzw. Mail-Zugriff. Der Server kann E-Mails lesen, suchen, verschieben, Entwuerfe erstellen und senden. Fuer reinen Lesezugriff kann in der Config bei `apple_mail` optional `args = ["--read-only"]` ergaenzt werden.

Apple Music MCP braucht die Apple Music App und fuer viele Workflows ein Apple-Music-Abo. Die lokalen macOS-Funktionen laufen per AppleScript; Katalogsuche und Empfehlungen koennen optional ueber MusicKit in `~/.config/applemusic-mcp/config.json` eingerichtet werden. Nach der Installation Codex neu starten und die macOS-Berechtigungsdialoge beim ersten Zugriff erlauben.

Apple Calendar MCP braucht macOS 12+, Node.js und eine lokale Swift/EventKit-Bridge. Das Setup klont `shadowfax92/apple-mcp-api-bridge`, baut `MacAPIBridge` mit Swift und klont/buildet `shadowfax92/apple-calendar-mcp`. Der Codex-MCP startet ueber einen Wrapper, der die Bridge auf Port `8080` bei Bedarf mitstartet. Falls Swift fehlt, installiere die Xcode Command Line Tools mit `xcode-select --install` und fuehre das Setup erneut aus. Beim ersten Zugriff muss macOS Calendar-Berechtigungen erlauben.

## Outlook MCP

Der verlinkte `marlonluo2018/outlook-mcp-server` ist fuer **Windows** gedacht, nicht fuer macOS. Er nutzt `win32COM`/`pywin32`, verarbeitet Outlook-Daten lokal und braucht Microsoft Outlook 2016+ als laufende Desktop-App sowie Windows 10+. Fuer macOS oder einen gemeinsamen macOS/Windows-Ansatz ist stattdessen ein Microsoft-Graph-basierter MCP sinnvoller; der ist plattformuebergreifend, braucht aber Microsoft-365/OAuth und arbeitet ueber die Cloud.

## Nach dem Setup

1. Terminal bzw. PowerShell neu starten.
2. Codex neu starten, damit Skills und MCP-Konfiguration geladen werden.
3. Optional pruefen:

```bash
codex --version
node --version
npm --version
composio whoami
```
