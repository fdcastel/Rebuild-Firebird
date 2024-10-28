#
# Tests for Rebuild-Firebird.
#

$ErrorActionPreference = 'Stop'

$outputPath = "$env:TEMP/Rebuild-Firebird-Tests/"

if (Test-Path $outputPath) {
    Remove-Item $outputPath -Recurse -Force
}
mkdir $outputPath -Force > $null

'FB50', 'FB40', 'FB30', 'FB25' | ForEach-Object {
    $versionRoot = ./Requires-Firebird.ps1 -Version $_ -Verbose    
    Copy-Item "$versionRoot/examples/empbuild/employee.fdb" "$outputPath/employee-$_.fdb"
}

./Rebuild-Firebird.ps1 -Source "$outputPath/employee-FB25.fdb" -Verbose
./Rebuild-Firebird.ps1 -Source "$outputPath/employee-FB25.fdb" -WithVersion FB30 -Verbose
./Rebuild-Firebird.ps1 -Source "$outputPath/employee-FB25.fdb" -WithVersion FB40 -Verbose
./Rebuild-Firebird.ps1 -Source "$outputPath/employee-FB25.fdb" -WithVersion FB50 -Verbose

./Rebuild-Firebird.ps1 -Source "$outputPath/employee-FB30.fdb" -Verbose
./Rebuild-Firebird.ps1 -Source "$outputPath/employee-FB30.fdb" -WithVersion FB40 -Verbose
./Rebuild-Firebird.ps1 -Source "$outputPath/employee-FB30.fdb" -WithVersion FB50 -Verbose

./Rebuild-Firebird.ps1 -Source "$outputPath/employee-FB40.fdb" -Verbose
./Rebuild-Firebird.ps1 -Source "$outputPath/employee-FB40.fdb" -WithVersion FB50 -Verbose

./Rebuild-Firebird.ps1 -Source "$outputPath/employee-FB50.fdb" -Verbose
