# Target group id, type the ID of the target group
$Users_Group = "" # ID of the users groupfor which you want to get devices
$Devices_Target_Group_Id = ""

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
