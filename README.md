# Active Directory Health Check Toolkit

A read-only PowerShell toolkit for L2/L3 Active Directory health review.

## Features

- Domain and forest summary
- Domain controller inventory
- FSMO role context
- DNS SRV record checks
- SYSVOL and NETLOGON share visibility
- Replication command output capture where available
- CSV, JSON, TXT, and HTML reports

## How to run

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\AD_Health_Check_Toolkit.ps1
```

## Safety

Diagnostic-only. It does not modify Active Directory.
