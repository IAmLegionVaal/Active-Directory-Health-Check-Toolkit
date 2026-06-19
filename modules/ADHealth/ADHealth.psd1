@{
    RootModule        = ''
    NestedModules     = @('ADHealth.psm1','ADHealth.Comparison.psm1')
    ModuleVersion     = '2.2.1'
    GUID              = '8e6b9955-1d10-4eb3-892f-b4ea975f25dd'
    Author            = 'Dewald Pretorius'
    CompanyName       = 'Community'
    Copyright         = '(c) 2026 Dewald Pretorius. All rights reserved.'
    Description       = 'Enterprise Active Directory health assessment, live evidence, reporting, and baseline comparison framework.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'New-AdhFinding',
        'Get-AdhSeverityRank',
        'Invoke-AdhAssessment',
        'Import-AdhSyntheticData',
        'Get-AdhLiveData',
        'New-AdhHtmlReport',
        'Compare-AdhAssessment'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('ActiveDirectory','Health','Assessment','Enterprise','PowerShell')
            ProjectUri = 'https://github.com/IAmLegionVaal/Active-Directory-Health-Check-Toolkit'
        }
    }
}
