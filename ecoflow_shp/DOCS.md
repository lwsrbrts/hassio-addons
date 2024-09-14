# How to use this add-on

First, you'll need a Developer Account at [ECOFLOW Developer Portal](https://developer.ecoflow.com/). Once you have that (manual approval by ECOFOW), you'll need a Developer Access Key and Developer Secret Key which you obtain from the ECOFLOW Developer Portal.

This add-on is intentionally limited in scope. I recommend you use the MQTT API since it doesn't require regular polling to get near real-time updates on current circuit power use from the Smart Home Panel.

The _issue_ with the MQTT API is that, as of September 2024, it does not include the hourly per-circuit grid and battery usage split data, EPS state or the charging and discharging limit setting on the Smart Home Panel. This add-on fills those gaps but it only polls for the data from the HTTP API every 5 minutes by default. This is customisable but I would not recommend increasing it since ECOFLOW could just revoke your developer access - besides, this data isn't changing regularly enough to warrant more frequent polling.

The following YAML assumes you use the default sensor names provided by this add-on. The below YAML will create additional `template` sensors, using the data in the sensors created and updated by this add-on to give you usable sensors.

I'm not being lazy by not doing this in the add-on, it's just easier to do it using a template sensor and so I'm not trying to imagine what your data looks like, munjing it etc. All the add-on will do is retrieve the data from the ECOFLOW HTTP API and drop it in to the sensors. Any failures should result in appropriate messages on the Log tab.

## Create GRID usage template sensors

Repeat this for your circuits. the `[0]` denotes Circuit 1. Circuit 2 would be `[1]` etc.

This gives you grid usage for your circuits every 5 minutes (default polling for the add-on).

```yaml
template:
  - sensor:
      - name: SHP Circuit 1 Grid Energy
        unique_id: shp_circuit_1_grid_energy
        icon: mdi:transmission-tower-import
        device_class: energy
        unit_of_measurement: "Wh"
        state_class: total
        state: "{{state_attr('sensor.shp_energy_usage','grid_usage')[0] | sum | round(0)}}"
        last_reset: "{{ today_at() }}"

        # ---REPEAT FOR OTHER 9 CIRCUITS---
```

Once you've set up all the **circuit** template sensors, you could add another one to add them all up and give you a total:

```yaml
template:
  - sensor:
      - name: SHP Circuits Grid Energy
        unique_id: shp_circuits_grid_energy
        icon: mdi:transmission-tower-import
        unit_of_measurement: "Wh"
        device_class: energy
        state_class: total
        state: >-
          {% set grid = 
          states.sensor
          | selectattr('entity_id', 'search', 'shp_circuit_\d+_grid_energy')
          | map(attribute='state')
          | map('int')
          | sum
          %}
          {{grid}}
        last_reset: "{{ today_at() }}"

```

## Create BATTERY usage template sensors

Following exactly the same logic as above but for battery usage.

```yaml
template:
  - sensor:
      - name: SHP Circuit 1 Battery Energy
        unique_id: shp_circuit_1_battery_energy
        icon: mdi:home-battery-outline
        device_class: energy
        unit_of_measurement: "Wh"
        state_class: total
        state: "{{state_attr('sensor.shp_energy_usage','battery_usage')[0] | sum | round(0)}}"
        last_reset: "{{ today_at() }}"

        # ---REPEAT FOR OTHER 9 CIRCUITS---

      - name: SHP Circuits Battery Energy
        unique_id: shp_circuits_battery_energy
        icon: mdi:battery-arrow-down-outline
        unit_of_measurement: "Wh"
        device_class: energy
        state_class: total
        state: >-
          {% set battery = 
          states.sensor
          | selectattr('entity_id', 'search', 'shp_circuit_\d+_battery_energy')
          | map(attribute='state')
          | map('int')
          | sum
          %}
          {{battery}}
        last_reset: "{{ today_at() }}"
```

## EPS & Charging/Discharging Limits

These are their own sensors, use them as you require.