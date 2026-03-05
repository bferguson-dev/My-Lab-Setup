Combined Bootstrap ISO Payload

Contents:
- windows/bootstrap-win.ps1
- windows/run-windows-bootstrap.cmd
- linux/bootstrap-linux.sh
- linux/run-linux-bootstrap.sh

Purpose:
- Windows: enable WinRM, disable auto updates, log to C:\LabSetup
- Linux: install/upgrade qemu-guest-agent, enable SSH, disable auto updates, log to /var/log/labsetup

Build:
- Use tools/build_bootstrap_iso_on_pm01.sh on pm01.
