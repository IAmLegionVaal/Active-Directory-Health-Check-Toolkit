function Compare-AdhAssessment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject]$Baseline,
        [Parameter(Mandatory)][psobject]$Current
    )

    $baselineIndex = @{}
    foreach ($finding in @($Baseline.Findings)) {
        $key = '{0}|{1}|{2}' -f $finding.Reference,$finding.Target,$finding.Title
        $baselineIndex[$key] = $finding
    }

    $currentIndex = @{}
    foreach ($finding in @($Current.Findings)) {
        $key = '{0}|{1}|{2}' -f $finding.Reference,$finding.Target,$finding.Title
        $currentIndex[$key] = $finding
    }

    $newFindings = [System.Collections.Generic.List[object]]::new()
    $resolvedFindings = [System.Collections.Generic.List[object]]::new()
    $persistentFindings = [System.Collections.Generic.List[object]]::new()
    $severityChanges = [System.Collections.Generic.List[object]]::new()

    foreach ($key in $currentIndex.Keys) {
        if (-not $baselineIndex.ContainsKey($key)) {
            $newFindings.Add($currentIndex[$key])
            continue
        }

        $persistentFindings.Add($currentIndex[$key])
        if ($baselineIndex[$key].Severity -ne $currentIndex[$key].Severity) {
            $severityChanges.Add([PSCustomObject]@{
                Key          = $key
                Reference    = $currentIndex[$key].Reference
                Target       = $currentIndex[$key].Target
                Title        = $currentIndex[$key].Title
                FromSeverity = $baselineIndex[$key].Severity
                ToSeverity   = $currentIndex[$key].Severity
            })
        }
    }

    foreach ($key in $baselineIndex.Keys) {
        if (-not $currentIndex.ContainsKey($key)) {
            $resolvedFindings.Add($baselineIndex[$key])
        }
    }

    [PSCustomObject]@{
        ComparedAtUtc     = [datetime]::UtcNow
        BaselineTimestamp = $Baseline.Summary.AssessedAtUtc
        CurrentTimestamp  = $Current.Summary.AssessedAtUtc
        NewFindings       = @($newFindings)
        ResolvedFindings  = @($resolvedFindings)
        PersistentFindings = @($persistentFindings)
        SeverityChanges   = @($severityChanges)
        Summary           = [PSCustomObject]@{
            BaselineFindingCount = @($Baseline.Findings).Count
            CurrentFindingCount  = @($Current.Findings).Count
            NewCount             = $newFindings.Count
            ResolvedCount        = $resolvedFindings.Count
            PersistentCount      = $persistentFindings.Count
            SeverityChangeCount  = $severityChanges.Count
        }
    }
}

Export-ModuleMember -Function Compare-AdhAssessment
