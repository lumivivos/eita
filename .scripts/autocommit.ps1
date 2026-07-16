$ErrorActionPreference = "Stop"

$repoPath = "C:\Users\Lucas\Documents\GitHub\eita"
$gitExe   = "C:\Users\Lucas\AppData\Local\GitHubDesktop\app-3.6.3\resources\app\git\cmd\git.exe"
$logFile  = Join-Path $repoPath ".scripts\autocommit.log"

Set-Location $repoPath

$status = & $gitExe status --porcelain
if ($status) {
    & $gitExe add -A
    $msg = "auto-save: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    & $gitExe commit -m $msg | Out-Null
    Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - commit criado: $msg"
} else {
    Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - sem mudancas, nada a commitar"
}
