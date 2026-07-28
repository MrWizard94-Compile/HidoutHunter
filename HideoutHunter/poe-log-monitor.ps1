# PoE Hideout Hunter - Instant Hideout Spawn Detection
# ====================================================
# Watches Client.txt for "Spawning discoverable Hideout" messages.
# Shows a TopMost overlay alert on your screen when one spawns.
#
# Usage: Double-click Start-PoE-Monitor.bat

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$LogPath = "C:\Program Files (x86)\Steam\steamapps\common\Path of Exile\logs\Client.txt"

# ============================================================
# STATE
# ============================================================
$Script:CurrentMap = ""
$Script:WaitingForHideoutCheck = $false
$Script:MapEntryTime = $null
$Script:HideoutSpawnDetected = $false
$Script:RunCount = 0

# ============================================================
# HIDEOUT ID -> DISPLAY NAME (from actual log data)
# ============================================================
$HideoutNames = @{
    "HideoutForest"       = "Arboreal Hideout"
    "HideoutSewer"        = "Baleful Hideout"
    "HideoutMine"         = "Skeletal Hideout"
    "HideoutCourts"       = "Stately Hideout"
    "HideoutCoral"        = "Coral Hideout"
    "HideoutRuinedTemple" = "Celestial Hideout"
    "HideoutBaths"        = "Sunken Hideout"
    "HideoutOasis"        = "Desert Hideout"
    "HideoutOssuary"      = "Cathedral Hideout"
    "HideoutLava"         = "Lava Hideout"
    "HideoutGlacier"      = "Glacial Hideout"
    "HideoutOvergrown"    = "Overgrown Hideout"
    "HideoutTropical"     = "Tropical Island Hideout"
    "HideoutImmaculate"   = "Immaculate Hideout"
}

# Internal area IDs for maps that can contain discoverable hideouts
# Mapped from "Generating level XX area "MapWorldsXXX"" log lines
$HideoutMapIds = @{
    "MapWorldsTerrace"          = "Terrace"
    "MapWorldsHauntedMansion"   = "Haunted Mansion"
    "MapWorldsDesertSpring"     = "Desert Spring"
    "MapWorldsBoneCrypt"        = "Bone Crypt"
    "MapWorldsSunkenCity"       = "Sunken City"
    "MapWorldsCoralRuins"       = "Coral Ruins"
    "MapWorldsLavaChamber"      = "Lava Chamber"
    "MapWorldsBasilica"         = "Basilica"
    "MapWorldsGlacier"          = "Glacier"
    "MapWorldsOvergrownShrine"  = "Overgrown Shrine"
    "MapWorldsPrimordialPool"   = "Primordial Pool"
    "MapWorldsTropicalIsland"   = "Tropical Island"
    "MapWorldsMoonTemple"       = "Moon Temple"
    "MapWorldsIvoryTemple"      = "Ivory Temple"
}

# ============================================================
# OVERLAY ALERT (TopMost window over game)
# ============================================================
function Show-Overlay {
    param (
        [string]$Text,
        [string]$Urgency = "Normal",
        [int]$DurationMs = 5000
    )

    Start-Job -ArgumentList $Text, $Urgency, $DurationMs -ScriptBlock {
        param ($Text, $Urgency, $DurationMs)

        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $Form = New-Object System.Windows.Forms.Form
        $Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
        $Form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
        $Form.TopMost = $true
        $Form.ShowInTaskbar = $false

        $Screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
        $Form.Width = 600
        $Form.Left = [Math]::Floor(($Screen.Width - $Form.Width) / 2)
        $Form.Top = 40

        if ($Urgency -eq "Critical") {
            $Form.BackColor = [System.Drawing.Color]::FromArgb(0, 160, 0)
            $FontColor = [System.Drawing.Color]::White
            $Form.Height = 120
            $FontSize = 18
        } else {
            $Form.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
            $FontColor = [System.Drawing.Color]::FromArgb(220, 220, 220)
            $Form.Height = 60
            $FontSize = 13
        }

        $Form.Opacity = 0.93

        $Label = New-Object System.Windows.Forms.Label
        $Label.Text = $Text
        $Label.ForeColor = $FontColor
        $Label.Font = New-Object System.Drawing.Font("Segoe UI", $FontSize, [System.Drawing.FontStyle]::Bold)
        $Label.AutoSize = $false
        $Label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $Label.Dock = [System.Windows.Forms.DockStyle]::Fill

        $Form.Controls.Add($Label)

        $Timer = New-Object System.Windows.Forms.Timer
        $Timer.Interval = $DurationMs
        $Timer.Add_Tick({ $Form.Close() })
        $Timer.Start()

        $Form.Add_Click({ $Form.Close() })
        $Label.Add_Click({ $Form.Close() })

        [System.Windows.Forms.Application]::Run($Form)
    } | Out-Null
}

