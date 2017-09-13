<#
  .SYNOPSIS
  Deploys Application Insights via ARM templates and webtests for a given list of endpoints. Checks for a HTTP200 status return code
  
  .NOTES
  Version:        1.0
  Author:         Aaron Saikovski
  Creation Date:  13th September 2017
  Purpose/Change: Initial script development 
#>
param (    
        #What subscription to run against
        [Parameter(Mandatory=$true)]
        [ValidateSet("DEV","PREPROD","PROD")]
        [string]$CurrentEnvironment,

        #Input file containing list of webjobs
        [Parameter(Mandatory=$true)]
        [string]$InputFileName,

        #Azure SubscriptionID
        [Parameter(Mandatory=$true)]
        [guid]$SubscriptionID,
    
        #New Resourcegroup to deploy webtest to
        [Parameter(Mandatory=$true)]
        [string]$NewResourceGroupName,
    
        #Target Region suffix
        [Parameter(Mandatory=$false)]
        [string]$targetregion = "CUS",
    
        #Target Resourcegroup location
        [Parameter(Mandatory=$false)]
        [string]$rsglocation = "South Central US",
    
        #Provision Resourcegroup
        [Parameter(Mandatory=$true)]
        [bool]$ProvisionRSG = $false, 
    
        #Provision webalerts
        [Parameter(Mandatory=$true)]
        [bool]$ProvisionWebAlerts = $false
    )   
    
    Clear-Host
    
    Set-StrictMode -Version 3
    $ErrorActionPreference = "Stop"
    #$DebugPreference="Continue" #SilentlyContinue    
    
    ###########################################################################################################################
    
    #region VARIABLES
    
    #Webhook URL
    $global:WebHookURL = 'https://raxengineering.azurewebsites.net/api/azureAlert?code=umDnzlayJAgSNUszoF9L2RbZAmDXc8tDaEafC3hPqx9ffcCshkGEpw==&resolutionUrl=https://rax.io/azr-5047349-webapps'
        
    ##Testing
    ##$global:WebHookURL = "https://raxengineering.azurewebsites.net"
    
    #receipient email
    #$global:Email  = 'MSAzureSupport@rackspace.com' #E-mail of recipients
    $global:Email = 'aaron.saikovski@rackspace.com' #E-mail of recipients
    
    # App-Insights monitoring regions - san jose, san antonio, miami
    $global:AppInsRegions="us-ca-sjc-azr", "us-tx-sn1-azr", "us-fl-mia-edge" 

    #endregion VARIABLES
    
    ###########################################################################################################################
    
    #region TEMPLATES
    
    #Template basepaths
    [string]$basePath = [System.IO.Directory]::GetParent([System.IO.Directory]::GetParent($MyInvocation.MyCommand.Path))
    [string]$baseScriptPath = "$basePath\scripts"
    [string]$basetemplatepath = "$basePath\templates"
    
    #template locations
    $global:TemplateLocation = "$basetemplatepath\deploy-appinsights-webtest-alert.json"       #location of webtest template
    $global:TemplatelocationAppInsight = "$basetemplatepath\deploy-appinsights-component.json"    #location of app insights template
    
    #endregion TEMPLATES
    
    #region INPUT_FILE

    ##Get the list of webjobs from the input file
    if(Test-Path $InputFileName)
    {
        #load the file
        $webapplist  = Import-Csv -path $InputFileName	
    }
    else
    {
        Write-Host "The file $InputFileName could not be found." -ForegroundColor Red
        Exit
    }
    #endregion INPUT_FILE

    ###########################################################################################################################

    #region LOGIN

    # Login to Azure - if already logged in, use existing credentials.
    Write-Host "Authenticating to Azure..." -ForegroundColor Cyan
    try
    {
        $AzureLoginTest = Get-AzureRmSubscription
    }
    catch
    {
        $null = Login-AzureRmAccount
        $AzureLogin = Get-AzureRmSubscription

        Write-Host "Selecting Azure Subscription: $($SubscriptionID) ..." -ForegroundColor Cyan
        $Null = Select-AzureRmSubscription -SubscriptionId $SubscriptionID
    }
    #endregion LOGIN    
    
    ###########################################################################################################################
    
    #region WEBXML
    
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
    
    #endregion WEBXML
    
    ###########################################################################################################################
    
   
    
    ###########################################################################################################################
    
    #region RESOURCEGROUP_FUNCTIONS
    
    #Creates the resourcegroup
    function CreateRSG {
    
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$True)]
            [string] $newrsgname,
    
            [Parameter(Mandatory=$True)]
            [string] $rsglocation,
    
            [Parameter(Mandatory=$True)]
            [string] $TemplatelocationAppInsight,
                    
            [Parameter(Mandatory=$True)]
            [string] $targetregion
        )
    
        try {
    
            #check if resource group exists
            $resourceGroup = Get-AzureRmResourceGroup -Name $newrsgname -ErrorAction SilentlyContinue
    
            if(!$resourceGroup)
            {
                Write-Output ($newrsgname + " is being created")
                New-AzureRmResourceGroup -Name $newrsgname -location $rsglocation -Force			
                New-AzureRmResourceGroupDeployment -ResourceGroupName $newrsgname -TemplateFile $TemplatelocationAppInsight -appInsightsComponentName ('AppInsightsComponent-' + $targetregion) -Force
                Write-Output ($newrsgname + " created")
            }
            else {
                Write-Host "The resourcegroup $newrsgname already exists." -ForegroundColor Yellow
            }
    
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            Write-Host "The resourcegroup $newrsgname could not be created. Error - " $ErrorMessage -ForegroundColor Red
            Exit
        }
    
    }
    
    #endregion RESOURCEGROUP_FUNCTIONS
    
    #region CREATE_WEBALERT
    
    #Creates the web alert in AppInsights
    function CreateWebAlert()
    {
        try {
    
            Write-Debug "Inside CreateWebAlert()"
    
            #loop over the list of web apps
            foreach ($web in $webapplist)
            {
                #set the monitor location
                $monitorLocation=$AppInsRegions
                $firstLoc=$monitorLocation[0]
                $secondLoc=$monitorLocation[1]
                $thirdLoc=$monitorLocation[2]

            	#get the web url
                [string]$webappurl = $web.weburl

                #check for url name
                if($webappurl -eq $null)
                {
                    Write-Host "The Web url is null or invalid." -ForegroundColor Red
                    Exit
                }
 
                #get the webtest name
                [string]$WebtestName = $web.webtestname
    
                #check for webtest name
                if($WebtestName-eq $null)
                {
                    Write-Host "The WebtestName is null or invalid." -ForegroundColor Red
                    Exit
                }              

                #Get the site status code - HTTP200 - OK by default
		        [int]$httpstatus = 200
    
                #Parse the XML result for the alert contents                
                [string]$xmlresult = SetWebAlertXML -WebTestName $WebtestName -Url $webappurl -HTTPStatusCode $httpstatus 
    
                #check xml result
                if($xmlresult -eq $null)
                {
                    Write-Host "The xmlresult is null or invalid." -ForegroundColor Red
                    Exit
                }
            
                #Deploy the alert with the custom xml
                Write-Host "values: 1: " $firstLoc " 2: " $secondLoc " 3: " $thirdLoc
		        New-AzureRmResourceGroupDeployment -ResourceGroupName $NewResourceGroupName -webTestName $WebtestName -appName ('AppInsightsComponent-' + $targetregion) -URL $webappurl -firstlocation $firstloc -secondlocation $secondloc -thirdlocation $thirdLoc -webhookurl $WebhookURL -emailrecipients $Email -webTestXML $xmlresult -TemplateFile $TemplateLocation	
            }
    
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            Write-Host ("The webalert could not be created. - Error: " + $ErrorMessage) -ForegroundColor Red
            Exit
        }
        
    }
    
    #endregion CREATE_WEBALERT
    
    ###########################################################################################################################
    
    #region PROVISION_MAIN
    #Uncomment on what function is needed to run
    if($ProvisionRSG)
    {
        Write-Host 'Provisioning resource group.' -ForegroundColor Yellow
        CreateRSG -newrsgname $NewResourceGroupName -rsglocation $rsglocation -TemplatelocationAppInsight $TemplatelocationAppInsight -targetregion $targetregion
    }
    
    if($ProvisionWebAlerts)
    {
        Write-Host 'Provisioning Webalert.' -ForegroundColor Yellow
        CreateWebAlert
    }
    
    Write-Host  '*******************' -ForegroundColor Yellow
    Write-Host 	'*****COMPLETED*****' -ForegroundColor Yellow
    Write-Host  '*******************' -ForegroundColor Yellow
    #endregion PROVISION_MAIN
    
    ###########################################################################################################################