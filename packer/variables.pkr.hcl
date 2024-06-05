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
    default = "GMs"
}
variable "resource_pool" {
    description = "Which resource pool to allocate the VM to."
    type    = string
    default = "ClusterResources"
}
variable "vm_version" {
    description = "Defaults to most current VM hardware supported by vCenter."
    type = number
    default = "19"
}
variable "vm_name" {
    description = "Name of the VM you are going to be templating."
    type = string
    default = "Win11GM"
}
variable "vm_network" {
    type = string
    description = "Assign the network which VM is to be connected."
    default = "VM Network"
}
variable "vm_guest_os_type" {
    description = "Defaults to guest os type of otherGuest."
    type = string
    default = "windows9_64Guest" # Win 11: windows11_64Guest / Win 10: windows9_64Guest
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
    default = 2
}
variable "ram" {
    description = "Amount of RAM in MB."
    type = number
    default = 4096
}
variable "disk_size" {
    description = "The size of the disk in MB."
    type = number
    default = 51200
}
variable "os_iso_path" {
    description = "ISO path for OS unattendeded installs."
    type = string
    default = "[datastore1] ISOs/Windows_11_Enterprise_23H2.iso"
}
variable "vmtools_iso_path" {
    description = "ISO Path for VMware Tools Windows exe. Used for drivers, performance etc."
    type = string
    # download from https://packages.vmware.com/tools/releases/latest/windows/
    default = "[datastore1] ISOs/VMware-tools-windows-12.4.0-23259341.iso"
}
variable "unattended_file" {
    type = string
    default = "autounattend-win11.xml"
}