# ============================================================
# PROCESS A SINGLE LINE
# ============================================================
function Process-Line {
    param ([string]$Line)

    $Timestamp = Get-Date -Format "HH:mm:ss"

    # HIDEOUT SPAWN DETECTION
    if ($Line -match "Spawning discoverable Hideout") {
        $Script:HideoutSpawnDetected = $true
        $Script:WaitingForHideoutCheck = $false

        Write-Host ""
        Write-Host "  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Green
        Write-Host "  !!   HIDEOUT SPAWNED IN THIS MAP!             !!" -ForegroundColor Green
        Write-Host "  !!   GO FIND THE ENTRANCE!                    !!" -ForegroundColor Green
        Write-Host "  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Green
        Write-Host ""

        Show-Overlay -Text "HIDEOUT SPAWNED!`nGO FIND THE ENTRANCE!" -Urgency "Critical" -DurationMs 15000
        [Console]::Beep(1000, 300); [Console]::Beep(1500, 300); [Console]::Beep(2000, 500)
        return
    }

    # MAP GENERATION DETECTION (from "Generating level XX area "MapWorldsXXX"")
    if ($Line -match 'Generating level \d+ area "(.+?)"') {
        $AreaId = $Matches[1]

        # Check if this is a hideout-capable map
        if ($HideoutMapIds.ContainsKey($AreaId)) {
            $MapName = $HideoutMapIds[$AreaId]
            $Script:CurrentMap = $MapName
            $Script:HideoutSpawnDetected = $false
            $Script:WaitingForHideoutCheck = $true
            $Script:MapEntryTime = Get-Date
            $Script:RunCount++

            Write-Host "[$Timestamp] Run #$($Script:RunCount) - Entered $MapName. Watching for hideout..." -ForegroundColor Yellow
            return
        }

        # Entered hideout or town — reset state
        if ($Script:CurrentMap -ne "") {
            if ($AreaId -match "^Hideout" -or $AreaId -match "^Town") {
                $Script:WaitingForHideoutCheck = $false
                $Script:CurrentMap = ""
            }
        }

        Write-Host "[$Timestamp] Zone: $AreaId" -ForegroundColor DarkGray
    }
}

# ============================================================
# MAIN
# ============================================================

if (-not (Test-Path $LogPath)) {
    Write-Host "ERROR: Client.txt not found at: $LogPath" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Clear-Host
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "   PoE Hideout Hunter - Spawn Detection" -ForegroundColor White
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Enter a map -> instant hideout check." -ForegroundColor Gray
Write-Host "  SPAWNED = GREEN OVERLAY + BEEP" -ForegroundColor Green
Write-Host "  Nothing = leave & rerun (5 sec)" -ForegroundColor Red
Write-Host ""
Write-Host "  Log: $LogPath" -ForegroundColor Gray
Write-Host "  Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

# Start at current end of file
$Script:LastSize = ([System.IO.FileInfo]::new($LogPath)).Length

Write-Host "--- Monitoring active ---" -ForegroundColor Cyan
Write-Host ""

while ($true) {
    Start-Sleep -Milliseconds 300

    try {
        $Stream = [System.IO.FileStream]::new(
            $LogPath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
        )
        $CurrentSize = $Stream.Length

        if ($CurrentSize -lt $Script:LastSize) {
            $Script:LastSize = 0
            $Script:RunCount = 0
            $Script:WaitingForHideoutCheck = $false
            $Script:CurrentMap = ""
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Log reset." -ForegroundColor Magenta
        }

        if ($CurrentSize -gt $Script:LastSize) {
            $Stream.Position = $Script:LastSize
            $BytesToRead = $CurrentSize - $Script:LastSize
            $Buffer = New-Object byte[] $BytesToRead
            $ActualRead = $Stream.Read($Buffer, 0, $BytesToRead)
            $Script:LastSize = $CurrentSize
            $Stream.Dispose()

            $Text = [System.Text.Encoding]::UTF8.GetString($Buffer, 0, $ActualRead)
            $Lines = $Text.Split([char[]]@("`r","`n"), [System.StringSplitOptions]::RemoveEmptyEntries)

            foreach ($Line in $Lines) {
                Process-Line -Line $Line.Trim()
            }
        } else {
            $Stream.Dispose()
        }
    } catch {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Error: $_" -ForegroundColor Red
    }

    # "No hideout" timeout - 5 seconds after entering a hideout-capable map
    if ($Script:WaitingForHideoutCheck -and $Script:MapEntryTime) {
        $Elapsed = ((Get-Date) - $Script:MapEntryTime).TotalSeconds
        if ($Elapsed -gt 5 -and -not $Script:HideoutSpawnDetected) {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Run #$($Script:RunCount) - $($Script:CurrentMap): No hideout. Leave & rerun." -ForegroundColor Red
            Show-Overlay -Text "No hideout in $($Script:CurrentMap) #$($Script:RunCount)" -DurationMs 3000
            $Script:WaitingForHideoutCheck = $false
        }
    }
}
