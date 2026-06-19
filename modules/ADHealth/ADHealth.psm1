Set-StrictMode -Version Latest

function Get-AdhSeverityRank {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Critical','High','Medium','Low','Informational')]
        [string]$Severity
    )

    switch ($Severity) {
        'Critical'      { 5 }
        'High'          { 4 }
        'Medium'        { 3 }
        'Low'           { 2 }
        'Informational' { 1 }
    }
}

function New-AdhFinding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Check,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)]
        [ValidateSet('Critical','High','Medium','Low','Informational')]
        [string]$Severity,
        [Parameter(Mandatory)][ValidateRange(0,100)][int]$Confidence,
        [Parameter(Mandatory)][string]$Evidence,
        [Parameter(Mandatory)][string]$Impact,
        [Parameter(Mandatory)][string]$Recommendation,
        [string]$Target = $env:COMPUTERNAME,
        [string]$Reference
    )

    [PSCustomObject]@{
        FindingId     = [guid]::NewGuid().Guid
        Check         = $Check
        Title         = $Title
        Severity      = $Severity
        SeverityRank  = Get-AdhSeverityRank -Severity $Severity
        Confidence    = $Confidence
        Target        = $Target
        Evidence      = $Evidence
        Impact        = $Impact
        Recommendation = $Recommendation
        Reference     = $Reference
        ObservedAtUtc = [datetime]::UtcNow
    }
}

function Import-AdhSyntheticData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateScript({ Test-Path $_ -PathType Leaf })][string]$Path
    )

    Get-Content -Path $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
}

function Invoke-AdhAssessment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject]$Data,
        [string]$OutputPath
    )

    $findings = [System.Collections.Generic.List[object]]::new()

    foreach ($controller in @($Data.DomainControllers)) {
        if (-not $controller.Reachable) {
            $findings.Add((New-AdhFinding -Check 'DomainControllerReachability' -Title "Domain controller unreachable: $($controller.Name)" -Severity Critical -Confidence 99 -Evidence "Reachable=$($controller.Reachable)" -Impact 'Authentication, replication, DNS, and directory services may be unavailable.' -Recommendation 'Validate network reachability, service state, DNS registration, and host health.' -Target $controller.Name -Reference 'AD-DC-001'))
        }

        if ($controller.ReplicationFailures -gt 0) {
            $severity = if ($controller.ReplicationFailureAgeHours -ge 24) { 'High' } else { 'Medium' }
            $findings.Add((New-AdhFinding -Check 'Replication' -Title "Replication failures detected on $($controller.Name)" -Severity $severity -Confidence 95 -Evidence "$($controller.ReplicationFailures) failure(s); oldest $($controller.ReplicationFailureAgeHours) hour(s)" -Impact 'Directory changes may not converge across domain controllers.' -Recommendation 'Review replication partners, DNS, site topology, RPC connectivity, and the reported error codes.' -Target $controller.Name -Reference 'AD-REPL-001'))
        }

        if (-not $controller.SysvolReady) {
            $findings.Add((New-AdhFinding -Check 'SYSVOL' -Title "SYSVOL not ready on $($controller.Name)" -Severity High -Confidence 98 -Evidence "SysvolReady=$($controller.SysvolReady)" -Impact 'Group Policy and logon scripts may fail for clients using this controller.' -Recommendation 'Review DFS Replication state, SYSVOL events, shares, and initial synchronization status.' -Target $controller.Name -Reference 'AD-SYSVOL-001'))
        }

        if ([math]::Abs([double]$controller.TimeOffsetSeconds) -gt 300) {
            $findings.Add((New-AdhFinding -Check 'TimeService' -Title "Excessive time offset on $($controller.Name)" -Severity High -Confidence 96 -Evidence "OffsetSeconds=$($controller.TimeOffsetSeconds)" -Impact 'Kerberos authentication and replication can fail when clocks differ significantly.' -Recommendation 'Validate the PDC time source, domain hierarchy, service state, and upstream NTP reachability.' -Target $controller.Name -Reference 'AD-TIME-001'))
        }
    }

    if ($Data.Dns.SrvRecordFailures -gt 0) {
        $findings.Add((New-AdhFinding -Check 'DNS' -Title 'Active Directory SRV record failures detected' -Severity High -Confidence 96 -Evidence "$($Data.Dns.SrvRecordFailures) failed SRV validation(s)" -Impact 'Clients and controllers may fail to locate directory services.' -Recommendation 'Validate AD-integrated zones, dynamic registration, replication, delegation, and DNS client configuration.' -Target $Data.ForestName -Reference 'AD-DNS-001'))
    }

    if ($Data.StaleObjects.ComputersOlderThanDays -gt 90) {
        $findings.Add((New-AdhFinding -Check 'IdentityHygiene' -Title 'Stale computer objects exceed threshold' -Severity Low -Confidence 85 -Evidence "$($Data.StaleObjects.ComputersOlderThanDays) computer object(s) older than 90 days" -Impact 'Stale identities increase administrative noise and may retain unnecessary access.' -Recommendation 'Validate ownership and last use, then follow the approved disable, quarantine, and deletion process.' -Target $Data.DomainName -Reference 'AD-HYGIENE-001'))
    }

    $sortedFindings = @($findings | Sort-Object SeverityRank -Descending, Confidence -Descending)
    $summary = [PSCustomObject]@{
        ForestName    = $Data.ForestName
        DomainName    = $Data.DomainName
        AssessedAtUtc = [datetime]::UtcNow
        FindingCount  = $sortedFindings.Count
        Critical      = @($sortedFindings | Where-Object Severity -eq 'Critical').Count
        High          = @($sortedFindings | Where-Object Severity -eq 'High').Count
        Medium        = @($sortedFindings | Where-Object Severity -eq 'Medium').Count
        Low           = @($sortedFindings | Where-Object Severity -eq 'Low').Count
    }

    $result = [PSCustomObject]@{
        Summary  = $summary
        Findings = $sortedFindings
        Evidence = $Data
    }

    if ($OutputPath) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        $result | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $OutputPath 'assessment.json') -Encoding UTF8
        $sortedFindings | Export-Csv -Path (Join-Path $OutputPath 'findings.csv') -NoTypeInformation -Encoding UTF8
    }

    $result
}

Export-ModuleMember -Function Get-AdhSeverityRank,New-AdhFinding,Import-AdhSyntheticData,Invoke-AdhAssessment
