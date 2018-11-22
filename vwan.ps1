####################
#   Virtual WAN    #
####################

# Variables
$subid="e7da9914-9b05-4891-893c-546cb7b0422e"
$rg="vwantest"
$vnetname="feVnet"
$vnetprefix="10.1.0.0/16"
$subnetname="fesubnet"
$subnetprefix="10.1.1.0/24"
$vwanname = "myvwan"
$location1="westeurope"
$hub1name="myhub1"
$hub1prefix="172.21.101.0/24"
$location2="northeurope"
$hub2name="myhub2"
$hub2prefix="172.22.101.0/24"
# To simulate the branches in Azure
$branch1vnetname="branch1vnet"
$branch1prefix="172.21.1.0/24"
$branch1subnetname="branch1subnet1"
$branch1subnetprefix="172.21.1.0/26"
$branch1name = "branch1"
$branch1asn=65101
$branch1bgpaddress="1.1.1.1"
$branch2vnetname="branch2vnet"
$branch2prefix="172.22.1.0/24"
$branch2subnetname="branch2subnet1"
$branch2subnetprefix="172.22.1.0/26"
$branch2name = "branch2"
$branch2asn=65102
$branch2bgpaddress="1.1.1.2"

# Login
Login-AzAccount
Select-AzSubscription -subscription $subid

# Create RG and Vnet/subnet
New-AzResourceGroup -name $rg -location $location1
$subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetname -AddressPrefix $subnetprefix
$vnet   = New-AzVirtualNetwork -Name $vnetname -AddressPrefix $vnetprefix -ResourceGroupName $rg -Location $location1 -Subnet $subnet

# Alternatively, get an already existing vnet
$vnet = get-azvirtualnetwork -resourcegroupname $rg -Name $vnetname

# Create vnets to simulate branch1 and branch2, here you can deploy your favorite NVAs to simulate onprem VPN devices
$branch1subnet = New-AzVirtualNetworkSubnetConfig -Name $branch1subnetname -AddressPrefix $branch1subnetprefix
$branch1vnet   = New-AzVirtualNetwork -Name $branch1vnetname -AddressPrefix $branch1prefix -ResourceGroupName $rg -Location $location1 -Subnet $branch1subnet
$branch2subnet = New-AzVirtualNetworkSubnetConfig -Name $branch2subnetname -AddressPrefix $branch2subnetprefix
$branch2vnet   = New-AzVirtualNetwork -Name $branch2vnetname -AddressPrefix $branch2prefix -ResourceGroupName $rg -Location $location2 -Subnet $branch2subnet
# Or get existing ones
$branch1vnet = get-azvirtualnetwork -resourcegroupname $rg -name $branch1vnetname
$branch2vnet = get-azvirtualnetwork -resourcegroupname $rg -name $branch2vnetname

# Deploy CSR1v routers to branch1 and branch2, to simulate remote onprem VPN devices
$basedir="C:\Users\jomore\OneDrive - Microsoft\code\Powershell\ARM_templates\csr1kv\"
$templatefile=$basedir+"nvaCsr1kv_novnet.json"
$paramfile=$basedir+"parameters.json"
$adminpwd = ConvertTo-SecureString "Microsoft123!" -AsPlainText -Force
$csrname1="csr01"
$nsgname1=$csrname1+"-nsg"
$nicname1=$csrname1+"-nic"
$pipname1=$csrname1+"-pip"
$csrdiag1=$(-join((97..122) | get-random -count 12 | % {[char]$_}))
New-azresourcegroupdeployment -name $csrname1 -resourcegroupname $rg -templatefile $templatefile -templateparameterfile $paramfile `
    -diagnosticsStorageAccountName $csrdiag1 `
    -location $location1 `
    -virtualMachineName $csrname1 `
    -networkSecurityGroupName $nsgname1 `
    -networkInterfaceName $nicname1 `
    -subnetName $branch1subnetname `
    -virtualNetworkId $branch1vnet.Id `
    -publicipaddressname $pipname1 `
    -adminPassword $adminpwd
$csrname2="csr02"
$nsgname2=$csrname2+"-nsg"
$nicname2=$csrname2+"-nic"
$pipname2=$csrname2+"-pip"
$csrdiag2=$(-join((97..122) | get-random -count 12 | % {[char]$_}))
New-azresourcegroupdeployment -name $csrname2 -resourcegroupname $rg -templatefile $templatefile -templateparameterfile $paramfile `
    -diagnosticsStorageAccountName $csrdiag2 `
    -location $location2 `
    -virtualMachineName $csrname2 `
    -networkSecurityGroupName $nsgname2 `
    -networkInterfaceName $nicname2 `
    -subnetName $branch2subnetname `
    -virtualNetworkId $branch2vnet.Id `
    -publicipaddressname $pipname2 `
    -adminPassword $adminpwd

