# Home Assistant Add-on: ECOFLOW SHP Energy Usage

Get Smart Home Panel energy data from the ECOFLOW API.

![Supports amd64 Architecture][amd64-shield]

May also support other architectures and platforms since the base image is based on Home Assistant's own Alpine Linux image.

## About

Typically I obtain my Smart Home Panel data from ECOFLOW's MQTT server but their MQTT API does not (currently, Sept '24) include the energy usage data splits for the battery and grid for the `quota` subscribed topic.

This add-on instead uses the public HTTP API to retrieve that energy usage data for a single ECOFLOW Smart Home Panel 1 and populate a sensor with the retrieved data. In addition, since the EPS (Emergency Power Supply) status is also not included in the MQTT API data, that status is also retrieved.

## How to use

Install it then, in the configuration section, add the relevant data as provided on the ECOFLOW Developer Portal.

For the Home Assistant sensors, provide a COMPLETE sensor name as suggested in the default, which you may override as you require.

`sensor.shp_energy_usage` - Energy Sensor Name

`binary_sensor.shp_eps_status` - EPS Status Sensor Name

## Background

Just to be clear, the solution is written in PowerShell (as can be seen on the code in Github). Feel free to fork and modify or rewrite in to your chosen language should you require.

[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
