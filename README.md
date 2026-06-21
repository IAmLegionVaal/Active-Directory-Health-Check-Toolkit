# Active Directory Health Check Toolkit

A PowerShell toolkit for L2/L3 Active Directory health review and selected guarded domain-controller repairs.

## Diagnostic script

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\AD_Health_Check_Toolkit.ps1
```

## Repair script

Preview a repair:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\AD_Health_Repair_Toolkit.ps1 -SyncReplication -DryRun
```

Examples:

```powershell
.\AD_Health_Repair_Toolkit.ps1 -SyncReplication
.\AD_Health_Repair_Toolkit.ps1 -RegisterDns
.\AD_Health_Repair_Toolkit.ps1 -RestartNetlogon
.\AD_Health_Repair_Toolkit.ps1 -RestartDns
.\AD_Health_Repair_Toolkit.ps1 -RestartKdc
```

## What the repair does

- Runs only on a domain controller.
- Synchronises Active Directory replication with `repadmin /syncall`.
- Registers domain-controller DNS records and refreshes Netlogon registration.
- Restarts the selected Netlogon, DNS Server or Kerberos KDC service.
- Captures `dcdiag`, replication and service evidence before and after repair.
- Supports `-DryRun`, confirmation prompts, logs and clear exit codes.

## Safety

Replication and directory-service changes can affect the entire domain. Run targeted actions only after reviewing the diagnostic report and confirming healthy DNS, time synchronisation and backups. The tool does not delete directory objects, seize FSMO roles or alter sites and subnets.

## Author

Dewald Pretorius — L2 IT Support Engineer
