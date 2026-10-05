# Optional: WiFi resilience extras (not enabled in the image)

These are for hotspots with flaky 2.4 GHz WiFi. Both are safe and reversible.

1. `wifi-powersave-off.service` — one-shot at boot, disables the radio power save.
2. `hotspot-netwatch.{sh,service,timer}` — checks connectivity every 60 s; gently
   re-kicks WiFi; restarts the supplicant; reboots ONLY when the stack is genuinely
   stuck (never when simply out of range).

Install on a running hotspot:

```
sudo mount -o remount,rw /
sudo cp wifi-powersave-off.service /etc/systemd/system/
sudo cp hotspot-netwatch.sh /usr/local/sbin/ && sudo chmod 755 /usr/local/sbin/hotspot-netwatch.sh
sudo cp hotspot-netwatch.service hotspot-netwatch.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now wifi-powersave-off.service hotspot-netwatch.timer
sudo sync; sudo mount -o remount,ro /
```

Remove: `systemctl disable --now ...` + delete the files.
