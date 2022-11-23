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
    [String]$Password = 'masterkey',

    [Parameter()]
    [String]$TargetFile = $null,

    [Parameter()]
    [ValidateSet(4096, 8192, 16384, 32768)]
    [String]$PageSize = $null
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

    if (-not $TargetFile) {
        $TargetFile = "$($SourceFile).$WithVersion"
        if ($WithVersion -eq $sourceVersion) {
            $TargetFile = "$($SourceFile).CERT"
        }
    }

    if ($PageSize) {
        $pageSizeArgument = " -page_size $PageSize"
    }

    if (Test-Path $TargetFile) {
        if ($PSCmdlet.ShouldProcess($TargetFile, 'Delete target database')) {
            Remove-Item $TargetFile -Force
        }
    }

    $sourceLog = "$($TargetFile).source.log"
    if (Test-Path $sourceLog) {
        if ($PSCmdlet.ShouldProcess($sourceLog, 'Delete source log')) {
            Remove-Item $sourceLog -Force
        }
    }

    $targetLog = "$($TargetFile).target.log"
    if (Test-Path $targetLog) {
        if ($PSCmdlet.ShouldProcess($targetLog, 'Delete target log')) {
            Remove-Item $targetLog -Force
        }
    }

    if ($PSCmdlet.ShouldProcess($TargetFile, "Stream database to version '$WithVersion'")) {
        $startTime = Get-Date

        # With -NT the conversion appears to be 4% faster -- TODO: Test with larger databases
        $sourceCommand = ".\$sourceVersion\gbak.exe -z -backup_database -garbage_collect -nt -verify -statistics T -y $sourceLog $SourceFile stdout"
        
        $restoreCommand = ".\$WithVersion\gbak.exe -z -create_database$($pageSizeArgument) -verify -statistics T -y $targetLog stdin $TargetFile"
        
        CMD.EXE /C "$sourceCommand | $restoreCommand"
        $elapsedTime = ((Get-Date) - $startTime).TotalSeconds

        "`nBackup command:`n    $sourceCommand" | Add-Content -Path $sourceLog
        "`nRestore command:`n    $restoreCommand" | Add-Content -Path $targetLog

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
