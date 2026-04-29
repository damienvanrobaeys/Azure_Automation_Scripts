$Registry_Key = "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing"
$Registry_Key_Value = (Get-ItemProperty -Path $Registry_Key -Name "UEFICA2023Status" -ErrorAction SilentlyContinue).UEFICA2023Status
If($Registry_Key_Value -eq "Updated")
{
	write-output "Status OK"
	EXIT 0
}Else{
	write-output "Status KO: $Registry_Key_Value"
	EXIT 1	
}
