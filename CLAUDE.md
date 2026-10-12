# Glucía: glucose display (DIY Gluvi replica)

The device is called `glucia` (hostname `glucia.local`) and its rescue WiFi, `Glucia`. **Public** GitHub repo: `albarin/glucia`. Never put personal data in the repo (nor in commits, releases or issues): private context lives in `CLAUDE.local.md`, which is not committed.

Desktop display that shows the glucose from a Dexcom sensor in large type: number, trend arrow, change since the previous reading, countdown to the next reading and the last 8 readings as bars. Inspired by https://migluvi.com.

## Who it's for and constraints

- It's for someone who lives far away and **has no Home Assistant** or any server. The device must work on its own, with its WiFi, without depending on anything else.
- Nobody can go fix it in person: all maintenance must be doable remotely.
- It's an **informational** display: it doesn't alert or beep. The Dexcom alarms on that person's phone must stay on. Don't add alarms.

## Decisions made

- **Firmware:** ESPHome (tested with 2026.9.1) with LVGL 9. No Home Assistant: the HA `api:` is not used.
- **Data:** Dexcom Share directly from the board (unofficial API, the same one `pydexcom` uses). Non-US server: `shareous1.dexcom.com`.
- **Hardware:** Guition **JC3248W535C** (ESP32-S3 N16R8, 3.5", 480x320, AXS15231 capacitive touch). 2 bought (one for testing, one to ship); expected arrival October 17–22, 2026.
- **Development:** first on the simulator (`host` + SDL2) on the Mac; then on the board.
- **Python:** Homebrew 3.13, in a `.venv` virtual environment inside the project (`.venv/bin/esphome`). The macOS one (3.9) installs an ESPHome that is too old, and 3.15 fails to build `ruamel.yaml.clib`.
- **Language:** code, comments, docs and commits in English. On-screen texts come from `common/lang/en.yaml` or `es.yaml` (one `lang` package per main file); the board ships in Spanish.

## Getting started

`.venv` and `.esphome/` are not in git and store absolute paths: if the folder is moved or renamed (or on another computer), rebuild them.

```sh
rm -rf .venv .esphome
/opt/homebrew/bin/python3.13 -m venv .venv
.venv/bin/pip install esphome==2026.9.1
cp secrets.example.yaml secrets.yaml      # only if it doesn't exist; fill in the values

.venv/bin/esphome run simulator.yaml      # simulator with demo data (needs SDL2: brew install sdl2)
.venv/bin/esphome compile guition.yaml    # board firmware (slow the first time: downloads ESP-IDF)
```

## Layout

```
README.md                # short public intro: what it is and how to run it
secrets.yaml             # passwords (never commit)
secrets.example.yaml     # secrets.yaml template, no real data
simulator.yaml           # simulator + demo data
simulator-dexcom.yaml    # simulator + real Dexcom (different name: doesn't share the build with the other)
guition.yaml             # real board + real Dexcom
hardware/
  simulator.yaml         # 480x320 SDL window, system clock, http_request
  guition.yaml           # ESP32-S3, PSRAM, QSPI, mipi_spi, touch, brightness, WiFi + rescue AP,
                         # local web page, OTA, automatic updates
common/
  ui.yaml                # globals, fonts, LVGL screen and the `render` script
  demo.yaml              # made-up readings every 15 s
  dexcom.yaml            # Dexcom Share login + read every 60 s
  lang/en.yaml, es.yaml  # on-screen texts (substitutions t_*)
.github/workflows/
  firmware.yml           # on a v* tag: builds guition.yaml and publishes it
```

The main files only combine `packages`: hardware + ui + lang + data.

### Contract between UI and data

`ui.yaml` doesn't know where the data comes from. A data source fills these globals and calls `script.execute: render`:

- `history` (`std::vector<int>`, 8 items, newest at `[7]`, 0 = no data)
- `last_ts` (time of the reading in Unix seconds, the one Dexcom reports, not when it arrived)
- `delta`, `delta_ok`, `trend` (Dexcom numbering: 1 rising fast, 4 steady, 7 falling fast, 8 not computable, 9 no trend)
- `status_text` (text at the top left), `connected` (WiFi icon)

Each source must also define the global `period` (seconds between readings: 300 for Dexcom, 15 for the demo) and the script `long_press`.

Stale data rule (in `render`): if the last reading is older than `3 * period` seconds, grey number, no arrow, no change, no countdown and age in red. Never show an old number looking current.

## Credentials and updates

The board firmware is published in this repo's public Releases, so it carries nothing private:

- **WiFi:** chosen from the `Glucia` rescue network (captive portal) or over USB (`improv_serial`, from web.esphome.io). Stored on the device.
- **Dexcom:** set on the local web page (`http://glucia.local`, `web_server` without a password, only reachable from the home network). `text` entities with `restore_value`. Changing them clears the session and the wait (`dexcom_reset`). Without credentials, the screen says "Set up Dexcom at glucia.local".
- Entity names ("Dexcom username", "Brightness"…) are fixed in English and must not change: the stored value is keyed by the name, so renaming one loses what the device had saved.
- Only `ap_password` and `ota_password` go in the binary: they can be extracted from the public binary, so don't reuse important passwords.
- `simulator-dexcom.yaml` does take the Dexcom credentials from `secrets.yaml` (via `substitutions`).

Updates: `git tag v1.2 && git push origin v1.2` triggers the Action, which builds with `-s version v1.2` and creates the `v1.2` Release with `manifest.json`, `glucia.ota.bin` and `glucia.factory.bin`. The board checks `releases/latest/download/manifest.json` every 6 h (`update: platform: http_request`) and installs it if the version differs. Local builds have version `dev` and don't update themselves.

Safety net: `safe_mode` + ESP-IDF rollback (on by default). If the new firmware reboots before running for 1 minute, the bootloader goes back to the previous one. It doesn't protect against firmware that boots but misbehaves (e.g. no WiFi): always test on the home board before tagging. Rollback needs the bootloader to have been flashed over USB with this configuration (the first install).

## Dexcom Share API

1. `POST General/AuthenticatePublisherAccount` with `accountName`, `password`, `applicationId` → account ID (UUID in quotes).
2. `POST General/LoginPublisherAccountById` with `accountId`, `password`, `applicationId` → session ID. An all-zeros UUID is a failure.
3. `POST Publisher/ReadPublisherLatestGlucoseValues?sessionId=…&minutes=60&maxCount=8` with body `{}` → list, newest first. Each reading: `{"WT": "Date(ms)", "Value": 142, "Trend": "FortyFiveUp"}` (`Trend` can be text or a number).

- `applicationId`: `d89443d2-327c-4a6f-89e5-496bbb0317db`.
- `SessionIdNotFound` or `SessionNotValid` errors → clear the session and sign in again.
- Wrong credentials → don't retry for 30 min (`dx_wait_until`), so the account doesn't get locked (`SSO_AuthenticateMaxAttemptsExceeded`). Other login failures → 2 min.
- No login attempt without a valid time (on the board the time arrives via SNTP after WiFi): without the time the wait can't be honored.
- Credentials: those of the **main account** (the person wearing the sensor), with Share enabled and at least one accepted follower.

## Status

**Tested (on Linux, in the cloud):**
- `simulator.yaml` builds and works: demo, inverted theme with a tap, pause and stale data with a long press.
- `dexcom.yaml` against a test server that mimics Dexcom: login, read, expired session and re-login, wrong password with a single attempt, server down.

**Tested on Alba's Mac:**
- ESPHome 2026.9.1 in `.venv` (Python 3.13). Use `.venv/bin/esphome`.
- `simulator.yaml` looks right: demo, countdown, inverted theme.
- `simulator.yaml`, `simulator-dexcom.yaml` and `guition.yaml` build; `guition.yaml` is 1.3 MB (16% of flash, 34% of RAM).
- The `firmware.yml` Action: `v0.1` built and published the Release with the manifest and both binaries.

**Builds but untested:**
- Credentials outside the firmware (captive portal, `improv_serial`, local web page) and automatic update with rollback.

**Untested:**
- Against the real Dexcom (no credentials yet).
- `guition.yaml` on the real board. Watch out for: orientation (`lvgl: rotation: 90`, maybe 270), touch orientation, brightness pin (GPIO1).

## Next steps

1. Liveness ping: periodic `http_request.get` to healthchecks.io.
2. Brightness control from the screen (the `backlight` `light` already exists in `hardware/guition.yaml`), mmol/L option.
3. Test with the real Dexcom credentials once available.
4. A few weeks running at home, provoking failures, before shipping it.

## Gotchas found

- `id(widget)` in a lambda is not an `lv_obj_t *`: cast it, `(lv_obj_t *) id(lbl_number)`, to use LVGL functions.
- Don't name a lambda local variable like a widget (a local `fondo` clashed with the widget id). Also avoid ids that clash with C names (`clock`, `time`): hence `sys_time`.
- With `mipi_spi` and LVGL, rotation goes in `lvgl: rotation:`, not in `display`. The AXS15231 can't rotate in hardware.
- `mipi_spi` needs a declared `spi` bus of type `quad` (CLK GPIO47, data 21/48/40/39).
- On the simulator, `http_request` on macOS uses OpenSSL from `/opt/homebrew/opt/openssl` (Apple Silicon); on Linux it needs `ca_certificate_path`.
- `render` runs every second: only change text, colors, sizes and visibility when they differ (`set_text`, `set_ink`, `set_fill`, `set_hidden`). LVGL redraws on every `set_style` even if the value is the same, and on the board rotation is done in software.
- `lv_obj_get_style_*` functions take an `lv_part_t`: pass `LV_PART_MAIN`, not `0` (with `0` it doesn't compile in C++).
- Fonts downloaded from GitHub use a pinned version (`raw/v7.4.47/`, not `raw/master/`), so the automated build doesn't change on its own.
- On-screen texts with a number (`t_minutes_ago`, `t_dexcom_error`) are `printf` formats with a single `%d`.

## Conventions

- Code, comments, docs and commits in English. On-screen texts only in `common/lang/*.yaml`, in every language.
- On-screen texts short and understandable for a non-technical person (the status line fits about 40 characters).
