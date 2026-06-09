$ErrorActionPreference = "Stop"

$HugoVersion = "0.160.1"
$GoVersion = "1.22.12"
$BaseUrl = if ($args.Count -gt 0) { $args[0] } else { "https://b0weny-qwq.github.io/Blog/" }

$Root = Split-Path -Parent $PSScriptRoot
$ToolsDir = Join-Path $Root ".tools"
$HugoDir = Join-Path $ToolsDir "hugo-$HugoVersion"
$GoDir = Join-Path $ToolsDir "go-$GoVersion"
$GoRoot = Join-Path $GoDir "go"
$HugoExe = Join-Path $HugoDir "hugo.exe"
$GoExe = Join-Path $GoRoot "bin\go.exe"

function Download-File {
    param(
        [string]$Url,
        [string]$OutFile
    )

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
    curl.exe -L $Url -o $OutFile
}

New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null

if (!(Test-Path $GoExe)) {
    $GoZip = Join-Path $GoDir "go.zip"
    $GoUrl = "https://go.dev/dl/go$GoVersion.windows-amd64.zip"
    Write-Host "Downloading Go $GoVersion..."
    Download-File -Url $GoUrl -OutFile $GoZip
    Expand-Archive -Force -Path $GoZip -DestinationPath $GoDir
}

if (!(Test-Path $HugoExe)) {
    $HugoZip = Join-Path $HugoDir "hugo.zip"
    $HugoUrl = "https://github.com/gohugoio/hugo/releases/download/v$HugoVersion/hugo_extended_$HugoVersion`_windows-amd64.zip"
    Write-Host "Downloading Hugo extended $HugoVersion..."
    Download-File -Url $HugoUrl -OutFile $HugoZip
    Expand-Archive -Force -Path $HugoZip -DestinationPath $HugoDir
}

$env:GOROOT = $GoRoot
$env:PATH = (Join-Path $GoRoot "bin") + ";" + $env:PATH
$env:GO111MODULE = "on"

& $GoExe version
& $HugoExe version
& $HugoExe --gc --minify --baseURL $BaseUrl
