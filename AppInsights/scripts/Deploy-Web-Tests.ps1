<#
  .SYNOPSIS
  Creates a resourcegroup, webtest and applies tags for AppInsight monitoring for TakeFlite's endpoints
  
  .NOTES
  Version:       2.0
  Author:         Aaron Saikovski
  Creation Date:  11th September 2017
  Purpose/Change: Initial script development  
#>

Clear-Host

Set-StrictMode -Version 3
$ErrorActionPreference = "Stop"


#Import-Module Azure -ErrorAction SilentlyContinue
#Import-Module ../scripts/AzureHelper.psm1 -Force 

#add login
#Import-Module ../scripts/switch-dpe-subs.psm1 -Force #-Verbose
#LoginMain

###########################################################################################################################

#Target Subscription
[string]$TargetSubId = "0a723bba-4077-498c-bddc-0434e10b7df7"

#Target Resource Group
[string]$TargetRsg ="SCU-RSG-RAXMON-PRD"

#Target Region
[string]$TargetRegion = "South Central US"

#List of sites to monitor
$SiteList=@(
	"https://tf-takefliteservice-scup01.tflite.com/TakeFliteWCFServiceJ/TakeFliteServices.svc";
	"https://tf-takefliteservice-scup01.tflite.com/TakeFliteWCFServiceI/TakeFliteServices.svc";
	"https://tf-fareengine-scup01.tflite.com/FareEngineWCFServiceH/FareServices.svc";
	"https://tf-companyrulesservice-scup01.tflite.com/CompanyRulesService/CompanyRules.svc";
	"https://tf-bookingportal-scup01.tflite.com/Public/SA/Booking/Search";
	"https://tf-legacybookingportal-scup01.tflite.com/takeflitepublicwfp/PgCreateOpenBooking.aspx";
	"https://tf-legacybookingportal-scup01.tflite.com/takeflitepublicnln/";
	"https://tf-legacybookingportal-scup01.tflite.com/takeflitepublic/PgAgentLogin.aspx";
	"https://tf-legacybookingportal-scup01.tflite.com/takeflitepublicrac/PgAgentLogin.aspx";
	"https://tf-legacybookingportal-scup01.tflite.com/takeflitepublickma/PgAgentLogin.aspx";
	"https://tf-externalportal-scup01.tflite.com/ExternalPortal/CompanyRules/";
	"https://tf-externalportal-scup01.tflite.com/ExternalPortal/IapiManager/";
	"https://tf-externalservice-scup01.tflite.com/TakefliteExternalServiceA/TakefliteExternalService.svc";
	"https://tf-publicservice-scup01.tflite.com/TakeflitePublicServiceT/TakeflitePublicServices.asmx";
	"https://tf-lepservice-scup01.tflite.com/Aetm/LEPservice.svc";
	"https://tf-aetmprofile-scup01.tflite.com/AetmProfile/sync.profile";
	"https://tf-mobileservice-scup01.tflite.com/MobileServiceT/MobileServices.asmx";
	"https://admin10125apps1.tflite.com/TakefliteExternalServiceA/TakefliteExternalService.svc";
)



#Webhook URL
[string]$WebHookURL = 'https://raxengineering.azurewebsites.net/api/azureAlert?code=umDnzlayJAgSNUszoF9L2RbZAmDXc8tDaEafC3hPqx9ffcCshkGEpw==&resolutionUrl=https://rax.io/azr-4827898-webapp'

#receipient email
[string]$Email = 'azuresupport@rackspace.com' #E-mail of recipients


###########################################################################################################################


##TODO
#Azure Login here

###########################################################################################################################

#VARIABLES


#What to provision
[bool]$ProvisionRSG = $true #$false $true
[bool]$ProvisionWebAlerts = $true
[bool]$TagResourceGroup = $true

###########################################################################################################################

#region TEMPLATES

#Template basepath
[string]$baseScriptPath = [System.IO.Directory]::GetParent([System.IO.Directory]::GetParent($MyInvocation.MyCommand.Path))
[string]$basetemplatepath= $baseScriptPath + '\ApplicationInsights'

#template locations
$TemplateLocation = "$basetemplatepath\deploy-appinsights-webtest-alert.json"   #location of webtest template
$TemplatelocationAppInsight = "$basetemplatepath\deploy-appinsights-component.json"    #location of app insights template

#endregion TEMPLATES

#region GETWEBAPPS

