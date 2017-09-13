#########################################################################################

##TakeFlite PROD

#Set Variables
[string]$CurrentEnvironment = "PROD"
[string]$InputFile = "C:\Development\azr-takeflitesolutions-anz\AppInsights\inputfiles\Takeflite-Webs.csv"
[guid]$SubscriptionID = "0a723bba-4077-498c-bddc-0434e10b7df7"
[string]$NewResourceGroup = "SCU-RSG-RAXMON-PRD"
[string]$targetregion = "SCU"
[string]$rsglocation = "South Central US"

#########################################################################################
#Deploy with params
.\deploy-webtests.ps1 -CurrentEnvironment $CurrentEnvironment -InputFileName $InputFile -SubscriptionID $SubscriptionID -NewResourceGroup $NewResourceGroup -targetregion $targetregion -rsglocation $rsglocation -ProvisionRSG $true -ProvisionWebAlerts $true
#########################################################################################