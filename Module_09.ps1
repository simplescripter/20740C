# Run the following code on LON-HOST2

#Enable nested virtualization on LON-NVHOST3 and LON-NVHOST4:
$vms = '20740C-LON-NVHOST3','20740C-LON-NVHOST4'
ForEach ($vm in $vms){
	Set-VMProcessor -VMName $vm -ExposeVirtualizationExtensions $true -Count 2
	Set-VMMemory $vm -DynamicMemoryEnabled $false
	Get-VMNetworkAdapter -VMName $vm | Set-VMNetworkAdapter -MacAddressSpoofing On
}

#Start LON-DC1C, LON-NVHOST3, and LON-NVHOST4

Get-VM | Start-VM
$creds = Get-Credential -UserName "adatum\administrator" -Message "Enter the admin password"

# Give the VMs a chance to start

Start-Sleep 20

# Install Hyper-V and wait for the reboot

Invoke-Command -VMName $vms {
    Install-WindowsFeature Failover-Clustering,Hyper-V,Hyper-V-Tools,Hyper-V-PowerShell -Restart -IncludeManagementTools
} -Credential $creds
Write-Host "Waiting for VMs to restart..." -BackgroundColor DarkCyan -NoNewline
For($i=1;$i -le 120;$i++){
    Write-Host '.' -BackgroundColor DarkCyan -NoNewline
    Sleep 1
}
Write-Host ''

Invoke-Command -VMName $vms {
    Set-Service -Name msiscsi -StartupType Automatic
    Start-Service msiscsi
    New-IscsiTargetPortal -TargetPortalAddress 172.16.0.10
    Get-IscsiTarget | Connect-IscsiTarget
} -Credential $creds

Invoke-Command -VMName 20740C-LON-NVHOST4 {
    Initialize-Disk -Number @(1,2,3)
    Get-Disk 1 | New-Volume -FriendlyName "ClusterDisk" -AccessPath "F:"
    Get-Disk 2 | New-Volume -FriendlyName "ClusterVMs" -AccessPath "G:"
    Get-Disk 3 | New-Volume -FriendlyName "Quorum" -AccessPath "H:"
} -Credential $creds

Invoke-Command -VMName 20740C-LON-NVHOST3 {
    1..3 | ForEach {
        Set-Disk -Number $_ -IsOffline $false
    }
    New-Cluster -Name 'VMCluster' -StaticAddress '172.16.0.126' -Node LON-NVHOST3,LON-NVHOST4
} -Credential $creds

