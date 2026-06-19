# Active Directory Health Check Toolkit — Enterprise v2 Roadmap

## Objective

Transform the current read-only assessment script into a senior-level Active Directory operations and assurance toolkit suitable for multi-domain, multi-site, and multi-domain-controller environments.

## Current implementation status

Phase-one engineering has started on branch `upgrade/enterprise-v2`.

Completed:

- Versioned `ADHealth` PowerShell module and manifest
- Normalized finding model with severity, confidence, evidence, impact, recommendation, target, reference, and UTC timestamp
- Synthetic assessment engine covering controller reachability, replication, SYSVOL, time offset, DNS SRV validation, and stale computer objects
- Clearly labelled synthetic AD dataset
- Machine-readable JSON and CSV exports
- Windows PowerShell 5.1 entry point
- Pester tests
- Windows GitHub Actions workflow with parser validation, PSScriptAnalyzer, Pester, synthetic assessment, and artifact upload

Still required:

- Live Active Directory collectors
- Forest, domain, FSMO, topology, trust, privileged-group, and policy collectors
- Enterprise HTML report and scorecards
- Controlled AD lab validation
- Baseline comparison and drift detection

## v2 architecture

- Versioned PowerShell module with public and private functions
- Assessment engine returning typed findings and structured evidence
- Collector plugins for forest, domain, controller, DNS, replication, SYSVOL, time, trusts, sites, FSMO, security, and stale objects
- Configurable severity and confidence scoring
- JSON, CSV, and HTML report outputs
- Baseline comparison and configuration-drift detection
- Simulation mode with clearly labelled synthetic data
- Windows PowerShell 5.1 and PowerShell 7 compatibility where supported

## Senior-level capabilities

### Directory topology

- Forest and domain inventory
- Functional levels and optional features
- Sites, subnets, site links, and bridgehead analysis
- Domain-controller role, operating system, global catalog, and read-only state
- FSMO placement and availability

### Replication and SYSVOL

- Replication summary and partner health
- Failure age, consecutive failures, and error-code interpretation
- Lingering-object risk indicators
- SYSVOL and NETLOGON validation
- DFS Replication event correlation
- Replication topology visualization data

### DNS and time

- AD-integrated zone inventory
- SRV, A, PTR, and delegation checks
- DNS client configuration on controllers
- Forwarder and scavenging review
- PDC time-source and domain hierarchy validation
- Time-offset and service-state evidence

### Security and identity hygiene

- Privileged group membership review
- AdminSDHolder and protected-account indicators
- Stale users and computers
- Password and service-account hygiene
- Fine-grained password-policy inventory
- LDAP signing, channel binding, SMB, and legacy protocol indicators
- Trust inventory and SID-filtering evidence

### Reporting

- Executive health score
- Domain and controller scorecards
- Finding severity, confidence, impact, evidence, and remediation
- Affected-object counts
- Machine-readable exports
- Sanitized sample reports

## Engineering standards

- Pester unit and integration tests
- Mocked AD cmdlets for CI
- PSScriptAnalyzer
- GitHub Actions on Windows
- Semantic versioning and changelog
- SECURITY.md and CONTRIBUTING.md
- Architecture decision records
- Least-privilege and permissions documentation

## Delivery phases

### Phase 1

- Module structure
- Finding model
- Forest, domain, controller, FSMO, replication, DNS, and SYSVOL collectors
- CI and tests
- Enterprise HTML report

### Phase 2

- Security posture and identity-hygiene collectors
- Baseline comparison
- Multi-domain and multi-site support
- Simulation datasets

### Phase 3

- Scheduled assessments
- Trend reports
- Remediation runbooks
- Integration adapters for ticketing or monitoring systems

## Completion standard

The upgrade is ready to merge only after CI passes, synthetic tests pass, a Windows lab assessment succeeds, reports are reviewed, and documentation clearly distinguishes simulated data from real evidence.