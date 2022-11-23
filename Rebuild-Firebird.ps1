#
# Rebuild a Firebird database using stream conversion (without intermediate files).
#
# Source: https://ib-aid.com/en/articles/fast-conversion-of-firebird-2-5-databases-to-firebird-3/
#

[CmdletBinding(SupportsShouldProcess)]
Param(
    [Parameter(
        Mandatory=$True,
        ValueFromPipeline=$True
    )]
    [String]$SourceFile,

    [Parameter()]
    [ValidateSet('FB25','FB30','FB40')]
    [String]$WithVersion = $null,

    [Parameter()]
    [String]$User = 'SYSDBA',

    [Parameter()]
    [String]$Password = 'masterkey'
)

$env:ISC_USER = $User
$env:ISC_PASSWORD = $Password
try {
    Write-Verbose 'Detecting source database version...'
    $sourceVersion = $null
    'FB25','FB30','FB40' | ForEach-Object {
        if (-not $sourceVersion) {
            & .\$_\gstat.exe -h $SourceFile 2>$null 1>$null 
            if ($?) {
                $sourceVersion = $_
                Write-Verbose "Source database is '$sourceVersion'."
            }
        }
    }
    if (-not $sourceVersion) {
        throw "Source database is of an unknown version."
    }

    if (-not $WithVersion) {
        $WithVersion = $sourceVersion
    }

    # Normalize $WithVersion
    $WithVersion = $WithVersion.ToUpperInvariant()

    $targetFile = "$($SourceFile).$WithVersion"
    if ($WithVersion -eq $sourceVersion) {
        $targetFile = "$($SourceFile).CERT"
    }

    if (Test-Path $targetFile) {
        if ($PSCmdlet.ShouldProcess($targetFile, 'Delete target database')) {
            Remove-Item $targetFile -Force
        }
    }

    $sourceLog = "$($targetFile).source.log"
    if (Test-Path $sourceLog) {
        if ($PSCmdlet.ShouldProcess($sourceLog, 'Delete source log')) {
            Remove-Item $sourceLog -Force
        }
    }

    $targetLog = "$($targetFile).target.log"
    if (Test-Path $targetLog) {
        if ($PSCmdlet.ShouldProcess($targetLog, 'Delete target log')) {
            Remove-Item $targetLog -Force
        }
    }

    if ($PSCmdlet.ShouldProcess($targetFile, "Stream database to version '$WithVersion'")) {
        $startTime = Get-Date
        # With -NT the conversion appears to be 4% faster -- TODO: Test with larger databases
        CMD.EXE /C ".\$sourceVersion\gbak.exe -z -backup_database -garbage_collect -nt -verify -statistics T -y $sourceLog $SourceFile stdout | .\$WithVersion\gbak.exe -z -create_database -verify -statistics T -y $targetLog stdin $targetFile"
        $elapsedTime = ((Get-Date) - $startTime).TotalSeconds

        if ($LASTEXITCODE) {
            if (Test-Path $sourceLog) {
                Write-Warning "----- [$sourceLog (last 10 lines)] -----"
                Get-Content $sourceLog | Select-Object -Last 10 | Write-Warning
                Write-Warning "----- [$sourceLog EOF] -----"
            }
    
            if (Test-Path $targetLog) {
                Write-Warning "----- [$targetLog (last 10 lines)] -----"
                Get-Content $targetLog | Select-Object -Last 10 | Write-Warning
                Write-Warning "----- [$targetLog EOF] -----"
            }
    
            throw "Conversion failed. Please see log files."
        }
        Write-Verbose "Finished. Elapsed time: $elapsedTime seconds."
    }
}
finally {
    $env:ISC_USER = $null
    $env:ISC_PASSWORD = $null
}
