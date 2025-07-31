# Arista telemetry troubleshooting

More information on [official github](https://github.com/aristanetworks/telegraf-eos)

## Telemetry not working

Check whether you're in an overlay fs, this will prevent the changes made in `/etc/default/telegraf` and other files to be persistent.

### Checking if you're in a overlay fs

Three common tools to check if root is mounted on an overlay fs:

```bash
$ mount | grep overlay
$ findmnt -t overlay
$ grep overlay /proc/self/mountinfo
```

If the result contains something like the following, then your root is mounted on an overlay fs

```bash
overlay on / type overlay (rw,relatime,lowerdir=...,upperdir=...,workdir=...)
```

### FIX: Make changes persistent

Use `/persist` to store persistent files.

Then copy or symlink them into place at boot using rc.eos or startup scripts.

Example (*If you have additional files in /etc/telegraf/telegraf.d, you have to also add those*):

1. Save the config:
  ```bash
  cp /etc/telegraf/telegraf.conf /persist/local/telegraf.conf
  cp /etc/default/telegraf /persist/secure/telegraf
  ```
2. Create `/mnt/flash/rc.eos` (with `+x`), e.g. containing (and everything else you need):
  ```bash
    #!/bin/bash
    echo "Starting rc.eos script..." >> /mnt/flash/rc.eos.log
    /bin/ls -l --full-time /persist/secure/ >> /mnt/flash/rc.eos.log 2>&1
    /bin/ls -l --full-time /persist/local/ >> /mnt/flash/rc.eos.log 2>&1
    /bin/cp /persist/local/telegraf.conf /etc/telegraf/telegraf.d/default.conf >> /mnt/flash/rc.eos.log 2>&1
    /bin/cp /persist/secure/telegraf /etc/default/telegraf >> /mnt/flash/rc.eos.log 2>&1
    echo "Finished rc.eos" >> /mnt/flash/rc.eos.log
  ```
3. Reboot and test if changes that you made are still there, also check `/mn/flash/rc.eos.log`.

#### files are still overwritten after rc.eos is executed

a) Add an event-handler, executing rc.eos and restarting telegraf after some delay on-boot:

```
localhost(config)#event-handler telegraf
localhost(config-handler-telegraf)#trigger on-boot
localhost(config-handler-telegraf)#action bash sudo sh /mnt/flash/rc.eos; sudo systemctl restart telegraf
localhost(config-handler-telegraf)#delay 5
localhost(config-handler-telegraf)#write memory
localhost(config-handler-telegraf)#exit
```

b) Add a cronjob via

```
Arista(config)#schedule telegraf interval 5 timeout 1 max-log-files 0 command bash /mnt/flash/heal-telegraf.sh
```

and add the file (`+x` permissions) `/persist/local/heal-telegraf.sh`:

```bash
#!/bin/bash

LOG="/mnt/flash/telegraf-restore.log"
ENV_SRC="/persist/secure/telegraf"
ENV_DEST="/etc/default/telegraf"
CONF_SRC="/persist/local/default.conf"
CONF_DEST="/etc/telegraf/telegraf.d/default.conf"

restore_needed=false

# Check if telegraf is running
if ! systemctl is-active --quiet telegraf; then
  echo "$(date) Telegraf not running." >> "$LOG"
  restore_needed=true
fi

# Check if files differ
cmp -s "$ENV_SRC" "$ENV_DEST" || restore_needed=true
cmp -s "$CONF_SRC" "$CONF_DEST" || restore_needed=true


# Restore if needed
if [ "$restore_needed" = true ]; then
  echo "$(date) Restoring telegraf files and restarting service." >> "$LOG"

  cp "$ENV_SRC" "$ENV_DEST"
  cp "$CONF_SRC" "$CONF_DEST"
  systemctl restart telegraf

  echo "$(date) Restore complete." >> "$LOG"
else
  echo "$(date) No changes detected, telegraf OK." >> "$LOG"
fi
```

