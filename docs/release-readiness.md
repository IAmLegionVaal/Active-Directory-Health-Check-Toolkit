# Release Readiness

## Completed

- Versioned PowerShell module
- Synthetic and live read-only collection modes
- Forest, domain, FSMO, site, domain-controller, replication, SYSVOL, DNS, time, and stale-computer evidence
- Normalized findings
- JSON, CSV, and HTML reporting
- Baseline comparison and drift summary
- Pester and PSScriptAnalyzer validation
- Windows GitHub Actions artifacts
- Controlled live-validation procedure

## Remaining merge gate

Run the live collector in an authorized Active Directory lab and review sanitized output. Trust, privileged-group, and extended policy collectors can follow as a later expansion without blocking the initial v2 assessment release.
