LAB Bootstrap ISO Payload

Files expected at ISO root:
- bootstra.ps1      (Windows bootstrap)
- run_wind.cmd      (Windows runner)
- bootstra.sh       (Linux bootstrap)
- run_linu.sh       (Linux runner)

Order enforced by scripts:
1) Disable auto updates
2) Install/update tools (qemu-guest-agent)
3) Enable remote access (WinRM/SSH)
4) Open firewall for remote management
5) Write verification logs

Logs:
- Windows: C:\LabSetup
- Linux: /var/log/labsetup
