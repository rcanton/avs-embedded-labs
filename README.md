# How to build SDDCs in GBB subscription and Embedded Labs

## AVS SDDCs builds

> Please keep in mind these instructions have been built for the purpose of having Hands-On exercises for partners. Your use and setup may vary depending on your own needs, this is just guidance.

Limits: Up to 10 SDDCs can be deployed at once. Check with the other members of the ESLZ group to ensure there's enough capacity and in what regions.

Under the .\parameters folder, you will find 10 .json files. You are free to edit these as needed but the CIDRs we use are consitent numbering for a lot of the further automation to function properly, so keep this in mind when changing the CIDR definitions of these files.

### JSON files

![](/images/embedded1.png)

1. Each of these files represent one (1) SDDC. Up to 10 SDDCs at once could be deployed using this automation.
2. The first parameter to edit is the "Location" which represents the Azure region where the AVS SDDC will be deployed, in this example it's brazilsouth.
3. The prefix to assign to the resources/resource groups. For partner hands-on labs, we recommend including the partner name, for example: GPSUS-XYZ1 for the first AVS SDDC.
4. Add the private cloud IP space. We in GPSUS have standardized this with this format: 10.101.0.0/22 where the last digit of the secont octet represents the SDDC number, in this example the last '1' in 101.
5. VNetAddressSpace: same as #4 where the last digit of the second octet represents the SDDC number.
6. VNetGatewaySubnet.
7. AlertEmails: Enter your email to get notified when the AVS SDDC is completed.
8. DeployJumpbox: Enter 'true' if you would like the automation to deploy a Jumpbox for you, otherwise, enter 'false'.
9. JumpboxUsername: Enter a name for the admin user for your Jumpbox.
10. JumpboxPassword: Enter a desired password for your jumpbox.
11. JumpboxSubnet: Edit as desired.
12. BastionSubnet: Edit as desired.
13. VNetExists: Default value is 'false' and will create a VNet.
14. DeployHCX: Default value is 'false', change it if you would like the automation to enable HCX for you.
15. DeploySRM: Default value is 'false', change it if you would like the automation to enable SRM for you.

### Start Deployments

Make sure to be logged in to the right subscription and tenant. To display your current login's subscription/tenant run the following command:

```
az account show
```
If your subscription/tenant need to be switched, run the following command to switch to the GBB subscription:
```
az login --tenant 8cb3390f-7308-4b0a-a113-432138b927aa
```

#### Preparing the deploy parameter files

The CLI deployment uses two files, the ESLZDeploy.deploy.json which contains the ARM template itself and the its counterpart a parameter file for example: `ESLZDeploy.parameters.json` Modify this file to define desired prefix, location, networking, alert emails and others... Usually for a hands-on workshop you might need more than a single deployment. In this case we recommend to prepare the different parameters files beforehand with the right prefix. For example see the files under the \parameters.

Once you've edited the JSON files, it's time to start the deployments of your AVS SDDCs by issuing the following command from a terminal:

```
az deployment sub create -l brazilsouth -n "202209200928-GPSUS-PARTNER1" -f ".\parameters\deploy\ESLZDeploy.deploy.json" -p "@.\parameters\avs-1.json"
```
Run the above command for each SDDC you'd like to build. If you don't want to wait for each process to finish or open multiple terminal sessions, add the --no-wait option as follows:
```
az deployment sub create -l brazilsouth -n "202209200928-GPSUS-PARTNER1" -f "ESLZDeploy.deploy.json" -p "@.\parameters\avs-1.json" --no-wait
```

> **IMPORTANT**: It's recommended that you create a unique name for your deployment. In our example above, we start the deployment name with the time stamp in the following format: YYYYMMDDHHMM. It's highly recommended to follow this format as if your deployment fails, subsequent tries may fail if you try to deploy them with the same name or another deployment with the same name is already running.

#### Add roles to participant accounts

There are 10 accounts in the GBB subscription we utilize to hand out to participants:

> Group#@vmwaresales101outlook.onmicrosoft.com - Replace "#" with numbers 1 through 10.

These accounts will need to have roles assigned to them in order to be able to perform the work in the newly created resource groups. You will need to run the following commands to assign the roles to each of the accounts. This example reflects for account 1:

```
az role assignment create --assignee "Group1@vmwaresales101outlook.onmicrosoft.com" --role "Contributor" --resource-group GPSUS-PARTNER1-Jumpbox

az role assignment create --assignee "Group1@vmwaresales101outlook.onmicrosoft.com" --role "Contributor" --resource-group GPSUS-PARTNER1-Network

az role assignment create --assignee "Group1@vmwaresales101outlook.onmicrosoft.com" --role "Contributor" --resource-group GPSUS-PARTNER1-Operational

az role assignment create --assignee "Group1@vmwaresales101outlook.onmicrosoft.com" --role "Contributor" --resource-group GPSUS-PARTNER1-PrivateCloud
```

#### Change passwords for user accounts

You will also need to change the passwords for these accounts:

```
az ad user update --id Group1@vmwaresales101outlook.onmicrosoft.com  --password "NewPassword" --force-change-password-next-sign-in false
```

> SECTION NOT COMPLETED YET, WILL COMPLETE SOON

## Embedded Lab Builds

Files used to deploy embedded simulated on-premises environments to AVS SDDCs.

Download zip file and extract in a directory where you'll be working from in the assigned Jumpbox.

Location of zip file to download to Jumpbox:
https://gpsusstorage.blob.core.windows.net/avs-embedded-labs/avs-embedded-labs.zip

