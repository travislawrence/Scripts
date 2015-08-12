# NutanixBuildDatacenter.ps1
# Build vCenter and vSphere environment for Nutanix solutions lab
# v0.5

# Variables
# Pull variable data from text file ***Passwords in plain text - LAB USE ONLY!***
$varVariablesFile = "C:\Server\Packer\Builds\NutanixBuildDatacenterVariables.txt" 
$varVCenterHost = (gc $varVariablesFile | Select-Object -Index 0 | out-string)
$varVCenterUsername = (gc $varVariablesFile | Select-Object -Index 1 | out-string)
$varVCenterPassword = (gc $varVariablesFile | Select-Object -Index 2 | out-string)
$varEsxiUsername = (gc $varVariablesFile | Select-Object -Index 3 | out-string)
$varEsxiPassword = (gc $varVariablesFile | Select-Object -Index 4 | out-string)
$varEsxi55License = (gc $varVariablesFile | Select-Object -Index 5 | out-string)
$vcenterLicense = (gc $varVariablesFile | Select-Object -Index 6 | out-string)

get-date -Format 'u'
$varStartTime=(get-date -Format 'u')

# Deploy vCenter Server Appliance to Nutanix node using vcsa-deploy and JSON file
E:
cd \Server\VCSA\VMware-VCSA-all-6.0.0-2562643\vcsa-cli-installer\win32\
cmd /c "vcsa-deploy.exe --no-esx-ssl-verify E:\Server\VCSA\VCSA-Nutanix.json 1>&2" 2>&1 | %{ "$_" }

# Log VCSA deploy time to console
$varCloneFinish=(get-date -Format 'u')
$varCloneTime=New-TimeSpan $varStartTime $varCloneFinish
$varCloneTimeDisplay="{0:g}" -f $varCloneTime
Write-Host -NoNewline $varCloneTimeDisplay

# Sign in to vCenter
# ***LAB USE ONLY - CREDENTIALS IN CLEAR TEXT***

if(get-item HKLM:\SOFTWARE\Microsoft\PowerShell\1\PowerShellSnapIns\VMware.VimAutomation.Core){
	. ((get-item HKLM:\SOFTWARE\Microsoft\PowerShell\1\PowerShellSnapIns\VMware.VimAutomation.Core).GetValue("ApplicationBase")+"\Scripts\Initialize-PowerCLIEnvironment.ps1")
}
else
{
	write-warning "PowerCLI Path not found in registry, please set path to Initialize-PowerCLIEnvironment.ps1 manually. Is PowerCli aleady installed?"
	. "D:\Programs (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"
}

# Connect to vCenter
Write-Host -Foreground Yellow -NoNewline "Connecting to vCenter $varVCenterHost..."
Connect-VIServer $varVCenterHost -User $varVCenterUsername -Password $varVCenterPassword -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | out-null
if(!$?){
	Write-Host -Foreground Red " Could not connect to $varVCenterHost"
	exit 2
}
else{
	Write-Host -Foreground Green "Connected."
}

New-Datacenter -Location Datacenters -Name CO-Denver
New-Cluster -Location CO-Denver -Name Nutanix01 -DrsEnabled -DrsAutomationLevel FullyAutomated
Add-VMHost -Name 172.24.8.81 -Location Nutanix01 -User $varEsxiUsername -Password $varEsxiPassword -Force
Add-VMHost -Name 172.24.8.82 -Location Nutanix01 -User $varEsxiUsername -Password $varEsxiPassword -Force
Add-VMHost -Name 172.24.8.83 -Location Nutanix01 -User $varEsxiUsername -Password $varEsxiPassword -Force
Add-VMHost -Name 172.24.8.84 -Location Nutanix01 -User $varEsxiUsername -Password $varEsxiPassword -Force

# Add ESXi 5.5 license to Licensing inventory
$si = Get-View ServiceInstance
$LicManRef=$si.Content.LicenseManager
$LicManView=Get-View $LicManRef
$license = New-Object VMware.Vim.LicenseManagerLicenseInfo
$license.LicenseKey = $varEsxi55License 
$license.EditionKey=”esxEnterprisePlus”
$LicManView.AddLicense($license.LicenseKey,$null)

# Add vCenter Server 6.0 license to Licensing inventory
$si = Get-View ServiceInstance
$LicManRef=$si.Content.LicenseManager
$LicManView=Get-View $LicManRef
$license = New-Object VMware.Vim.LicenseManagerLicenseInfo
$license.LicenseKey = $vcenterLicense
$license.EditionKey=”esxEnterprisePlus”
$LicManView.AddLicense($license.LicenseKey,$null)

# Apply vCenter Server 6 Standard license to vCenter Server
$si = Get-View ServiceInstance
$LicManRef=$si.Content.LicenseManager
$LicManView=Get-View $LicManRef
$license = New-Object VMware.Vim.LicenseManagerLicenseInfo
$license.LicenseKey = $vcenterLicense
$LicManView.AddLicense($license.LicenseKey,$null)

$vcLicName = "VMware vCenter Server 6 Standard"
$servInst = Get-View ServiceInstance
$licMgr = Get-View $servInst.Content.licenseManager
$licAssignMgr = Get-View $licMgr.licenseAssignmentManager
$vcUuid = $servInst.Content.About.InstanceUuid
$vcDisplayName = $servInst.Content.About.Name
$vcLicKey = ($licMgr.Licenses | where {$_.Name -eq $vcLicName}).LicenseKey
$licInfo = $licAssignMgr.UpdateAssignedLicense($vcUuid, $vcLicKey,$vcDisplayName)

 # Show the properties of the VC license
 $licInfo.Properties | % {
 $licFeat = $_
 switch($_.Key){
 "feature"{
 $licFeat.Value | % {
 Write-Host $_.Key $_.Value
 }
 }
 Default{
 Write-Host $licFeat.Key $licFeat.Value
 }
 }
 }

# Apply vSphere 5.5 Enterprise Plus licenses to all hosts in cluster
Foreach ($vmhost in (get-vmhost))
{
    $targethostMoRef = (get-VMHost $vmhost | get-view).MoRef
    $si = Get-View ServiceInstance
    $LicManRef=$si.Content.LicenseManager
    $LicManView=Get-View $LicManRef
    $licassman = Get-View $LicManView.LicenseAssignmentManager
    $licassman.UpdateAssignedLicense($targethostMoRef.value,$varEsxi55License,”VMware vSphere 5 Enterprise Plus”)
}

# Display datacenter build time
$varEndTime=(get-date -Format 'u')
$varCompleteTime=New-TimeSpan $varStartTime $varEndTime
$varCompleteTimeDisplay="{0:g}" -f $varCompleteTime
Write-Host -NoNewline $varCompleteTimeDisplay
Write-Host -Foreground Yellow " Build complete!"
get-date -Format 'u'