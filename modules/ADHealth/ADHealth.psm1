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
        FindingId      = [guid]::NewGuid().Guid
        Check          = $Check
        Title          = $Title
        Severity       = $Severity
        SeverityRank   = Get-AdhSeverityRank -Severity $Severity
        Confidence     = $Confidence
        Target         = $Target
        Evidence       = $Evidence
        Impact         = $Impact
        Recommendation = $Recommendation
        Reference      = $Reference
        ObservedAtUtc  = [datetime]::UtcNow
    }
}

function Import-AdhSyntheticData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path
    )

    Get-Content -Path $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
}

function Get-AdhLiveData {
    [CmdletBinding()]
    param(
        [ValidateRange(1,3650)][int]$StaleComputerDays = 90
    )

    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        throw 'The ActiveDirectory PowerShell module is required for live collection.'
    }

    Import-Module ActiveDirectory -ErrorAction Stop
    $forest = Get-ADForest -ErrorAction Stop
    $domain = Get-ADDomain -ErrorAction Stop
    $controllers = @(Get-ADDomainController -Filter * -ErrorAction Stop)
    $replicationFailures = @(Get-ADReplicationFailure -Target * -Scope Forest -ErrorAction SilentlyContinue)
    $collectionNotes = [System.Collections.Generic.List[string]]::new()

    $controllerEvidence = foreach ($controller in $controllers) {
        $reachable = Test-Connection -ComputerName $controller.HostName -Count 1 -Quiet -ErrorAction SilentlyContinue
        $sysvolReady = Test-Path -Path ("\\{0}\SYSVOL" -f $controller.HostName) -ErrorAction SilentlyContinue
        $controllerFailures = @($replicationFailures | Where-Object { $_.Server -eq $controller.HostName -or $_.Partner -eq $controller.HostName })
        $oldestFailureHours = 0
        if ($controllerFailures.Count -gt 0) {
            $oldest = $controllerFailures | Sort-Object FirstFailureTime | Select-Object -First 1
            if ($oldest.FirstFailureTime) {
                $oldestFailureHours = [math]::Round(((Get-Date) - $oldest.FirstFailureTime).TotalHours, 1)
            }
        }

        [PSCustomObject]@{
            Name                       = $controller.HostName
            Site                       = $controller.Site
            IPv4Address                = $controller.IPv4Address
            IsGlobalCatalog            = [bool]$controller.IsGlobalCatalog
            IsReadOnly                 = [bool]$controller.IsReadOnly
            OperatingSystem            = $controller.OperatingSystem
            Reachable                  = [bool]$reachable
            ReplicationFailures        = $controllerFailures.Count
            ReplicationFailureAgeHours = $oldestFailureHours
            SysvolReady                = [bool]$sysvolReady
            TimeOffsetSeconds          = 0
        }
    }

    $srvRecordFailures = 0
    $srvName = "_ldap._tcp.dc._msdcs.$($forest.Name)"
    try {
        $srvRecords = @(Resolve-DnsName -Name $srvName -Type SRV -ErrorAction Stop)
        if ($srvRecords.Count -lt $controllers.Count) {
            $srvRecordFailures = $controllers.Count - $srvRecords.Count
        }
    }
    catch {
        $srvRecordFailures = $controllers.Count
        $collectionNotes.Add("SRV lookup failed: $($_.Exception.Message)")
    }

    $cutoff = (Get-Date).AddDays(-1 * $StaleComputerDays)
    $staleComputers = @(Get-ADComputer -Filter * -Properties LastLogonDate -ErrorAction Stop | Where-Object { -not $_.LastLogonDate -or $_.LastLogonDate -lt $cutoff })

    [PSCustomObject]@{
        Classification    = 'LIVE READ-ONLY ASSESSMENT DATA'
        ForestName        = $forest.Name
        DomainName        = $domain.DNSRoot
        ForestMode        = [string]$forest.ForestMode
        DomainMode        = [string]$domain.DomainMode
        ForestFsmOwners   = [PSCustomObject]@{
            SchemaMaster        = $forest.SchemaMaster
            DomainNamingMaster  = $forest.DomainNamingMaster
        }
        DomainFsmOwners   = [PSCustomObject]@{
            PDCEmulator          = $domain.PDCEmulator
            RIDMaster            = $domain.RIDMaster
            InfrastructureMaster = $domain.InfrastructureMaster
        }
        Sites             = @($forest.Sites)
        DomainControllers = @($controllerEvidence)
        Dns               = [PSCustomObject]@{
            SrvRecordName     = $srvName
            SrvRecordFailures = $srvRecordFailures
        }
        StaleObjects      = [PSCustomObject]@{
            ThresholdDays          = $StaleComputerDays
            ComputersOlderThanDays = $staleComputers.Count
        }
        CollectionNotes   = @($collectionNotes)
        CollectedAtUtc    = [datetime]::UtcNow
    }
}

