# done-alert.ps1
# Completion alarm for Claude Code (wired up as a Stop hook).
# Plays a sound on a loop when Claude finishes, until you press any key
# in the alert window that pops up.
#
# ============================================================
#   EASY SETTINGS  --  edit just this block, nothing else needed
# ============================================================

# 1) Pick a ready-made sound by name:
#       laundry  gentle   alarm   chime   doorbell   fanfare   arcade   siren
#    ("laundry" = the classic Samsung washing-machine done tune, Schubert's Trout)
$Preset = 'laundry'

# 2) (Optional) Write your OWN tune instead. Leave '' to use the preset above.
#    Just list note names separated by spaces. Add ":ms" to set a note's length
#    (default 200). Use "r" for a short silence/rest.
#       Notes:  C D E F G A B  (sharps add #, flats add b)  + octave 3-6
#       Examples:   'C5 E5 G5 C6'        (a simple rise)
#                   'E5:150 G5:150 C6:400'   (with custom lengths)
#                   'A5 r A5 r A5'       (beep ... beep ... beep)
$CustomTune = ''

# 3) (Optional) Play a sound FILE instead of notes -- supports .wav AND .mp3.
#    Drop in any sound you like (e.g. a real laundry alarm). Leave '' to use notes.
#       Example:  'C:\Users\bensu\Music\laundry.mp3'
$SoundFile = ''

# 4) Pause between repeats, in milliseconds. Smaller = more frantic alarm.
$GapMs = 1200

# ============================================================
#   (no need to edit below here)
# ============================================================

$Presets = @{
  laundry  = 'G5:200 G5:200 G5:200 B5:300 A5:200 G5:200 A5:340 r:140 G5:200 G5:200 G5:200 B5:300 D6:300 B5:200 G5:420'
  gentle   = 'D5:170 B4:170 G4:300'
  alarm    = 'A5:150 A5:150 r:90 A5:150 A5:320'
  chime    = 'G5:180 E5:180 C5:380'
  doorbell = 'E5:260 C5:460'
  fanfare  = 'C5:140 E5:140 G5:140 C6:420'
  arcade   = 'E6:90 G6:90 E6:90 C6:90 D6:90 G6:220'
  siren    = 'A5:300 D5:300 A5:300 D5:300'
}

function ConvertTo-Notes([string]$tune) {
  $semis = @{
    'C'=0;'C#'=1;'Db'=1;'D'=2;'D#'=3;'Eb'=3;'E'=4;'F'=5;'F#'=6;'Gb'=6
    'G'=7;'G#'=8;'Ab'=8;'A'=9;'A#'=10;'Bb'=10;'B'=11
  }
  $out = @()
  foreach ($tok in ($tune -split '\s+' | Where-Object { $_ })) {
    $bits = $tok -split ':'
    $name = $bits[0]
    $dur  = if ($bits.Count -gt 1 -and $bits[1] -match '^\d+$') { [int]$bits[1] } else { 200 }
    if ($name -match '^[rR-]$') {            # rest / silence
      $out += ,@(0, $dur)
    }
    elseif ($name -match '^([A-Ga-g])([#b]?)(\d)$') {
      $key  = $matches[1].ToUpper() + $matches[2]
      $semi = $semis[$key]
      if ($null -ne $semi) {
        $midi = ([int]$matches[3] + 1) * 12 + $semi
        $freq = [int][math]::Round(440 * [math]::Pow(2, ($midi - 69) / 12.0))
        $out += ,@($freq, $dur)
      }
    }
  }
  return ,$out
}

function Play-Notes($notes) {
  foreach ($n in $notes) {
    if ($n[0] -ge 37) { [console]::Beep($n[0], $n[1]) }   # 37 Hz = lowest Beep allows
    else { Start-Sleep -Milliseconds $n[1] }              # rest
  }
}

# Always prepare the note fallback (cheap), so we can fall back if a file won't load.
$tune = if ($CustomTune.Trim() -ne '') { $CustomTune }
        elseif ($Presets.ContainsKey($Preset)) { $Presets[$Preset] }
        else { $Presets['gentle'] }
$Notes = ConvertTo-Notes $tune
if (-not $Notes -or $Notes.Count -eq 0) { $Notes = ConvertTo-Notes $Presets['gentle'] }

# Set up Windows Media Player (plays .wav AND .mp3) if a sound file is configured.
$useFile = ($SoundFile -ne '' -and (Test-Path $SoundFile))
$wmp = $null
if ($useFile) {
  try {
    # WinForms gives us a message pump (DoEvents) -- the ActiveX player loads
    # media asynchronously and won't start without one.
    Add-Type -AssemblyName System.Windows.Forms
    $wmp = New-Object -ComObject WMPlayer.OCX
    $wmp.settings.autoStart = $false
    $wmp.settings.volume = 100
    $wmp.URL = (Resolve-Path $SoundFile).Path
  }
  catch { $useFile = $false; $wmp = $null }   # fall back to notes
}

# Single-instance guard: if an alarm is already going, don't stack another window.
$mutex = New-Object System.Threading.Mutex($false, 'Global\ClaudeCodeDoneAlert')
if (-not $mutex.WaitOne(0)) { exit 0 }

try {
  $host.UI.RawUI.WindowTitle = 'Claude finished - press any key to silence'
  Write-Host ''
  Write-Host '  >> Claude finished the task.' -ForegroundColor Green
  Write-Host '  Press any key in this window to silence the alarm.' -ForegroundColor Yellow
  Write-Host ''

  $stopped = $false
  while (-not $stopped) {
    if ($useFile) {
      $wmp.controls.currentPosition = 0
      $wmp.controls.play()
      # Wait for it to actually start (state 3 = Playing), with a short timeout.
      $startBy = (Get-Date).AddSeconds(3)
      while ($wmp.playState -ne 3 -and (Get-Date) -lt $startBy) {
        [System.Windows.Forms.Application]::DoEvents()
        if ([console]::KeyAvailable) { [void][console]::ReadKey($true); $stopped = $true; break }
        Start-Sleep -Milliseconds 60
      }
      # Play through to the end, bailing instantly on a keypress.
      while (-not $stopped -and $wmp.playState -eq 3) {
        [System.Windows.Forms.Application]::DoEvents()
        if ([console]::KeyAvailable) { [void][console]::ReadKey($true); $stopped = $true; break }
        Start-Sleep -Milliseconds 80
      }
      $wmp.controls.stop()
    }
    else {
      Play-Notes $Notes
    }

    if ($stopped) { break }

    # Short, responsive gap between repeats.
    $deadline = (Get-Date).AddMilliseconds($GapMs)
    while ((Get-Date) -lt $deadline) {
      if ([console]::KeyAvailable) { [void][console]::ReadKey($true); $stopped = $true; break }
      Start-Sleep -Milliseconds 80
    }
  }
}
finally {
  if ($wmp) { try { $wmp.controls.stop(); $wmp.close() } catch {} }
  $mutex.ReleaseMutex()
  $mutex.Dispose()
}
