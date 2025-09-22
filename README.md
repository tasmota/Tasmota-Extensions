# Tasmota Extensions

Official repository for Tasmota extensions as `.tapp` files. Extensions provide an extensible way to load and unload features dynamically on ESP32 variants without rebooting.

## Features

- Online Extension Store integrated into Tasmota WebUI
- Install/uninstall extensions on-demand
- Start/stop extensions to manage memory usage
- Auto-start configuration at boot

## For Developers

To publish new extensions to this repository:

1. Create a folder in `raw/` directory with your extension files
2. Include required files: `manifest.json`, `autoexec.be`, and your Berry scripts
3. Test locally with `python3 gen.py`
4. Submit a pull request

## Documentation

Full documentation available at: https://tasmota.github.io/docs/Tasmota-Extension/

## Build System

Extensions are automatically built from the `raw/` directory into `.tapp` files using GitHub Actions. The build process validates manifests and generates the extension catalog.