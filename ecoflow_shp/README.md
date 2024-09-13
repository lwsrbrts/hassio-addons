# Home Assistant Add-on: ECOFLOW SHP Energy Usage

Get Smart Home Panel energy data from the ECOFLOW API.

Don't forget to review the Documentation tab for usage information!

![Supports amd64 Architecture][amd64-shield]

May also support other architectures and platforms since the base image is based on Home Assistant's own Alpine Linux image.

## About

Typically I obtain my Smart Home Panel data [from ECOFLOW's MQTT server and port that to Home Assistant sensors](https://gist.github.com/lwsrbrts/50d6c8168fab3360e8619ec31aad422a) but their MQTT API does not (currently, Sept '24) include the energy usage data splits for the battery and grid for the `quota` subscribed topic.

This add-on instead uses the public HTTP API to retrieve that energy usage data for a single ECOFLOW Smart Home Panel 1 and populate a sensor with the retrieved data.

In addition, since the EPS (Emergency Power Supply) status, Charging & Discharging Limits are also not included in the MQTT API data, these are also retrieved.

So, using [ECOFLOW's own terminology](https://developer-eu.ecoflow.com/us/document/shp), these are the `GetCmdRequest` values being requested from their HTTP API by this add-on:
 * backupLoadWatt.watth
 * mainsLoadWatt.watth
 * epsModeInfo.eps
 * backupChaDiscCfg.forceChargeHigh
 * backupChaDiscCfg.discLower

## How to use

Install it, then, in the configuration section, add the relevant data as provided on the ECOFLOW Developer Portal.

You may customise the names of the Home Assistant sensors that this add-on creates/updates. If you are customising, provide a COMPLETE sensor name using the platform suggested in the default.

`sensor.shp_energy_usage` - Energy Sensor Name is a `sensor` type.

`binary_sensor.shp_eps_status` - EPS Status Sensor Name is a `binary_sensor` type.

`number.shp_charging_limit` - Smart Home Panel Battery Charging Limit is a `number` type.

`number.shp_discharging_limit` - Smart Home Panel Battery Discharging Limit is a `number` type.

## Background

Just to be clear, the solution is written in PowerShell (as can be seen on the code in Github). Feel free to fork and modify or rewrite in to your chosen language should you require.

[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
