Import-Module ../scripts/AzureHelper.psm1 -Force #-Verbose

$buildDate = get-date -format u
$environment = 'PROD'
$lease = 'Forever'
$user='Rackspace Azure Support'
$scriptVersion = '1.0.0.0'

#get RSGs
$rsglist = get-azurermresourcegroup | where-object {$_.ResourceGroupName -like '*DPE-RAXMON-PROD*'}
##$rsglist = get-azurermresourcegroup | where-object {$_.ResourceGroupName -like '*DPE-RAXMGMT-PROD-GLOBAL*'}


#loop and add tags and lock RSGs
foreach ($RSG in $rsglist) 
{
		$location = $RSG.Location

		switch ($location)
		{
			"australiaeast" {$region='AUE'}
			"australiasoutheast" {$region='ASE'}			
			"southeastasia" {$region='SEA'}	
			"eastasia" {$region='EAS'}						
			"japaneast" {$region='JPE'}
			"japanwest" {$region='JPW'}	
			"northeurope" {$region='NEU'}	
			"westeurope" {$region='WEU'}	
			"uksouth" {$region='UKS'}	
			"westus" {$region='WUS'}	
		}


		$resourceGroupName = $RSG.resourcegroupname


	AddResourceGroupTags -resourceGroupName $resourceGroupName -resourceGroupTags @{Customer="Dominos Pizza Enterprises";Environment=$environment;Region=$region;Lease=$lease;User=$user;ScriptVersion=$scriptVersion}
	LockResourceGroup -resourceGroupName $resourceGroupName
}

