$params  = @{  
DeviceName ="$env:COMPUTERNAME"
} 

$webhookURI = ""

# Here is a example using registry key check
$Registry_check = Get-ItemProperty -Path HKCU:\SOFTWARE\_systanddeploy -Name Installed -ea silentlycontinue
If($Registry_check -eq $null)
{
	EXIT
}

# Call the webhook
$body = ConvertTo-Json -InputObject $params  
$response = Invoke-WebRequest -Method Post -Uri $webhookURI -Body $body -UseBasicParsing  