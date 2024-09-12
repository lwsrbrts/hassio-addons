# Home Assistant Add-on: PowerShell for Home Assistant

Run PowerShell scripts in Home Assistant.

![Supports amd64 Architecture][amd64-shield]

## About

This add-on allows you to run arbitrary PowerShell (7+) scripts that YOU create.

The scripts can be placed in either the `\\{HASS}\share\pwsh` folder, or a NAS share off `\\{HASS}\share\` by making use of the Add Network Storage feature of Home Assistant. Add script files to the folder and declare the `Scripts` in the `Configuration` section.

## How do I use it?

There's two ways.
 - **Declared** - script file names you set in the configuration.
 - **On-demand** - script file names you send to the add-on.

For **Declared** scripts, either:
1. Copy your scripts to `\\{HASS}\share\pwsh` (create it if you need to), then add the file names of the scripts to the `Scripts` section in `Configuration` as shown below.
2. Copy your scripts to `\\{HASS}\addon_configs\{random-chars}_pwsh` folder, then add the file name(s) AND path, ensuring to begin with `/config/`, of the script to the `Scripts` section in `Configuration`.
3. Use Home Assistant's Add Network storage feature to mount a network location as a `Share` type. Ensure this is available to Home Assistant by navigating to eg. `\\{HASS}\share\mynasfolder`. Place your scripts there and declare the path appropriately as part of the `Scripts` section.

```yaml
- filename: My-AwesomeScript.ps1 # in share/pwsh/
- filename: My-OtherAwesomeScript.ps1
  path: /share/mynasfolder/scripts/
- filename: My-ThirdAwesomeScript.ps1 # in addon_configs/{random-chars}_pwsh/
  path: /config/
- filename: TEST.ps1 # in share/pwsh/
```

Start the add-on and review the `Log` section to see any output.

**TIP**: To see how to interact with Home Assistant sensors using PowerShell scripts run by this add-on, see the [HOWTO](HOWTO.md) file.

For **On-Demand** scripts:
1. Ensure that the `On-Demand` feature toggle is enabled in the `Configuration` section of the add-on.
2. Follow the same process as for **Declared** scripts to put your scripts in to a directory off `/share/` or `/addon_configs\{random-chars}_pwsh`.
3. Use the Home Assistant Action `hassio.addon_stdin` to send properly formatted data containing the `filename`s and their `path`s (if not in `/share/pwsh/`) to the add-on.

```yaml
action: hassio.addon_stdin
data:
  addon: {{addon_slug_name}}
  input:
    scripts:
      - filename: On-Demand.ps1
      - filename: Test-Script.ps1
        path: /share/pwsh/
      - filename: My-ThirdAwesomeScript.ps1 # in addon_configs/{random-chars}_pwsh/
        path: /config/
```

Yes, this means you can schedule or run PowerShell scripts as Actions in Automations and Scripts.

_**NB**: A side effect of running scripts on-demand means that the data you send to the add-on with `hassio.addon_stdin` appears as formatted JSON in the `Log` section of the add-on. This is harmless and appears due to the way PowerShell listens for content._

[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
