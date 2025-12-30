# Monitoring Arista switches

>This is tested with telegraf version 1.34

Prerequisites in InfluxDB:

Create bucket "arista" and token:
- [Create bucket](https://docs.influxdata.com/influxdb/v2/admin/buckets/create-bucket/#create-a-bucket-from-the-load-data-menu)
- [Create token](https://docs.influxdata.com/influxdb/v2/admin/tokens/create-token/#create-a-token-in-the-influxdb-ui)

## Setup Telegraf on Arista

### FYI

>The systemd controlled Telegraf uses the config files
>  - `/etc/telegraf/telegraf.conf`
>  - `/etc/telegraf/telegraf.d/*.conf`
>
>and variables or secrets like influx token should be stored in
>  - `/etc/default/telegraf`
>
>But as Arista switches often use overlay fs, changes made in those files may not be persistent.
>
>The following steps will setup telegraf persistently, whether the root directory is mounted on an overlay fs or not.

### Setup

#### Create eapi user

```
 Arista>enable
 Arista#configure
 Arista(config)#username <ARISTA_USER> secret <ARISTA_PASS> (same as in `/persist/secure/telegraf`)
```

#### Enable eapi with https:

```
Arista> enable
Arista# configure terminal
Arista(config)# management api http-commands
Arista(config-mgmt-api-http-cmds)# no shutdown
Arista(config-mgmt-api-http-cmds)# protocol https
Arista(config-mgmt-api-http-cmds)# no protocol http
Arista(config)#write memory
```

#### Enable gnmi with https:

```
Arista> enable
Arista# configure terminal
Arista(config)# management api gnmi
Arista(config-mgmt-api-http-cmds)# transport grpc default
Arista(config-mgmt-api-http-cmds)# port 50051
Arista(config-mgmt-api-http-cmds)# provider eos-native
Arista(config)#write memory
```

#### Setup telegraf

1. Install version of telegraf from here (i386.rpm): 
    -   https://github.com/influxdata/telegraf/releases
1. Copy into `/mnt/flash` and execute `rpm -i <telegraf-<version>-i386.rpm> -U`
    - If something gets stuck, check [this site](https://arista.my.site.com/AristaCommunity/s/article/graphing-arista-eos-with-grafanatelegraf-and-influxdb#Comm_Kna_ka08C0000008SJFQA2_55)
1. Create a config file `/persist/local/default.conf`
    ```conf
    [[outputs.influxdb_v2]]
      urls = ["http://<influxdb-location>:8086"]
      token = "${INFLUX_TOKEN}"
      organization = "myorg"
      bucket = "arista"
      ## Timeout for HTTP messages.
      # timeout = "5s"

    [[inputs.exec]]
      commands = ["/usr/local/bin/arista_ifstats"]
      timeout = "5s"
      data_format = "influx"
      interval = "30s"

     [[inputs.gnmi]]
       addresses = ["127.0.0.1:50051"]
       username = "admin"
       password = "atadmin"
       encoding = "proto"

       [[inputs.gnmi.subscription]]
         name = "interface_counters"
#         origin = "eos-interfaces"
         path = "/interfaces/interface/state/counters"
         subscription_mode = "sample"
         sample_interval = "10s"

       [[inputs.gnmi.subscription]]
         name = "lldp_neighbors"
#         origin = "eos-lldp"
         path = "/lldp/interfaces/interface/neighbors/neighbor/state/system-name"
         subscription_mode = "on_change"
         heartbeat_interval = "60s" # if supported, report every 10 min even if unchanged
  
       [[inputs.gnmi.subscription]]
         name = "lldp_neighbors_sample"
#         origin = "eos-lldp"
         path = "/lldp/interfaces/interface/neighbors/neighbor/state/system-name"
         subscription_mode = "sample"
         sample_interval = "10s"
    ```
      - this config will be loaded in addition to the telegraf.conf file which should include a lot of arista-specific metrics already
1. Create environment file (used by systemd) in `/persist/secure/telegraf`
    ```bash
    NET_NS=default
    INFLUX_TOKEN=token-with-write-permissions-for-your-bucket
    ARISTA_USER=<your-user>
    ARISTA_PASS=<your-password>
    ARISTA_HOST=<ip-address-of-Management1-interface>
    EAPI_PROTOCOL=<https|http> # https preferred as defined in "Enable eapi with https"
    ```
    > all env variables in /etc/default/telegraf can be used in config file like: ${INFLUX_TOKEN}
1. Create `/mnt/flash/rc.eos` (with `+x`), containing:
    ```bash
    #!/bin/bash
    echo "Starting rc.eos script..." >> /mnt/flash/rc.eos.log
    /bin/cp /persist/local/default.conf /etc/telegraf/telegraf.d/default.conf
    /bin/cp /persist/secure/telegraf /etc/default/telegraf
    echo "Finished rc.eos" >> /mnt/flash/rc.eos.log
    ```
1. Delete `>> /var/log/agents/Telegraf 2>&1` from the "ExecStart" line in the service file to prevent telegraf logging to the disk
1. `[sudo] systemctl daemon-reload`
1. Enable telegraf with `[sudo] systemctl enable telegraf`
1. Reboot switch to see if made configs are persistent. If not, check [these steps](./arista_telemetry_troubleshoot.md).

## Monitor Arista interface traffic rates with script (optional, only needed if gnmi is not working properly)

On the switch:

1. [Setup Telegraf on Arista](#setup-telegraf-on-arista)
1. Check with:
    ```
    Arista# show management api http-commands 
    Enabled: Yes 
    HTTPS server: running, set to use port 443 
    HTTP server: shutdown, set to use port 80 
    Local HTTP server: shutdown, no authentication, set to use port 8080 
    Unix Socket server: shutdown, no authentication 
    VRF: default 
    Hits: 71 
    Last hit: 1433 seconds ago 
    Bytes in: 7669 
    Bytes out: 13554 
    Requests: 5 
    Commands: 8 
    Duration: 0.384 seconds 
    User        Requests       Bytes in       Bytes out       Last hit 
    ----------- -------------- -------------- --------------- ---------------- 
    admin       5              7669           13554           1433 seconds ago 
    ```
    Depending if server is configured/running with http or https, set in /etc/default/telegraf `EAPI_PROTOCOL=https` (best to use https)
1. Start bash `Arista#bash` and copy/create extras/arista_ifstats to/at `/usr/local/bin/arista_ifstats` as an executable script
    - Check if the script works with `sudo arista_ifstats`, it should print out a lot of data in the influx format
1. Check if `/etc/telegraf/telegraf.conf` has inputs.exec configured:
    ```conf
    [[inputs.exec]]
      commands = ["/usr/local/bin/arista_ifstats"]
      timeout = "5s"
      data_format = "influx"
      interval = "30s"
    ```
1. Restart telegraf `[sudo] systemctl restart telegraf`
