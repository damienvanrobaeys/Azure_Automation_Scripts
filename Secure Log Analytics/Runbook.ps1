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
        "RequestHeader not valid"
        EXIT
    }    

$Inputs = ConvertFrom-Json $webhookdata.RequestBody 
$DeviceName = $($Inputs[0].DeviceName)
$Inputs_JSON = $webhookdata.RequestBody 
$DCR = $($Inputs[0].DCR)
$Table = $($Inputs[0].Table)

If($DCR -eq $null -or $Table -eq $null)
	{
		If(($DCR -eq $null) -and ($Table -eq $null))
			{
				"DCR and Table are missing"
			}
		ElseIf(($DCR -eq $null) -and ($Table -ne $null))
			{
				"DCR is missing"
			}
		ElseIf(($DCR -ne $null) -and ($Table -eq $null))
			{
				"Table is missing"
			}
		EXIT
	}

$url = $env:IDENTITY_ENDPOINT  
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-IDENTITY-HEADER", $env:IDENTITY_HEADER) 
$headers.Add("Metadata", "True") 
$body = @{resource='https://graph.microsoft.com/' }
$script:accessToken = (Invoke-RestMethod $url -Method 'POST' -Headers $headers -ContentType 'application/x-www-form-urlencoded' -Body $body ).access_token
Connect-AzAccount -Identity
$headers = @{'Authorization'="Bearer " + $accessToken}

$Get_Device_URL = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices?$filter' + "=contains(deviceName,'$DeviceName')"   
$Get_Device_Info = Invoke-WebRequest -Uri $Get_Device_URL -Method GET -Headers $Headers -UseBasicParsing  
$Get_Device_Info_JsonResponse = ($Get_Device_Info.Content | ConvertFrom-Json).value
If($Get_Device_Info_JsonResponse -ne $null) # "The device is allowed"
    {
        $Device_Compliance = $Get_Device_Info_JsonResponse.complianceState
        $Device_OwnerType = $Get_Device_Info_JsonResponse.managedDeviceOwnerType

        If(($Device_Compliance -ne "compliant") -or ($Device_OwnerType -ne "company"))
            {
                If(($Device_Compliance -ne "compliant") -and ($Device_OwnerType -ne "company"))
                    {
                        "Device is not compliant and owner is not company"
                    }
                ElseIf(($Device_Compliance -eq "compliant") -and ($Device_OwnerType -ne "company"))
                    {
                        "Device owner is not company"
                    }   
                ElseIf(($Device_Compliance -ne "compliant") -and ($Device_OwnerType -eq "company"))
                    {
                        "Device is not compliant"
                    }   
                EXIT                                      
            }

        $bearerToken = (Get-AzAccessToken -ResourceUrl "https://monitor.azure.com//.default").Token

        $DceURI = "https://dce-grt-dwpprd-we-telemetry-rmuq.westeurope-1.ingest.monitor.azure.com" # available in DCE > Logs Ingestion value
        $DcrImmutableId = "dcr-$DCR" # id available in DCR > JSON view > immutableId
				
        Add-Type -AssemblyName System.Web

        $headers = @{"Authorization" = "Bearer $bearerToken"; "Content-Type" = "application/json" };
        $uri = "$DceURI/dataCollectionRules/$DcrImmutableId/streams/Custom-$Table"+"?api-version=2023-01-01";
        $uploadResponse = Invoke-RestMethod -Uri $uri -Method "Post" -Body $Inputs_JSON -Headers $headers;
    }
Else
{
    "The device is not allowed (not managed)"
}
