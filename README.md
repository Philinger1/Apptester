# Application Tester Tool

  

### Requirements
-	SCCM-Agent (WMI-Data), 
-	Exported Helpline-CSV in this format: packagename;userid
-	Right-Permission in registry: HKLM:\Software\EPinsight\Apptest
-	Setup SCCM inventoy mof-File:
o	configurationmof 
o	client settings

## Parameters (modify only if reall needed)
You find some parameters in the head of the script
[switch]$Log_enabled=$false
$LogfileName = ".\Apptester.log"
$ApplicationManagerFile=".\SoftwarePackage.csv"
$RegLocation="HKLM:\Software\Apptest"
Application tester  tool

The tool should enable the application managers to report the function status of an application in an uncomplicated way. 
 
![image](https://github.com/Philinger1/Apptester/assets/96050818/b0692219-d064-4c52-8dda-0881e8fb77b2)


## Description
The tool is written in Powershell and will converted to a executable file for the deployment. It displays all applications assigned via SCCM in a list. Optionally, the list can be filtered so that the app manager only sees the applications for which he is responsible. Via some radio buttons and a description field he can capture the status and make some notes in the descriptions field.
There are three states:
•	1= perfect
•	2=not working
•	3=works with problems
Filter by Application Manager
The Filter is an option in the tool it requires a SoftwarePackage.csv in the following format with exported data from helpline: 
productid;majorversion;manufacturer;productname;softwarename;version;coid;architecture;packagename;userid;name;email
(see ticket: 20230206-0531)
the CSV is required in the same folder like the tool itself
When there is no CSV in that folder , the option is automatically disabled in the tool.
### Optional feature: automatic keep the data-Filter in the tool up-to-date
To ensure a current status of the application managers in the tool, it would be necessary to update the csv regularly. Maybe the automatic update is also an option for the future. For this the helpline report would have to be created in and subscribed with file sharing. the CSV could then be distributed e.g. via self-updating package in SCCM regularly with new data.

### Clear function
In the tool there is a clear function to delete all status settings from the Registry at once. This enables the user to delete misconfigurations or to delete some test cases that we make in some test-sessions.

## Registry
The captured settings are stored in the registry. The Registry values are read out automatically by the hardware inventory of SCCM.
Computer\HKEY_LOCAL_MACHINE\SOFTWARE\EPinsight\Apptest
 
Registry permissions > done by Tokic Silvio
in order for the tool to have write permission on this reg-key, full permissions have been set via the GPO (“GPO DLT_W10_Clientengineering“)  and assigned.

## SCCM Inventory configurations
Inventory Database (configuration.mof) > done by Emmenegger, Erich
So that SCCM can see the data and display it in the report, the extension of the configuration.mof (of SCCM) is necessary. This extension causes the automatic creation of a new table of the SQL data base of SCCM. In this table the registry-values are stored and can be read out over SQL-ReportingServices 
// RegKeyToMOF by Mark Cochrane (with help from Skissinger, SteveRac, Jonas Hettich, Kent Agerlund & Barker)
// this section tells the inventory agent what to collect
// 2/2/2023 1:21:15 AM

#pragma namespace ("\\\\.\\root\\cimv2")
#pragma deleteclass("Apptest", NOFAIL)
[dynamic, provider("RegProv"), ClassContext("Local|HKEY_LOCAL_MACHINE\\SOFTWARE\\EPinsight\\Apptest")]
Class Apptest
{
[key] string KeyName;
[PropertyContext("Status")] Uint32 Status;
[PropertyContext("Description")] String Description;
[PropertyContext("User")] String User;
};

#pragma namespace ("\\\\.\\root\\cimv2")
#pragma deleteclass("Apptest_64", NOFAIL)
[dynamic, provider("RegProv"), ClassContext("Local|HKEY_LOCAL_MACHINE\\SOFTWARE\\EPinsight\\Apptest")]
Class Apptest_64
{
[key] string KeyName;
[PropertyContext("Status")] Uint32 Status;
[PropertyContext("Description")] String Description;
[PropertyContext("User")] String User;

};


## Client Hardware Inventory 
In addition, it is necessary to extend the hardware inventory in the client settings of SCCM accordingly. This ensures that the SCCM agents on the clients write the respective registry values to the SCCM database.
// RegKeyToMOF by Mark Cochrane (with help from Skissinger, SteveRac, Jonas Hettich, Kent Agerlund & Barker)
// this section tells the inventory agent what to report to the server
// 2/2/2023 1:21:15 AM

#pragma namespace ("\\\\.\\root\\cimv2\\SMS")
#pragma deleteclass("Apptest", NOFAIL)
[SMS_Report(TRUE),SMS_Group_Name("Apptest"),SMS_Class_ID("Apptest"),
SMS_Context_1("__ProviderArchitecture=32|uint32"),
SMS_Context_2("__RequiredArchitecture=true|boolean")]
Class Apptest: SMS_Class_Template
{
[SMS_Report(TRUE),key] string KeyName;
[SMS_Report(TRUE)] Uint32 Status;
[SMS_Report(TRUE)] String Description;
[SMS_Report(TRUE)] String User;
};

#pragma namespace ("\\\\.\\root\\cimv2\\SMS")
#pragma deleteclass("Apptest_64", NOFAIL)
[SMS_Report(TRUE),SMS_Group_Name("Apptest64"),SMS_Class_ID("Apptest64"),
SMS_Context_1("__ProviderArchitecture=64|uint32"),
SMS_Context_2("__RequiredArchitecture=true|boolean")]
Class Apptest_64 : SMS_Class_Template
{
[SMS_Report(TRUE),key] string KeyName;
[SMS_Report(TRUE)] Uint32 Status;
[SMS_Report(TRUE)] String Description;
[SMS_Report(TRUE)] String User;
};


## Client settings
The inventory of the client settings are configured here in SCCM and deployed to “All Windows Clients”:
![image](https://github.com/Philinger1/Apptester/assets/96050818/4bb64b2d-6691-42ff-b832-172340df8728)



## SQL Report
![image](https://github.com/Philinger1/Apptester/assets/96050818/e4ad9ab4-73c5-4ffd-8bbc-3059637e14c9)

 



