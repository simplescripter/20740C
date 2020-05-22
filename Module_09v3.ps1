# Run the following code on LON-HOST2 in MOC 20740C Module 9 Lab to prepare the environment

#Enable nested virtualization on LON-NVHOST3 and LON-NVHOST4:
$vms = '20740C-LON-NVHOST4','20740C-LON-NVHOST3'
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

ForEach ($vm in $vms){
    Do{
        Try{
            $done = $true
            Write-Host "Waiting for $vm to restart..." -BackgroundColor DarkCyan
            Start-Sleep 10
            Invoke-Command -VMName $vm {
                Set-Service -Name msiscsi -StartupType Automatic
                Start-Service msiscsi
                New-IscsiTargetPortal -TargetPortalAddress 172.16.0.10
                Get-IscsiTarget | Connect-IscsiTarget
            } -Credential $creds -ErrorAction Stop
        }Catch{
            $done = $false
        }
    }Until($done -eq $true)
}

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

