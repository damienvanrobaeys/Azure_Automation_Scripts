param (
    [Parameter (Mandatory = $false)]
    [object] $WebHookData
)

If($WebHookData -eq "")
	{
		write-warning "No data"
		EXIT 
	}

# Getting inputs from the script
$Inputs = ConvertFrom-Json $webhookdata.RequestBody  
$DeviceName = $($Inputs.DeviceName) 
$Action = $($Inputs.Action)  

# Fill the variable here with the group id in which you want to add devices
$Target_Group_ID = ""

# Authenticating to the managed Identity
$url = $env:IDENTITY_ENDPOINT  
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-IDENTITY-HEADER", $env:IDENTITY_HEADER) 
$headers.Add("Metadata", "True") 
$body = @{resource='https://graph.microsoft.com/' }
$script:accessToken = (Invoke-RestMethod $url -Method 'POST' -Headers $headers -ContentType 'application/x-www-form-urlencoded' -Body $body ).access_token
Connect-AzAccount -Identity
$headers = @{'Authorization'="Bearer " + $accessToken}

# Checking if the current device is a managed device
$Get_Device_URL = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices?$filter' + "=contains(deviceName,'$DeviceName')"   
$Get_Device_Info = Invoke-WebRequest -Uri $Get_Device_URL -Method GET -Headers $Headers -UseBasicParsing  
$Get_Device_Info_JsonResponse = ($Get_Device_Info.Content | ConvertFrom-Json).value
If($Get_Device_Info_JsonResponse -ne $null)
{
    $AAD_ID = $Get_Device_Info_JsonResponse.azureADDeviceId 
    $AzureAD_Device_URL = "https://graph.microsoft.com/v1.0/devices?`$filter=deviceId eq '$AAD_ID'"		
    $Get_AAD_Device_Info = Invoke-WebRequest -Uri $AzureAD_Device_URL -Method GET -Headers $Headers -UseBasicParsing
    If($Get_AAD_Device_Info -ne $null)
        {
            $Get_AAD_Device_JsonResponse = ($Get_AAD_Device_Info.Content | ConvertFrom-Json).value	
            $Device_ObjectID = $Get_AAD_Device_JsonResponse.id  
            If($Device_ObjectID -ne $null)
                {
                    $Get_Group_Members = (Get-AzADGroupMember -GroupObjectId $Target_Group_ID) | where {$_.id -eq $Device_ObjectID}
$URL = "https://graph.microsoft.com/v1.0/groups/$Target_Group_ID/members/`$ref"
$GroupMember = @{
"@odata.id"="https://graph.microsoft.com/v1.0/devices/$Device_ObjectID"
} | ConvertTo-Json
Invoke-WebRequest -Method POST -Uri $URL -Headers $Headers -UseBasicParsing -Body $GroupMember -ContentType 'application/json'     
                }
        }    
}