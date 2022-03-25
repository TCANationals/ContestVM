#############################################################
##                                                         ##
##  Converting Variables from AzureDevOps Variable Group   ##
##                                                         ##
#############################################################

$User = "<Your_Horizon_Administrator>"
$Password = "<Your_Horizon_Administrator_Password>"
$Domain = "<Your_Domaion>"
$Server = "<Your_Connection_Server_FQDN>"
$Snapshot = "Created by Packer"
$Pool = "<Your_Desktop_Pool>"


#############################################################
##                                                         ##
##           Create Dynamic Virtual Machine Nae            ##
##                                                         ##
#############################################################


$Date = Get-Date -Format dd-MM-HH
$VMName = "W10-" + "$Date"


#############################################################
##                                                         ##
##           Connect to Horizon Connection Server          ##
##                                                         ##
#############################################################

VMware.VimAutomation.HorizonView\Connect-HVServer -Server $Server -Domain $Domain -User $User -Password $Password


#############################################################
##                                                         ##
##           Push Image to Horizon ACC Pool                ##
##                                                         ##
#############################################################


Start-HVPool -SchedulePushImage -Pool $Pool -LogoffSetting WAIT_FOR_LOGOFF -ParentVM $VMName -SnapshotVM $Snapshot


#############################################################
##                                                         ##
##      Disconnect from Horizon Connection Server          ##
##                                                         ##
#############################################################

VMware.VimAutomation.HorizonView\Disconnect-HVServer -Confirm:$False
