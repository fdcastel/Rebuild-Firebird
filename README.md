# Firebird-Convert

Convert a Firebird database between different On-Disk-Structure versions.

Based on [Fast conversion of Firebird 2.5 databases to Firebird 3.0](https://ib-aid.com/en/articles/fast-conversion-of-firebird-2-5-databases-to-firebird-3/) article from Basil Sidorov.

Requires a 64-bit Windows.



## How to install

Just checkout this repository. All necessary files are included.

You don't need an installation of Firebird Server.



## Usage

```powershell
.\Firebird-Convert.ps1 [-SourceFile] <string> [[-TargetVersion] <string>] [[-User] <string>] [[-Password] <string>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

Inform the source database through `-SourceFile` parameter. The ODS version will be detected automatically.

Use the `-TargetVersion` parameter to choose the target Firebird version (default = `fb40`).

Currently allowed conversions are:

  - From `fb25` to `fb30`
  - From `fb25` to `fb40`
  - From `fb30` to `fb40`

The `-WhatIf` switch may be used to display the operations without actually execute them.



### Additional parameters:

  - `-User`: Firebird username. Default = `SYSDBA`.
  - `-Password`: Firebird password. Default = `masterkey`.
