BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\modules\ADHealth\ADHealth.psd1'
    Import-Module $modulePath -Force
    $dataPath = Join-Path $PSScriptRoot '..\sample-data\synthetic-ad-health.json'
    $script:Data = Import-AdhSyntheticData -Path $dataPath
}

Describe 'ADHealth module' {
    It 'imports successfully' {
        Get-Module ADHealth | Should -Not -BeNullOrEmpty
    }

    It 'exports live, reporting, and comparison commands' {
        $commands = Get-Command -Module ADHealth | Select-Object -ExpandProperty Name
        foreach ($name in @('Get-AdhLiveData','New-AdhHtmlReport','Compare-AdhAssessment')) {
            $commands | Should -Contain $name
        }
    }

    It 'maps severity ranks correctly' {
        Get-AdhSeverityRank -Severity Critical | Should -Be 5
        Get-AdhSeverityRank -Severity High | Should -Be 4
        Get-AdhSeverityRank -Severity Low | Should -Be 2
    }

    It 'creates normalized findings' {
        $finding = New-AdhFinding -Check Test -Title 'Synthetic finding' -Severity Medium -Confidence 80 -Evidence Evidence -Impact Impact -Recommendation Recommendation -Target DC01
        $finding.Severity | Should -Be 'Medium'
        $finding.SeverityRank | Should -Be 3
        $finding.FindingId | Should -Not -BeNullOrEmpty
    }

    It 'produces expected findings from synthetic data' {
        $result = Invoke-AdhAssessment -Data $script:Data
        $result.Summary.FindingCount | Should -Be 5
        $result.Summary.High | Should -Be 4
        $result.Summary.Low | Should -Be 1
        $result.Findings.Title | Should -Contain 'Replication failures detected on DC02'
        $result.Findings.Title | Should -Contain 'SYSVOL not ready on DC02'
        $result.Findings.Title | Should -Contain 'Excessive time offset on DC02'
        $result.Findings.Title | Should -Contain 'Active Directory SRV record failures detected'
    }

    It 'exports JSON, CSV, and HTML evidence' {
        $outputPath = Join-Path $TestDrive 'assessment'
        Invoke-AdhAssessment -Data $script:Data -OutputPath $outputPath | Out-Null
        Test-Path (Join-Path $outputPath 'assessment.json') | Should -BeTrue
        Test-Path (Join-Path $outputPath 'findings.csv') | Should -BeTrue
        Test-Path (Join-Path $outputPath 'report.html') | Should -BeTrue
    }

    It 'compares a current assessment with a baseline' {
        $baseline = Invoke-AdhAssessment -Data $script:Data
        $currentData = $script:Data | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $currentData.Dns.SrvRecordFailures = 0
        $current = Invoke-AdhAssessment -Data $currentData
        $comparison = Compare-AdhAssessment -Baseline $baseline -Current $current

        $comparison.Summary.BaselineFindingCount | Should -Be 5
        $comparison.Summary.CurrentFindingCount | Should -Be 4
        $comparison.Summary.ResolvedCount | Should -Be 1
        $comparison.ResolvedFindings.Reference | Should -Contain 'AD-DNS-001'
    }
}
