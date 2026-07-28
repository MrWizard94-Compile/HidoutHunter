# Quick test to see if we can detect new lines in Client.txt
# Run this, then go enter a zone in PoE and come back

$LogPath = "C:\Program Files (x86)\Steam\steamapps\common\Path of Exile\logs\Client.txt"

Write-Host "=== Log Read Test ===" -ForegroundColor Cyan
Write-Host ""

# Method 1: Line count via Get-Content
$Count1 = @(Get-Content -Path $LogPath -ReadCount 0).Count
Write-Host "Method 1 (Get-Content): $Count1 lines" -ForegroundColor Green

# Method 2: File size via .NET
$Size1 = ([System.IO.FileInfo]::new($LogPath)).Length
Write-Host "Method 2 (FileInfo): $Size1 bytes" -ForegroundColor Green

# Method 3: File size via FileStream
$S = [System.IO.FileStream]::new($LogPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
$Size2 = $S.Length
$S.Dispose()
Write-Host "Method 3 (FileStream): $Size2 bytes" -ForegroundColor Green

# Method 4: Last line via Get-Content -Tail
$Last = Get-Content -Path $LogPath -Tail 1
Write-Host "Method 4 (Tail): $Last" -ForegroundColor Green

Write-Host ""
Write-Host "Now go enter a zone in PoE, then come back here and press Enter..." -ForegroundColor Yellow
Read-Host

# Re-check all methods
Write-Host ""
Write-Host "=== After zone change ===" -ForegroundColor Cyan

$Count2 = @(Get-Content -Path $LogPath -ReadCount 0).Count
Write-Host "Method 1 (Get-Content): $Count2 lines (was $Count1, diff: $($Count2 - $Count1))" -ForegroundColor $(if ($Count2 -gt $Count1) { "Green" } else { "Red" })

$Size3 = ([System.IO.FileInfo]::new($LogPath)).Length
Write-Host "Method 2 (FileInfo): $Size3 bytes (was $Size1, diff: $($Size3 - $Size1))" -ForegroundColor $(if ($Size3 -gt $Size1) { "Green" } else { "Red" })

$S = [System.IO.FileStream]::new($LogPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
$Size4 = $S.Length
$S.Dispose()
Write-Host "Method 3 (FileStream): $Size4 bytes (was $Size2, diff: $($Size4 - $Size2))" -ForegroundColor $(if ($Size4 -gt $Size2) { "Green" } else { "Red" })

$Last2 = Get-Content -Path $LogPath -Tail 1
Write-Host "Method 4 (Tail): $Last2" -ForegroundColor Green

Write-Host ""
Write-Host "If all diffs are 0 or the last line didn't change, PoE is not writing to this file." -ForegroundColor Yellow
Read-Host "Press Enter to exit"
