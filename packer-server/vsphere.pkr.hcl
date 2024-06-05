packer {
  required_version = ">= 1.7.4"

  required_plugins {
    windows-update = {
      version = "0.15.0"
      source = "github.com/rgl/windows-update"
      # Github Plugin Repo https://github.com/rgl/packer-plugin-windows-update
    }
    vsphere = {
      version = "~> 1"
      source  = "github.com/hashicorp/vsphere"
    }
  }
}

source "vsphere-iso" "win_2022_sysprep" {
  insecure_connection     = true

  create_snapshot         = false

  vcenter_server          = var.vcenter_server
  username                = var.vcenter_username
  password                = var.vcenter_password

  cluster                 = var.vcenter_cluster
  datacenter              = var.vcenter_datacenter
  host                    = var.vcenter_host
  datastore               = var.vcenter_datastore
  folder                  = var.vcenter_folder
  resource_pool           = var.resource_pool

  convert_to_template     = false
  notes                   = "Windows Server 2022 VM template built using Packer."

  ip_wait_timeout         = "20m"
  ip_settle_timeout       = "1m"
  communicator            = "winrm"
  #winrm_port             = "5985"
  winrm_timeout           = "10m"
  #pause_before_connecting = "1m"
  winrm_username          = "Administrator"
  winrm_password          = "AdminPass123"

  vm_name                 = var.vm_name
  vm_version              = var.vm_version
  firmware                = var.vm_firmware
  guest_os_type           = var.vm_guest_os_type
  CPUs                    = var.cpu_num
  CPU_hot_plug            = true
  RAM                     = var.ram
  RAM_reserve_all         = false
  RAM_hot_plug            = true
  video_ram               = "131072" # 128MB in bytes
  cdrom_type              = "sata"
  remove_cdrom            = false
  NestedHV                = true
  disk_controller_type    = ["pvscsi"]

  configuration_parameters = {
    "devices.hotplug" = "true",
    "mks.enable3d" = "true", # enable 3d support
  }
    
  network_adapters {
    network               = var.vm_network
    network_card          = var.network_card
  }
  
   storage {
    disk_thin_provisioned = true
    disk_size             = var.disk_size
  }

  iso_paths = [
    var.os_iso_path,
    var.vmtools_iso_path
  ]

  // Only expose files needed for autounattend to run
  // Everything else is controlled by packer & winrm
  floppy_files = [
    "unattended/AddTrust_External_CA_Root.cer",
    "unattended/BgAssist-Config.exe.config",
    "unattended/bootstrap-base.bat",
    "unattended/bootstrap-packerbuild.ps1",
    "unattended/choco-cleaner.ps1",
    "unattended/clean-profiles.ps1",
    "unattended/defaultassociations.xml",
    "unattended/logon.bgi",
    "unattended/susa_black.bmp",
    "unattended/tca-env.ps1",
    "unattended/windows-env.ps1",
    "unattended/nextdns_ca.crt",
  ]

  // Add template for TCA URI
  floppy_content = {
    "tca-uri.ps1" = templatefile("../unattended/tca-uri.ps1.tpl", {
      private_url = var.tca_private_url
    })
    "autounattend.xml" = templatefile("../unattended/${var.unattended_file}", {})
  }

  boot_wait    = "3s"
  boot_command = [
    "<spacebar><spacebar>"
  ]
}

build {
  /* 
  Note that provisioner "Windows-Update" performs Windows updates and reboots where necessary.
  Run the update provisioner as many times as you need. I found that 3-to-4 runs tended,
  to be enough to install all available Windows updates. Do check yourself though!
  */

  sources = ["source.vsphere-iso.win_2022_sysprep"]

  provisioner "windows-restart" { # A restart to settle Windows after VMware Tools install
    restart_timeout = "15m"
  }

  provisioner "windows-update" {
    pause_before = "5s"
    timeout = "1h"
    search_criteria = "IsInstalled=0"
    filters = [
      #"exclude:$_.Title -like '*VMware*'", # Can break winRM connectivity to Packer since driver installs interrupt network connectivity
      "include:$true"
    ]
  }

  provisioner "windows-update" {
    pause_before = "1m"
    timeout = "1h"
    search_criteria = "IsInstalled=0"
    filters = [
      #"exclude:$_.Title -like '*VMware*'", # Can break winRM connectivity to Packer since driver installs interrupt network connectivity
      "include:$true"
    ]
  }

  // Not pausing on these since they're not likely to yield anything...
  provisioner "windows-update" {
    timeout = "1h"
    search_criteria = "IsInstalled=0"
    filters = [
      #"exclude:$_.Title -like '*VMware*'", # Can break winRM connectivity to Packer since driver installs interrupt network connectivity
      "include:$true"
    ]
  }

  provisioner "windows-update" {
    timeout = "1h"
    search_criteria = "IsInstalled=0"
    filters = [
      #"exclude:$_.Title -like '*VMware*'", # Can break winRM connectivity to Packer since driver installs interrupt network connectivity
      "include:$true"
    ]
  }

  provisioner "powershell" {
    pause_before      = "5s"
    elevated_user     = "Administrator"
    elevated_password = "AdminPass123"
    script            = "scripts/customise_win_10.ps1"
    timeout           = "15m"
  }

  provisioner "windows-restart" { # A restart before choco to settle the VM once more.
    pause_before    = "5s"
    restart_timeout = "1h"
  }

  provisioner "powershell" {
    pause_before      = "5s"
    elevated_user     = "Administrator"
    elevated_password = "AdminPass123"
    script            = "scripts/choco-core.ps1"
    timeout           = "1h"
    valid_exit_codes  = [0, 3010]  # 3010 indicates reboot required
  }

  provisioner "windows-restart" { # A restart after choco core & before horizon
    pause_before    = "10s"
    restart_timeout = "1h"
  }

  provisioner "powershell" {
    pause_before      = "5s"
    elevated_user     = "Administrator"
    elevated_password = "AdminPass123"
    script            = "server_scripts/1_base_setup.ps1"
    timeout           = "1h"
    valid_exit_codes  = [0, 3010]  # 3010 indicates reboot required
  }
}
