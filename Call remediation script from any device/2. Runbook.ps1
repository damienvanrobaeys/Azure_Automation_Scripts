param (
    [Parameter (Mandatory = $false)]
    [object] $WebHookData
)

If($WebHookData -eq "")
	{
		write-warning "No data"
		EXIT 
	}

If($WebhookData.RequestHeader.message -ne 'Iam_a_bit_more_secure')
    {
        "Password does not match"
        EXIT
    }    

$Inputs = ConvertFrom-Json $webhookdata.RequestBody 
$DeviceName = $($Inputs[0].DeviceName)
$serialnumber = $($Inputs[0].serialnumber)
$Device_ID = $($Inputs[0].DeviceID)
$RemediationID = $($Inputs[0].ScriptID)

Connect-MgGraph -Identity | out-null

$Get_Device_URL = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices?$filter' + "=contains(serialnumber,'$serialnumber')"
$Device_Infos = Invoke-MgGraphRequest -Method get -Uri $Get_Device_URL
$Device_ID = $Device_Infos.value.id

$RemediationScript_URL = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$Device_ID')/initiateOnDemandProactiveRemediation"                              
$RemediationScript_Body = @{
"ScriptPolicyId"="$RemediationID"
}  				
Invoke-MgGraphRequest -Uri $RemediationScript_URL -Method POST -Body $RemediationScript_Body	