# WinPE-WireGuard
Script to apply IP address of bare metal device and start WireGuard tunnel. The purpose is to use the existing IP and WireGuard tunnel information of the physical, or virtual, device to perform a bare metal restore. 

Need to download and place wg.exe, wintun.dll, and wireguard.exe into the BareMetal folder. Build, or open, a WinPE ISO and place the Baremetal folder in the mount. 

My example, after creating the mount point for WinPE:
Dism /Mount-Image /ImageFile:"C:\WinPE_Fresh\media\sources\boot.wim" /index:1 /MountDir:"C:\WinPE_Fresh\mount" 

Copy the BareMetal folder to the mount then close the image:
Dism /Unmount-Image /MountDir:"C:\WinPE_Fresh\mount" /Commit

Finally, make the ISO:
oscdimg -m -o -u2 -udfver102 -bootdata:2#p0,e,b"C:\WinPE_Fresh\media\boot\etfsboot.com"#pEF,e,b"C:\WinPE_Fresh\media\efi\microsoft\boot\efisys.bin" "C:\WinPE_Fresh\media" "C:\WinPE_UEFIBIOS_BMR_v1.06.iso" 

Note, my ISO will work for either UEFI or BIOS boot. 
