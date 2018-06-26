#Requires -Modules HPELogAnalyticsPSModule

<#
.Synopsis
   This runbook is used to start a log recored generation cycle.
.DESCRIPTION
   Use this runbook to drive the HPELogAnalyticsPSModule to collect data from 
   one or more instances of HPE OneView and generate Azure Log Analytics log 
   records.  This script can be used to generate log records for multiple
   instance of HPE OneView.
#>

param(
	[parameter (Mandatory=$false)] [string] $jsonConfigString
    )


$VerbosePreference = 'Continue'
#$ErrorActionPreference = 'Stop'

if([String]::IsNullOrEmpty($jsonConfigString)){

	<# 
		jsonConfigString drives the collection of data from HPE OneView.  This array
		contains entries that define the instance of HPE OneView to collect data from.
		A particular entry also defines which Log Analytics workspace to target for the
		associated HPE OneView instance.  Members of each entry are defined below:
			* LogAnalyticsWorkSpaceID - The Log Analytics WorkSpace ID associated with
				the instance of Log Analytics to target Log Record generation. This is 
	            obtained from the OMS Workspace inside the Azure portal.

			* LogAnalyticsPrimaryKeyVariable - The name of the encrypted automation variable 
				which contains the primary key used to communicate with the instance of Log Analytics 
				defined by LogAnalyticsWorkSpaceID.

			* OneViewHostName - The host name or IP address for the instance of HPE OneView 
				to collect information from.  This information will in turn be used to generate 
				Log Records in the instance of Log Analytics defined by LogAnalyticsWorkSpaceID

			* OneViewCredVariable - The name of the credential asset containing credentials needed 
				to authenticate with the instance of HPE OneView defined by OneViewHostName.
	#>

	<# Uncomment the following $jsonConfigString variable definition and configure the JSON array entries
	   to match your environment using the definitions above. #>
	<# $jsonConfigString =
                '[

                    {"LogAnalyticsWorkSpaceID":"d2811520-3313-4073-b6fb-xxxxxxxxxxxx",
                    "LogAnalyticsPrimaryKeyVariable":"<automation variable PK>",
                    "OneViewHostName":"<IP address of first HPE OV>",
                    "OneViewCredVariable":"<HPE OneView automation credential>"},

                    {"LogAnalyticsWorkSpaceID":"d2811520-3313-4073-b6fb-xxxxxxxxxxxx",
                    "LogAnalyticsPrimaryKeyVariable":"<automation variable PK blah blah>",
                    "OneViewHostName":"<IP address of second HPE OV",
                    "OneViewCredVariable":"OneViewAutomationCredential"}

                ]' #>

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

$configurationData | foreach {

    Write-Verbose "Processing config item -> "
    Write-Verbose "Log Analytics workspace ID: $($_.LogAnalyticsWorkspaceID)"
    Write-Verbose "HPE OneView appliance host name: $($_.OneViewHostName)"

    # get credential used to connect to instalce of HPE OneView appliance
    $cred = Get-AutomationPSCredential -Name $_.OneViewCredVariable
    if(-not $cred){
        Write-Warning "Could not get credential: $($_.OneViewCredVariable)"
        Continue;
    }
    else{
        Write-Verbose "Credential User Name: $($cred.UserName)"
    }
	
    # get Log Analytics Workspace primary key
    $logAnalyticsPrimaryKey = Get-AutomationVariable $_.LogAnalyticsPrimaryKeyVariable
    #if([String]::IsNullOrEmpty($omsPrimaryKey)){
    if( -not $logAnalyticsPrimaryKey){
        Write-Warning "Could not get Log Analytics workspace primary key automation variable: $($_.LogAnalyticsPrimaryKeyVariable)"
        Continue;
    }
    else{
        Write-Verbose "Got Log Analytics primary key from automation variable: $($_.LogAnalyticsPrimaryKeyVariable)"
    }

	try{
		$success = Send-HPELogAnalyticsLogs `
                    -LogAnalyticsWorkspaceID $_.LogAnalyticsWorkspaceID `
                    -LogAnalyticsPrimaryKey $logAnalyticsPrimaryKey `
                    -HPEOneViewHostName $_.OneViewHostName `
                    -HPEOneViewCredential $cred 
					
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