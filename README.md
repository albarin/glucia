# Glucía

A desktop display that shows glucose readings from a Dexcom sensor: the current value, its trend arrow, the change since the last reading, a countdown to the next one and the last 8 readings as bars. It also has a kids look for children who can't read numbers yet: the whole screen takes the range color, with a friendly face and a level gauge. Inspired by [Gluvi](https://migluvi.com).

It runs on its own: an ESP32-S3 board reads Dexcom Share directly over WiFi, with no Home Assistant or server. Built with [ESPHome](https://esphome.io) and LVGL.

> **Not a medical device.** It is informational only and has no alarms. Keep the Dexcom app's alerts on.

## Hardware

Guition **JC3248W535C** (ESP32-S3, 3.5" 480x320 touchscreen). There is also a simulator that runs in a window on your computer.

## Running it

You need Python 3.13 from Homebrew and, for the simulator, SDL2 (`brew install sdl2`).

```sh
make setup   # creates .venv with ESPHome and secrets.yaml (then fill in its values)
make sim     # simulator with made-up data
```

| Command | What it does |
|---|---|
| `make` | List every command |
| `make setup` | Create `.venv` with ESPHome, and `secrets.yaml` from the template if missing |
| `make sim` | Simulator with made-up data |
| `make sim-dexcom` | Simulator with your Dexcom account (credentials from `secrets.yaml`) |
| `make sim-reset` | Forget what the simulators stored (e.g. old Dexcom credentials) |
| `make build` | Build the board firmware |
| `make flash` | Build and install on the board (over USB or WiFi, it asks) |
| `make logs` | Show the board logs over USB |
| `make check` | Build everything |
| `make release VERSION=v1.2` | Publish a firmware version (only from a clean `main` in sync with GitHub) |
| `make clean` | Delete build files |
| `make shots` | Screenshots of every UI case in `dev/shots/sheet.png` (`LANG_SHOTS=es` for Spanish) |

On the screen itself, two hidden gestures (so a child can't trigger them by accident):

- Hold the **top-left** corner for 5 seconds: switch between the light and dark themes.
- Hold the **top-right** corner for 5 seconds: switch between the classic and kids looks.

On the simulator, a long press anywhere else pauses the demo.

## Setting up the board

1. Flash it once over USB with `make flash`.
2. WiFi: connect to the `Glucia` network the board creates (password: your `ap_password`) and choose your WiFi.
3. Dexcom: open `http://glucia.local` and enter the username and password of the **main** Dexcom account (the person wearing the sensor), with Share enabled and at least one follower.
4. Look: on the same page, choose **Display mode** (`Classic` or `Kids`) and **Theme** (`Light` or `Dark`).

After that, the board installs new releases of this repo by itself (every 6 hours). They are published with `make release VERSION=v1.2` (it pushes a tag), and the release binaries are built with this repo's own passwords: if you fork it, set the `AP_PASSWORD` and `OTA_PASSWORD` secrets and point `update: source:` in `hardware/guition.yaml` to your fork.

The on-screen language is set in `guition.yaml` (`common/lang/es.yaml` or `en.yaml`).

## Credits

The kids UI uses emoji from [Noto Emoji](https://github.com/googlefonts/noto-emoji) by Google, under the Apache License 2.0.
