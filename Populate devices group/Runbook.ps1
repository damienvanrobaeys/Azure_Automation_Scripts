# Target group id, type the ID of the target group
$Users_Group = "" # ID of the users groupfor which you want to get devices
$Devices_Target_Group_Id = ""

# If you want to send a notif by mail
$Send_Mail = $True # $True or $False
$Send_All_Devices_CSV = $False # $True or $False
$Mail_From = ""
$Mail_To = ""
$CSV_File = "TeamName_Devices_Group_new_members.csv"
$CSV_File_All = "TeamName_Devices_Group_all_members.csv"

# Notif content
$Notif_Title = "New devices added in the TeamName group"
$Notif_Message = "Here is the list of new devices added in the TeamName group based on the users."

Connect-MgGraph -Identity | out-null
 
$Get_Users_Group_Member = Get-MgGroupMember -GroupId $Users_Group -All
$Get_Target_Group_Members = (Get-MgGroupMember -GroupId $Devices_Target_Group_Id -All) 
  
$Devices_Array = @()
ForEach($user in $Get_Users_Group_Member) 
	{
		$devices = Get-MgUserOwnedDevice -UserId $user.Id | where {($_.AdditionalProperties.operatingSystem -eq "windows") -and ($_.AdditionalProperties.deviceOwnership -eq "company") -and ($_.AdditionalProperties.isManaged -eq $true) -and ($_.AdditionalProperties.accountEnabled -eq $true) -and ($_.AdditionalProperties.isManaged -ne $null)}
		ForEach($device in $devices) 
			{
				$Device_ID = $device.Id
				$Device_Name = $device.AdditionalProperties.displayName
				$Device_Manufacturer = $device.AdditionalProperties.Manufacturer

				If($Get_Target_Group_Members.id -eq $Device_ID)
					{
						$Member_Status = "Already member"
					}
				Else
					{
						$User_ID = $user.id
						$Get_User_DisplayName = (Get-MgUser -UserId $User_ID).DisplayName	

						$Member_Status = "Not member"
						Try{
							New-MgGroupMember -GroupId $Devices_Target_Group_Id -DirectoryObjectId $device.Id
							$Status = "OK"
						}
						Catch{
							$Status = "KO"
						}
					}
								
				$Obj = New-Object PSObject
				Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Device name" -Value $Device_Name
				Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Member status" -Value $Member_Status
				Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Manufacturer" -Value $Device_Manufacturer
				Add-Member -InputObject $Obj -MemberType NoteProperty -Name "User name" -Value $Get_User_DisplayName
                Add-Member -InputObject $Obj -MemberType NoteProperty -Name "User ID" -Value $user.id
				Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Device object ID" -Value $Device_ID
				Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Status" -Value $Status
				$Devices_Array += $Obj
			}
	}

If($Send_Mail -eq $True)
    {
		$New_Devices = $Devices_Array | where {(($_."Member status" -eq "Not member") -and ($_.Status -eq "OK"))}
		
        If($Send_All_Devices_CSV -eq $True)
        {
            $All_Devices = $Devices_Array | where {($_.Status -eq "OK")}
        }
		
        $Devices_Count = $New_Devices.count
		If($Devices_Count -eq 0)
			{
				EXIT 
			}
			
		$NewFile = New-Item -ItemType File -Name $CSV_File	

        If($Send_All_Devices_CSV -eq $True)
        {
		    $NewFile = New-Item -ItemType File -Name $CSV_File_ALL
    		$All_Devices | Select "Device name","User name","User ID", "Device object ID","Member status" | export-csv $CSV_File_ALL -notype -Delimiter ";"
            $attachmentmessage_all = [Convert]::ToBase64String([IO.File]::ReadAllBytes($CSV_File_All))
            $attachmentname_all = (Get-Item -Path $CSV_File_ALL).Name
        }        	

		$New_Devices | Select "Device name","User name","User ID", "Device object ID" | export-csv $CSV_File -notype -Delimiter ";"

        $Text_Message = "$Notif_Message" + " $Devices_Count new devices added."

        $attachmentmessage = [Convert]::ToBase64String([IO.File]::ReadAllBytes($CSV_File))
        $attachmentname = (Get-Item -Path $CSV_File).Name

        $params = @{
            Message         = @{
                Subject       = $Notif_Title
                Body          = @{
                    ContentType = "HTML"
                    Content     = $Text_Message
                }
                ToRecipients  = @(
                    @{
                        EmailAddress = @{
                            Address = $Mail_To
                        }
                    }
                )
                Attachments   = @(
                    @{
                        "@odata.type" = "#microsoft.graph.fileAttachment"
                        Name          = $attachmentname
                        ContentType   = "text/plain"
                        ContentBytes  = $attachmentmessage
                    }

                    If($Send_All_Devices_CSV -eq $True)
                    {
                    @{
                        "@odata.type" = "#microsoft.graph.fileAttachment"
                        Name          = $attachmentname_all
                        ContentType   = "text/plain"
                        ContentBytes  = $attachmentmessage_all
                    }  
                    }                     
                )
            }
            SaveToSentItems = "false"
        }

        Send-MgUserMail -UserId $Mail_From -BodyParameter $params                
    }
