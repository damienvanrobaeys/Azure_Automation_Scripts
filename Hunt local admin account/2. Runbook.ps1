<# 
Modules to use:
Connect-MgGraph: Microsoft.Graph.Authentication
Start-MgSecurityHuntingQuery: Microsoft.Graph.Security
Send-MgUserMail: Microsoft.Graph.Users.Actions
#>

# Who send the mail
$Mail_From = ""

# Who receive the mail
$Mail_To = ""
$CC1 = ""
$CC2 = ""
$CC3 = ""

# Notif content
$Notif_Title = "Devices with local admin account(s)"
$Notif_Message = "Here is a list of device(s) with local admin account(s)"

# Authenticate through the managed identiy
Connect-MgGraph -Identity 

# The KQL query to run remotely on MDE
# Getting all admin account authenticating to devices in DeviceLogonEvents table
$DeviceLogonEvents_Query = @"
DeviceLogonEvents 
| where Timestamp > ago(30d)
| where ActionType contains "LogonSuccess"
| where IsLocalAdmin == 1
| where DeviceName == AccountDomain
| where  AccountName !contains "defaultuser0" and AccountName !contains "lenovo_tmp"
//| where DeviceName !contains "" // you can add a filter on devicename like where DeviceName !contains "mtr-"
| where LogonType contains "Interactive" and LogonType !contains "RemoteInteractive"
| join DeviceInfo on DeviceName
| where isempty(DeviceManualTags)
| summarize arg_max(Timestamp,*) by DeviceName, AccountName
| project Timestamp,AccountName,DeviceName,AccountDomain,AccountSid
"@	

# Executing the KQL query
# Start-MgSecurityHuntingQuery  from the module Microsoft.Graph.Security
$Results  = Start-MgSecurityHuntingQuery -Query $DeviceLogonEvents_Query

# Getting results from the query
$rows = @($Results.Results)
$allKeys = $rows | ForEach-Object { $_.AdditionalProperties.Keys } | Select-Object -Unique
$DeviceLogonEvents = @()
foreach ($row in $rows) {
    $obj = New-Object PSObject
    foreach ($key in $allKeys) {
        $value = $row.AdditionalProperties[$key]
        if ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
            $obj | Add-Member -NotePropertyName $key -NotePropertyValue ($value -join ", ")
        } else {
            $obj | Add-Member -NotePropertyName $key -NotePropertyValue $value
        }
    }
    $DeviceLogonEvents += $obj
}

# Creating the CSV file if local admin found
$Devices_Count = $DeviceLogonEvents.count
$Notif_Title = "$Devices_Count" + " $Notif_Title"
If($Devices_Count -gt 0)
{
	New-Item -ItemType File -Name $CSV_File	
}Else{
	EXIT
}


$Devices_Array = @()
$Found_in_Intune = $False	
$Found_in_EntraID = $False	
$Found_in_Autopilot = $False	

