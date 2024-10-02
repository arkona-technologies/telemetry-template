# Arkona Technologies Telemetry Template

![Telemetry Logo](.readme/blade-runner.png)

## Overview

`telemetry-template` is a containerized software package for monitoring multiple Arkona Technologies BLADE//runner processors. This repository provides a Docker Compose setup to conveniently deploy the telemetry service, InfluxDB, and Grafana. The Docker Compose file provisions both the database and Grafana installation, eliminating the need for additional configuration.

**If you want a recent influxDB and syslog collection, go to branch "v2"**

## Features

- **Convenient Setup:** Use Docker Compose to easily set up the telemetry service, InfluxDB, and Grafana.
- **Integrated Database:** The setup provisions InfluxDB, a powerful and efficient time-series database, for storing telemetry data.
- **Visualization with Grafana:** Grafana is included in the setup, providing a user-friendly interface for visualizing and analyzing telemetry data.
- **Scalable Monitoring:** Monitor multiple BLADE//runner processors seamlessly with the scalability of containerized deployments.

## Prerequisites

Before deploying the Docker Compose setup, ensure the following prerequisites are met:

- Docker installed on the host machine.
- Docker Compose installed on the host machine.

## Installation

1. Clone this repository to your local machine:

   ```bash
   git clone https://github.com/arkona-technologies/telemetry-template.git
   ```

2. Navigate to the project directory:

   ```bash
   cd telemetry-template
   ```

3. Create a `.env` file in the project root with your desired configurations. Use the provided `.env` file as a template:

4. **Configure via `.env` file:** Customize the `.env` file as needed, specifying parameters such as processor IPs, ports, and authentication details. Example configuration in `.env`:

   ```env
   BLADES=ws://172.16.210.107,ws://172.16.120.170
   DB_NAME=test
   DB_PASSWORD=test
   DB_USER=test
   DB_PORT=8086

   GRAFANA_USER=test
   GRAFANA_PW=test
   ```

5. Run the Docker Compose setup:

   ```bash
   docker-compose --env-file .env up -d
   ```

   This command will start the telemetry service, InfluxDB, and Grafana in detached mode.

6. Access Grafana at [http://localhost:3000](http://localhost:3000) in your browser. Log in with the supplied credentials.

7. Create dashboards in Grafana to visualize telemetry data from BLADE//runner processors. Take a look at the supplied Dashboards as a guide.


## Links

- [VTelemetry2](https://hub.docker.com/r/arkonatechnologies/vtelemetry2)
- [InfluxDB](https://hub.docker.com/_/influxdb)
- [Grafana-OSS](https://hub.docker.com/r/grafana/grafana-oss)
- [Docker](https://www.docker.com/)

## Further Reading
- [Arista EOS Telemetry ](https://arista.my.site.com/AristaCommunity/s/article/streaming-eos-telemetry-states-to-influxdb)
- [Cisco Telemetry](https://ultraconfig.com.au/blog/cisco-telemetry-tutorial-with-telegraf-influxdb-and-grafana/)
- [General Linux Server Telemetry](https://community.hetzner.com/tutorials/server-monitoring-using-grafana-and-influxdb)

## License

This project is licensed under the [MIT License](LICENSE).

## Contributing

Feel free to contribute by submitting issues or pull requests. Your feedback is valuable to us!

