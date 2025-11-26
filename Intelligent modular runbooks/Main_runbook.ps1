# Automation account info
$AutomationAccountName = "automating-reports"
$ResourceGroupName = "intune_reporting"

# Child runbook name
$RunbookName = "Child_runbook"

# Authenticating through the managed identity
Connect-AzAccount -Identity | out-null

# Function to wait for the current job execution
function Wait-ForAutomationJob
{	
    param(
        [string]$JobId, # unique identifier of the Azure Automation job to monitor
        [int]$TimeoutSeconds = 600, # maximum time to wait for the job to complete. Default is 10 minutes (in seconds)
        [int]$PollIntervalSeconds = 10
    )

	# Initializing elapsed time
    $elapsed = 0
	# Checks job status until either completion or timeout
    While($true){
		# Retrieving job status
        $job = Get-AzAutomationJob -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Id $JobId
		# If job is finished: exit the loop
        If($job.Status -in @('Completed', 'Failed', 'Stopped')) {
            Break
        }
        Start-Sleep -Seconds $PollIntervalSeconds
        $elapsed += $PollIntervalSeconds
		
		# If time exceeds the timeout: throw an error
        If($elapsed -ge $TimeoutSeconds) {
            Throw "Timeout waiting for job $JobId"
        }
    }
}

# Things to run in each runbook as parameter
$Values = @("MyJob1",
"MyJob2",
"MyJob3",
"MyJob4",
"MyJob5",
"MyJob6",
"MyJob7",
"MyJob8",
"MyJob9",
"MyJob10")

$Automation_jobs = @()

# For each things to run in $Values
ForEach($Value in $Values)
	{
		# Start the child runbook 
		$Automation_job = Start-AzAutomationRunbook -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Name $RunbookName -Parameters @{ Name = $Value }
		$Automation_jobs += $Automation_job
		If($Automation_jobs.Count -ge 5) {
			ForEach($job in $Automation_jobs) {
				Wait-ForAutomationJob -JobId $job.JobId
			}
			$Automation_jobs = @()
		}
	}