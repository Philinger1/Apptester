<#
By: Philipp Schindler  | Endpointinsights.net
Date: 21/02/23
Version: 1.3

.SYNOPSIS
    Tool to get the App-Test-Status from Software-manager defined in Helpline
 .Required:
    - SCCM-Agent (WMI-Data), 
    - Exported Helpline-CSV in this format: packagename;userid
    - Right-Permission in registry: HKLM:\Software\Apptest
    - SCCM inventoy mof-File (there is no detection in this script that checks the SCMM inventory)
        configurationmof 
        client settings

    
.DESCRIPTION
    This Tool shows all SCCM-Assinged Apps on a client computer
    The User can select a App and save the Status and and a description

    Additionally The Apps in the List are filterd:
    All Apps with Applictaion Category "System" are exclude

    When the "User-Filter" is enabled only Apps that are assigned to the logged on User are shown
    The Tool gets the assignement between Software Tester and Software from the CSV-File, exported from Helpline
    When the csv is not accessible the User-Filter checkbox is disabled

    CAUTION: Because the Helpline and the SCCM Application-Name dat does not match 100%. To get the Data anyway the script tries a few versions of the name
    See in #Region Application Names. So could happen in some cases that the script shows Application that ar not really assigned with the logged on User when the filter is enabled  
 



Change-log
#apps with User Category "System" won't be listed
#User with Fullname - got from registry
#better Form design
#logging
02/22/2023: Philipp Schindler: Reg-Key as variable and solved some bug inerror handling
02/09/2023: Philipp Schindler: required comment when problem
                               disabe Multi Select
                               solved Bug in sort function
                               disable formsize-change 
                               clear-button + function
                               Status in word not in numbers
02/10/2023: Philipp Schindler: solved bug: delete status message when click "perfect"
02/23/2023: Philipp Schindler: shows selected App, Status-colors, changed mouseclickevent to indexchangeevent on datagridview



#>


#region setup parameter

[switch]$Log_enabled=$false
$LogfileName = ".\Apptester.log"
$ApplicationManagerFile=".\SoftwarePackage.csv"


$RegLocation="HKLM:\Software\Apptest"

#endregion






