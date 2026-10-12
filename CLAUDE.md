# Glucía: pantalla de glucosa (réplica DIY de Gluvi)

El aparato se llama `glucia` (hostname `glucia.local`) y su WiFi de rescate, `Glucia`. Repo **público** en GitHub: `albarin/glucia`. No poner datos personales en el repo (ni en commits, releases o issues): el contexto privado está en `CLAUDE.local.md`, que no se sube.

Pantalla de sobremesa que muestra en grande la glucosa de un sensor Dexcom: número, flecha de tendencia, cambio respecto a la lectura anterior, cuenta atrás hasta la próxima lectura y las 8 últimas lecturas en barras. Inspirada en https://migluvi.com.

Tutorial completo con todo el código explicado: https://claude.ai/code/artifact/3ac6b8ec-e27f-43b9-afdf-cdf8565ab950

## Para quién y restricciones

- Es para una persona que vive lejos y **no tiene Home Assistant** ni ningún servidor. El aparato tiene que funcionar solo, con su WiFi, sin depender de nada más.
- No se puede ir a arreglarlo en persona: todo el mantenimiento tiene que poder hacerse a distancia.
- Es una pantalla **informativa**: no avisa ni suena. Las alarmas de Dexcom en el móvil de esa persona tienen que seguir activas. No añadir alarmas.

## Decisiones tomadas

