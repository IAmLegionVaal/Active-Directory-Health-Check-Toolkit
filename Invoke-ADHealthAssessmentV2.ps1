[CmdletBinding()]
param(
    [string]$SyntheticDataPath = (Join-Path $PSScriptRoot 'sample-data\synthetic-ad-health.json'),
    [string]$OutputPath = (Join-Path $PSScriptRoot 'artifacts\latest-assessment')
)

$modulePath = Join-Path $PSScriptRoot 'modules\ADHealth\ADHealth.psd1'
Import-Module $modulePath -Force -ErrorAction Stop

$data = Import-AdhSyntheticData -Path $SyntheticDataPath
$result = Invoke-AdhAssessment -Data $data -OutputPath $OutputPath

$result.Summary | Format-List
$result.Findings | Format-Table Severity,Confidence,Check,Target,Title -AutoSize
