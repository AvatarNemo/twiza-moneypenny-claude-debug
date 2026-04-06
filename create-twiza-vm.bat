@echo off
echo Creating TWIZA VirtualBox VM...
echo.

REM Create the VM
VBoxManage createvm --name "TWIZA" --register --ostype "Ubuntu_64"

REM Set VM specs (2GB RAM, 20GB HDD)
VBoxManage modifyvm "TWIZA" --memory 2048 --cpus 2 --vram 128
VBoxManage modifyvm "TWIZA" --nic1 nat --nictype1 82540EM
VBoxManage modifyvm "TWIZA" --audio none
VBoxManage modifyvm "TWIZA" --clipboard bidirectional
VBoxManage modifyvm "TWIZA" --draganddrop bidirectional

REM Create virtual hard disk
VBoxManage createhd --filename "%USERPROFILE%\VirtualBox VMs\TWIZA\TWIZA.vdi" --size 20480

REM Attach storage
VBoxManage storagectl "TWIZA" --name "SATA Controller" --add sata --bootable on
VBoxManage storageattach "TWIZA" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "%USERPROFILE%\VirtualBox VMs\TWIZA\TWIZA.vdi"

REM Create shared folder mapping C:\Users\chris\Downloads\TWIZA
VBoxManage sharedfolder add "TWIZA" --name "twiza-shared" --hostpath "C:\Users\chris\Downloads\TWIZA" --automount

echo.
echo VM TWIZA created successfully!
echo Shared folder mapped: C:\Users\chris\Downloads\TWIZA -^> /media/sf_twiza-shared
echo.
echo To start the VM: VBoxManage startvm "TWIZA"
echo.
pause