#to log something
function Write-Log {
    [CmdletBinding()]
    param
    (
        [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR')]
        [string]$Type,
        [string]$Text
        
    )
    if($Log_enabled -eq $true){
 
    [string]$logFile = $LogfileName
    $logEntry = '{0}: <{1}> {2}' -f $(Get-Date -Format dd.MM.yyyy-HH:mm:ss), $Type, $Text
    Add-Content -Path $logFile -Value $logEntry
    }
}





$script:keypressed = {

if($textBox.Text.Length -eq 0){
$saveButton.Enabled=$false
$labelstatus.Text = 'please descripe the problem'
   $labelstatus.ForeColor='RED'


}else
{
$saveButton.Enabled=$true
$labelstatus.Text = ""
}

}


$script:problem = {

$saveButton.Enabled=$false
$labelstatus.Text = 'please descripe the problem'
   $labelstatus.ForeColor='RED'

}



$script:allright = {

$saveButton.Enabled=$true

$labelstatus.Text = ""

}


$script:clearAll = {

$mb = [System.Windows.Forms.MessageBox]
$mbIcon = [System.Windows.Forms.MessageBoxIcon]
$mbBtn = [System.Windows.Forms.MessageBoxButtons]

$result = $mb::Show("Are you sure?", "Question", $mbBtn::YesNo, $mbIcon::Question)
if ($result -eq 'Yes') {
        Remove-Item -Path $RegLocation\* -Recurse
 
                 if($Checkbox.checked){
                    get-Apps -Filter
                    } else {
                 get-Apps
                    }      
}


            
}





#always remog logfile at the start of the tool
if (Test-Path $LogfileName){Remove-Item $LogfileName}

Write-Log -Type INFO -Text "Starting tool"

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 


Write-Log -Type INFO -Text "Load Form"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Application Manager Report 1.3'
$form.Size = New-Object System.Drawing.Size(600,600)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle="Fixed3D"
$form.MaximizeBox=$false



$saveButton = New-Object System.Windows.Forms.Button
$saveButton.Location = New-Object System.Drawing.Point(390,520)
$saveButton.Size = New-Object System.Drawing.Size(80,23)
$saveButton.Text = 'save'
$savebutton.Enabled=$false
#$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.AcceptButton = $saveButton
$form.Controls.Add($saveButton)



$clearButton = New-Object System.Windows.Forms.Button
$clearButton.Location = New-Object System.Drawing.Point(270,520)
$clearButton.Size = New-Object System.Drawing.Size(100,23)
$clearButton.Text = 'clear all'
$clearButton.Enabled=$true
#$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$clearButton.add_Click($clearall)
$form.AcceptButton = $clearButton
$form.Controls.Add($clearButton)



$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Location = New-Object System.Drawing.Point(490,520)
$cancelButton.Size = New-Object System.Drawing.Size(80,23)
$cancelButton.Text = 'Cancel'
$cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.CancelButton = $cancelButton
$form.Controls.Add($cancelButton)

$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(10,20)
$label.Size = New-Object System.Drawing.Size(280,20)


$Checkbox = New-Object System.Windows.Forms.Checkbox 
$Checkbox.Location = New-Object System.Drawing.Size(450,20) 
$Checkbox.Size = New-Object System.Drawing.Size(500,20)
$Checkbox.Text = "User Filter"
$Checkbox.TabIndex = 4
$Checkbox.Checked=$true


try{
$AppManagers=Import-Csv $ApplicationManagerFile -Delimiter ";"


}Catch{
Write-Log -Type WARNING -Text "$ApplicationManagerFile is not accessible. Turning filter Off"
$Checkbox.Checked=$false
$Checkbox.Enabled=$false
}


$form.Controls.Add($Checkbox)


#event: Filter Checkbox
$Checkbox.Add_CheckStateChanged({


$saveButton.Enabled=$false

$labelstatus.Text = 'nothing selected'
$labelstatus.ForeColor='RED'


  if($Checkbox.checked){
         get-Apps -Filter
     } else {
     get-Apps

     }

})



#read Full USer name from Registry if exists. If not take Shortname for the welcome message
$path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\SessionData\1\"
$value="LoggedOnDisplayName"

try{

if ((Get-Item -Path $path).GetValue($value) -ne $null){
$userFN=Get-ItemPropertyValue -Path $path -Name $value | %{$_.Split(' ')[1] +" "+ $_.Split(' ')[0]} -Verbose
 $label.Text = "Hello $userFN!" 
 
} 
else{
$label.Text = "Hello $env:USERNAME!" 
}
}
catch
{
Write-Log -Type ERROR -Text "There is no value in HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\SessionData\1\"
}



#add label
$form.Controls.Add($label)
$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(10,50)
$label.Size = New-Object System.Drawing.Size(400,20)
$label.Text = 'Please select an application:'
$label.Font=[System.Drawing.Font]::new("Microsoft Sans Serif", 12, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($label)

#add status Maessage
$labelstatus = New-Object System.Windows.Forms.Label
$labelstatus.Location = New-Object System.Drawing.Point(10,520)
$labelstatus.Size = New-Object System.Drawing.Size(280,20)
$labelstatus.Text = 'nothing selected'
$labelstatus.ForeColor='RED'
$form.Controls.Add($labelstatus)


#add the listbox
$listBox = New-Object System.Windows.Forms.DataGridView
$listBox.Location = New-Object System.Drawing.Point(10,80)
$listBox.Size=New-Object System.Drawing.Size(560,190)
$listBox.ColumnCount=2
$listbox.ColumnHeadersVisible=$true
$listbox.AllowUserToAddRows=$false
$listbox.SelectionMode='FullRowSelect'
$listbox.MultiSelect=$false
$listBox.ReadOnly=$true
$listBox.Columns[0].Width=400
$listBox.columns[0].Name="Applications"
$listBox.columns[1].Name="Status"
$listBox.Columns[1].Width=117





#Listbox Event
$listBox.Add_SelectionChanged({
    #The event is actually $listBox.SelectedIndexChanged but we want to ADD an action. add_SelectedIndexChanged is not listed in get-member.
    #$ListSelected = $listBox.Rows[$listBox.SelectedRow].cells[1].Value
    # Write-Host "ListSelected = $ListSelected"
    # You will note that $ListSelected is not available outside the event yet. It is in the scope of the scriptblock.
   $textBox.Text=""
 #  $x=$listBox.SelectedRows.cells[1].Value


     if ($listBox.SelectedRows){
     $Appname=$listBox.SelectedRows.cells[0].Value

   $label.Text ="Selected Application: $Appname"


    if(Test-Path "$RegLocation\$Appname\"){
         $status=Get-ItemPropertyValue "$RegLocation\$Appname\" -name "Status"
         if($status -eq 1){
             $RadioButton1.Checked=$true
	    }

        if($status -eq 2){
         $RadioButton2.Checked=$true
	    }

        if($status -eq 3){
        $RadioButton3.Checked=$true
	    }
        if($status -eq 0){
        $RadioButton1.Checked=$true
	    }

        $description=Get-ItemPropertyValue "$RegLocation\$Appname\" -name "Description"
        $textBox.Text=$description
    }
    else{
        $RadioButton1.Checked=$true
    }
    $savebutton.Enabled=$true


$labelstatus.ForeColor='BLACK'
$labelstatus.Text=''
}

})


    $saveButton.add_Click({. $saveScript})



 # Create a group that will contain your radio buttons
    $MyGroupBox = New-Object System.Windows.Forms.GroupBox
    $MyGroupBox.Location = '10,280'
    $MyGroupBox.size = '560,130'
    $MyGroupBox.text = "App Status?"
    
    # Create the collection of radio buttons
    $RadioButton1 = New-Object System.Windows.Forms.RadioButton
    $RadioButton1.Location = '10,40'
    $RadioButton1.size = '350,20'
    $RadioButton1.Checked = $true 
    $RadioButton1.Text = "It works perfect"
       $RadioButton1.add_Click($allright)
 
    $RadioButton2 = New-Object System.Windows.Forms.RadioButton
    $RadioButton2.Location = '10,70'
    $RadioButton2.size = '350,20'
    $RadioButton2.Checked = $false
    $RadioButton2.Text = "doesn't work at all"
    $RadioButton2.add_Click($problem)
 
    $RadioButton3 = New-Object System.Windows.Forms.RadioButton
    $RadioButton3.Location = '10,100'
    $RadioButton3.size = '350,20'
    $RadioButton3.Checked = $false
    $RadioButton3.Text = "Works. But with problems"
        $RadioButton3.add_Click($problem)
 




 # Add all the GroupBox controls on one line
    $MyGroupBox.Controls.AddRange(@($Radiobutton1,$RadioButton2,$RadioButton3))
    $form.Controls.AddRange(@($MyGroupBox))




   $textBox = New-Object System.Windows.Forms.TextBox
   $textBox.Multiline = 1
   $textBox.Scrollbars = 1
   $textBox.Location = New-Object System.Drawing.Point(10,420)
   $textBox.Size = New-Object System.Drawing.Size(560,80)
   $textBox.MaxLength=256
   $textBox.add_TextChanged($keypressed)
   $form.Controls.Add($textBox)




   
#Event Save selected Item from listbos to Registry 

$script:saveScript = {

$saveButton.Enabled=$false

    # or define the whole ScriptBlock in a higher scope...
    if( $comboBox.SelectedIndex -ge 0){

        $Env = $comboBox.SelectedItem    #Be carefull $env is the beginning of environmental variables like $env:path
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.close()

    }
    else{
          if ($RadioButton1.Checked -eq $true ){
           $status=1}
           elseif ($RadioButton2.Checked-eq $true ){
           $status=2}
           elseif ($RadioButton3.Checked-eq $true ){
           $status=3
           }
      
     # write-host $status
         
      $Appname=$listBox.SelectedRows.cells[0].Value
           
             

        If (Get-ItemProperty -Path "$RegLocation\$Appname" -Name User -ErrorAction SilentlyContinue) {
        
             $username=Get-ItemProperty -Path "$RegLocation\$Appname" -Name User 
         
             #write-host $username.User
             #write-host $env:USERNAME

     
            if($username.User -ne $env:USERNAME){
                 
                 $un=$username.User
            
                [System.Windows.Forms.MessageBox]::Show("Test status has already been submitted by user $un from this machine","Application-Manager User bereits vorhanden",0,[System.Windows.Forms.MessageBoxIcon]::Exclamation)
                Write-Log -Type WARNING -Text "Test Status  $appname already send from $un"

            }else{
 
               
               try{
            New-Item "$RegLocation\$Appname" -Force -ErrorAction Stop
            New-ItemProperty -Type DWord -Path "$RegLocation\$Appname" -Name Status -value $status -Force -ErrorAction Stop
            New-ItemProperty -Type String -Path "$RegLocation\$Appname" -Name Description -value $textbox.Text -Force -ErrorAction Stop
            New-ItemProperty -Type String -Path "$RegLocation\$Appname" -Name User -value $env:USERNAME -Force -ErrorAction Stop
             Write-Log -Type INFO -Text "Saved $appname with Status= $status, User= $env:USERNAME"  
                }
                catch{
                Write-Log -Type ERROR -Text "Error writing reg-values in $RegLocationt\"
                [System.Windows.Forms.MessageBox]::Show("cannot save anything","please contact you Admins",0,[System.Windows.Forms.MessageBoxIcon]::Exclamation)
                }
                


                 if($Checkbox.checked){
                    get-Apps -Filter
                    } else {
                 get-Apps
                   
                }
                 $labelstatus.Text = 'nothing selected'
                 $labelstatus.ForeColor='RED'
                #Invoke-WmiMethod  -Namespace root\CCM -Class SMS_Client -Name TriggerSchedule -ArgumentList "{00000000-0000-0000-0000-000000000001}"
              
                
            }
        } 
        Else {


            try{
            New-Item "$RegLocation\$Appname" -Force -ErrorAction Stop
            New-ItemProperty -Type DWord -Path "$RegLocation\$Appname" -Name Status -value $status -Force -ErrorAction Stop
            New-ItemProperty -Type String -Path "$RegLocation\$Appname" -Name Description -value $textbox.Text -Force -ErrorAction Stop
            New-ItemProperty -Type String -Path "$RegLocation\$Appname" -Name User -value $env:USERNAME -Force -ErrorAction Stop
             Write-Log -Type INFO -Text "Saved $appname with Status= $status, User= $env:USERNAME"  
              }
                catch{
                Write-Log -Type ERROR -Text "Error writing reg-values in $RegLocation\"
                [System.Windows.Forms.MessageBox]::Show("cannot save anything","please contact you Admins",0,[System.Windows.Forms.MessageBoxIcon]::Exclamation)
                } 
               
               
        
            
             if($Checkbox.checked){
             get-Apps -Filter
             } else {
            get-Apps
    
             }
                  $labelstatus.Text = 'nothing selected'
                    $labelstatus.ForeColor='RED'
   
               
            #Invoke-WmiMethod  -Namespace root\CCM -Class SMS_Client -Name TriggerSchedule -ArgumentList "{00000000-0000-0000-0000-000000000001}"
        }
  
      }
    
}


function get-Apps{


    param
    (
        [switch] $Filter
    )

   
     $applications = get-wmiobject -query "SELECT * FROM CCM_Application" -namespace "ROOT\ccm\ClientSDK" | Select-Object FullName, InstallState, EvaluationState, ErrorCode, Id, Revision, IsMachineTarget, Categories
      if(-not $applications)
     {
     Write-Log -Type ERROR -Text "No WMI Data from SCCM found"
     [System.Windows.Forms.MessageBox]::Show("there is no Data from SCCM","SCCM-WMI-Error",0,[System.Windows.Forms.MessageBoxIcon]::Exclamation)

     }else
     {
     Write-Log -Type INFO -Text "gets data from SCCM"
     }
     
     
     $listBox.RowCount=0
     foreach($app in $applications)
     
        { $ctr=0
        $status="no status"
        $Appname=$app.FullName

        if(Test-Path "$RegLocation\$Appname")
                {#Write-Host $appname

                if (Get-ItemPropertyValue "$RegLocation\$Appname\" -name "Status"){
                    $status=Get-ItemPropertyValue "$RegLocation\$Appname\" -name "Status"

                    switch(Get-ItemPropertyValue "$RegLocation\$Appname\" -name "Status"){
            

                    1{$status="works"}
                    2{$status="Doesn't works"}
                    3{$status="works with problems"}
                    
                    
                   }




                    $description=Get-ItemPropertyValue "$RegLocation\$Appname\" -name "Description"
                }
         }

        #apps with User Category "System" won't be listed
        if  (-not $app.Categories.contains("System")){

            
            #write-host $possiblename5
            #write-host  $possiblename3

            if($filter){
                foreach($testapp in $AppManagers){
                    if($testapp.UserId -eq $env:USERNAME){
                        

                         #region Application Names
                         $ctr=0
                         $x1=$appname.LastIndexOf(" ")
                         $x2=$Appname.Substring(0,$x1).LastIndexOf(" ")
                         $possiblename1=$Appname.Substring(0,$x2)
                         $possiblename2= $possiblename1.Replace(" ","_")
                         $possiblename3= $possiblename2.Remove(0,1)
                         $possiblename4= $possiblename1.Remove(0,1)
                         $x3= $possiblename4.IndexOf(" ")
                         $possiblename5=$possiblename4.Remove(0,$x3+1)
                         switch ($testapp.packagename){
                        {$_.Contains($appname)}{$ctr=1}
                        {$_.Contains($possiblename1)}{$ctr=1}
                        {$_.Contains($possiblename2)}{$ctr=1}
                        {$_.Contains($possiblename3)}{$ctr=1}
                        {$_.Contains($possiblename4)}{$ctr=1}
                        {$_.Contains($possiblename5)}{$ctr=1}
                        }
                        #endregion
                     }
            
                    if($ctr -eq 1){
    
                        #write-host $Appname
                        $listBox.rows.Add($app.FullName,$status)| out-null

                         


                        break
      
                    } 
         
                }
            }else
            {
                $listBox.rows.Add($app.FullName,$status)| out-null
   
            }
        }
    }
    $textbox.Clear()
    $RadioButton1.Checked=$true

     
    $listBox.Sort($listBox.Columns[0],'Ascending')


 


 
 



    foreach ($Row in $listBox.Rows) {
 
  switch($Row.cells[1].Value ){
            

                    "works"{$row.defaultcellstyle.backcolor = "#cef8d4"}
                    "Doesn't works"{$row.defaultcellstyle.backcolor = "#fbcac6"}
                    "works with problems"{$row.defaultcellstyle.backcolor = "#f5d4b2"}
                    "no status"{$row.defaultcellstyle.backcolor = "#ffffff"}
                    
 
 }
 
 
 
 $listBox.Rows[0].Selected = 1
 
 
 
 
 
}




}
     if($Checkbox.checked){
                    get-Apps -Filter
                    } else {
                 get-Apps}
    $form.Controls.Add($listBox)
    $form.Topmost = $true
    $result = $form.ShowDialog()
    
 