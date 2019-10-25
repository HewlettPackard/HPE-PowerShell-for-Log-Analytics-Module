#Requires -Modules HPELogAnalyticsPSModule

<#
.Synopsis
   This runbook is used to start a log recored generation cycle.
.DESCRIPTION
   Use this runbook to drive HPELogAnalyticsPSModule to collect data from 
   one or more instances of HPE OneView and generate Azure Log Analytics log 
   records.  This script can be used to generate log records for multiple
   instance of HPE OneView.
#>

param(
	[parameter (Mandatory=$false)] [string] $jsonConfigString
    )


$VerbosePreference = 'Continue'
#$ErrorActionPreference = 'Stop'

<#
	If configuration string is not passed in, get configuration list stored in Automation Variable Ov4LaConfigList.
	This variable stores the configuration created by running the Add-HpeLogAnalyticsConfig command in the 
	HpeLogAnalyticsPSModule.
#>
if([String]::IsNullOrEmpty($jsonConfigString)){

	Write-Verbose "jsonConfigString not passed in.  Getting from automation variable: Ov4LaConfigList"

	$configList = Get-AutomationVariable -Name "Ov4LaConfigList" -ErrorAction 'Continue'

	if(!$configList){
		$ErrorMessage =  "Could not get Ov4LaConfigList.  Script cannot continue without configuration."
		throw $ErrorMessage
	}

	$jsonConfigString = $configList.ToString()
}

# Deserialize incoming JSON configuration data.
try{
	$configurationData = ConvertFrom-Json -InputObject $jsonConfigString
}
catch{
	$ErrorMessage = 'Could not convert JSON configuration string.'
	$ErrorMessage += "`n"
	$ErrorMessage += $_ 

	throw $ErrorMessage
}
<#
	If azure configuration string is not passed in, get azure configuration list stored in Automation Variable Ov4LaAsConfigList.
	This variable stores the configuration created by running the Add-HPELogAnalyticsAzureStackConfig command in the 
	HpeLogAnalyticsPSModule.
#>

Write-Verbose "Getting value from azure automation variable: Ov4LaASConfigList"
$azureConfigList = Get-AutomationVariable -Name "Ov4LaAsConfigList" -ErrorAction 'SilentlyContinue'
if($azureConfigList)
{		
    $jsonAzureConfigString = $azureConfigList.ToString() 
}
else 
{
    $jsonAzureConfigString = ""
    Write-Verbose "Automation variable for azure is not found"      
}
   
# Deserialize incoming JSON configuration data.
try{
	 $azureconfigurationData = ConvertFrom-Json -InputObject $jsonAzureConfigString     
   }
catch{ 
  	$ErrorMessage = 'Could not convert JSON azure configuration string.'
	$ErrorMessage += "`n"
	$ErrorMessage += $_ 
	throw $ErrorMessage
}

$configurationData | foreach {

    Write-Verbose "Initialize variables for azure stack scale unit name and region"
    $AzureStackScaleUnitName = ""
    $AzureStackScaleUnitRegion = ""

    Write-Verbose "Processing config item -> "
    Write-Verbose "Log Analytics workspace ID: $($_.LogAnalyticsWorkSpaceId)"
    Write-Verbose "HPE OneView appliance host name: $($_.OneViewHostName)"
	
    $applianceHostName =  $_.OneViewHostName
     
    #get azure stack scale unit name and region 
    $azureconfigurationData | Where-Object { $applianceHostName -eq $_.OneViewHostName } | Foreach-Object { 
		
			Write-Verbose "Azure Stack OneView appliance host name: $($_.OneViewHostName)"
			$AzureStackScaleUnitName = $_.AzureStackScaleUnitName
			$AzureStackScaleUnitRegion = $_.AzureStackScaleUnitRegion
    }
     
    # get credential used to connect to instance of HPE OneView appliance
    $cred = Get-AutomationPSCredential -Name $_.OneViewCredVariableName
    if(-not $cred){
        Write-Warning "Could not get credential: $($_.OneViewCredVariableName)"
        Continue;
    }
    else{
        Write-Verbose "Credential User Name: $($cred.UserName)"
    }
	
    # get Log Analytics Workspace primary key
    $logAnalyticsPrimaryKey = Get-AutomationVariable $_.LogAnalyticsPkVariableName
    #if([String]::IsNullOrEmpty($omsPrimaryKey)){
    if( -not $logAnalyticsPrimaryKey){
        Write-Warning "Could not get Log Analytics workspace primary key automation variable: $($_.LogAnalyticsPkVariableName)"
        Continue;
    }
    else{
        Write-Verbose "Got Log Analytics primary key from automation variable: $($_.LogAnalyticsPkVariableName)"
    }

	try{
		$success = Send-HPELogAnalyticsLogs `
                    -LogAnalyticsWorkspaceID $_.LogAnalyticsWorkSpaceId `
                    -LogAnalyticsPrimaryKey $logAnalyticsPrimaryKey `
                    -HPEOneViewHostName $_.OneViewHostName `
                    -HPEOneViewCredential $cred `
                    -AzureStackScaleUnitName $AzureStackScaleUnitName `
                    -AzureStackScaleUnitRegion $AzureStackScaleUnitRegion
		}
	catch{
		$ErrorMessage = 'An exception was generated when calling Send-HPELogAnalyticsLogs. Check log file for details'
		$ErrorMessage += "`n"
		$ErrorMessage += $_ 

		throw $ErrorMessage
	}


    if($success){
        Write-Verbose "Send-HPELogAnalyticsLogs success."
    }
    else {
        Write-Warning "One or more errors in Send-HPELogAnalyticsLogs.  Check log file for details."
    }

	Write-Output($success)
}
