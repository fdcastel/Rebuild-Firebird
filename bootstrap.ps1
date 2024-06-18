# Enables TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$url = 'https://codeload.github.com/fdcastel/Rebuild-Firebird/zip/master'
$fileName = Join-Path $env:TEMP 'Rebuild-Firebird-master.zip'

$ProgressPreference = 'SilentlyContinue'    # Faster downloads
Invoke-RestMethod $url -OutFile $fileName
Expand-Archive $fileName -DestinationPath $env:TEMP -Force

Set-Location "$env:TEMP\Rebuild-Firebird-master"
