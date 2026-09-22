================================================================================
WinPE Supplementary Drivers Directory
================================================================================

Any network or storage drivers (.inf, .sys, .cat) placed in this directory
or any subdirectories (e.g., VirtIO, VMXNet3, Dell, HP) will be automatically
scanned and loaded into memory by `baremetal-setup.bat` at launch using `drvload`.

Recommended Drivers:
1. Proxmox / KVM VirtIO (NetKVM):
   - Source: virtio-win.iso (https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso)
   - Files: NetKVM\w11\amd64\ (netkvm.inf, netkvm.sys, netkvm.cat)
   - Destination: Drivers\VirtIO\

2. VMware vmxnet3:
   - Source: VMware Tools ISO (windows.iso) -> extract VMware Tools -> Drivers\vmxnet3
   - Files: vmxnet3.inf, vmxnet3.sys, vmxnet3.cat
   - Destination: Drivers\VMXNet3\

3. Physical Server Drivers (Dell / HPE / Lenovo / Broadcom / Intel):
   - Place extracted vendor .inf driver folders here as needed.
================================================================================
