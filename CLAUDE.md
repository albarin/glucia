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
make setup        # .venv with ESPHome 2026.9.1 + secrets.yaml from the template (fill in the values)
make sim          # simulator with demo data (needs SDL2: brew install sdl2)
make build        # board firmware (slow the first time: downloads ESP-IDF)
make              # every command: sim-dexcom, sim-reset, flash, logs, check, release, clean
```

## Layout

```
Makefile                 # shortcuts: make sim, sim-dexcom, build, flash, release VERSION=v1.2…
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
  ui.yaml                # shared globals and fonts, "Display mode" select, `render` -> chosen look
  ui-classic.yaml        # classic look: big number, arrow, countdown, last 8 readings
  ui-kids.yaml           # kids look: zone color, emoji face, level gauge, arrow
  demo.yaml              # made-up readings every 15 s
  dexcom.yaml            # Dexcom Share login + read every 60 s
  lang/en.yaml, es.yaml  # on-screen texts (substitutions t_*)
dev/
  screenshots.yaml       # headless simulator that renders fixed cases (scenarios.yaml)
  shots.sh               # dev/shots.sh [en|es] -> dev/shots/sheet.png with every case
.github/workflows/
  firmware.yml           # on a v* tag: builds guition.yaml and publishes it
```

The main files only combine `packages`: hardware + ui + lang + data.

### Two looks in one firmware

`ui.yaml` includes both looks (nested `packages`). Each one has its own LVGL page (`classic_page`, `kids_page`) and its own script (`render_classic`, `render_kids`); `render` shows the page of the chosen look and draws only that one. The look is the `select` "Display mode" (`Classic`/`Kids`, `restore_value`) on the local web page; the `display_mode` substitution in each main file is only the choice on first start (board: `Classic`, simulators: `Kids`). The simulator has no web page (`web_server` doesn't run on `host`): change the substitution and `make sim-reset`.
- Widget ids are global: kids widgets that mirror classic ones take a `k_` prefix (`k_number`, `k_arrow`…), and its big arrow font is `f_arrow_big`.
- Shared fonts (`f_text`, `f_medium`, `f_icons`) live in `ui.yaml`; each look only declares its own.

### Kids look (`ui-kids.yaml`)

For a young child who can't read numbers: the whole screen takes the zone color (red low, green in range, amber high), an emoji shows it and a gauge on the left shows the level. Design rules:
- Faces are never sad or "bad": 😊 in range, 😮 when low, 😐 when high, 😴 (grey screen) without fresh data. Diabetes care advice is to avoid judging numbers as good or bad.
- Emoji are Noto Emoji PNGs (Apache 2.0, credited in the README), downloaded at build time from a pinned tag (`v2.047`) and stored as RGB565 + alpha images. LVGL fonts are single-color, so color emoji can only be images.
- The emoji sits on a white disc by day so its yellow doesn't blend with the amber zone. At night the disc is black with a ring in the zone color.
- The number stays, small, for grown-ups. Stale data: grey, sleeping face, faded number and gauge, age in a red pill.
- Dark ink on the colors (white on green/amber is unreadable). A tap toggles night mode: black background, the zone color moves to the ring.

To check a UI change, run `make shots` (and `make shots LANG_SHOTS=es`) and look at `dev/shots/sheet.png` (every case in both looks): the SDL display has `headless` and `snapshot.take` built in.

### Contract between UI and data

The UI doesn't know where the data comes from. A data source fills these globals and calls `script.execute: render`:

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

Updates: `make release VERSION=v1.2` (only from a clean `main` in sync with GitHub) pushes the tag that triggers the Action, which builds with `-s version v1.2` and creates the `v1.2` Release with `manifest.json`, `glucia.ota.bin` and `glucia.factory.bin`. The board checks `releases/latest/download/manifest.json` every 6 h (`update: platform: http_request`) and installs it if the version differs. Local builds have version `dev` and don't update themselves.

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
- `simulator.yaml`, `simulator-dexcom.yaml` and `guition.yaml` build; `guition.yaml` with both looks is 1.6 MB (20% of flash, 34% of RAM).
- `simulator-dexcom.yaml` against the real Dexcom Share (2026-10-12): login and readings work.
- The `firmware.yml` Action: `v0.1` built and published the Release with the manifest and both binaries.

**Builds but untested:**
- Credentials outside the firmware (captive portal, `improv_serial`, local web page) and automatic update with rollback.

**Untested:**
- `guition.yaml` on the real board. Watch out for: orientation (`lvgl: rotation: 90`, maybe 270), touch orientation, brightness pin (GPIO1).

## Next steps

1. Liveness ping: periodic `http_request.get` to healthchecks.io.
2. Brightness control from the screen (the `backlight` `light` already exists in `hardware/guition.yaml`), mmol/L option.
3. A few weeks running at home, provoking failures, before shipping it.

## Gotchas found

- `id(widget)` in a lambda is not an `lv_obj_t *`: cast it, `(lv_obj_t *) id(lbl_number)`, to use LVGL functions.
- Don't name a lambda local variable like a widget: `lv_obj_t *marker = (lv_obj_t *) id(marker);` compiles but segfaults (the local shadows the global). Also avoid ids that clash with C names (`clock`, `time`): hence `sys_time`.
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
