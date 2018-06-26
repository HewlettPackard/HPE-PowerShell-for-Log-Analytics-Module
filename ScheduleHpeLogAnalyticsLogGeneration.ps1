<#
.Synopsis
   This runbook is used to schedule log recored generation cycles.
.DESCRIPTION
   Use this runbook to schedule GenerateHpeLogAnalyticsLogs to run 
   periodically using Azure Automation schedule definitions.  This
   runbook can schedule the runbook to run a number of times per
   hour given a frequency variable.
#>

# Suspend the runbook if any errors, not just exceptions, are encountered
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

Write-Verbose "Logging in to Azure..."
$Conn = Get-AutomationConnection -Name AzureRunAsConnection 
 Add-AzureRmAccount -ServicePrincipal -Tenant $Conn.TenantID `
 -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint

Write-Verbose "Selecting Azure subscription..."
Select-AzureRmSubscription -SubscriptionId $Conn.SubscriptionID -TenantId $Conn.tenantid 

# Specialize the following parameters to match your environment:
#	$AutomationResourceGroup -	enter the resource group name containing the target 
#								Azure Automation account.
#	$AutomationAccountName -	Enter the Azure Automation account name.
#	$HybridRunbookWokerGroupName - Enter the hybrid worker group to target.
$AutomationResourceGroup = "<Enter Resource Group Name>"
$AutomationAccountName = "<Enter Automation Account Name>"
$HybridRunbookWokerGroupName = "<Enter Hybrid Worker Group Name>"

$RunbookName = "GenerateHpeLogAnalyticsLogs"      
$ScheduleName = "GenerateHpeOmsLogsSchedule"

$RunbookStartTime = $Date = $([DateTime]::Now.AddMinutes(10))

# Set to the number of minutes between each scheduled collection
[int]$RunFrequency = 10
$NumberofSchedules = 60 / $RunFrequency
Write-Verbose "$NumberofSchedules schedules will be created which will invoke the servicebusIngestion runbook to run every $RunFrequency mins"

$Count = 0
While ($count -lt $NumberofSchedules)
{
    $count ++

    try
    {
		Write-Verbose "Creating schedule $ScheduleName-$Count for $RunbookStartTime for runbook $RunbookName"
		$Schedule = New-AzureRmAutomationSchedule   -Name "$ScheduleName-$Count" `
													-StartTime $RunbookStartTime `
													-HourInterval 1 `
													-AutomationAccountName $AutomationAccountName `
													-ResourceGroupName $AutomationResourceGroup

        Write-Verbose "Scheduling runbook using previously created schedule."
		$Sch = Register-AzureRmAutomationScheduledRunbook   -RunbookName $RunbookName `
															-AutomationAccountName $AutomationAccountName `
															-ResourceGroupName $AutomationResourceGroup `
															-ScheduleName "$ScheduleName-$Count" `
															-RunOn $HybridRunbookWokerGroupName

		$RunbookStartTime = $RunbookStartTime.AddMinutes($RunFrequency)
    }
    catch
    {
        $ErrorMessage = 'Could not schedule runbook.'
	    $ErrorMessage += "`n"
	    $ErrorMessage += $_ 

	    throw $ErrorMessage
    }
}

Write-Verbose "Scheduling Complete."