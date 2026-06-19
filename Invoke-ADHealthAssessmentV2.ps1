[CmdletBinding()]
param(
    [ValidateSet('Synthetic','Live')][string]$Mode = 'Synthetic',
    [string]$SyntheticDataPath = (Join-Path $PSScriptRoot 'sample-data\synthetic-ad-health.json'),
    [string]$OutputPath = (Join-Path $PSScriptRoot 'artifacts\latest-assessment'),
    [ValidateRange(1,3650)][int]$StaleComputerDays = 90,
    [switch]$OpenReport
)

$modulePath = Join-Path $PSScriptRoot 'modules\ADHealth\ADHealth.psd1'
Import-Module $modulePath -Force -ErrorAction Stop

$data = if ($Mode -eq 'Live') {
    Get-AdhLiveData -StaleComputerDays $StaleComputerDays
}
else {
    Import-AdhSyntheticData -Path $SyntheticDataPath
}

$result = Invoke-AdhAssessment -Data $data -OutputPath $OutputPath
$result.Summary | Format-List
$result.Findings | Format-Table Severity,Confidence,Check,Target,Title -AutoSize

$reportPath = Join-Path $OutputPath 'report.html'
if ($OpenReport -and (Test-Path $reportPath)) {
    Start-Process $reportPath
}
