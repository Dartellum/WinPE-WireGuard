    ================================================================================
    WinPE Supplementary Drivers Directory
    ================================================================================

    Any network or storage drivers (.inf, .sys, .cat) placed in this directory or
    any subdirectories (e.g., VirtIO, VMXNet3, Dell, HPE) will be automatically
    scanned and loaded into memory by `baremetal-setup.bat` at launch using `drvload`.

    Because `drvload` uses Plug-and-Play (PnP) hardware matching, any driver that
    matches the system's PCI hardware initializes immediately, while non-matching
    drivers are safely ignored with no adverse effects.

    --------------------------------------------------------------------------------
    Recommended Driver Slices & Extraction Notes:
    --------------------------------------------------------------------------------

    1. Proxmox / KVM VirtIO (Network & Storage):
       - Source: virtio-win.iso
         (https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso)
       - Destination: Drivers\VirtIO\
       - Network Files (NetKVM\w10\amd64\ or NetKVM\w11\amd64\):
           * netkvm.inf
           * netkvm.sys
           * netkvm.cat
           * netkvmp.exe  <-- CRITICAL: netkvm.inf requires this helper executable;
                               omitting it causes drvload Error 0x80070002.
       - Storage Files (vioscsi\w10\amd64\ and viostor\w10\amd64\):
           * vioscsi.inf, vioscsi.sys, vioscsi.cat
           * viostor.inf, viostor.sys, viostor.cat

    2. VMware vSphere / ESXi / Workstation (VMXNet3 & PVSCSI):
       - Source: VMware Tools ISO (`windows.iso`) -> Extract setup.exe / MSI payload
       - Destination: Drivers\VMXNet3\
       - Network Files (from Drivers\vmxnet3\Win8\):
           * vmxnet3.inf
           * vmxnet3.sys
           * vmxnet3.cat
           * vmxnet3ver.dll
           * IMPORTANT OS BUILD NOTE: For Windows 10 WinPE (Build 18362 / Win10 ADK),
             use the driver from the `Win8\` folder (NDIS 6.30 / NTamd64.6.2).
             VMware's `Win10\` driver folder is restricted to Build 20124+ (Windows 11
             and Server 2022) and will silently fail to bind on WinPE 10.
       - Storage Files (from Drivers\pvscsi\Win8\):
           * pvscsi.inf, pvscsi.sys, pvscsi.cat, pvscsiver.dll

    3. Physical Bare-Metal Server Drivers (Dell, HPE, Lenovo, Broadcom, Intel):
       - Place extracted vendor .inf driver folders here as needed (e.g., Dell PERC
         percsas3.inf, Intel 10G/25G i40ea68.inf, Broadcom NetXtreme bxe.inf).
    ================================================================================
