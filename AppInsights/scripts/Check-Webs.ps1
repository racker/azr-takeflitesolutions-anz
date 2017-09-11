Clear-Host

Set-StrictMode -Version 3
$ErrorActionPreference = "Stop"

#add login
Import-Module ../scripts/switch-dpe-subs.psm1 -Force #-Verbose
LoginMain

###########################################################################################################################

#VARIABLES

#DPE-OLO-PROD-GLOBAL
#DPE-OLO-PROD-AUE
#DPE-OLO-PROD-JPE
#DPE-OLO-PROD-WEU
$resourcegrouplist = @(
	"DPE-OLO-PROD-GLOBAL",
	"DPE-OLO-PROD-AUE",
	"DPE-OLO-PROD-JPE",
	"DPE-OLO-PROD-WEU"
)


#Domino's API Key
[string]$DominosApiKey = '?api_key=y8vSsk90/j8NqTzeqPXaSppZDShiE3KcncoxWKH7DiR6BTxYld5SalBu/3ehHrJ4tuk='

###########################################################################################################################

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

#Rewrites a given url with the Given API key for Domino's
function URL401Rewrite([string]$InputUrl, [string]$ApiKey)
{
	#Get the site status code
	[int]$httpstatus = CheckURLStatusCode -Url $InputUrl

	#the new url
	[string] $newURL=$null

	#check for 401 add API key to url		
	if($httpstatus -eq 401)
	{
		#Add the API key to the Url
		$newURL = ($InputUrl + $ApiKey)
		return $newURL
	}
	else
	{
		#else just return the original url
		return $InputUrl
	}

}

#gets the web apps
function GetWebInfo()
{
	#loop over the resource groups
	foreach ($resgroup in $resourcegrouplist)
	{
		#get webapps
		$webapps = Get-AzureRmWebApp -ResourceGroupName $resgroup

		write-host ('Resource Group: ' + $resgroup) -ForegroundColor Green

		#Get the webapps and filter
		$WebList = $webapps | Select-Object @{N = 'SiteName';E={$_.SiteName}}, @{N = 'Location';E={$_.Location.replace(' ','')}} , @{N = 'URL';E={$_.DefaultHostName}} 
	
		foreach ($WebAppValue in $WebList)
		{			

			#get the wep app url
			[string]$webappurl = ('http://' + $WebAppValue.URL)
			[string]$webappurlnew=$null


			#Get the site status code
			[int]$httpstatus = CheckURLStatusCode -Url $webappurl
			[int]$httpstatusnew=0

			if($httpstatus -eq 401)
			{
				write-host "*****************************************************"
				#write the output
				write-host ($httpstatus.ToString() + ' - URL: ' + $webappurl) 

				$webappurlnew = ($webappurl + $DominosApiKey)
				$httpstatusnew = CheckURLStatusCode -Url $webappurlnew
				write-host ($httpstatusnew.ToString() + ' - URL: ' + $webappurlnew) 
				write-host "*****************************************************"
			}		


		}

	}
}

#call Main
GetWebInfo