function New-AdhHtmlReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject]$Result,
        [Parameter(Mandatory)][string]$Path
    )

    $summaryRows = @(
        [PSCustomObject]@{ Metric = 'Forest'; Value = $Result.Summary.ForestName },
        [PSCustomObject]@{ Metric = 'Domain'; Value = $Result.Summary.DomainName },
        [PSCustomObject]@{ Metric = 'Critical'; Value = $Result.Summary.Critical },
        [PSCustomObject]@{ Metric = 'High'; Value = $Result.Summary.High },
        [PSCustomObject]@{ Metric = 'Medium'; Value = $Result.Summary.Medium },
        [PSCustomObject]@{ Metric = 'Low'; Value = $Result.Summary.Low }
    )

    $style = @'
<style>
body{font-family:Segoe UI,Arial,sans-serif;margin:32px;color:#1f2937;background:#f8fafc}
h1,h2{color:#0f172a}table{border-collapse:collapse;width:100%;margin:12px 0 28px;background:white}
th,td{border:1px solid #cbd5e1;padding:8px;text-align:left;vertical-align:top}th{background:#e2e8f0}.Critical{background:#fee2e2}.High{background:#ffedd5}.Medium{background:#fef3c7}.Low{background:#ecfccb}.meta{color:#475569}
</style>
'@

    $summaryHtml = $summaryRows | ConvertTo-Html -Fragment
    $findingRows = foreach ($finding in @($Result.Findings)) {
        [PSCustomObject]@{
            Severity       = $finding.Severity
            Confidence     = $finding.Confidence
            Check          = $finding.Check
            Target         = $finding.Target
            Title          = $finding.Title
            Evidence       = $finding.Evidence
            Impact         = $finding.Impact
            Recommendation = $finding.Recommendation
        }
    }
    $findingsHtml = $findingRows | ConvertTo-Html -Fragment
    $html = @"
<!doctype html><html><head><meta charset='utf-8'><title>Active Directory Health Assessment</title>$style</head><body>
<h1>Active Directory Health Assessment</h1>
<p class='meta'>Generated $([datetime]::UtcNow.ToString('u')) UTC | Classification: $($Result.Evidence.Classification)</p>
<h2>Executive Summary</h2>$summaryHtml
<h2>Findings</h2>$findingsHtml
</body></html>
"@
    Set-Content -Path $Path -Value $html -Encoding UTF8
    Get-Item -Path $Path
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

    $sortProperties = @(
        @{ Expression = 'SeverityRank'; Descending = $true },
        @{ Expression = 'Confidence'; Descending = $true }
    )
    $sortedFindings = @($findings | Sort-Object -Property $sortProperties)
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
    $result = [PSCustomObject]@{ Summary = $summary; Findings = $sortedFindings; Evidence = $Data }

    if ($OutputPath) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        $result | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $OutputPath 'assessment.json') -Encoding UTF8
        $sortedFindings | Export-Csv -Path (Join-Path $OutputPath 'findings.csv') -NoTypeInformation -Encoding UTF8
        New-AdhHtmlReport -Result $result -Path (Join-Path $OutputPath 'report.html') | Out-Null
    }

    $result
}

Export-ModuleMember -Function Get-AdhSeverityRank,New-AdhFinding,Import-AdhSyntheticData,Get-AdhLiveData,New-AdhHtmlReport,Invoke-AdhAssessment
