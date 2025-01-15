$win32_computersystem = get-ciminstance win32_computersystem
$Manufacturer = $win32_computersystem.Manufacturer
$Model = $win32_computersystem.Model
If($Manufacturer -like "*lenovo*")
	{
		$Model_FriendlyName = $win32_computersystem.SystemFamily
	}Else
	{
		$Model_FriendlyName = $Model
	}	

$DCR = "" # id available in DCR > JSON view > immutableId
$Table = "DriversSecureLA_CL" # custom log to create
$webhookURI = ""

$PNPSigned_Drivers = get-ciminstance win32_PnpSignedDriver | where {($_.manufacturer -ne "microsoft") -and ($_.driverprovidername -ne "microsoft") -and`
($_.DeviceName -ne $null)} | select-object @{label="TimeGenerated";Expression={get-date -Format "dddd MM/dd/yyyy HH:mm K"}},`
@{Label="DCR";Expression={$DCR}},`
@{Label="Table";Expression={$Table}},`
@{Label="DeviceName";Expression={$env:computername}},`
@{Label="ModelFriendlyName";Expression={$Model_FriendlyName}},`
@{Label="DeviceManufacturer";Expression={$Manufacturer}},`
@{Label="Model";Expression={$Model}},`
@{Label="DriverName";Expression={$_.DeviceName}},DriverVersion,`
@{Label="DriverDate";Expression={$_.ConvertToDateTime($_.DriverDate)}},`
DeviceClass, DeviceID, manufacturer,InfName,Location

$PS_Version = ($psversiontable).PSVersion.Major
If($PS_Version -eq 7)
	{
		$Body_JSON = $PNPSigned_Drivers | ConvertTo-Json -AsArray;
	}Else{
		$Body_JSON = $PNPSigned_Drivers | ConvertTo-Json
	}

$Secure_header = @{message='Iam_a_bit_more_secure'}
$response = Invoke-WebRequest -Method Post -Uri $webhookURI -Body $Body_JSON -UseBasicParsing -Headers $Secure_header  

$StatusCode = $response.StatusCode
$Code_Return = @{
	"202" = "Request accepted"
	"400" = "Bad Request : The webhook has expired or is disabled"
	"404" = "Not Found: webhook, runbook or account wasn't found"
	"500" = "Internal Server Error: The URL was valid, but an error occurred. Resubmit the request"
}
$Error_code = $Code_Return.GetEnumerator() | Select-Object -Property Key,Value 
$Get_Error_Label = ($Error_code | Where {$_.Key -eq $StatusCode}).Value
$Get_Error_Label	
