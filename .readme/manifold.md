# Monitoring manifold

>This is tested with telegraf version 1.34 

Prerequisites in InfluxDB:

Create bucket "manifold" and token:
- [Create bucket](https://docs.influxdata.com/influxdb/v2/admin/buckets/create-bucket/#create-a-bucket-from-the-load-data-menu)
- [Create token](https://docs.influxdata.com/influxdb/v2/admin/tokens/create-token/#create-a-token-in-the-influxdb-ui)

## Setup Telegraf on manifold server

### Setup for manifold database

On the manifold server:

1. Get telegraf from [here](https://dl.influxdata.com/telegraf/releases/), like:
`wget https://dl.influxdata.com/telegraf/releases/telegraf_1.34.1-1_amd64.deb`
2. Install package: `sudo dpkg -i telegraf_1.34.1-1_amd64.deb`
3. Create config file `/etc/telegraf/telegraf.d/outputs.conf`:
```conf
[[outputs.influxdb_v2]]
urls = ["http://<ip-address-of-influxdb>:8086"]
token = "<write-token>"
organization = "myorg"
bucket = "manifold"
```
4. Create config file `/etc/telegraf/telegraf.d/manifold.conf` (very simple example):
```conf
[[inputs.sql]]
  driver = "pgx"
  dsn = "postgres://user:password@127.0.0.1:5432/manifold_cloud_db?sslmode=disable"

  [[inputs.sql.query]]
    query = '''
      SELECT
        server,
        accelerator,
        processor_id,
        load
      FROM ui.afu_processors
    '''
    measurement = "afu_processors_load"

  [[inputs.sql.query]]
    query = '''
      SELECT
        link_is_up,
        ingress_load,
        egress_load,
        egress_bandwidth,
        ingress_bandwidth,
        local_lldp_port_id,
        afu_ethernet_port_id
      FROM ui.afu_ethernet_ports
    '''
    measurement = "port_statistics"

[[processors.converter]]
  namepass = ["afu_processors_load"]
  [processors.converter.fields]
    tag = ["server", "accelerator", "processor_id"]

[[processors.converter]]
  namepass = ["port_statistics"]
  [processors.converter.fields]
    tag = ["local_lldp_port_id", "afu_ethernet_port_id"]
```
5. Add as many queries as needed, if you want to specify fields as tags explicitly, define "processors.converter" as seen above for every measurement.
6. `sudo systemctl restart telegraf`
7. `sudo systemctl enable telegraf`
8. `sudo loginctl enable-linger <current-user>`

You can set the polling of telegraf to another interval, default is 10s, in `/etc/telegraf/telegraf.conf -> "agent"`

This setting will change polling for all metrics, either postgresql or any other inputs defined for telegraf.

### Setup of additional inputs

It's recommended to also monitor cpu,ram,disk of the server with standard inputs, like:

```conf
[[inputs.cpu]]
  ## Whether to report per-cpu stats or not
  percpu = true
  ## Whether to report total system cpu stats or not
  totalcpu = true
  ## If true, collect raw CPU time metrics
  collect_cpu_time = false
  ## If true, compute and report the sum of all non-idle CPU states
  ## NOTE: The resulting 'time_active' field INCLUDES 'iowait'!
  report_active = false
  ## If true and the info is available then add core_id and physical_id tags
  core_tags = false
  

# Read metrics about disk usage by mount point
[[inputs.disk]]
  ignore_fs = ["tmpfs", "devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]
[[inputs.diskio]]
[[inputs.mem]]
[[inputs.processes]]
[[inputs.swap]]
[[inputs.system]]
```

and/or [monitor docker](https://github.com/influxdata/telegraf/blob/master/plugins/inputs/docker/README.md)