- **Firmware:** ESPHome (probado con 2026.9.1) con LVGL 9. Sin Home Assistant: no se usa la `api:` de HA.
- **Datos:** Dexcom Share directamente desde la placa (API no oficial, la misma que usa `pydexcom`). Servidor de fuera de EE. UU.: `shareous1.dexcom.com`.
- **Hardware:** Guition **JC3248W535C** (ESP32-S3 N16R8, 3,5", 480x320, táctil capacitivo AXS15231). Compradas 2 (una para pruebas, otra para enviar); llegada prevista 17 a 22 de octubre de 2026.
- **Desarrollo:** primero en el simulador (`host` + SDL2) en el Mac; luego en la placa.
- **Python:** 3.13 de Homebrew, en un entorno virtual `.venv` dentro del proyecto (`.venv/bin/esphome`). El de macOS (3.9) instala un ESPHome demasiado viejo, y 3.15 falla al compilar `ruamel.yaml.clib`.

## Puesta en marcha

`.venv` y `.esphome/` no están en git y guardan rutas absolutas: si se mueve o renombra la carpeta (o en otro ordenador), hay que rehacerlos.

```sh
rm -rf .venv .esphome
/opt/homebrew/bin/python3.13 -m venv .venv
.venv/bin/pip install esphome==2026.9.1
cp secrets.example.yaml secrets.yaml      # solo si no existe; rellenar los valores

.venv/bin/esphome run simulador.yaml      # simulador con demo (necesita SDL2: brew install sdl2)
.venv/bin/esphome compile guition.yaml    # firmware de la placa (la primera vez tarda: descarga ESP-IDF)
```

## Estructura

```
secrets.yaml             # contraseñas (no subir a git)
secrets.example.yaml     # plantilla de secrets.yaml, sin datos reales
simulador.yaml           # simulador + datos de demo
simulador-dexcom.yaml    # simulador + Dexcom real (nombre distinto: no comparte compilación con el otro)
guition.yaml             # placa real + Dexcom real
hardware/
  simulador.yaml         # ventana SDL 480x320, reloj del sistema, http_request
  guition.yaml           # ESP32-S3, PSRAM, QSPI, mipi_spi, táctil, brillo, WiFi + AP de rescate,
                         # web local, OTA, actualización automática
.github/workflows/
  firmware.yml           # al subir una etiqueta v*: compila guition.yaml y lo publica
comun/
  interfaz.yaml          # globales, fuentes, pantalla LVGL y script `pintar`
  demo.yaml              # lecturas inventadas cada 15 s
  dexcom.yaml            # login + lectura de Dexcom Share cada 60 s
```

Los ficheros principales solo combinan `packages`: hardware + interfaz + datos.

### Contrato entre interfaz y datos

`interfaz.yaml` no sabe de dónde vienen los datos. Una fuente de datos rellena estas globales y llama a `script.execute: pintar`:

- `historial` (`std::vector<int>`, 8 elementos, el más reciente en `[7]`, 0 = sin dato)
- `ultima_ts` (hora de la lectura en segundos Unix, la que da Dexcom, no la de recepción)
- `delta`, `delta_ok`, `tendencia` (numeración de Dexcom: 1 sube rápido, 4 estable, 7 baja rápido, 8 no calculable, 9 sin tendencia)
- `estado` (texto arriba a la izquierda), `conectado` (icono WiFi)

Además cada fuente debe definir el global `periodo` (segundos entre lecturas: 300 en Dexcom, 15 en la demo) y el script `pulsacion_larga`.

Regla de dato caducado (en `pintar`): si la última lectura tiene más de `3 * periodo` segundos, número en gris, sin flecha, sin cambio, sin cuenta atrás y edad en rojo. Nunca mostrar una cifra vieja con aspecto de actual.

## Credenciales y actualizaciones

El firmware de la placa se publica en los Releases públicos de este repo, así que no lleva nada privado:

- **WiFi:** se elige desde la red de rescate `Glucia` (portal cautivo) o por USB (`improv_serial`, desde web.esphome.io). Se guarda en el aparato.
- **Dexcom:** se pone en la web local (`http://glucia.local`, `web_server` sin contraseña, solo accesible desde la red de casa). Entidades `text` con `restore_value`. Al cambiarlas se borra la sesión y la espera (`dexcom_olvidar`). Sin credenciales, la pantalla dice «Falta Dexcom: entra en glucia.local».
- En el binario solo van `ap_password` y `ota_password`: se pueden sacar del binario público, así que no reutilizar contraseñas importantes.
- `simulador-dexcom.yaml` sí toma las credenciales de Dexcom de `secrets.yaml` (por `substitutions`).

Actualizaciones: `git tag v1.2 && git push origin v1.2` lanza la Action, que compila con `-s version v1.2` y crea el Release `v1.2` con `manifest.json`, `glucia.ota.bin` y `glucia.factory.bin`. La placa mira `releases/latest/download/manifest.json` cada 6 h (`update: platform: http_request`) y si la versión es distinta la instala. Las compilaciones locales llevan versión `dev` y no se actualizan solas.

Red de seguridad: `safe_mode` + rollback del ESP-IDF (activo por defecto). Si el firmware nuevo se reinicia antes de 1 minuto funcionando, el arranque vuelve al anterior. No protege de un firmware que arranca pero funciona mal (p. ej. sin WiFi): probar siempre en la placa de casa antes de etiquetar. El rollback necesita que el gestor de arranque se haya grabado por USB con esta configuración (la primera instalación).

## API de Dexcom Share

1. `POST General/AuthenticatePublisherAccount` con `accountName`, `password`, `applicationId` → account ID (UUID entre comillas).
2. `POST General/LoginPublisherAccountById` con `accountId`, `password`, `applicationId` → session ID. Un UUID de ceros es un fallo.
3. `POST Publisher/ReadPublisherLatestGlucoseValues?sessionId=…&minutes=60&maxCount=8` con cuerpo `{}` → lista, la más reciente primero. Cada lectura: `{"WT": "Date(ms)", "Value": 142, "Trend": "FortyFiveUp"}` (`Trend` puede venir como texto o número).

- `applicationId`: `d89443d2-327c-4a6f-89e5-496bbb0317db`.
- Errores `SessionIdNotFound` o `SessionNotValid` → se borra la sesión y se repite el login.
- Credenciales incorrectas → no reintentar en 30 min (`dx_esperar_hasta`), para no bloquear la cuenta (`SSO_AuthenticateMaxAttemptsExceeded`). Otros fallos de login → 2 min.
- No se intenta el login sin hora válida (en la placa la hora llega por SNTP después del WiFi): sin hora no se puede respetar la espera.
- Credenciales: las de la **cuenta principal** (quien lleva el sensor), con Share activado y al menos un seguidor aceptado.

## Estado

**Probado (en Linux, en la nube):**
- `simulador.yaml` compila y funciona: demo, tema invertido con un toque, pausa y dato caducado con pulsación larga.
- `dexcom.yaml` contra un servidor de prueba que imita a Dexcom: login, lectura, sesión caducada y re-login, contraseña incorrecta con un solo intento, servidor caído.

**Probado en el Mac de Alba:**
- ESPHome 2026.9.1 en `.venv` (Python 3.13). Usar `.venv/bin/esphome`.
- `simulador.yaml` se ve bien: demo, cuenta atrás, tema invertido.
- `simulador.yaml`, `simulador-dexcom.yaml` y `guition.yaml` compilan; `guition.yaml` ocupa 1,2 MB (15 % de flash, 33 % de RAM).

**Compila pero no está probado:**
- Credenciales fuera del firmware (portal cautivo, `improv_serial`, web local) y actualización automática con rollback.
- La Action `firmware.yml` (falta crear los secretos `AP_PASSWORD` y `OTA_PASSWORD` y lanzar la primera etiqueta).

**No probado:**
- Contra el Dexcom real (aún no hay credenciales).
- `guition.yaml` en la placa real. Puntos a vigilar: orientación (`lvgl: rotation: 90`, quizá 270), orientación del táctil, pin de brillo (GPIO1).

## Próximos pasos

1. Poner en marcha la publicación: secretos `AP_PASSWORD` y `OTA_PASSWORD` en el repo, primera etiqueta y comprobar que el Release lleva el manifiesto y los binarios.
2. Aviso de que sigue vivo: `http_request.get` periódico a healthchecks.io.
3. Control de brillo desde la pantalla (la `light` `brillo` ya existe en `hardware/guition.yaml`), opción de mmol/L.
4. Probar con las credenciales reales de Dexcom cuando las haya.
5. Unas semanas funcionando en casa, provocando fallos, antes de enviarla.
6. Actualizar el tutorial (enlace arriba): aún habla de `hola.yaml`, del nombre `glucosa` y tiene el código antiguo de `pintar` y del login de Dexcom.

## Trampas encontradas

- `id(widget)` en una lambda no es `lv_obj_t *`: hay que hacer `(lv_obj_t *) id(lbl_numero)` para usar funciones de LVGL.
- No llamar a una variable local de la lambda igual que un widget (`fondo` chocaba con el id del widget).
- En `mipi_spi` con LVGL, la rotación va en `lvgl: rotation:`, no en `display`. El AXS15231 no rota por hardware.
- `mipi_spi` necesita un bus `spi` de tipo `quad` declarado (CLK GPIO47, datos 21/48/40/39).
- En el simulador, `http_request` en macOS usa OpenSSL de `/opt/homebrew/opt/openssl` (Apple Silicon); en Linux hace falta `ca_certificate_path`.
- `pintar` se ejecuta cada segundo: solo cambiar texto, colores, tamaños y visibilidad si son distintos (`poner`, `tinta_de`, `relleno_de`, `ocultar`). LVGL redibuja con cada `set_style` aunque el valor sea el mismo, y en la placa la rotación es por software.
- Las funciones `lv_obj_get_style_*` piden `lv_part_t`: pasar `LV_PART_MAIN`, no `0` (con `0` no compila en C++).
- Las fuentes descargadas de GitHub, con versión fija (`raw/v7.4.47/`, no `raw/master/`), para que la compilación automática no cambie sola.

## Convenciones

- Código, comentarios y textos de pantalla en español.
- Textos de pantalla cortos y comprensibles para alguien no técnico.
