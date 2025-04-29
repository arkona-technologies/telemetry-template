# Monitor Arista switch

Prerequisit:

Create bucket "arista" and token:
- [Create bucket](https://docs.influxdata.com/influxdb/v2/admin/buckets/create-bucket/#create-a-bucket-from-the-load-data-menu)
- [Create token](https://docs.influxdata.com/influxdb/v2/admin/tokens/create-token/#create-a-token-in-the-influxdb-ui)

## Setup Telegraf on Arista

1. Install version  of telegraf from here (i386.rpm): https://github.com/influxdata/telegraf/releases
1. Copy into /mnt/flash and execute rpm -i <telegraf-<version>-i386.rpm> -U
    - If something gets stuck, check: https://arista.my.site.com/AristaCommunity/s/article/graphing-arista-eos-with-grafanatelegraf-and-influxdb#Comm_Kna_ka08C0000008SJFQA2_55
    - Maybe check for installation script "installtelegraf.sh" (but that should not be necessary)
1. Edit config file, maybe preconfigured in influxdb gui.
    - Example config:
    ```conf
    # Configuration for telegraf agent
    [agent]
      ## Default data collection interval for all inputs
      interval = "30s"
      round_interval = true
      metric_batch_size = 1000
      metric_buffer_limit = 10000
      collection_jitter = "0s"
      flush_interval = "10s"
      flush_jitter = "0s"
      precision = ""

      ## Override default hostname, if empty use os.Hostname()
      hostname = ""
      ## If set to true, do no set the "host" tag in the telegraf agent.
      omit_hostname = false

    [[outputs.influxdb_v2]]
      urls = ["http://<influxdb-location>:8086"]
      token = "${INFLUX_TOKEN}"
      organization = "myorg"
      bucket = "arista"
      ## Timeout for HTTP messages.
      # timeout = "5s"

    [[inputs.cpu]]
      percpu = false
      totalcpu = true
      collect_cpu_time = false
      ## If true, compute and report the sum of all non-idle CPU states
      report_active = false

    [[inputs.net]]

    [[inputs.system]]

    [[inputs.exec]]
      commands = ["/usr/local/bin/arista_ifstats"]
      timeout = "5s"
      data_format = "influx"
      interval = "30s"
    ```
1. Edit environment file used by systemd in `/etc/default/telegraf`:
    ```bash
    NET_NS=default
    INFLUX_TOKEN=token-with-write-permissions-for-your-bucket
    ```
    - optional values if you want to execute eapi scripts with telegraf:
    ```bash
    ARISTA_USER=<your-user>
    ARISTA_PASS=<your-password>
    ARISTA_HOST=<ip-address-of-Management1-interface>
    EAPI_PROTOCOL=<https|http>
    ```
    > all env variables in /etc/default/telegraf can be used in config file like: ${INFLUX_TOKEN}
1. Start telegraf with `[sudo] systemctl start telegraf`

## Monitor Arista interface traffic rates with script

On the switch:

1. [Setup Telegraf on Arista](#setup-telegraf-on-arista)
1. Enable eapi with https:
    ```
    Arista> enable
    Arista# configure terminal
    Arista(config)# management api http-commands
    Arista(config-mgmt-api-http-cmds)# no shutdown
    Arista(config-mgmt-api-http-cmds)# protocol https
    Arista(config-mgmt-api-http-cmds)# no protocol http
    ```
1. Check with :
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
1. Start bash `Arista#bash` and copy/create extras/arista_ifstats.sh to/at `/usr/local/bin/arista_ifstats` as an executable script (note the missing .sh ending)
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