# Enables TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$url = 'https://codeload.github.com/fdcastel/Rebuild-Firebird/zip/master'

$tempFolder = [System.IO.Path]::GetTempPath()
$fileName = Join-Path $tempFolder 'Rebuild-Firebird-master.zip'

$ProgressPreference = 'SilentlyContinue'    # Faster downloads
Invoke-RestMethod $url -OutFile $fileName
Expand-Archive $fileName -DestinationPath $tempFolder -Force

Join-Path $tempFolder 'Rebuild-Firebird-master' | Set-Location