# Public IP addresses onprem (for this test I configured Azure PIPs)
$onprempip1=$(Get-AzPublicIpAddress -ResourceGroupName $rg -name $pipname1).ipAddress
$onprempip2=$(Get-AzPublicIpAddress -ResourceGroupName $rg -name $pipname2).ipAddress
write-host("Connect to the CSR routers using the IP addresses " + $onprempip1 + " and " + $onprempip2)

# Create new Azure Virtual WAN and hubs
$vwan = New-AzVirtualWan -ResourceGroupName $rg -Location $location1 -Name $vwanname
$hub1 = New-AzVirtualHub -ResourceGroupName $rg -Location $location1 -VirtualWan $vwan -name $hub1name -AddressPrefix $hub1prefix
$hub2 = New-AzVirtualHub -ResourceGroupName $rg -Location $location2 -VirtualWan $vwan -name $hub2name -AddressPrefix $hub2prefix

# Connect Vnet to hub1
$connectionname = $hub1name + "to" + $vnetname  # No hyphens allowed
New-AzVirtualHubVnetConnection -ResourceGroupName $rg -ParentResourceName $hub1name -Name $connectionname -RemoteVirtualNetwork $vnet

# Sites (similar to Local Network Connections)
# Without BGP
#$site1 = New-AzVpnSite -ResourceGroupName $rg -Name $branch1name -Location $location1 -VirtualWanResourceGroupName $rg -VirtualWanName $vwanname -IpAddress $onprempip1 -AddressSpace $branch1prefix
#$site2 = New-AzVpnSite -ResourceGroupName $rg -Name $branch2name -Location $location2 -VirtualWanResourceGroupName $rg -VirtualWanName $vwanname -IpAddress $onprempip2 -AddressSpace $branch2prefix
# With BGP
$site1 = New-AzVpnSite -ResourceGroupName $rg -Name $branch1name -Location $location1 -VirtualWanResourceGroupName $rg -VirtualWanName $vwanname -IpAddress $onprempip1 -BgpAsn $branch1asn -BgpPeeringAddress $branch1bgpaddress -AddressSpace $branch1prefix
$site2 = New-AzVpnSite -ResourceGroupName $rg -Name $branch2name -Location $location2 -VirtualWanResourceGroupName $rg -VirtualWanName $vwanname -IpAddress $onprempip2 -BgpAsn $branch2asn -BgpPeeringAddress $branch2bgpaddress -AddressSpace $branch2prefix


# Get VPN configs (Not working!!!)
$vpnconfigaccount = $(-join((97..122) | get-random -count 12 | % {[char]$_}))
write-host("Getting VPN configs to storage account " + $vpnconfigaccount)
$containername = "vpnconfigs"
$policyname = "vpnconfigpolicy"
$storageaccount = New-AzStorageAccount -ResourceGroupName $rg -Location $location1 -Name $vpnconfigaccount -Sku Standard_LRS -Kind StorageV2
$storagekeys = get-azstorageaccountkey -resourcegroupname $rg -name $vpnconfigaccount
$storagekey = $storagekeys[0].Value
$storagecontext = New-AzStorageContext -storageaccountname $vpnconfigaccount -storageaccountkey $storagekey
$storagecontainer = new-azstoragecontainer -Name $containername -Context $storagecontext
$expiryTime = (get-date).AddYears(1)
$permission = "rwl"
$storagesap = new-azstoragecontainerstoredaccesspolicy -context $storagecontext -policy $policyname -container $containername -expirytime $expirytime -permission $permission
$sasToken = New-AzStorageContainerSASToken -Name $containername -Policy $policyname -Context $storageContext
$url = $storageaccount.context.blobendpoint + $containername + $sastoken
get-azvirtualwanvpnconfiguration -storagesasurl $url -ResourceGroupName $rg -Name $vwanname -VpnSiteId $site1.Id

# Hub-Site Association cmdlets?????

# CSR config example
<#
crypto ikev2 proposal azure-proposal
  encryption aes-cbc-256 aes-cbc-128 3des
  integrity sha1
  group 2
  exit
!
crypto ikev2 policy azure-policy
  proposal azure-proposal
  exit
!
crypto ikev2 keyring azure-keyring
  peer 52.142.116.152
    address 52.142.116.152
    pre-shared-key Microsoft123!
    exit
  exit
!
crypto ikev2 profile azure-profile
  match address local interface GigabitEthernet1
  match identity remote address 52.142.116.152 255.255.255.255
  authentication remote pre-share
  authentication local pre-share
  keyring local azure-keyring
  exit
!
crypto ipsec transform-set azure-ipsec-proposal-set esp-aes 256 esp-sha-hmac
 mode tunnel
 exit

crypto ipsec profile azure-vti
  set transform-set azure-ipsec-proposal-set
  set ikev2-profile azure-profile
  set security-association lifetime kilobytes 102400000
  set security-association lifetime seconds 3600 
 exit
!
interface Tunnel0
 ip address 1.1.1.2 255.255.255.0 
 ip tcp adjust-mss 1350
 tunnel source GigabitEthernet1
 tunnel mode ipsec ipv4
 tunnel destination 52.142.116.152
 tunnel protection ipsec profile azure-vti
