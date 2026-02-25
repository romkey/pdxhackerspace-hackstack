# Music Assistant

## Troubleshooting

### "No buffer space available"

See [Container does not start successfully](https://github.com/music-assistant/hass-music-assistant/issues/1804)

As root create `/etc/sysctl.d/99-music-assistant.conf` on your host server with these lines:
```
# For Music Assistant
net.ipv4.igmp_max_memberships = 50
net.ipv4.igmp_max_msf = 30
```

then run these commands to activate these settings immediately without reboot:
```
sysctl -w net.ipv4.igmp_max_memberships=50
sysctl -w net.ipv4.igmp_max_msf=30
```

