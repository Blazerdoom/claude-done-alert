# claude-done-alert

A tiny [Claude Code](https://claude.com/claude-code) hook that **plays a sound when Claude finishes a task** — so you stop forgetting that it's done and waiting on you.

It doesn't just beep once. It plays a short jingle and then **nags every minute until you press a key**, so you'll notice even if you wandered off.

> **Platform:** Windows (uses PowerShell + the Windows `Beep` API). Contributions adding macOS/Linux support are very welcome — see [Contributing](#contributing).

## What it does

When Claude Code stops (finishes responding), a small alert window pops up and:

1. Plays a soft chime.
2. Pauses briefly, then plays again — **looping like an alarm** until you press **any key** in that window.
   - Press a key → the alarm stops and the window closes immediately.

A single-instance guard means you never get a pile of stacked alert windows.

## Install

### Option A — as a Claude Code plugin (recommended)

```
/plugin install claude-done-alert@Blazerdoom
```

(Or add this repo as a marketplace/plugin source, then enable it.)

### Option B — manual

1. Copy `hooks/done-alert.ps1` somewhere, e.g. `C:\Users\<you>\.claude\hooks\done-alert.ps1`.
2. Add this to your `~/.claude/settings.json` (merge with any existing `hooks`):

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell.exe -NoProfile -Command \"Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','C:\\Users\\<you>\\.claude\\hooks\\done-alert.ps1'\"",
            "timeout": 15,
            "async": true
          }
        ]
      }
    ]
  }
}
```

3. Open the `/hooks` menu once (or restart Claude Code) so the new config is picked up.

## Customize

Everything lives in one clearly-marked **EASY SETTINGS** block at the top of `done-alert.ps1` — no need to touch anything else.

| Setting | What it does |
|---------|--------------|
| `$Preset` | Pick a ready-made sound by name: `laundry` (the Samsung washer "done" tune), `gentle`, `alarm`, `chime`, `doorbell`, `fanfare`, `arcade`, `siren`. |
| `$CustomTune` | Write your own tune with plain **note names** — e.g. `'C5 E5 G5 C6'`. Add `:ms` for length (`'E5:150 G5:400'`), use `r` for a rest. Leave `''` to use the preset. |
| `$SoundFile` | Play your own sound **file** instead — supports `.wav` **and** `.mp3`. e.g. `'C:\Users\you\Music\laundry.mp3'`. Leave `''` to use notes. |
| `$GapMs` | Pause between alarm repeats, in milliseconds (default `1200`). Smaller = more frantic. |

Notes are written as `<letter><octave>`, e.g. `C5`, `F#4`, `Bb5` (octaves 3–6). No frequency math required.

### Use your own sound (e.g. a phone alarm tone)

Want a real recording instead of beeps? Save any `.wav` or `.mp3` somewhere stable and point `$SoundFile` at it:

```powershell
$SoundFile = 'C:\Users\you\.claude\hooks\my-alarm.mp3'
```

The clip plays in full, then repeats after `$GapMs` until you press a key. Tip: keep the file in your `~/.claude/hooks/` folder so the path doesn't break if you clean out Downloads.

> Respect copyright — only use audio you have the right to use, and don't commit copyrighted clips to a public repo.

## Why a hook and not a "skill"?

Skills only run when explicitly invoked — they can't react to an event on their own. A **Stop hook** is the part of Claude Code that fires automatically every time Claude finishes. That's the only mechanism that reliably catches "Claude is done."

## Why a separate window?

A hook runs outside Claude's terminal, so it can't read keys you type into Claude — those keystrokes belong to Claude. To support "press any key to stop," the alert opens its own little window that owns its keyboard input.

## Contributing

PRs welcome, especially:

- macOS support (`afplay` / `osascript beep`)
- Linux support (`paplay` / `aplay` / `pactl`)
- A cross-platform launcher that picks the right backend

## License

MIT © 2026 Blazerdoom
