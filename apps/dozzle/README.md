# Dozzle Log File Server

Dozzle servers Docker logs through a web server.

## Agent

Run Dozzle agent on satellites.

docker compose up agent -d

Dozzle Agent will not be able to report RAM usage on Raspberry Pis running Raspberry Pi OS without this change:

Edit /boot/firmware/cmdline.txt

Add this to the end of the command line. It's very important that it be added to the end, after a space, and not on a new line:

cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1