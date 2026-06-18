#requires -Version 5.1
<#
.SYNOPSIS
    Active Directory Health Check Toolkit.
.DESCRIPTION
    Read-only AD domain health context reporter for L2/L3 support.
#>
[CmdletBinding()]
param([string]$OutputPath)
$RunStamp=Get-Date -Format 'yyyyMMdd_HHmmss'
if([string]::IsNullOrWhiteSpace($OutputPath)){$OutputPath=Join-Path ([Environment]::GetFolderPath('Desktop')) 'AD_Health_Reports'}
New-Item -Path $OutputPath -ItemType Directory -Force|Out-Null
function Export-Data{param($Name,$Data)$Data|Export-Csv (Join-Path $OutputPath "$Name.csv") -NoTypeInformation -Encoding UTF8;$Data|ConvertTo-Json -Depth 6|Set-Content (Join-Path $OutputPath "$Name.json") -Encoding UTF8}
try{Import-Module ActiveDirectory -ErrorAction Stop}catch{Write-Error 'ActiveDirectory module not found. Install RSAT AD tools.';return}
$domain=Get-ADDomain;$forest=Get-ADForest;$dcs=Get-ADDomainController -Filter *|Select-Object HostName,Site,IPv4Address,OperatingSystem,IsGlobalCatalog,OperationMasterRoles
Export-Data "domain_$RunStamp" @($domain|Select-Object DNSRoot,NetBIOSName,DomainMode,PDCEmulator,RIDMaster,InfrastructureMaster)
Export-Data "forest_$RunStamp" @($forest|Select-Object Name,ForestMode,SchemaMaster,DomainNamingMaster,GlobalCatalogs,Domains)
Export-Data "domain_controllers_$RunStamp" $dcs
$checks=@()
foreach($dc in $dcs){$sysvol="\\$($dc.HostName)\SYSVOL";$netlogon="\\$($dc.HostName)\NETLOGON";$checks+=[PSCustomObject]@{DC=$dc.HostName;SYSVOL=Test-Path $sysvol;NETLOGON=Test-Path $netlogon;Site=$dc.Site;GlobalCatalog=$dc.IsGlobalCatalog}}
Export-Data "dc_share_checks_$RunStamp" $checks
try{Resolve-DnsName -Type SRV "_ldap._tcp.dc._msdcs.$($domain.DNSRoot)"|Select-Object Name,Type,NameTarget,Priority,Port|Export-Csv (Join-Path $OutputPath "dns_srv_$RunStamp.csv") -NoTypeInformation -Encoding UTF8}catch{}
try{repadmin.exe /replsummary | Out-File (Join-Path $OutputPath "repadmin_replsummary_$RunStamp.txt") -Encoding UTF8}catch{}
$html="<h1>AD Health Check - $($domain.DNSRoot)</h1><p>Generated $(Get-Date)</p><h2>Domain Controllers</h2>$($dcs|ConvertTo-Html -Fragment)<h2>Share Checks</h2>$($checks|ConvertTo-Html -Fragment)"
$html|ConvertTo-Html -Title 'AD Health Check'|Set-Content (Join-Path $OutputPath "ad_health_$RunStamp.html") -Encoding UTF8
$checks|Format-Table -AutoSize
Write-Host "Reports saved to: $OutputPath" -ForegroundColor Green
Start-Process explorer.exe -ArgumentList "`"$OutputPath`"" -ErrorAction SilentlyContinue
