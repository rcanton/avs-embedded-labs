# AVS Embedded Labs for GPS-US Enablement
# Created by: Roberto Canton
# rcanton@microsoft.com
# July 2022
# Additional Credits:
# William Lam - VMware
# Jon Chancellor - Microsoft (Thanks for the help!)
#
#
 
# ---------------------------------------------------------------------------------------------------------------------------------

$StartTime = Get-Date
$StartTime

$mypath = Get-Location
# Reading from config.yml, setting variables for easier identification
$msg = "Reading from config.yml file"
Write-Host -ForegroundColor Green "$msg"

$option = "$Arg0$($args[0])"
$labnumberfile = "$Arg0$($args[1])"
$a,$b=$labnumberfile.Split(".")
$c,$labNumber=$a.Split("lab")

if ($option -ne "-lab") {
    $msg = "ERROR! You must provide a lab yaml file, for example, labdeploy.ps1 -lab lab1.yml"
    Write-Host -ForegroundColor Red "$msg"
    $labnumberfile

    exit
} elseif ($labnumberfile -NotLike "lab*.yml")  {
    $msg = "A valid yaml file was not found in your arguments. Please enter a valid name for the yaml file, for example, labdeploy.ps1 -lab lab2.yml"
    Write-Host -ForegroundColor Red "$msg"

    exit
} else {
    Function My-Logger {
        param(
        [Parameter(Mandatory=$true)]
        [String]$message
        )

        $timeStamp = Get-Date -Format "MM-dd-yyyy_hh:mm:ss"

        Write-Host -NoNewline -ForegroundColor White "[$timestamp]"
        Write-Host -ForegroundColor Green " $message"
        $logMessage = "[$timeStamp] $message"
        $logMessage
    }

}

[string[]]$fileContent = Get-Content 'config.yml'
$content = ''
foreach ($line in $fileContent) { $content = $content + "`n" + $line }
$config = ConvertFrom-YAML $content

# vCenter Server Variables
$mypath = Get-Location
$msg = "Setting up vCenter Server variables from config.yml"
My-Logger $msg
Write-Host -ForegroundColor Green "$msg"
$vcURLsdk = $config.vCenter.URL 
$a, $b, $vcURL, $c = $vcURLsdk.Split("/")
$a, $b, $c, $d = $vcURL.Split(".")
$a, $groupNumber = $b.Split("10")
$vcUser = $config.vCenter.Username
$vcPass = $config.vCenter.Password
$vcRP = "NestedLabs"
$vcFolder = "NestedLabs"
$vcESXiVMTemplate = $config.vCenter.ESXiVMTemplate
$ESXiTemplateLocation = "${mypath}\Templates\Nested_ESXi67u3.ova"
$vcVCSAVMTemplate = $config.vCenter.VCSAVMTemplate
$VCSATemplateLocation = "${mypath}\Templates\VCSA67-Install\vcsa\VMware-vCenter-Server-Appliance-6.7.0.31000-13643870_OVF10.ova"
$vcNFSVMTemplate = $config.vCenter.NFSVMTemplate 
$NFSTemplateLocation = "${mypath}\Templates\PhotonOS_NFS_Appliance_0.1.0.ova" 
#$vcVyOSVMTemplate = $config.vCenter.VyOSVMTemplate 
#$VYOSTemplateLocation = "${mypath}\Lab-Template-vyos.ova"
$appTemplateLocation = "${mypath}\Templates\app-a-standalone.ova"

$vcDatastore = "vsanDatastore" 
$vcNetworkPrefix = $config.vCenter.NetworkPrefix 

# NSX-T Variables
$msg = "Setting up NSX-T variables from config.yml"
Write-Host -ForegroundColor Green "$msg"
$nsxtHost = $config.NSXT.Host 
$nsxtUser = $config.NSXT.Username
$nsxtPass = $config.NSXT.Password

# DNS Variables
$msg = "Setting up DNS variables from config.yml"
My-Logger $msg
Write-Host -ForegroundColor Green "$msg"
$dnsDomain = $config.DNS.Domain 
$dnsServers = $config.DNS.Servers 
$dnsCloudMgrEndpoint = $config.DNS.CloudManagerEndpoint 

# Connect AVS NSX-T
$msg = "Connecting to AVS NSX-T $nsxtHost"
Write-Host -ForegroundColor Green "$msg"
$nsxtConnection = Connect-NsxtServer -Server ${nsxtHost} -User ${nsxtUser} -Password ${nsxtPass}
$nsxtConnection

# Get Transport Zone ID: Transport Zone Overlay = $tzoneOverlay, Transport Zone Overlay ID = $tzoneOverlayID, tzPath
$msg = "Getting Transport Zone Overlay ID from NSX-T"
Write-Host -ForegroundColor Green "$msg"

