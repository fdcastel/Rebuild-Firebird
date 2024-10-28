#
# Downloads Firebird packages for a given version.
#

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $True)]
    [ValidateSet('FB25', 'FB30', 'FB40', 'FB50')]
    [String]$Version
)

if (-not $env:FIREBIRD_ROOT) {
    $env:FIREBIRD_ROOT = Join-Path ([System.IO.Path]::GetTempPath()) 'Requires-Firebird/'
    mkdir $env:FIREBIRD_ROOT -Force > $null
}

if (-not (Test-Path $env:FIREBIRD_ROOT)) {
    throw "Root folder '$env:FIREBIRD_ROOT' (from FIREBIRD_ROOT env var) does not exists."
}

function Invoke-DownloadAndExtract([string]$Url, [string]$TargetPath) {
    $zipFile = ([uri]$Url).Segments[-1]
    $fullZipFile = Join-Path $env:FIREBIRD_ROOT $zipFile

    Write-Verbose "  Downloading '$zipFile'..."
    Invoke-WebRequest $Url -OutFile $fullZipFile -Verbose:$false

    Write-Verbose "  Extracting '$zipFile'..."
    if (Test-Path $TargetPath) {
        Remove-Item $TargetPath -Recurse -Force
    }
    Expand-Archive -Path $fullZipFile -DestinationPath $TargetPath
    Remove-Item $fullZipFile
}



#
# Main
#

$ErrorActionPreference = 'Stop'

$versionRoot = Join-Path $env:FIREBIRD_ROOT $Version.ToUpperInvariant()
if (Test-Path "$versionRoot/firebird.conf") {
    Write-Verbose "$Version already installed."
    return $versionRoot
}

$url = switch ([System.Environment]::OSVersion.Platform) {
    'Win32NT' {
        switch ($Version) {
            'FB50' { 'https://github.com/FirebirdSQL/firebird/releases/download/v5.0.1/Firebird-5.0.1.1469-0-windows-x64.zip' }
            'FB40' { 'https://github.com/FirebirdSQL/firebird/releases/download/v4.0.5/Firebird-4.0.5.3140-0-x64.zip' }
            'FB30' { 'https://github.com/FirebirdSQL/firebird/releases/download/v3.0.12/Firebird-3.0.12.33787-0-x64.zip' }
            'FB25' { 'https://github.com/FirebirdSQL/firebird/releases/download/R2_5_9/Firebird-2.5.9.27139-0_x64_embed.zip' }
        }
    }

    'Unix' {
        switch ($Version) {
            'FB50' { 'https://github.com/FirebirdSQL/firebird/releases/download/v5.0.1/Firebird-5.0.1.1469-0-linux-x64.tar.gz' }
            'FB40' { 'https://github.com/FirebirdSQL/firebird/releases/download/v4.0.5/Firebird-4.0.5.3140-0.amd64.tar.gz' }
            'FB30' { 'https://github.com/FirebirdSQL/firebird/releases/download/v3.0.12/Firebird-3.0.12.33787-0.amd64.tar.gz' }
            'FB25' { 'https://github.com/FirebirdSQL/firebird/releases/download/R2_5_9/FirebirdCS-2.5.9.27139-0.amd64.tar.gz' }
        }
    }
}

if([System.Environment]::OSVersion.Platform -eq 'Unix') {
    # TODO: Port
    throw "Not implemented (Unix platform)."
}

Write-Verbose "Installing $Version..."
Invoke-DownloadAndExtract -Url $url -TargetPath $versionRoot

if ($Version -eq 'FB25') {
    # Extra steps for FB25.
    $extraUrl = 'https://github.com/FirebirdSQL/firebird/releases/download/R2_5_9/Firebird-2.5.9.27139-0_x64.zip'
    Invoke-DownloadAndExtract -Url $extraUrl -TargetPath "${versionRoot}_FULL"

    Write-Verbose "  Renaming 'fbembed.dll' to 'fbclient.dll'..."
    Move-Item "$versionRoot/fbembed.dll" "$versionRoot/fbclient.dll"
    
    'gbak', 'gfix', 'gstat', 'isql' | ForEach-Object {
        Write-Verbose "  Copying '$_.exe'..."
        Copy-Item "${versionRoot}_FULL/bin/$_.exe" $versionRoot
    }

    Write-Verbose "  Copying 'employee.fdb'..."
    mkdir "$versionRoot/examples/empbuild/" -Force > $null
    Copy-Item "${versionRoot}_FULL/examples/empbuild/employee.fdb" "$versionRoot/examples/empbuild/"
}

Write-Verbose "  Patching $Version/firebird.conf"
$newIpcName = 'FB50' -replace 'FB', 'FIREBIRD'
(Get-Content "$versionRoot/firebird.conf" -Raw).Replace('#IpcName = FIREBIRD', "IpcName = $newIpcName") | 
    Set-Content "$versionRoot/firebird.conf" -Encoding Ascii

return $versionRoot