#get the webapps in the given resourcegroup
$webapps = Get-AzureRmWebApp -ResourceGroupName $resourcegroup

#Get the webapps and filter
$WebList = $webapps | Select-Object @{N = 'SiteName';E={$_.SiteName}}, @{N = 'Location';E={$_.Location.replace(' ','')}} , @{N = 'URL';E={$_.DefaultHostName}}  
#endregion GETWEBAPPS

#region APPREGIONS
 # App-Insights monitoring regions
$apac="emea-au-syd-edge","apac-hk-hkn-azr","apac-sg-sin-azr" #sydney, hong kong, singapore
$japan="apac-jp-kaw-edge","apac-hk-hkn-azr","apac-sg-sin-azr" #Kawaguchi, hong kong, singapore
$northeurope="emea-gb-db3-azr", "emea-se-sto-edge", "us-fl-mia-edge" #northern ireland, stockholm, miami
$westeurope="emea-nl-ams-azr", "emea-ch-zrh-edge", "us-fl-mia-edge" #amsterdam, zurich, miami
$uksouth="emea-gb-db3-azr", "emea-se-sto-edge", "us-fl-mia-edge" #northern ireland, stockholm, miami
$eastasia="apac-hk-hkn-azr", "apac-sg-sin-azr", "apac-jp-kaw-edge" #hong kong, singapore, kawaguchi
$southeastasia="apac-sg-sin-azr", "apac-hk-hkn-azr", "emea-au-syd-edge" #singapore, hong kong, sydney
$westus="us-ca-sjc-azr", "us-tx-sn1-azr", "apac-jp-kaw-edge" #san jose, san antonio, kawaguchi
#endregion APPREGIONS

###########################################################################################################################

#region RESOURCEGROUP_FUNCTIONS

#Creates the resourcegroup
function CreateRSG()
{	
	foreach ($RSG in $WebList) 
	{	
		$location = $RSG.Location

		switch ($location)
		{
			"australiaeast" {$rsgloc='AUE'}
			"australiasoutheast" {$rsgloc='ASE'}			
			"southeastasia" {$rsgloc='SEA'}	
			"eastasia" {$rsgloc='EAS'}						
			"japaneast" {$rsgloc='JPE'}
			"japanwest" {$rsgloc='JPW'}	
			"northeurope" {$rsgloc='NEU'}	
			"westeurope" {$rsgloc='WEU'}	
			"uksouth" {$rsgloc='UKS'}	
			"westus" {$rsgloc='WUS'}	
		}

		#check if resource group exists
		$resourceGroup = Get-AzureRmResourceGroup -Name ($rsgname + $rsgloc) -ErrorAction SilentlyContinue

		if(!$resourceGroup)
		{
			Write-Output ($rsgname + ($rsgloc) + " is being created")
			New-AzureRmResourceGroup -Name ($rsgname + $rsgloc) -location $RSG.location -Force
			New-AzureRmResourceGroupDeployment -ResourceGroupName ($rsgname + $rsgloc) -TemplateFile $TemplatelocationAppInsight -appinsightscomponentName ('AppInsightsComponent-' + $rsgloc) -Force
			Write-Output ($rsgname + ($rsgloc) + " created")
		}
		
	}

}

#Tag and lock resourcgroup
function TagLockResources()
{
	$buildDate = get-date -format u	
	[string]$lease = 'Forever'
	[string]$user='Rackspace Azure Support'
	[string]$scriptVersion = '1.0.0.0'

	#get RSG
	[string]$targetrsg = $rsgname + $targetregion		
	
	#Add tags and lock RSGs
	Write-Host ($targetrsg + " is being tagged and locked")
	AddResourceGroupTags -resourceGroupName $targetrsg -resourceGroupTags @{Customer="Dominos Pizza Enterprises";Environment=$activeEnvironment;Region=$targetregion;Lease=$lease;User=$user;ScriptVersion=$scriptVersion}
	LockResourceGroup -resourceGroupName $targetrsg	

}

#endregion RESOURCEGROUP_FUNCTIONS


#region WEBALERT_FUNCTIONS