$tzSvc = Get-NsxtService -Name com.vmware.nsx.transport_zones
$tzones = $tzSvc.list()
$tzoneOverlay = $tzones.results | Where-Object {$_.display_name -like 'TNT**-OVERLAY-TZ'}
$tzoneOverlayID = $tzoneOverlay.id
$tzoneOverlay = $tzoneOverlay.display_name
$transportZonePolicyService = Get-NsxtPolicyService -Name "com.vmware.nsx_policy.infra.sites.enforcement_points.transport_zones"
$tzPath = ($transportZonePolicyService.list("default","default").results | where {$_.display_name -like "TNT**-OVERLAY-TZ"}).path


# Get Default T1 Gateway
$msg = "Getting NSX-T Default T1 Gateway"
My-Logger $msg
Write-Host -ForegroundColor Green "$msg"
$t1svc = Get-NsxtService -Name com.vmware.nsx.logical_routers
$t1list = $t1Svc.list()
$t1result = $t1list.results | Where-Object {$_.display_name -like 'TNT**-T1'}
$t1ID = $t1result.id
$t1Name = $t1result.display_name

# Connect to AVS vCenter Server
$msg = "Connecting to AVS vCenter Server $vcURL"
Write-Host -ForegroundColor Green "$msg"
$vcConnection = Connect-VIServer -Server ${vcURL} -User $vcUser -Password $vcPass -WarningAction SilentlyContinue
$vcConnection

# Generating a random 8 digit number for the embedded labs
$msg = "Generating a random 8 digit number for the embedded lab"
Write-Host -ForegroundColor Green "$msg"
$random = -join (((65..90)+(97..122)) * 80 | Get-Random -Count 8 | %{[char]$_})
$random = $random.ToLower()
$randomlabID = $random