exit
!
interface Loopback0
 ip address 172.22.1.254 255.255.255.255
!
router bgp 65102
 bgp router-id interface Loopback00
 bgp log-neighbor-changes
 neighbor 10.2.0.254 remote-as 65515
 neighbor 10.2.0.254 ebgp-multihop 10
 neighbor 10.2.0.254 update-source Loopback0
!
#>

# Example config download (from the portal, no BGP)
<#
[
  { "configurationVersion":{"LastUpdatedTime":"2018-11-17T23:31:23.5658997Z","Version":"82e10b69-d867-41fd-ac14-debf28f9a4b3"},
    "vpnSiteConfiguration":{"Name":"branch2", "IPAddress":"40.113.73.92"},
    "vpnSiteConnections":[{
       "hubConfiguration":{"AddressSpace":"172.22.101.0/24", "Region":"North Europe"},
       "gatewayConfiguration":{"IpAddresses":{"Instance0":"52.142.116.152","Instance1":"52.142.95.128"}},
       "connectionConfiguration":{"IsBgpEnabled":false,"PSK":"Microsoft123!","IPsecParameters":{"SADataSizeInKilobytes":102400000,"SALifeTimeInSeconds":3600}}
    }]
  }
]
#>

<#
Example config download (BGP)
[
  {"configurationVersion":{
    "LastUpdatedTime":"2018-11-18T13:08:17.5154511Z",
    "Version":"2cb4660d-a96e-4c3a-83a6-648f26dd1411"},
    "vpnSiteConfiguration":{
       "Name":"branch1",
       "IPAddress":"51.144.177.30",
       "BgpSetting":{"Asn":65101,"BgpPeeringAddress":"172.21.1.154","PeerWeight":32768}},
       "vpnSiteConnections":[{
           "hubConfiguration":{"AddressSpace":"172.21.101.0/24","Region":"West Europe","ConnectedSubnets":["10.1.0.0/16"]},
           "gatewayConfiguration":{
               "IpAddresses":{"Instance0":"52.142.232.43","Instance1":"52.142.232.0"},
               "BgpSetting":{"Asn":65515,"BgpPeeringAddresses":{"Instance0":"172.21.101.4","Instance1":"172.21.101.5"},"PeerWeight":0}},
               "connectionConfiguration":{"IsBgpEnabled":true,"PSK":"Microsoft123!","IPsecParameters":{"SADataSizeInKilobytes":102400000,"SALifeTimeInSeconds":3600}}}]},
  {"configurationVersion":{"LastUpdatedTime":"2018-11-18T13:08:17.5154511Z","Version":"10bc3692-a3f9-48db-b737-bb16d886205b"},
   "vpnSiteConfiguration":{"Name":"branch2","IPAddress":"40.113.73.92","BgpSetting":{"Asn":65102,"BgpPeeringAddress":"172.22.1.254","PeerWeight":32768}},
   "vpnSiteConnections":[{"hubConfiguration":{"AddressSpace":"172.22.101.0/24","Region":"North Europe"},"gatewayConfiguration":
   {"IpAddresses":{"Instance0":"52.142.116.152","Instance1":"52.142.95.128"},"BgpSetting":{"Asn":65515,
   "BgpPeeringAddresses":{"Instance0":"172.22.101.5","Instance1":"172.22.101.4"},"PeerWeight":0}},"connectionConfiguration":{"IsBgpEnabled":true,"PSK":"Microsoft123!","IPsecParameters":{"SADataSizeInKilobytes":102400000,"SALifeTimeInSeconds":3600}}}]}
]
#>

# Remarks:
# 1. No branch-to-branch with different hubs
# 2. BGP does not seem to be configurable

# Verify/Troubleshoot
get-azvirtualwan | ft
get-azvirtualhub | ft
Get-AzVirtualHubVnetConnection -ResourceGroupName $rg -ParentResourceName $hub1name
Get-AzVirtualHubVnetConnection -ResourceGroupName $rg -ParentResourceName $hub2name
$vwan = get-azvirtualwan -resourcegroupname $rg -name $vwanname
$hub1 = get-azvirtualhub -resourcegroupname $rg -name $hub1name
$hub2 = get-azvirtualhub -resourcegroupname $rg -name $hub2name
$site1 = get-azvpnsite -resourcegroupname $rg -name $branch1name
$site2 = get-azvpnsite -resourcegroupname $rg -name $branch2name

# Delete virtual hubs
Remove-AzVirtualHub -ResourceGroupName $rg -Name $hub1name -Force
Remove-AzVirtualHub -ResourceGroupName $rg -Name $hub2name -Force
Remove-AzVpnSite -ResourceGroupName $rg -name $branch1name -Force
Remove-AzVpnSite -ResourceGroupName $rg -name $branch2name -Force
Remove-AzVirtualWan -ResourceGroupName $rg -name $vwanname -Force

# Cleanup
remove-azresourcegroup -name $rg


