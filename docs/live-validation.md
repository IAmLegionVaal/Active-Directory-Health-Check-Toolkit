# Controlled Live Validation

Run this only from an authorized domain-connected Windows host with the Active Directory PowerShell module installed and read access to directory health information.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Invoke-ADHealthAssessmentV2.ps1 `
  -Mode Live `
  -OutputPath .\artifacts\live-assessment `
  -OpenReport
```

## Expected outputs

- `assessment.json`
- `findings.csv`
- `report.html`

## Review checklist

- Confirm the forest and domain names are correct.
- Review every domain controller for reachability, replication, SYSVOL, and DNS evidence.
- Verify stale-object counts against an authoritative administrative query.
- Confirm no credentials or private customer data are committed.
- Store only sanitized validation evidence in the repository.

The collector is read-only. It requires no repair permissions and performs no directory changes.