# For each device found with local admin account getting DeviceName, connexion date, AccountName and AccountSid
ForEach($Device in $DeviceLogonEvents)
	{
		$Device_Name = $Device.DeviceName	
		$Connexion = $Device.Timestamp	
		$AccountName = $Device.AccountName	
		$AccountSid = $Device.AccountSid	

# Checking when the account has been created based on the AccountSid in the DeviceEvents table
$DeviceEvents_Query = @"
DeviceEvents
| where ActionType == "UserAccountAddedToLocalGroup"
| extend Details = parse_json(AdditionalFields)
| extend GroupName = tostring(Details.GroupName),GroupSid = tostring(Details.GroupSid)
| where GroupSid == "S-1-5-32-544"
| summarize arg_max(Timestamp,*) by DeviceName
| where DeviceName contains "$Device_Name"
| extend TimeAdded=Timestamp
| where AccountSid contains "$AccountSid"
| project DeviceName,AccountSid,TimeAdded,GroupName
"@	

		$Results  = Start-MgSecurityHuntingQuery -Query $DeviceEvents_Query
		$rows = @($Results.Results)
		$allKeys = $rows | ForEach-Object { $_.AdditionalProperties.Keys } | Select-Object -Unique
		$DeviceEvents = @()
		foreach ($row in $rows) {
			$obj = New-Object PSObject
			foreach ($key in $allKeys) {
				$value = $row.AdditionalProperties[$key]
				if ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
					$obj | Add-Member -NotePropertyName $key -NotePropertyValue ($value -join ", ")
				} else {
					$obj | Add-Member -NotePropertyName $key -NotePropertyValue $value
				}
			}
			$DeviceEvents += $obj
		}			
				
		# Getting the date when the account has been created
		If($DeviceEvents.count -gt 0)
		{
			$TimeAdded = $DeviceEvents.TimeAdded
		}Else{
			$TimeAdded = $null
		}
			
		# Getting info about the device in Intune
		$Intune_Device_URL = "https://graph.microsoft.com/v1.0/devicemanagement/manageddevices?`$filter=deviceName eq '$Device_Name'"
		$Intune_Device_info = (Invoke-MgGraphRequest -Uri $Intune_Device_URL  -Method GET).value	
		If($Intune_Device_info -ne $null)
		{		
			$Found_in_Intune = $True					
			$userDisplayName = $Intune_Device_info.userDisplayName
			$model = $Intune_Device_info.model		
			$enrolledDateTime = $Intune_Device_info.enrolledDateTime
			$lastSyncDateTime = $Intune_Device_info.lastSyncDateTime
			$serialNumber = $Intune_Device_info.serialNumber
			$deviceEnrollmentType = $Intune_Device_info.deviceEnrollmentType
			$deviceRegistrationState = $Intune_Device_info.deviceRegistrationState
			$ManagementCertificateExpirationDate = $Intune_Device_info.ManagementCertificateExpirationDate
		}Else{
			$Found_in_Intune = $False			
			$userDisplayName = $null	
			$model = $null		
			$enrolledDateTime = $null	
			$lastSyncDateTime = $null	
			$serialNumber = $null	
			$deviceEnrollmentType = $null	
			$deviceRegistrationState = $null
			$ManagementCertificateExpirationDate = $null			
		}		

		# Getting info about the device in EntraID		
		$EntraID_Device_URL = "https://graph.microsoft.com/v1.0/devices?`$filter=displayName eq '$Device_Name'"
		$EntraID_Device_info = (Invoke-MgGraphRequest -Uri $EntraID_Device_URL  -Method GET).value	
		If($EntraID_Device_info -ne $null)
		{
			$Found_in_EntraID = $True			
			$registrationDateTime = $EntraID_Device_info.registrationDateTime
			$enrollmentProfileName = $EntraID_Device_info.enrollmentProfileName
			$approximateLastSignInDateTime = $EntraID_Device_info.approximateLastSignInDateTime
		}Else{
			$Found_in_EntraID = $False	
			$registrationDateTime = $null
			$enrollmentProfileName = $null
			$approximateLastSignInDateTime = $null
		}
				
		# Getting info about the device in Autopilot
		If($serialNumber -ne $null)
		{
			$Autopilot_Device_URL = 'https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities?$filter' + "=contains(serialNumber,'$SerialNumber')"
			$Autopilot_Device_info = (Invoke-MgGraphRequest -Uri $Autopilot_Device_URL  -Method GET).value
			If($Autopilot_Device_info -ne $null)
			{
				$Found_in_Autopilot = $True	
				$enrollmentState = $Autopilot_Device_info.enrollmentState
				$lastContactedDateTime = $Autopilot_Device_info.lastContactedDateTime
				$deploymentProfileAssignedDatetime = $Autopilot_Device_info.deploymentProfileAssignedDatetime
				
			}Else{
				$Found_in_Autopilot = $False
				$enrollmentState = $null
				$lastContactedDateTime = $null
				$deploymentProfileAssignedDatetime = $null
			}
		}

		# Getting info about the device in Autopilot
		$AutopilotEvents_Device_URL = "https://graph.microsoft.com/beta/deviceManagement/autopilotEvents?`$filter=deviceSerialNumber eq '$serialNumber'"				
		$AutopilotEvents_Device_info = (Invoke-MgGraphRequest -Uri $AutopilotEvents_Device_URL  -Method GET).value					
		If($AutopilotEvents_Device_info -ne $null)
		{
			$deploymentTotalDuration = $AutopilotEvents_Device_info.deploymentTotalDuration
			$deviceSetupDuration = $AutopilotEvents_Device_info.deviceSetupDuration
			$accountSetupDuration = $AutopilotEvents_Device_info.accountSetupDuration
			
			If($deploymentTotalDuration -ne $null)
			{
				$deployment_Total_Duration = ([System.Xml.XmlConvert]::ToTimeSpan("$deploymentTotalDuration")).ToString()
				
			}Else{
				$deployment_Total_Duration = $null
			}
	
			If($deviceSetupDuration -ne $null)
			{
				$device_Setup_Duration = ([System.Xml.XmlConvert]::ToTimeSpan("$deviceSetupDuration")).ToString()
				
			}Else{
				$device_Setup_Duration = $null
			}		

			If($accountSetupDuration -ne $null)
			{
				$account_Setup_Duration = ([System.Xml.XmlConvert]::ToTimeSpan("$accountSetupDuration")).ToString()
				
			}Else{
				$account_Setup_Duration = $null
			}				

			$enrollmentState = $AutopilotEvents_Device_info.enrollmentState			
			$deviceSetupStatus = $AutopilotEvents_Device_info.deviceSetupStatus
			$accountSetupStatus = $AutopilotEvents_Device_info.accountSetupStatus		
		}Else{
			$deployment_Total_Duration = $null
			$device_Setup_Duration = $null
			$account_Setup_Duration = $null

			$enrollmentState = $null		
			$deviceSetupStatus = $null
			$accountSetupStatus = $null		
		}

		$Obj = New-Object PSObject
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Device name" -Value $Device_Name
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Admin account" -Value $AccountName
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Last MDE connexion" -Value $Connexion
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Account add time" -Value $TimeAdded
		
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Found in Intune" -Value $Found_in_Intune
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "User" -Value $userDisplayName		
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Model" -Value $model
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "EnrolledDateTime" -Value $enrolledDateTime
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "LastSyncDateTime" -Value $lastSyncDateTime
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "SerialNumber" -Value $serialNumber
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "DeviceEnrollmentType" -Value $deviceEnrollmentType
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "deviceRegistrationState" -Value $deviceRegistrationState
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "CertificateExpirationDate" -Value $ManagementCertificateExpirationDate

		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Found in EntraID" -Value $Found_in_EntraID
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Registration datetime" -Value $registrationDateTime
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "EnrollmentProfileName" -Value $enrollmentProfileName
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Last Signin" -Value $approximateLastSignInDateTime

		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Found in Autopilot" -Value $Found_in_Autopilot
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Autopilot enrollment State" -Value $enrollmentState
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Last contacted DateTime " -Value $lastContactedDateTime
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Deployment profile assigned Date" -Value $deploymentProfileAssignedDatetime

		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Deployment total duration" -Value $deployment_Total_Duration
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Device setup duration" -Value $device_Setup_Duration
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Account setup duration" -Value $account_Setup_Duration
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "enrollmentState" -Value $enrollmentState
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "deviceSetupStatus" -Value $deviceSetupStatus
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "accountSetupStatus" -Value $accountSetupStatus
				
		$Devices_Array += $Obj
	}