### Items needed to prepare Jumpbox

- Ensure your AVS SDDC has internet access enabled.
- If your AVS SDDC /22 range's second octet is anywhere between 1-10, then this will conflict with the defaults being used by the script. We recommend setting the second octect to the 100's to avoid this conflict. If this cannot be done, you will need to edit the script before running it to avoid IP conflicts.

#### Install PowerShell Core (7)
Run the following one-liner from Windows PowerShell
```
iex "& { $(irm 'https://aka.ms/install-powershell.ps1') } -UseMSI -Quiet"
```
Reference: https://github.com/PowerShell/PowerShell

> Once installed, all further operations should be performed from **PowerShell Core**, not Windows PowerShell.

> PowerShell Core should be a black icon with a black background, if you have a light blue background, you're using the old version of PowerShell, it should have been added to your Start menu.

#### Commands to Run from PowerShell 7
```
# Change PowerShell ExecutionPolicy
Set-ExecutionPolicy Unrestricted

# Install VMware PowerCLI
Install-Module VMware.PowerCLI -scope AllUsers -Force -SkipPublisherCheck -AllowClobber

# Configure PowerCLI
Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

# Install YAML PowerShell Module
Install-Module powershell-yaml -Force
```

#### Edit nestedlabs.yml file

1. Open the nestedlabs.yml file with a text editor from your working directory.
2. Enter the information for:
    - AVS vCenter URL
    - AVS Username
    - AVS cloudadmin password
    - AVS NSX-T URL
    - AVS NSX-T Username
    - AVS NSX-T cloudadmin password

> If you need advanced text editor, you can either install VSCode, or use the online version through Internet browser (**Edge**) by going to https://vscode.dev

#### Ready for Deployment

At this point you're ready to start deploying the nested environments. You will run the following command from your Jumpbox's PowerShell Core window:
```
.\labdeploy.ps1 -group 1 -lab 1
```
> **IMPORTANT** - This numbering sequence (for groups and labs) where created for the purposes of enabling partner groups (many at a time), therefore it may not map directly to your needs.

The group and lab number you specify when you run the script will determine the IP address schemes of the nested environments very similar to the following table:


| **Group** | **Lab** | **vCenter IP** | **Username**                | **Password** | **Web workload IP**|
| --------- | --------------- | -------------- | --------------------------- | ------------ | ------------------- |
| **X**         | **Y**               | 10.**X**.**Y**.2       | administrator@avs.lab | MSFTavs1! | 10.**X**.1**Y**.1/25 |

#### Example for Group 1 with 4 participants

| **Group** | **Lab** | **vCenter IP** | **Username**                | **Password** | **Web workload IP**|
| --------- | --------------- | -------------- | --------------------------- | ------------ | ------------------- |
| 1         | 1               | 10.1.1.2       | administrator@avs.lab | MSFTavs1! | 10.1.11.1/25 |
| 1         | 2               | 10.1.2.2       | administrator@avs.lab | MSFTavs1! | 10.1.12.1/25 |
| 1         | 3               | 10.1.3.2       | administrator@avs.lab | MSFTavs1! | 10.1.13.1/25 |
| 1         | 4               | 10.1.4.2       | administrator@avs.lab | MSFTavs1! | 10.1.14.1/25 |

### What gets deployed?

![](/images/image1.png)

1. A NestedLabs Resource group is created in the AVS vCenter.
2. Each "Lab" is grouped into its own vApp inside of vCenter for organizational purposes. It will use the group number and the lab number to identify which one it is using. For example you use group 1 lab 1, that would be 11 as in the above example.
3. It deploys the following VMs:
    - ESXi server
    - NFS VM
    - vCenter Server Appliance (VCSA)
    > It will also add the "-XY" to each where X is the group number you used and Y is the lab number.

![](/images/image2.png)

It will also create a folder in the AVS vCenter called **NestedLabs** where all the vApps will be placed.

![](/images/image3.png)

In NSX-T it will first create 3 segment profiles per group. In this example it's only group 1 in this SDDC so there's only 3 segment profiles (1 of each type):
- IP Discovery Profile
- MAC Discovery Profile
- Segment Security Profile

![](/images/image4.png)

1. For each lab (participant) the automation will create one NSX-T segment called **Group-XY-NestedLab** where X is the group number specified and Y is the lab or participant number specified.
2. Each NSX-T segment will be created using the following CIDR:
    10.**X**.**Y**.1/24

### Embedded vCenter

![](/images/image5.png)

Every embedded vCenter as described in the table above will be reachable via https://10.X.Y.2/ui URL.

- The embedded Datacenter name inside of the vCenter Server is called **OnPrem-SDDC-Datacenter-XY**.
- The embedded cluster is called **OnPrem-SDDC-Cluster-XY**.
- 2 workload VMs are deployed inside each embedded vCenter:
    - Workload-XY-1
    - Workload-XY-2

![](/images/image6.png)

- A datastore named **LabDatastore** is created off the mounted NFS VM created in each nested environment. It has approximately 500GB of capacity.

![](/images/image7.png)

- A Virtual Distributed Switch (vDS) named **OnPrem-SDDC-VDS-XY** is created in each embedded vCenter Server.
- Each of the following networks are created:
    - OnPrem-**management**-XY
    - OnPrem-**replication**-XY
    - OnPrem-**uplink**-XY
    - OnPrem-**vmotion**-XY
    - OnPrem-**workload**-XY
        - The **workload** port group is tagged with a VLAN ID so that it can be stretched with HCX.

Enjoy the environments, and please feel free to provide feedback or contribute to make this process better.