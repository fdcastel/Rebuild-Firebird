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
    [ValidateSet('FB25','FB30','FB40','FB50')]
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
    $scriptPath = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)

    'FB25','FB30','FB40','FB50' | ForEach-Object {
        if (-not $sourceVersion) {
            & $scriptPath\$_\gstat.exe -h $SourceFile 2>$null 1>$null 
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

    $sourceExtraArguments = $null
    $targetExtraArguments = $null

    if ($PageSize) {
        $targetExtraArguments += " -page_size $PageSize"
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

        # Using -G option inhibits Firebird garbage collection, speeding up the backup process if a lot of updates have been done.
        #   https://firebirdsql.org/file/documentation/html/en/firebirddocs/gbak/firebird-gbak.html#gbak-backup-speedup

        # Using -NT option makes backup 5% faster (tested with a 320GB database)
        
        $sourceCommand = "$scriptPath\$sourceVersion\gbak.exe -z -backup_database$($sourceExtraArguments) -g -nt -verify -statistics T -y $sourceLog $SourceFile stdout"
        
        $restoreCommand = "$scriptPath\$WithVersion\gbak.exe -z -create_database$($targetExtraArguments) -verify -statistics T -y $targetLog stdin $TargetFile"
        
        # Powershell redirection is hell on Earth. Use CMD.
        CMD.EXE /C "$sourceCommand | $restoreCommand"
        $elapsedTime = ((Get-Date) - $startTime).TotalSeconds

        # Adds each command used to log files. "-Skip 3" (ahead) will omit this.
        "`nBackup command:`n    $sourceCommand" | Add-Content -Path $sourceLog
        "`nRestore command:`n    $restoreCommand" | Add-Content -Path $targetLog

        # $LASTEXITCODE is the exit code of $restoreCommand (last command of pipe).
        if ($LASTEXITCODE) {
            if (Test-Path $sourceLog) {
                $errors = Get-Content $sourceLog | Select-String -SimpleMatch 'gbak: ERROR:'
                if ($errors) {
                    "----- [$sourceLog (errors)] -----" | Write-Warning
                    $errors | Write-Warning
                }

                "----- [$sourceLog (last 10 lines)] -----" | Write-Warning 
                Get-Content $sourceLog | Select-Object -Last 10 -Skip 3 | Write-Warning

                "----- [$sourceLog EOF] -----" | Write-Warning
            }
    
            if (Test-Path $targetLog) {
                $errors = Get-Content $targetLog | Select-String -SimpleMatch 'gbak: ERROR:'
                if ($errors) {
                    "----- [$targetLog (errors)] -----" | Write-Warning
                    $errors | Write-Warning
                }

                "----- [$targetLog (last 10 lines)] -----" | Write-Warning
                Get-Content $targetLog | Select-Object -Last 10 -Skip 3 | Write-Warning

                "----- [$targetLog EOF] -----" | Write-Warning
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
