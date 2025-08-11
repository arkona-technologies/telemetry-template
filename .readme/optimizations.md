# Hints and recommendations

## Optimize your environment for the database

Optimizing your environment for the time-series database can have a huge impact for bigger installations and prevent possible problems like full write queues where data batches could get dropped.
To get the best possible disk write performance for the database you can do one of the following:

- [install influxdb bare-metal](https://docs.influxdata.com/influxdb/v2/install/)
- For docker/podman:  [optimizing docker storage](https://overcast.blog/optimizing-docker-storage-volume-management-and-disk-i-o-0c4e6af35886) 
  - podman is usually faster and does not have as much overhead than docker, but for best results search for optimizations for your individual setup
- For installation in VMs: use VT-d/AMD-d to get direct disk access

For more detailed information, you can read about database performance in different environments in this [publication about hypervisor overhead](https://pure.qub.ac.uk/en/publications/performance-overhead-comparison-between-hypervisor-and-container-) from the Queen's University of Belfast.