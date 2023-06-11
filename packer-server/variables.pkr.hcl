/*
Packer documentation for variables and so on: https://www.packer.io/docs/builders/vsphere/vsphere-iso
*/ 


variable "vcenter_username" {
    description = "vCenter username."
    type    = string
}
variable "vcenter_password" {
    description = "vCenter password."
    type    = string
    sensitive = true
}
variable "tca_private_url" {
    description = "Base URL for private TCA files."
    type        = string
    sensitive   = true
    default     = "https://www.tcanationals.com/my_url"
}
variable "vcenter_server" {
    description = "vCenter server to connect."
    type    = string
}
variable "vcenter_cluster" {
    description = "Which cluster to select from the vCenter."
    type    = string
    default = "Cluster1"
}
variable "vcenter_datacenter" {
    description = "Which datacentre to select from the vCenter cluster."
    type    = string
    default = "BUR1"
}
variable "vcenter_host" {
    description = "Which ESXi host to select from the vCenter datacentre."
    type    = string
}
variable "vcenter_datastore" {
    description = "Which datastore to select from the ESXI host."
    type    = string
    default = "datastore1"
}
variable "vcenter_folder" {
    description = "The vCenter folder to store the template"
    type    = string
    default = "ServerVMs"
}
variable "vm_version" {
    description = "Defaults to most current VM hardware supported by vCenter."
    type = number
    default = "13"
}
variable "vm_name" {
    description = "Name of the VM you are going to be templating."
    type = string
    default = "Win10GM"
}
variable "vm_network" {
    type = string
    description = "Assign the network which VM is to be connected."
    default = "VM Network"
}
variable "vm_guest_os_type" {
    description = "Defaults to guest os type of otherGuest."
    type = string
    default = "windows9_64Guest" # Refer to https://code.vmware.com/apis/704/vsphere/vim.vm.GuestOsDescriptor.GuestOsIdentifier.html for guest OS types.
}
variable "network_card" {
    default = "vmxnet3"
}
variable "vm_firmware"{
    description = "Packer by default uses BIOS."
    type = string
    default = "efi"
}
variable "cpu_num" {
    description = "Number of CPU cores."
    type = number
    default = 4
}
variable "ram" {
    description = "Amount of RAM in MB."
    type = number
    default = 4096
}
variable "disk_size" {
    description = "The size of the disk in MB."
    type = number
    default = 81920
}
variable "os_iso_path" {
    description = "ISO path for OS unattendeded installs."
    type = string
    default = "[vsanDatastore] uploads/SW_DVD9_Win_Server_STD_CORE_2022_64Bit_English_DC_STD_MLF_X22-74290.iso"
}
variable "vmtools_iso_path" {
    description = "ISO Path for VMware Tools Windows exe. Used for drivers, performance etc."
    type = string
    default = "[vsanDatastore] uploads/VMware-tools-windows-12.2.0-21223074.iso"
}
variable "unattended_file" {
    type = string
    default = "autounattend-win2022.xml"
}