$labnumberfile = "$Arg1$($args[1])"
if (!$labnumberfile) {
    $msg = "ERROR! You must provide a lab yaml file, for example, labdeploy.ps1 -lab lab1.yml"
    Write-Host -ForegroundColor Red "$msg"

    exit
} elseif ($labnumberfile -NotLike "lab*.yml")  {
    $msg = "A valid yaml file was not found in your arguments. Please enter a valid name for the yaml file, for example, labdeploy.ps1 -lab lab2.yml"
    Write-Host -ForegroundColor Red "$msg"

    exit
} else {
    $a, $b = $labnumberfile.Split(".")
    $c, $labnumber = $a.Split("lab")
    $random = -join (((65..90)+(97..122)) * 80 | Get-Random -Count 8 | %{[char]$_})
    $random = $random.ToLower()
    $randomlabID = $random
    $verboseLogFile = "${mypath}\LabDeployment${groupNumber}${labNumber}.log"

    $msg = "Generating a random number for your embedded lab! - ${randomlabID}"
    Write-Host -ForegroundColor Green "$msg"

    $msg = "Starting embedded environment build for lab number ${labnumber}"
    Write-Host -ForegroundColor Green "$msg"

    # Reading from $args[1] file, setting variables for easier identification
    $msg = "Reading from ${labnumberfile} file"
    Write-Host -ForegroundColor Green "$msg"

    [string[]]$fileContent = Get-Content $labnumberfile
    $content = ''
    foreach ($line in $fileContent) { $content = $content + "`n" + $line }
    $config = ConvertFrom-YAML $content

    # Organizing embedded lab variables from yaml file
    $msg = "Organizing embedded lab variables from ${labnumberfile} yaml file"
    Write-Host -ForegroundColor Green "$msg"

    $labVLAN = $config.VLAN
    $labCIDR = $config.LabCIDR
    $webCIDRName = $config.Workloads.webName
    $webWorkloadVLANid = $config.Workloads.webID
    $webWorkloadGwy = $config.Workloads.webGateway
    $appCIDRName = $config.Workloads.appName
    $appWorkloadVLANid = $config.Workloads.appID
    $appWorkloadGwy = $config.Workloads.appGateway

    #Defining the embedded Lab CIDRs
    $msg = "Defining the embedded Lab CIDRs for Lab ${labNumber}"
    Write-Host -ForegroundColor Green "$msg"

    $o1,$o2,$o3,$o4 = $labCIDR.Split(".")
    $a,$netmask = $o4.Split("/")
    
    $ips = @"
    {
        "uplink": {
            "CIDR": "${o1}.${o2}.${o3}.33/28",
            "DHCP": "${o1}.${o2}.${o3}.44/30",
            "GWY": "${o1}.${o2}.${o3}.33",
            "MASK": "28"
        },
        "storage": {
            "CIDR": "${o1}.${o2}.${o3}.49/28",
            "DHCP": "${o1}.${o2}.${o3}.60/30",
            "GWY": "${o1}.${o2}.${o3}.49",
            "MASK": "28"
        },
        "vmotion": {
            "CIDR": "${o1}.${o2}.${o3}.65/27",
            "DHCP": "${o1}.${o2}.${o3}.92/30",
            "GWY": "${o1}.${o2}.${o3}.65",
            "MASK": "27"
        },
        "replication": {
            "CIDR": "${o1}.${o2}.${o3}.97/27",
            "DHCP": "${o1}.${o2}.${o3}.124/30",
            "GWY": "${o1}.${o2}.${o3}.97",
            "MASK": "27"
        },
        "management": {
            "CIDR": "${o1}.${o2}.${o3}.1/27",
            "DHCP": "${o1}.${o2}.${o3}.28/30",
            "GWY": "${o1}.${o2}.${o3}.1",
            "MASK": "27"
        },
        "wlwan": {
            "CIDR": "${o1}.${o2}.${o3}.129/27",
            "DHCP": "${o1}.${o2}.${o3}.156/30",
            "GWY": "${o1}.${o2}.${o3}.129",
            "MASK": "27"
        },
        "workloadweb": {
            "CIDR": "${o1}.${o2}.1${o3}.1/25",
            "DHCP": "${o1}.${o2}.1${o3}.124/30",
            "GWY": "${o1}.${o2}.1${o3}.1",
            "MASK": "25"
        },
        "workloadapp": {
            "CIDR": "${o1}.${o2}.1${o3}.129/25",
            "DHCP": "${o1}.${o2}.1${o3}.252/30",
            "GWY": "${o1}.${o2}.1${o3}.129",
            "MASK": "25"
        }
    }
"@
    $ipInput = ConvertFrom-Json $ips


    # Create Network Segments in NSX-T
    ## Create all Network Segments
    $msg = "Creating all Networks in AVS NSX-T for Lab ${labNumber}"
    Write-Host -ForegroundColor Green "$msg"

    $networks = @("uplink", "storage", "vmotion", "replication", "management", "wlwan", "workloadweb", "workloadapp")
    $networks | ForEach-Object {
        $network = $_
        $segmentName = "Lab${groupNumber}${labNumber}-${network}-${randomlabID}"
        $gatewayaddress = $ipInput.$_.GWY + "/" + $ipInput.$_.MASK
        $msg = "Creating $segmentName....."
        Write-Host -ForegroundColor Green "$msg"

        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($nsxtUser):$($nsxtPass)"))
        $Header = @{
            Authorization = "Basic $base64AuthInfo"
        }

$Body = @{
    display_name = $segmentName
    subnets = @(
        @{
            gateway_address = $gatewayaddress
        }
    )
    connectivity_path="/infra/tier-1s/" + $t1Name
    transport_zone_path="/infra/sites/default/enforcement-points/default/transport-zones/" + $tzoneOverlayID
}

        $jsonBody = ConvertTo-Json $Body
        $patchSegmentURL = "https://$nsxtHost/policy/api/v1/infra/tier-1s/$t1Name/segments/" + $segmentName
        Invoke-RestMethod -Uri $patchSegmentURL -Headers $Header -Method Patch -Body $jsonBody -ContentType "application/json" -SkipCertificateCheck
        
        $msg = "$segmentName created....."
        Write-Host -ForegroundColor Green "$msg"
        Sleep 20

        # Get Logical Switch Information
        $msg = "Getting Logical Switch Information for $segmentName"
        Write-Host -ForegroundColor Green "$msg"

        $lssvc = Get-NsxtService -Name com.vmware.nsx.logical_switches
        $lslist = $lsSvc.list()
        $lsresult = $lslist.results | Where-Object {$_.display_name -eq "$network"}
        $lsID = $lsresult.id
        $lsName = $lsresult.display_name


#        # Create T1 Uplink Logical Port
#        $msg = "Getting T1 Uplink Logical Port Information"
#        Write-Host -ForegroundColor Green "$msg"
#
#        $lssvc = Get-NsxtService -Name com.vmware.nsx.logical_switches
#        $lslist = $lsSvc.list()
#        $lsresult = $lslist.results | Where-Object {$_.display_name -eq "$network"}
#        $lsID = $lsresult.id
#        $lsName = $lsresult.display_name
#        $LSportName = "${lsName}T1Uplink-LP"
#
#        $uri = "https://${nsxtHost}/policy/api/v1/infra/tier-1s/${t1Name}/segments/${lsName}/ports/${LSportName}"
#
#        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($nsxtUser):$($nsxtPass)"))
#
#        $Header = @{
#            Authorization = "Basic $base64AuthInfo"
#        }
#
#        $Body = @"
#        {
#            "resource_type": "SegmentPort",
#            "id": "${LSportName}",
#            "display_name": "${LSportName}",
#            "path": "/infra/tier-1s/${t1Name}/segments/${lsName}/ports/${LSportName}",
#            "relative_path": "${LSportName}",
#             "parent_path": "/infra/tier-1s/${t1Name}/segments/${lsName}"
#        }
#"@
#
#        Invoke-RestMethod -Uri $uri -Headers $Header -Method Patch -Body $jsonBody -ContentType "application/json" -SkipCertificateCheck
#        Read-Host -Prompt "Press any key to continue"

    }

    # General Deployment Configuration for Nested ESXi, VCSA & NFS VMs
    $msg = "Setting the General Deployment Configuration for Nested ESXi, VCSA & NFS VMs"
    Write-Host -ForegroundColor Green "$msg"

    $VMDatacenter = "SDDC-Datacenter"
    $VMCluster = "Cluster-1"
    $VMResourcePool = "NestedLabs"
    $VMNetwork = "Lab${groupNumber}${labNumber}-management-${randomlabID}"
    $VMDatastore = "vsanDatastore"

    $VMNetmask = "255.255.255.224"
    $VMGateway = $ipInput.management.GWY
    $VMDNS = "1.1.1.1"
    $VMNTP = "pool.ntp.org"
    $VMPassword = "GPSUSavs1!"
    $VMDomain = "avs.lab"
    $VMFolder = "NestedLabs"
    # Applicable to Nested ESXi only
    $VMSSH = "true"
    $VMVMFS = "false"

    # Nested ESXi VMs to deploy
    $msg = "Setting up the Nexted ESXi VMs to deploy"
    Write-Host -ForegroundColor Green "$msg"

    $a,$b,$c,$d=$VMGateway.Split(".")
    $d = [int]$d + 1
    $esxiIP1 = "${a}.${b}.${c}.${d}"
    $NestedESXiHostnameToIPs = @{
    "esxi-${groupNumber}${labNumber}-${randomlabID}" = $esxiIP1
    #"esxi-2" = "192.168.1.12"
    #"esxi-3" = "192.168.1.13"
    }

    # Nested ESXi VM Resources
    $msg = "Setting the Nested ESXi VM Resources"
    Write-Host -ForegroundColor Green "$msg"

    $NestedESXivCPU = "4"
    $NestedESXivMEM = "24" #GB
    $NestedESXiCachingvDisk = "8"
    $NestedESXiCapacityvDisk = "100"
    
    # Deploy Nested ESXi VM
    $ESXiVMName = "Lab-${randomlabnumber}-esxi-${groupNumber}${labNumber}"

    if(!(Test-Path $ESXiTemplateLocation)) {
        Write-Host -ForegroundColor Red "`nUnable to find $ESXiTemplateLocation ...`n"
        exit
    }

    $esxiTotalStorage = [int]$NFSCapacity

    $msg = "Connecting to Management (AVS) vCenter Server $vcURL ..."
    Write-Host -ForegroundColor Green "$msg"

    $viConnection = Connect-VIServer $vcURL -User $vcUser -Password $vcPass -WarningAction SilentlyContinue

    $msg = "Creating $vcRP if it does not exist ......"
    Write-Host -ForegroundColor Green "$msg"

    if(-Not (Get-ResourcePool -Name $vcRP -ErrorAction Ignore)) {
        New-ResourcePool -Location 'Cluster-1' -Name $vcRP
    }

    $datastore = Get-Datastore -Server $viConnection -Name $vcDatastore | Select -First 1
    $resourcepool = Get-ResourcePool -Server $viConnection -Name $vcRP
    $cluster = Get-Cluster -Server $viConnection -Name 'Cluster-1'
    $datacenter = $cluster | Get-Datacenter
    $vmhost = $cluster | Get-VMHost | Select -First 1

    $NestedESXiHostnameToIPs.GetEnumerator() | Sort-Object -Property Value | Foreach-Object {
        $VMName = $_.Key
        $VMIPAddress = $_.Value

        $ovfconfig = Get-OvfConfiguration $ESXiTemplateLocation
        $ovfNetworkLabel = ($ovfconfig.NetworkMapping | Get-Member -MemberType Properties).Name
        $ovfconfig.NetworkMapping.$ovfNetworkLabel.value = $VMNetwork

        $ovfconfig.common.guestinfo.hostname.value = $VMName
        $ovfconfig.common.guestinfo.ipaddress.value = $VMIPAddress
        $ovfconfig.common.guestinfo.netmask.value = $VMNetmask
        $ovfconfig.common.guestinfo.gateway.value = $VMGateway
        $ovfconfig.common.guestinfo.dns.value = $VMDNS
        $ovfconfig.common.guestinfo.domain.value = $VMDomain
        $ovfconfig.common.guestinfo.ntp.value = $VMNTP
        $ovfconfig.common.guestinfo.syslog.value = $VMSyslog
        $ovfconfig.common.guestinfo.password.value = $VMPassword
        if($VMSSH -eq "true") {
            $VMSSHVar = $true
        } else {
            $VMSSHVar = $false
        }
        $ovfconfig.common.guestinfo.ssh.value = $VMSSHVar

        $msg = "Deploying Nested ESXi VM $VMName ..."
        Write-Host -ForegroundColor Green "$msg"

        $vm = Import-VApp -Source $ESXiTemplateLocation -OvfConfiguration $ovfconfig -Name $VMName -Location $resourcepool -VMHost $vmhost -Datastore $datastore -DiskStorageFormat thin -Force

        $msg = "Adding vmnic2/vmnic3 to $VMNetwork ..."
        Write-Host -ForegroundColor Green "$msg"

        New-NetworkAdapter -VM $vm -Type Vmxnet3 -NetworkName $VMNetwork -StartConnected -confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        New-NetworkAdapter -VM $vm -Type Vmxnet3 -NetworkName $VMNetwork -StartConnected -confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

        $msg = "Updating vCPU Count to $NestedESXivCPU & vMEM to $NestedESXivMEM GB ..."
        Write-Host -ForegroundColor Green "$msg"

        Set-VM -Server $viConnection -VM $vm -NumCpu $NestedESXivCPU -MemoryGB $NestedESXivMEM -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

        $msg = "Powering On $VMname ..."
        Write-Host -ForegroundColor Green "$msg"
        
        $vm | Start-Vm -RunAsync | Out-Null

    }

    # Deploy VCSA VM
    $VCSAInstallerPath = $VCSATemplateLocation
    $a,$b,$c,$d=$esxiIP1.Split(".")
    $d = [int]$d + 1
    $vcsaIP = "${a}.${b}.${c}.${d}"

    # VCSA Deployment Configuration
    $msg = "Gathering VCSA Configuration Information"
    Write-Host -ForegroundColor Green "$msg"

    $VCSADeploymentSize = "tiny"
    $VCSADisplayName = "vcsa-${groupNumber}${labNumber}-${randomlabID}"
    $VCSAIPAddress = $vcsaIP
    $VCSAHostname = $vcsaIP
    $VCSAPrefix = $ipInput.management.MASK
    $VCSASSODomainName = "vsphere.local"
    $VCSASSOPassword = "GPSUSavs1!"
    $VCSARootPassword = "GPSUSavs1!"
    $VCSASSHEnable = "true"

    $VCSAInstallerPath = "$($mypath)\Templates\VCSA67-Install"
    $config = (Get-Content -Raw "$VCSAInstallerPath\vcsa-cli-installer\templates\install\embedded_vCSA_on_VC.json") | ConvertFrom-Json

    $config.'new_vcsa'.vc.hostname = $vcURL
    $config.'new_vcsa'.vc.username = $vcUser
    $config.'new_vcsa'.vc.password = $vcPass
    $config.'new_vcsa'.vc.deployment_network = $VMNetwork
    $config.'new_vcsa'.vc.datastore = $datastore
    $config.'new_vcsa'.vc.datacenter = $datacenter.name
    $config.'new_vcsa'.appliance.thin_disk_mode = $true
    $config.'new_vcsa'.appliance.deployment_option = $VCSADeploymentSize
    $config.'new_vcsa'.appliance.name = $VCSADisplayName
    $config.'new_vcsa'.network.ip_family = "ipv4"
    $config.'new_vcsa'.network.mode = "static"
    $config.'new_vcsa'.network.ip = $VCSAIPAddress
    $config.'new_vcsa'.network.dns_servers[0] = $VMDNS
    $config.'new_vcsa'.network.prefix = $VCSAPrefix
    $config.'new_vcsa'.network.gateway = $VMGateway
    $config.'new_vcsa'.os.ntp_servers = $VMNTP
    $config.'new_vcsa'.network.system_name = $VCSAHostname
    $config.'new_vcsa'.os.password = $VCSARootPassword
    if($VCSASSHEnable -eq "true") {
        $VCSASSHEnableVar = $true
    } else {
        $VCSASSHEnableVar = $false
    }
    $config.'new_vcsa'.os.ssh_enable = $VCSASSHEnableVar
    $config.'new_vcsa'.sso.password = $VCSASSOPassword
    $config.'new_vcsa'.sso.domain_name = $VCSASSODomainName

    # Hack due to JSON depth issue
    $config.'new_vcsa'.vc.psobject.Properties.Remove("target")
    $config.'new_vcsa'.vc | Add-Member NoteProperty -Name target -Value "REPLACE-ME"


    if($IsWindows) {
        $msg = "Creating VCSA JSON Configuration file for deployment ..."
        Write-Host -ForegroundColor Green "$msg"

        $config | ConvertTo-Json | Set-Content -Path "$($ENV:Temp)\jsontemplate.json" | ConvertTo-Json -Depth 9

        $target = "[`"$VMCluster`",`"Resources`",`"$VMResourcePool`"]"
        (Get-Content -path "$($ENV:Temp)\jsontemplate.json" -Raw) -replace '"REPLACE-ME"',$target | Set-Content -path "$($ENV:Temp)\jsontemplate.json"

        $msg = "Deploying the VCSA. Be patient this may take about 20 minutes on average to deploy......."
        Write-Host -ForegroundColor Green "$msg"

        Invoke-Expression "$($VCSAInstallerPath)\vcsa-cli-installer\win32\vcsa-deploy.exe install --no-ssl-certificate-verification --accept-eula --acknowledge-ceip $($ENV:Temp)\jsontemplate.json"| Out-File -Append -LiteralPath $verboseLogFile
        
    } elseif($IsMacOS) {
        $msg = "Creating VCSA JSON Configuration file for deployment ..."
        Write-Host -ForegroundColor Green "$msg"

        $config | ConvertTo-Json | Set-Content -Path "$($ENV:TMPDIR)jsontemplate.json"

        $msg = "Deploying the VCSA. Be patient this may take about 20 minutes on average to deploy......."
        Write-Host -ForegroundColor Green "$msg"

        Invoke-Expression "$($VCSAInstallerPath)/vcsa-cli-installer/mac/vcsa-deploy install --no-ssl-certificate-verification --accept-eula --acknowledge-ceip $($ENV:TMPDIR)jsontemplate.json"| Out-File -Append -LiteralPath $verboseLogFile

    } elseif ($IsLinux) {
        $msg = "Creating VCSA JSON Configuration file for deployment ..."
        Write-Host -ForegroundColor Green "$msg"

        $config | ConvertTo-Json | Set-Content -Path "/tmp/jsontemplate.json"

        $msg = "Deploying the VCSA. Be patient this may take about 20 minutes on average to deploy......."
        Write-Host -ForegroundColor Green "$msg"

        Invoke-Expression "$($VCSAInstallerPath)/vcsa-cli-installer/lin64/vcsa-deploy install --no-ssl-certificate-verification --accept-eula --acknowledge-ceip /tmp/jsontemplate.json"| Out-File -Append -LiteralPath $verboseLogFile

    }

    # Deploy NFS VM
    $PhotonNFSOVA = $NFSTemplateLocation
    $msg = "Gathering settings for NFS VM"
    Write-Host -ForegroundColor Green "$msg"

    $a,$b,$c,$d=$VCSAIPAddress.Split(".")
    $d = [int]$d + 1
    $nfsIP = "${a}.${b}.${c}.${d}"

    $NFSVMDisplayName = "nfs-${groupNumber}${labNumber}-${randomlabID}"
    $NFSVMHostname = $NFSVMDisplayName
    $NFSVMIPAddress = $nfsIP

    $VMNetwork = "Lab${groupNumber}${labNumber}-management-${randomlabID}"
    $NFSVMPrefix = $ipInput.management.MASK
    $NFSVMRootPassword = "GPSUSavs1!"
    $NFSVMVolumeLabel = "nfs"
    $NFSVMCapacity = "100" #GB

    $ovfconfig = Get-OvfConfiguration $NFSTemplateLocation
    $ovfNetworkLabel = ($ovfconfig.NetworkMapping | Get-Member -MemberType Properties).Name
    $ovfconfig.NetworkMapping.$ovfNetworkLabel.value = $VMNetwork

    $ovfconfig.common.guestinfo.hostname.value = $NFSVMHostname
    $ovfconfig.common.guestinfo.ipaddress.value = $NFSVMIPAddress
    $ovfconfig.common.guestinfo.netmask.value = $NFSVMPrefix
    $ovfconfig.common.guestinfo.gateway.value = $VMGateway
    $ovfconfig.common.guestinfo.dns.value = $VMDNS
    $ovfconfig.common.guestinfo.domain.value = $VMDomain
    $ovfconfig.common.guestinfo.root_password.value = $NFSVMRootPassword
    $ovfconfig.common.guestinfo.nfs_volume_name.value = $NFSVMVolumeLabel
    $ovfconfig.Common.disk2size.value = $NFSVMCapacity

    $msg = "Deploying PhotonOS NFS VM $NFSVMDisplayName ..."
    Write-Host -ForegroundColor Green "$msg"

    $vm = Import-VApp -Source $PhotonNFSOVA -OvfConfiguration $ovfconfig -Name $NFSVMDisplayName -Location $resourcepool -VMHost $vmhost -Datastore $datastore -DiskStorageFormat thin -Force

    $msg = "Powering On $NFSVMDisplayName ..."
    Write-Host -ForegroundColor Green "$msg"

    $vm | Start-Vm -RunAsync | Out-Null
    Sleep 90
    Get-VM $NFSVMDisplayName | New-NetworkAdapter -NetworkName $VMNetwork -StartConnected

    # Create and Move VMs into vApp
    $VAppName = "Nested-SDDC-Lab-${groupNumber}${labNumber}"

    $msg = "Creating vApp $VAppName ..."
    Write-Host -ForegroundColor Green "$msg"

    $VApp = New-VApp -Name $VAppName -Server $viConnection -Location $resourcepool

    if(-Not (Get-Folder $VMFolder -ErrorAction Ignore)) {
        $msg = "Creating VM Folder $VMFolder ..."
        Write-Host -ForegroundColor Green "$msg"

        $folder = New-Folder -Name $VMFolder -Server $viConnection -Location (Get-Datacenter $VMDatacenter | Get-Folder vm)

    }
    
    ## Moving NFS VM to vApp
    $nfsVM = Get-VM -Name $NFSVMDisplayName -Server $viConnection
    $msg = "Moving $NFSVMDisplayName into $VAppName vApp ..."
    Write-Host -ForegroundColor Green "$msg"

    Move-VM -VM $nfsVM -Server $viConnection -Destination $VApp -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

    #$msg = "Rebooting NFS VM - $nfsVM ..."
    #Write-Host -ForegroundColor Green "$msg"
    #Restart-VM -VM $nfsVM -Confirm:$false
    #Sleep 60


    ## Moving the ESXi VM to vApp
    $NestedESXiHostnameToIPs.GetEnumerator() | Sort-Object -Property Value | Foreach-Object {
        $vm = Get-VM -Name $_.Key -Server $viConnection
        Move-VM -VM $vm -Server $viConnection -Destination $VApp -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

        #$msg = "Rebooting ESXi VM - $vm ..."
        #Write-Host -ForegroundColor Green "$msg"
        #Restart-VM -VM $vm -Confirm:$false
        #Sleep 60

    }

    ## Moving the VCSA VM to vApp
    $vcsaVM = Get-VM -Name $VCSADisplayName -Server $viConnection
    $msg = "Moving $VCSADisplayName into $VAppName vApp ..."
    Write-Host -ForegroundColor Green "$msg"

    Move-VM -VM $vcsaVM -Server $viConnection -Destination $VApp -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

    $msg = "Moving $VAppName to VM Folder $VMFolder ..."
    Write-Host -ForegroundColor Green "$msg"

    Move-VApp -Server $viConnection $VAppName -Destination (Get-Folder -Server $viConnection $VMFolder) | Out-File -Append -LiteralPath $verboseLogFile

    $msg = "Disconnecting from AVS vCenter $vcURL ..."
    Write-Host -ForegroundColor Green "$msg"

    Disconnect-VIServer -Server $viConnection -Confirm:$false

    $msg = "Connecting to the new VCSA ..."
    Write-Host -ForegroundColor Green "$msg"

    $vc = Connect-VIServer $VCSAIPAddress -User "administrator@$VCSASSODomainName" -Password $VCSASSOPassword -WarningAction SilentlyContinue -Force

    # Name of new vSphere Datacenter/Cluster when VCSA is deployed
    $msg = "Setting names of new vSphere Datacenter/Cluster when Embedded VCSA is deployed"
    Write-Host -ForegroundColor Green "$msg"

    $NewVCDatacenterName = "OnPrem-Datacenter-${groupNumber}${labNumber}"
    $NewVCVSANClusterName = "OnPrem-Cluster-${groupNumber}${labNumber}"
    $NewVCVDSName = "OnPrem-VDS-${groupNumber}${labNumber}"
    $NewVCMgmtDVPGName = "management"
    $NewVCvMotionDVPGName = "vmotion"
    $NewVCReplicationDVPGName = "replication"
    $NewVCUplinkDVPGName = "uplink"
    $NewVCWorkloadDVPGName = "workload"
    $NewVCWorkloadVMFormat = "OnPrem-Workload-${groupNumber}${labNumber}"
    $NewVcWorkloadVMCount = 1

    $d = Get-Datacenter -Server $vcsaIP $NewVCDatacenterName -ErrorAction Ignore
    if( -Not $d) {
        $msg = "Creating Datacenter $NewVCDatacenterName ..."
        Write-Host -ForegroundColor Green "$msg"

        New-Datacenter -Server $vcsaIP -Name $NewVCDatacenterName -Location (Get-Folder -Type Datacenter -Server $vcsaIP) | Out-File -Append -LiteralPath $verboseLogFile

    }

    $c = Get-Cluster -Server $vcsaIP $NewVCVSANClusterName -ErrorAction Ignore
    if( -Not $c) {
        $msg = "Creating vSphere Cluster $NewVCVSANClusterName ..."
        Write-Host -ForegroundColor Green "$msg"

        New-Cluster -Server $vcsaIP -Name $NewVCVSANClusterName -Location (Get-Datacenter -Name $NewVCDatacenterName -Server $vcsaIP) -DrsEnabled

    }

    $NestedESXiHostnameToIPs.GetEnumerator() | Sort-Object -Property Value | Foreach-Object {
        $VMName = $_.Key
        $VMIPAddress = $_.Value

        $targetVMHost = $VMIPAddress
        if($addHostByDnsName -eq 1) {
            $targetVMHost = $VMName
        }

        $msg = "Adding ESXi host $targetVMHost to Cluster ..."
        Write-Host -ForegroundColor Green "$msg"

        Add-VMHost -Server $vcURL -Location (Get-Cluster -Name $NewVCVSANClusterName) -User "root" -Password $VMPassword -Name $targetVMHost -Force | Out-File -Append -LiteralPath $verboseLogFile

    }

    $msg = "Adding NFS Storage ..."
    Write-Host -ForegroundColor Green "$msg"

    foreach ($vmhost in Get-Cluster -Server $vcsaIP | Get-VMHost) {
        New-Datastore -VMHost $vmhost -Nfs -Name $NFSVMVolumeLabel -Path /mnt/${NFSVMVolumeLabel} -NfsHost $NFSVMIPAddress
    }

    $vds = New-VDSwitch -Server $vcsaIP -Name $NewVCVDSName -Location (Get-Datacenter -Name $NewVCDatacenterName) -Mtu 1600

    $msg = "Creating Portgroups for $vcsaIP ..."
    Write-Host -ForegroundColor Green "$msg"

    New-VDPortgroup -Server $vcsaIP -Name $NewVCMgmtDVPGName -Vds $vds | Out-File -Append -LiteralPath $verboseLogFile
    New-VDPortgroup -Server $vcsaIP -Name $NewVCWorkloadDVPGName -Vds $vds | Out-File -Append -LiteralPath $verboseLogFile
    New-VDPortgroup -Server $vcsaIP -Name $NewVCvMotionDVPGName -Vds $vds | Out-File -Append -LiteralPath $verboseLogFile
    New-VDPortgroup -Server $vcsaIP -Name $NewVCReplicationDVPGName -Vds $vds | Out-File -Append -LiteralPath $verboseLogFile
    New-VDPortgroup -Server $vcsaIP -Name $NewVCUplinkDVPGName -Vds $vds | Out-File -Append -LiteralPath $verboseLogFile

    foreach ($vmhost in Get-Cluster -Server $vcsaIP | Get-VMHost) {
        $msg = "Adding $vmhost to $NewVCVDSName"
        Write-Host -ForegroundColor Green "$msg"

        $vds | Add-VDSwitchVMHost -VMHost $vmhost | Out-Null

        $vmhostNetworkAdapter = Get-VMHost $vmhost | Get-VMHostNetworkAdapter -Physical -Name vmnic1
        $vds | Add-VDSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter $vmhostNetworkAdapter -Confirm:$false
    }

    # Final configure and then exit maintenance mode in case patching was done earlier
    $msg = "Final configuration beginning"
    Write-Host -ForegroundColor Green "$msg"

    foreach ($vmhost in Get-Cluster -Server $vcsaIP | Get-VMHost) {
        # Disable Core Dump Warning
        Get-AdvancedSetting -Entity $vmhost -Name UserVars.SuppressCoredumpWarning | Set-AdvancedSetting -Value 1 -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

        # Enable vMotion traffic
        $vmhost | Get-VMHostNetworkAdapter -VMKernel | Set-VMHostNetworkAdapter -VMotionEnabled $true -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

        if($vmhost.ConnectionState -eq "Maintenance") {
            Set-VMHost -VMhost $vmhost -State Connected -RunAsync -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        }
    }

    if($deployWorkload -eq 1) {
        $vmhost = Get-Cluster -Server $vcsaIP | Get-VMHost | Select -First 1
        $datastore = Get-Datastore -Server $vcsaIP

        $ovfconfig = Get-OvfConfiguration -Server $vcsaIP $appTemplateLocation
        $ovfNetworkLabel = ($ovfconfig.NetworkMapping | Get-Member -MemberType Properties).Name
        $ovfconfig.NetworkMapping.$ovfNetworkLabel.value = $NewVCWorkloadDVPGName

        foreach ($i in 1..$NewVcWorkloadVMCount) {
            $VMName = "${NewVCWorkloadVMFormat}"
            $vm = Import-VApp -Server $vcsaIP -Source $appTemplateLocation -OvfConfiguration $ovfconfig -Name $VMName -VMHost $VMhost -Datastore $Datastore -DiskStorageFormat thin -Force
            $vm | Start-VM -Server $vcsaIP -Confirm:$false | Out-Null
        }
    }

    $msg = "Disconnecting from new VCSA ..."
    Write-Host -ForegroundColor Green "$msg"

    Disconnect-VIServer $vcsaIP -Confirm:$false

    $EndTime = Get-Date
    $duration = [math]::Round((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes,2)
    
    $msg = "Nested SDDC Lab Deployment Complete!"
    Write-Host -ForegroundColor Green "$msg"

    $msg = "StartTime: $StartTime"
    Write-Host -ForegroundColor Green "$msg"

    $msg = "  EndTime: $EndTime"
    Write-Host -ForegroundColor Green "$msg"

    $msg = " Duration: $duration minutes"
    Write-Host -ForegroundColor Green "$msg"
}

$EndTime = Get-Date
$EndTime