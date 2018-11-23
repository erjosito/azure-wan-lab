# Azure Virtual WAN lab

## Setup the scenario

This template will generate the following resources:
* A Vnet with an NVA to simulate your onprem device (you can choose between different NVA types, Linux and Cisco CSR 1000v supported at this time)
* A Virtual WAN resource, with a Virtual Hub and a VPN Site, preconfigured with BGP and the public/private IP addresses of the NVA described in the previous bullet

First you need to create a resource group, we will use `vwantest` in `westeurope` along this demo:

```
az group create -n vwantest -l westeurope
```

Now you can issue this command (on a Linux system) to deploy the template with a Linux NVA: 

```
az group deployment create -g vwantest --template-uri https://raw.githubusercontent.com/erjosito/azure-wan-lab/master/vwan_quickstart.json --parameters '{"nvaPwd":{"value":"yoursupersecretpassword"}}'
```

For commands on Windows you cannot use single quotes, so you need to escape the double quotes in your parameter declaration:

```
az group deployment create -g vwantest --template-uri https://raw.githubusercontent.com/erjosito/azure-wan-lab/master/vwan_quickstart.json --parameters "{\"nvaPwd\":{\"value\":\"yoursupersecretpassword\"}}"
```

The default NVA type is a Linux Ubuntu VM with Quagga (for BGP) and StrongSwan (for VPN). An initial StrongSwan configuration is provided, but you will have to update it with the right parameters corresponding to your VPN site (public IP address, BGP peering IP address, Pre-Shared-Key).

If you want to deploy a Cisco CSR 1000v router as NVA (you do not need any license, since all functionality is active in eval mode, only bandwidth is limited), you can use the parameter nvaType like this:

```
az group deployment create -g vwantest --template-uri https://raw.githubusercontent.com/erjosito/azure-wan-lab/master/vwan_quickstart.json --parameters '{"nvaPwd":{"value":"yoursupersecretpassword"}, "nvaType":{"value":"cisco_csr"}, }'
```

The password you provided in the template will be used for authentication in the NVA, for the user `lab-user` (so it need to be compliant with the VM password policy: 12-character long, numbers, letters, special sign), as well as Pre-Shared Key for VPN. In a production environment you would probably separate both (the ARM template allows to do that).

# Inspect created resources

You can now go to the portal and have a look at the Virtual WAN resources, or you can do it using Powershell. Azure CLI is not supported yet.

## Using Powershell

You can go to https://shell.azure.com or install the latest version of the Azure Powershell modules to have access to the Virtual WAN cmdlets. Here some examples that help you understanding the deployed environment, as well as retrieving some interesting information:

```
Azure:/
PS Azure:\> $rg="vwantest"
Azure:/
PS Azure:\> get-azvirtualwan -ResourceGroupName $rg

Name                       : myVirtualWan
Id                         : /subscriptions/your_sub_id/resourceGroups/vwantest/providers/Microsoft.Network/virtualWans/myVirtualWan
AllowVnetToVnetTraffic     : True
AllowBranchToBranchTraffic : True
Location                   : westeurope
Type                       : Microsoft.Network/virtualWans
ProvisioningState          : Succeeded
```

```
Azure:/
PS Azure:\> get-azvirtualhub -ResourceGroupName $rg

VirtualWan                : /subscriptions/your_sub_id/resourceGroups/vwantest/providers/Microsoft.Network/virtualWans/myVirtualWan
ResourceGroupName         : vwantest
Name                      : myVirtualHub
Id                        : /subscriptions/your_sub_id/resourceGroups/vwantest/providers/Microsoft.Network/virtualHubs/myVirtualHub
AddressPrefix             : 192.168.0.0/24
RouteTable                : Microsoft.Azure.Commands.Network.Models.PSVirtualHubRouteTable
VirtualNetworkConnections : {}
Location                  : westeurope
Type                      : Microsoft.Network/virtualHubs
ProvisioningState         : Succeeded
```

```
Azure:/
PS Azure:\> get-azvpnsite -ResourceGroupName $rg

ResourceGroupName : vwantest
Name              : myVpnSite
Id                : /subscriptions/your_sub_id/resourceGroups/vwantest/providers/Microsoft.Network/vpnSites/myVpnSite
Location          : westeurope
IpAddress         : 192.168.100.4
VirtualWan        : /subscriptions/your_sub_id/resourceGroups/vwantest/providers/Microsoft.Network/virtualWans/myVirtualWan
AddressSpace      : 192.168.100.4/32
BgpSettings       :
Type              : Microsoft.Network/vpnSites
ProvisioningState : Succeeded
```

# Configure your NVA

You can get the public IP address of your NVA