#sets the web alert xml with params
function SetWebAlertXML{
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$True)]
		[string] $WebTestName,
		[Parameter(Mandatory=$True)]
		[string] $Url,
		[Parameter(Mandatory=$True)]
		[int] $HTTPStatusCode=200
	)

	#build XML string
	$strxml = '<WebTest Name=' + '"' + $WebTestName + '"' + ' Enabled="True"  CssProjectStructure="" CssIteration="" Timeout="30" WorkItemIds="" xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010" Description="" CredentialUserName="" CredentialPassword="" PreAuthenticate="True" Proxy="default" StopOnError="False" RecordedResultFile="" ResultsLocale=""><Items><Request Method="GET" Version="1.1" Url=' + '"' + $Url + '"' + ' ThinkTime="0" Timeout="30" ParseDependentRequests="True" FollowRedirects="True" RecordResult="True" Cache="False" ResponseTimeGoal="0" Encoding="utf-8" ExpectedHttpStatusCode=' + '"' + $HTTPStatusCode + '"' + ' ExpectedResponseUrl="" ReportingName="" IgnoreHttpStatusCode="False" /></Items></WebTest>'

	#Return Modified XML	
	return $strxml
}

#Checks a given Url for a HTTP status return code
function CheckURLStatusCode{
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$True)]
		[string] $Url
	)

	try{
		$http_resp = wget $url -UseBasicParsing 

	} catch [System.Net.WebException]{
		$http_resp = $_.Exception.Response
	}

	$ret = [int]$http_resp.StatusCode
	return $ret
}

#Creates the web alert in AppInsights
function CreateWebAlert()
{

	foreach ($WebAppValue in $WebList)
	{
		$rsglocation = $WebAppValue.Location

		switch ($rsglocation)
		{
			"australiaeast" {$rsgloc='AUE'}
			"australiasoutheast" {$rsgloc='ASE'}			
			"southeastasia" {$rsgloc='SEA'}	
			"eastasia" {$rsgloc='EAS'}						
			"japaneast" {$rsgloc='JPE'}
			"japanwest" {$rsgloc='JPW'}		
			"northeurope" {$rsgloc='NEU'}	
			"westeurope" {$rsgloc='WEU'}	
			"uksouth" {$rsgloc='UKS'}
			"westus" {$rsgloc='WUS'}			
		}


		$location = $WebAppValue.Location

		switch ($location)
		{
			"australiaeast" {$monitorLocation=$apac}
			"australiasoutheast" {$monitorLocation=$apac}
			"northeurope" {$monitorLocation=$northeurope}
			"westeurope" {$monitorLocation=$westeurope}
			"uksouth" {$monitorLocation=$uksouth}
			"eastasia" {$monitorLocation=$eastasia}
			"southeastasia" {$monitorLocation=$southeastasia}
			"westus" {$monitorLocation=$westus}
			"japaneast" {$monitorLocation=$japan}
			"japanwest" {$monitorLocation=$japan}
			"westus" {$monitorLocation=$westus}
			default {$monitorLocation=$apac}
		}

		$firstLoc=$monitorLocation[0]
		$secondLoc=$monitorLocation[1]
		$thirdLoc=$monitorLocation[2]

		#get the wep app url
		[string]$webappurl = ('http://' + $WebAppValue.URL)

		#Get the site status code
		[int]$httpstatus = CheckURLStatusCode -Url $webappurl

		#check for 401 and recheck with API key
		#[int]$httpstatusrecheck =$null		
		#if($httpstatus -eq 401)
		#{
		#	$httpstatusrecheck = CheckURLStatusCode -Url ($webappurl + $DominosApiKey)
		#}
		#else
		#{

		#}
		
		#Parse the XML result for the alert contents
		[string]$xmlresult = SetWebAlertXML -WebTestName ($WebAppValue.SiteName) -Url $webappurl -HTTPStatusCode $httpstatus 
		
		#Deploy the alert with the custom xml
		Write-Host "values: 1: " $firstLoc " 2: " $secondLoc " 3: " $thirdLoc
		New-AzureRmResourceGroupDeployment -ResourceGroupName ($rsgname + $rsgloc) -webTestName ($WebAppValue.SiteName) -appName ('AppInsightsComponent-' + $rsgloc) -URL $webappurl -firstlocation $firstloc -secondlocation $secondloc -thirdlocation $thirdLoc -webhookurl $WebhookURL -emailrecipients $Email -webTestXML $xmlresult -TemplateFile $TemplateLocation	
	

	}
}
#endregion WEBALERT_FUNCTIONS

###########################################################################################################################

#region PROVISION
#Uncomment on what function is needed to run
if($ProvisionRSG)
{
	CreateRSG
}

if($ProvisionWebAlerts)
{
	CreateWebAlert
}

if($TagResourceGroup)
{
	TagLockResources
}

#endregion PROVISION

###########################################################################################################################