# Exporting data to the CSV
$Devices_Array | export-csv $CSV_File -notype -Delimiter ";" 		

# Attach the CSV to the mail
$attachmentmessage = [Convert]::ToBase64String([IO.File]::ReadAllBytes($CSV_File))
$attachmentname = (Get-Item -Path $CSV_File).Name

# Prepare the mail structure
$params = @{
    Message = @{
        Subject = $Notif_Title
        Body    = @{
            ContentType = "HTML"
            Content     = $Notif_Message
        }
        ToRecipients = @(
            @{
                EmailAddress = @{
                    Address = $Mail_To
                }
            }
        )
        CcRecipients = @(
            @{ EmailAddress = @{ Address = "$CC1" } }
            @{ EmailAddress = @{ Address = "$CC2" } }
            @{ EmailAddress = @{ Address = "$CC3" } }
        )
        Attachments = @(
            @{
                "@odata.type" = "#microsoft.graph.fileAttachment"
                Name          = $attachmentname
                ContentType   = "text/plain"
                ContentBytes  = $attachmentmessage
            }
        )
    }
    SaveToSentItems = "false"
}

# Sending the mail (Microsoft.Graph.Users.Actions module)
Send-MgUserMail -UserId $Mail_From -BodyParameter $params   

<#
Device name                      : desktop-7ed0puy7
Admin account                    : admin_1
Last MDE connexion               : 2026-03-19T07:49:27.4198519Z
Account add time                 : 2026-03-19T07:48:00.2656054Z
Found in Intune                  : True
User                             : VAN ROBAEYS Damien
Model                            : 20WNS7M800
EnrolledDateTime                 : 3/3/2026 7:22:17 AM
LastSyncDateTime                 : 3/24/2026 2:57:52 PM
SerialNumber                     : PC6TLVBTR
DeviceEnrollmentType             : windowsAzureADJoin
deviceRegistrationState          : registered
CertificateExpirationDate        : 2/28/2027 11:19:27 AM
Found in EntraID                 : True
Registration datetime            : 3/10/2026 12:57:16 PM
EnrollmentProfileName            : DEPL_WhiteGlove
Last Signin                      : 3/24/2026 2:54:30 PM
Found in Autopilot               : True
Autopilot enrollment State       : enrolled
Last contacted DateTime          : 3/24/2026 2:57:52 PM
Deployment profile assigned Date : 6/16/2023 8:30:05 AM
Deployment total duration        : 00:44:30
Device setup duration            : 00:42:36
Account setup duration           : 00:01:54
enrollmentState                  : enrolled
deviceSetupStatus                : success
accountSetupStatus               : success
#>