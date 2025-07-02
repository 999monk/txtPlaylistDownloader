# cfg, variables
$playlistPath = ".\playlist.txt"
$destDir = Join-Path $PSScriptRoot 'playlist'
$MaxParallelDownloads = 4 
$Global:SuccessCount = 0
$Global:FailCount = 0
$Global:FailedTracks = @()
$startTime = Get-Date

# funciones
function Download-Track {
    param($track, $destDir)
    try {
        $output = & yt-dlp `
            "ytsearch1:$track" `
            --extract-audio `
            --audio-format mp3 `
            --audio-quality 0 `
            --output "$destDir/%(title)s.%(ext)s" `
            --no-playlist `
            --socket-timeout 15 `
            --retries 1 `
            2>&1 | Out-String

        if ($LASTEXITCODE -eq 0) {
            $script:SuccessCount++
            Write-Host "✓ $track" -ForegroundColor Green
        } else {
            throw $output
        }
    } catch {
        $script:FailCount++
        $script:FailedTracks += $track
        Write-Host "✗ $track" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

# validar yr-dlp, .txt, directorio
if (-not (Get-Command yt-dlp -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: yt-dlp no está instalado. Usa: winget install yt-dlp.yt-dlp" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $playlistPath)) {
    Write-Host "ERROR: No se encontró playlist.txt" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $destDir)) { New-Item -Path $destDir -ItemType Directory | Out-Null }

# playlist
$tracks = Get-Content $playlistPath -Encoding UTF8 | 
          Where-Object { $_ -notmatch '^#|^\s*$' }

Write-Host "`n Iniciando descarga de $($tracks.Count) canciones..." -ForegroundColor Cyan

# descargas paralelas
$jobs = @()
foreach ($track in $tracks) {
    while (($jobs | Where-Object { $_.State -eq 'Running' }).Count -ge $MaxParallelDownloads) {
        Start-Sleep -Seconds 1
    }

    $job = Start-Job -ScriptBlock ${function:Download-Track} -ArgumentList $track, $destDir
    $jobs += $job
    Write-Host "▶ Iniciado: $track" -ForegroundColor Yellow
}

# esperar finalización
while ($jobs | Where-Object { $_.State -eq 'Running' }) {
    Write-Host " Esperando finalización ($($jobs.Count - ($jobs | Where-Object { $_.State -eq 'Running' }).Count)/$($jobs.Count))..." -ForegroundColor Gray
    Start-Sleep -Seconds 3
}

# resumen
$endTime = Get-Date
$duration = ($endTime - $startTime).ToString('hh\:mm\:ss')

Write-Host "`n RESUMEN FINAL" -ForegroundColor Magenta
Write-Host "  Total:       $($tracks.Count)" -ForegroundColor White
Write-Host "  Descargadas: $SuccessCount" -ForegroundColor Green
Write-Host "  Fallidas:    $FailCount" -ForegroundColor Red
Write-Host "  Duración:    $duration" -ForegroundColor White

if ($FailCount -gt 0) {
    Write-Host "`n Canciones fallidas:" -ForegroundColor Red
    $FailedTracks | ForEach-Object { Write-Host "  - $_" }
}

Write-Host "`n Archivos guardados en: $destDir" -ForegroundColor Cyan