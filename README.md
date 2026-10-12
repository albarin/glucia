# Glucía

A desktop display that shows glucose readings from a Dexcom sensor: the current value, its trend arrow, the change since the last reading, a countdown to the next one and the last 8 readings as bars. Inspired by [Gluvi](https://migluvi.com).

It runs on its own: an ESP32-S3 board reads Dexcom Share directly over WiFi, with no Home Assistant or server. Built with [ESPHome](https://esphome.io) and LVGL.

> **Not a medical device.** It is informational only and has no alarms. Keep the Dexcom app's alerts on.

## Hardware

Guition **JC3248W535C** (ESP32-S3, 3.5" 480x320 touchscreen). There is also a simulator that runs in a window on your computer.

## Running it

You need Python 3.13 and, for the simulator, SDL2 (`brew install sdl2` on macOS).

```sh
python3.13 -m venv .venv
.venv/bin/pip install esphome==2026.9.1
cp secrets.example.yaml secrets.yaml   # then fill in the values

.venv/bin/esphome run simulator.yaml          # simulator with made-up data
.venv/bin/esphome run simulator-dexcom.yaml   # simulator with your Dexcom account (from secrets.yaml)
.venv/bin/esphome run guition.yaml            # build and flash the board over USB
```

On the simulator, tap the screen to invert the colors and long-press it to pause the demo.

## Setting up the board

1. Flash it once over USB with `esphome run guition.yaml`.
2. WiFi: connect to the `Glucia` network the board creates (password: your `ap_password`) and choose your WiFi.
3. Dexcom: open `http://glucia.local` and enter the username and password of the **main** Dexcom account (the person wearing the sensor), with Share enabled and at least one follower.

After that, the board installs new releases of this repo by itself (every 6 hours). They are published by pushing a tag (`git tag v1.2 && git push origin v1.2`), and the release binaries are built with this repo's own passwords: if you fork it, set the `AP_PASSWORD` and `OTA_PASSWORD` secrets and point `update: source:` in `hardware/guition.yaml` to your fork.

The on-screen language is set in `guition.yaml` (`common/lang/es.yaml` or `en.yaml`).
