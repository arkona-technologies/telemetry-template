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

#### rc.eos seems to fail

If an unknown process replaces the config files after rc.eos runs, you can modify the the telegraf systemd unit with a "drop-in":

1. Create the drop-in directory:
    ```
    sudo mkdir -p /etc/systemd/system/telegraf.service.d
    ```
2. Create the override file:
    ```
    sudo nano /etc/systemd/system/telegraf.service.d/override.conf
    ```
3. Add the following content:
    ```
    [Service]
    ExecStartPre=/bin/bash -c '/bin/cp -f /persist/secure/telegraf /etc/default/telegraf'
    ExecStartPre=/bin/bash -c '/bin/cp -f /persist/local/default.conf /etc/telegraf/telegraf.d/'
    ```
4. Reload systemd and restart telegraf:
    ```
    sudo systemctl daemon-reexec
    sudo systemctl daemon-reload
    sudo systemctl restart telegraf
    ```