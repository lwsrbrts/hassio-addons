# How to use this add-on

The following YAML assumes you use the default sensor names.

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

