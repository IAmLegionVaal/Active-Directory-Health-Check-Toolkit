[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
 [switch]$SyncReplication,
 [switch]$RegisterDns,
 [switch]$RestartNetlogon,
 [switch]$RestartDns,
 [switch]$RestartKdc,
 [switch]$DryRun,[switch]$Yes,
 [string]$OutputPath=(Join-Path $env:ProgramData 'ADHealthRepair')
)
$ErrorActionPreference='Stop';$script:Failures=0;$script:Actions=0
$run=Join-Path $OutputPath (Get-Date -Format yyyyMMdd_HHmmss);New-Item -ItemType Directory $run -Force|Out-Null
$log=Join-Path $run 'repair.log';$before=Join-Path $run 'before.txt';$after=Join-Path $run 'after.txt'
function Log($m){"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m"|Tee-Object -FilePath $log -Append}
function Admin{$p=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent());$p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
function State($path){@("Collected: $(Get-Date -Format o)",(& dcdiag.exe /test:Advertising /test:Services /test:SysVolCheck /test:NetLogons 2>&1|Out-String),(& repadmin.exe /replsummary 2>&1|Out-String),(& repadmin.exe /showrepl 2>&1|Out-String),(Get-Service NTDS,Netlogon,DNS,KDC -ErrorAction SilentlyContinue|Format-Table -Auto|Out-String))|Set-Content $path -Encoding UTF8}
function Act($d,[scriptblock]$a){$script:Actions++;Log $d;if($DryRun){Log "DRY-RUN: $d";return};try{&$a;Log "SUCCESS: $d"}catch{$script:Failures++;Log "FAILED: $d - $($_.Exception.Message)"}}
if(-not($SyncReplication -or $RegisterDns -or $RestartNetlogon -or $RestartDns -or $RestartKdc)){Write-Error 'Choose at least one repair action.';exit 2}
if(-not(Get-Service NTDS -ErrorAction SilentlyContinue)){Write-Error 'This workflow must run on a domain controller.';exit 3}
if(-not $DryRun -and -not(Admin)){Write-Error 'Run from elevated PowerShell.';exit 4}
State $before
if(-not $Yes -and -not $DryRun){if((Read-Host 'Apply selected Active Directory repairs on this domain controller? Type YES') -ne 'YES'){Log 'Cancelled.';exit 10}}
if($RestartNetlogon){Act 'Restarting Netlogon' {Restart-Service Netlogon -Force}}
if($RestartDns){Act 'Restarting DNS Server service' {Restart-Service DNS -Force}}
if($RestartKdc){Act 'Restarting Kerberos Key Distribution Center' {Restart-Service KDC -Force}}
if($RegisterDns){Act 'Registering domain controller DNS records' {& ipconfig.exe /registerdns|Out-Null;Restart-Service Netlogon -Force}}
if($SyncReplication){Act 'Synchronising Active Directory replication' {& repadmin.exe /syncall /AdeP|Out-File (Join-Path $run 'repadmin-syncall.txt');if($LASTEXITCODE -ne 0){throw "repadmin exited $LASTEXITCODE"}}}
Start-Sleep 5;State $after
if($script:Failures){Log "Completed with $script:Failures failure(s).";exit 20};Log "Repair completed. Actions: $script:Actions";exit 0
