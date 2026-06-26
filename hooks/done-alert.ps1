# done-alert.ps1
# Completion alert for Claude Code (wired up as a Stop hook).
#
# Behavior:
#   1. Plays a jingle.
#   2. Waits up to $WaitSeconds for ANY key press in THIS alert window.
#        - Key pressed  -> stops and closes.
#        - No key in time -> plays the jingle again. Repeats until you press a key.
#
# NOTE: This must run in its own window to capture a keypress. A hook cannot
#       read keys typed into Claude's terminal -- those go to Claude.
#
# CUSTOMIZE:
#   $WaitSeconds -> seconds to wait before nagging again (default 60)
#   $Notes       -> the melody; each note is @(frequencyHz, durationMs)
#                   C5=523 D5=587 E5=659 F5=698 G5=784 A5=880 B5=988 C6=1047 D6=1175

$WaitSeconds = 60

# Gentle default: a soft descending chime in the calm lower-mid range,
# meant to nudge -- not jumpscare -- when you're focused elsewhere.
$Notes = @(
  @(587, 170),   # D5
  @(494, 170),   # B4
  @(392, 300)    # G4 (soft resolve)
)

# Single-instance guard: if an alert is already nagging, don't stack another window.
$mutex = New-Object System.Threading.Mutex($false, 'Global\ClaudeCodeDoneAlert')
if (-not $mutex.WaitOne(0)) { exit 0 }

try {
  $host.UI.RawUI.WindowTitle = 'Claude finished - press any key to silence'
  Write-Host ''
  Write-Host '  >> Claude finished the task.' -ForegroundColor Green
  Write-Host '  Press any key in this window to silence the alert.' -ForegroundColor Yellow
  Write-Host ''

  $stopped = $false
  while (-not $stopped) {
    foreach ($n in $Notes) { [console]::Beep($n[0], $n[1]) }

    $deadline = (Get-Date).AddSeconds($WaitSeconds)
    while ((Get-Date) -lt $deadline) {
      if ([console]::KeyAvailable) {
        [void][console]::ReadKey($true)
        $stopped = $true
        break
      }
      Start-Sleep -Milliseconds 120
    }
  }
}
finally {
  $mutex.ReleaseMutex()
  $mutex.Dispose()
}
