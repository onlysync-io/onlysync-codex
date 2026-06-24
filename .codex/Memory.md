# Codex Workspace Memory

## 2026-06-24 - Lokale Runtime-Einschränkungen

- Der Workspace ist nicht vorkonfiguriert mit einem Workspace-Office-Runtime-Bundle.
- Python ist über die normale Konsole aktuell nicht verfügbar.
- Die folgenden Node-Pakete sind aktuell nicht installiert: `mammoth`, `docx`, `xlsx`, `pptxgenjs`, `pdf-parse`.
- Folge für spätere Arbeit: Dokument- und Office-Automation darf nicht als sofort verfügbar angenommen werden und muss vor Nutzung explizit eingerichtet oder ersetzt werden.

## 2026-06-24 - `documents`-Bundle erweitert

- `install_tools` installiert im Bundle `documents` jetzt zusätzlich die Node-Pakete `mammoth`, `docx`, `xlsx`, `pptxgenjs` und `pdf-parse`.
- Das gilt für `global` und `workspace` Mode.
- Hintergrund: Diese Pakete waren im Workspace nicht vorkonfiguriert und sollen gezielt über den Bootstrap installierbar sein.
