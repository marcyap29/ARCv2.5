# Ollama: Address Already in Use & Unknown "quit" Command

Date: 2026-02-13  
Status: Open (environment / tooling)  
Area: Environment, Ollama, local LLM  
Severity: Low

## Summary
When running `OLLAMA_HOST=0.0.0.0 ollama serve`, the command failed because port 11434 was already in use. Attempting to stop the existing server with `ollama quit` failed with "unknown command \"quit\" for \"ollama\"".

## Errors (from terminal)
```
OLLAMA_HOST=0.0.0.0 ollama serve
Error: listen tcp 0.0.0.0:11434: bind: address already in use

ollama quit
Error: unknown command "quit" for "ollama"
```

## Impact
- Cannot start a second Ollama server on the same host without freeing the port.
- Unclear how to stop the existing Ollama process from the CLI (e.g. before changing `OLLAMA_HOST` or restarting the service).

## How to fix

1. **Free port 11434 so a new server can bind:**
   - List what is using the port: `lsof -i :11434`
   - Kill that process: `kill $(lsof -t -i :11434)` (macOS/Linux), or note the PID from `lsof` and run `kill <PID>`.

2. **Stop the existing Ollama server** (choose one that matches your setup):
   - **If Ollama was installed as an app:** Quit Ollama from the menu bar icon or Dock (e.g. right‑click → Quit).
   - **If running as a CLI process:** Run `pkill ollama` to stop all Ollama processes.
   - **Check CLI help:** Run `ollama --help` (or `ollama -h`) and look for a stop/quit/server command; the exact subcommand may differ by version.

3. **Start serve again (optional):** After the port is free, run `OLLAMA_HOST=0.0.0.0 ollama serve` if you need the server listening on all interfaces.

## Workarounds (summary)
- Free port: `kill $(lsof -t -i :11434)` (macOS).
- Stop server: quit the app, or `pkill ollama`, or see `ollama --help` for the current stop command.

## Recommendations
- Document in project or team runbooks: how to stop Ollama and how to free port 11434 when needed.
- Verify current Ollama CLI subcommands (e.g. `ollama --help`) for the installed version and document the correct stop/quit command.

## References
- Terminal log: 2026-02-13 (EPI / ARC MVP)
- Ollama: https://github.com/ollama/ollama (CLI and docs)
