# Argus

> Keep your Mac awake while AI agents do the work — even with the lid closed.

**Status:** Pre-alpha. No public release yet.

## What it does

Start a long-running task — typically an AI coding agent like Claude Code or Cursor — close the lid, walk away. Argus keeps your Mac awake until the task finishes, then puts it back to sleep and notifies you.

The closest existing tool is [Lungo](https://sindresorhus.com/lungo). Argus differs in two ways:

- **Closed-lid operation on battery, with no external display required.** Lungo, Caffeine, and Amphetamine all need either an external display or AC power for closed-lid operation — that's an App Store sandbox restriction. Argus ships outside the App Store specifically to bypass it.
- **Process-aware.** Argus watches a specific command or PID — your AI agent — and goes back to sleep automatically when that process exits. No fixed timer, no manual toggle.

## Why "Argus"?

In Greek mythology, **Argus Panoptes** was a hundred-eyed giant who never slept. Hera assigned him to watch over Io. Your Mac will watch over your AI agent the same way.

## Planned features (MVP)

- **Closed-lid wake** on battery, no external display required.
- **Process watcher** in three modes:
  - `argus run -- <command>` — start and watch a command directly.
  - **Attach** — pick a running process from a preset list (`claude`, `cursor-agent`, `codex`, `aider`, …) or any custom PID.
  - **Manual** — toggle on, optional max-duration timeout.
- **Auto-protect** — automatic sleep on low battery or rising thermal pressure.
- **Notifications** — local notification on completion; optional shell hook for arbitrary push services (ntfy, Pushover, iMessage, …).
- **Menu bar UI kept dead simple.** Power features live in the CLI and a config file.

## Requirements

- macOS 13 (Ventura) or later
- Apple Silicon Mac (M1 or later)

Intel Macs are not supported. Closed-lid operation has different thermal characteristics on Intel, and we'd rather not ship a half-working experience.

## How it works

```
  Menu bar app ─┐
                ├── XPC ──→ argusd (LaunchDaemon, root) ──→ pmset / IOPMAssertion
  argus CLI    ─┘
```

A small privileged helper (`argusd`) is registered as a `LaunchDaemon` via Apple's [`SMAppService`](https://developer.apple.com/documentation/servicemanagement/smappservice). The helper is the only component that touches power management — the menu bar app and the CLI talk to it over XPC.

That helper, running as root, is what enables closed-lid operation on battery. The trade-off: you install Argus like any non-App Store app (drag to Applications) and approve the helper once in **System Settings → Login Items & Extensions**.

### Safety

Closed-lid operation reduces airflow. Argus auto-suspends if battery falls below a configurable threshold or thermal pressure exceeds a safe level. Defaults are conservative; you can tune them in the config file but not below safe minimums.

## License

[MIT](LICENSE).

## Credits

Heavily inspired by [Lungo](https://sindresorhus.com/lungo) by Sindre Sorhus.
