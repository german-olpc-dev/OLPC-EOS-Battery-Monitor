# OLPC EndlessOS Battery Monitor

Monitor de diagnóstico para baterías de laptops OLPC con Endless OS. El script
muestra en la terminal el estado de la batería en tiempo real, guarda una muestra
en formato CSV cada 5 segundos y genera un resumen de la sesión al finalizar.

Versión documentada del script: **1.1.2**.

## Funcionalidades

- Detecta automáticamente la primera batería disponible como
  `/sys/class/power_supply/BAT*`.
- Obtiene el número de serie, fabricante y modelo de la laptop.
- Registra la versión de Endless OS y del kernel.
- Muestra si el adaptador de corriente está conectado.
- Lee carga, estado, voltaje, corriente, potencia y energía de la batería.
- Calcula la corriente o la potencia cuando uno de esos valores no es reportado
  directamente por el BMS (Battery Management System).
- Calcula la salud estimada de la batería.
- Mantiene estadísticas de potencia y voltaje durante la sesión.
- Guarda todas las muestras en un archivo CSV.
- Genera automáticamente un resumen al detenerse con `Ctrl+C` o al recibir
  `SIGTERM`.

## Requisitos

- Una laptop con Linux y una batería expuesta mediante `sysfs` en
  `/sys/class/power_supply/`.
- Bash.
- Acceso a `sudo`. Se usa para leer `/sys/class/dmi/id/product_serial`.
- Utilidades habituales de Linux: `awk`, `cat`, `cut`, `date`, `grep`, `tr`,
  `uname` y, preferiblemente, `getent`.
- Un controlador de batería que exponga valores en unidades estándar de
  `sysfs` (microvoltios, microamperios, microwatts y microvatios-hora).

El monitor fue diseñado para Endless OS. Puede funcionar en otras distribuciones
Linux, aunque el campo `EndlessOS` mostrará realmente el `VERSION_ID` declarado
en `/etc/os-release`.

## Instalación

Clona o copia este repositorio y entra en su directorio:

```bash
cd OLPC-EOS-Battery-Monitor
chmod +x olpc-battery-monitor.sh
```

El archivo incluido en el repositorio puede no conservar inicialmente el permiso
de ejecución; `chmod +x` lo habilita.

## Uso

### Ejecución normal

```bash
./olpc-battery-monitor.sh
```

El script solicitará la contraseña de `sudo`, iniciará el monitoreo y actualizará
la pantalla cada 5 segundos. Para terminar la prueba y generar el resumen,
presiona `Ctrl+C`.

Se recomienda ejecutarlo como usuario normal. El propio script solicita los
privilegios que necesita y guarda los resultados en el directorio personal de ese
usuario.

### Ejecución sin cambiar permisos

```bash
bash olpc-battery-monitor.sh
```

### Prueba de carga

1. Conecta el adaptador de corriente.
2. Ejecuta el monitor.
3. Déjalo activo durante el período de prueba.
4. Presiona `Ctrl+C`.
5. Revisa el cambio de carga y energía en el archivo de resumen.

### Prueba de descarga

1. Desconecta el adaptador de corriente.
2. Ejecuta el monitor mientras la laptop trabaja con la batería.
3. Presiona `Ctrl+C` al finalizar el período de prueba.
4. Revisa los valores mínimo, máximo y promedio de potencia.

El script no acepta argumentos de línea de comandos. Para cambiar el intervalo
de muestreo hay que modificar la variable `INTERVAL=5` al inicio del archivo. El
valor está expresado en segundos.

## Salida en pantalla

Durante la ejecución se presenta una interfaz de dos columnas. Este es un ejemplo
ilustrativo; los datos dependen de cada equipo y de su controlador:

```text
==============================================================================
 EndlessOS Battery Diagnostic Monitor                               v1.1.2
==============================================================================

DEVICE INFORMATION                     | BATTERY INFORMATION
---------------------------------------+--------------------------------------
 Laptop SN:        OLPC000123           | Battery:          BAT0
 Vendor:           OLPC                 | Battery SN:       BATT987654
 Product:          NL3                  | Vendor:           SMP
 EndlessOS:        6.0.5                | Model:            L20M3PG0
 Kernel:           6.8.0-52-generic     |

==============================================================================

LIVE STATUS                           | SESSION
---------------------------------------+--------------------------------------
 Time:             2026-09-07 10:30:15 | Initial charge:   62%
 AC Adapter:       CONNECTED           | Current charge:   63%
 Battery status:   Charging            | Samples:          13
 Charge:           63%                 | Interval:         5s
 Voltage:          11.984 V            | Power min:        18.421 W
 Current:          1.672 A              | Power max:        20.038 W
 Power:            20.036 W (calc)     | Power samples:    13
 Energy now:       27.421 Wh            | Voltage min:      11.842 V
 Energy full:      43.812 Wh            | Voltage max:      11.984 V
 Energy remaining: 16.391 Wh            |
 Battery health:   91.3%                |

==============================================================================
 LOG FILE
------------------------------------------------------------------------------
 /home/olpc/battery-logs/battery_OLPC000123_20260907_102915.csv

 CTRL+C to stop monitoring and generate summary
==============================================================================
```

La marca `(calc)` indica que el valor fue calculado porque el BMS no lo entregó
directamente.

## Archivos generados

Los resultados se guardan en:

```text
~/battery-logs/
```

Cada ejecución crea dos archivos cuyos nombres contienen el número de serie de la
laptop y la fecha/hora de inicio:

```text
battery_<SERIE>_<AAAAMMDD_HHMMSS>.csv
battery_<SERIE>_<AAAAMMDD_HHMMSS>_summary.txt
```

Ejemplo:

```text
/home/olpc/battery-logs/battery_OLPC000123_20260907_102915.csv
/home/olpc/battery-logs/battery_OLPC000123_20260907_102915_summary.txt
```

Si no es posible obtener un número de serie válido, se usa `UNKNOWN` en el
nombre. Al ejecutar el monitor mediante `sudo`, el script usa `SUDO_USER` para
guardar los archivos en el directorio personal del usuario original y no en
`/root`.

### Ejemplo de CSV

```csv
timestamp,script_version,laptop_serial,device_vendor,device_model,endless_version,kernel,battery,battery_serial,battery_vendor,battery_model,ac,status,charge_percent,voltage_V,current_A,current_source,power_W,power_source,energy_now_Wh,energy_full_Wh,energy_design_Wh,energy_remaining_Wh,battery_health_percent
"2026-09-07 10:29:15","1.1.2","OLPC000123","OLPC","NL3","6.0.5","6.8.0-52-generic","BAT0","BATT987654","SMP","L20M3PG0","CONNECTED","Charging","62","11.842","1.690","BMS","20.013","CALCULATED","27.219","43.812","47.980","16.593","91.3"
```

Cada fila corresponde a una muestra. Las columnas son:

| Columna | Descripción |
| --- | --- |
| `timestamp` | Fecha y hora local de la muestra. |
| `script_version` | Versión del monitor. |
| `laptop_serial` | Número de serie de la laptop. |
| `device_vendor` | Fabricante de la laptop. |
| `device_model` | Modelo o nombre de producto. |
| `endless_version` | `VERSION_ID` de `/etc/os-release`. |
| `kernel` | Versión del kernel. |
| `battery` | Dispositivo detectado, por ejemplo `BAT0`. |
| `battery_serial` | Número de serie de la batería. |
| `battery_vendor` | Fabricante de la batería. |
| `battery_model` | Modelo de la batería. |
| `ac` | `CONNECTED`, `DISCONNECTED` o `N/A`. |
| `status` | Estado reportado por el sistema, como `Charging`, `Discharging` o `Full`. |
| `charge_percent` | Porcentaje de carga. |
| `voltage_V` | Voltaje en voltios. |
| `current_A` | Corriente en amperios. |
| `current_source` | `BMS` o `CALCULATED`. |
| `power_W` | Potencia en watts. |
| `power_source` | `BMS` o `CALCULATED`. |
| `energy_now_Wh` | Energía almacenada actualmente, en Wh. |
| `energy_full_Wh` | Capacidad máxima actual estimada, en Wh. |
| `energy_design_Wh` | Capacidad de diseño, en Wh. |
| `energy_remaining_Wh` | Energía faltante para alcanzar `energy_full_Wh`. |
| `battery_health_percent` | Salud estimada respecto a la capacidad de diseño. |

### Ejemplo del resumen

El resumen se crea al detener correctamente el monitor:

```text
==============================================================================
 EndlessOS Battery Diagnostic Summary
 Script Version: 1.1.2
==============================================================================

DEVICE INFORMATION
------------------------------------------------------------------------------
Laptop SN          : OLPC000123
Vendor             : OLPC
Product            : NL3
EndlessOS          : 6.0.5
Kernel             : 6.8.0-52-generic

BATTERY INFORMATION
------------------------------------------------------------------------------
Battery            : BAT0
Battery SN         : BATT987654
Vendor             : SMP
Model              : L20M3PG0

TEST RESULTS
------------------------------------------------------------------------------
Start charge       : 62%
End charge         : 78%
Charge change      : 16%

Start energy       : 27.219 Wh
End energy         : 34.231 Wh
Energy change      : 7.012 Wh

Power min          : 18.421 W
Power max          : 20.038 W
Power average      : 19.442 W

Voltage min        : 11.842 V
Voltage max        : 12.311 V
Duration           : 00:30:05
Samples            : 362

CSV log:
/home/olpc/battery-logs/battery_OLPC000123_20260907_102915.csv
==============================================================================
```

## Cálculos realizados

Cuando los datos necesarios están disponibles, el monitor aplica estas fórmulas:

```text
Potencia calculada (W) = Voltaje (V) × Corriente (A)
Corriente calculada (A) = Potencia (W) ÷ Voltaje (V)
Energía faltante (Wh) = Energía máxima actual - Energía actual
Salud (%) = Energía máxima actual ÷ Energía de diseño × 100
Cambio de energía (Wh) = Energía final - Energía inicial
Cambio de carga (%) = Porcentaje final - Porcentaje inicial
```

Los valores originales de `sysfs` se convierten de micro-unidades a unidades
estándar dividiéndolos entre 1,000,000.

## Interpretación de valores

- Un cambio de carga o energía positivo indica carga; uno negativo indica
  descarga.
- `battery_health_percent` es una estimación basada en la capacidad que reporta
  el BMS, no una prueba química independiente.
- La corriente o potencia puede aparecer con signo negativo según el controlador
  del equipo. El script conserva el signo reportado.
- `N/A` significa que el archivo correspondiente no existe, no es legible o no
  contiene un valor numérico reconocido.
- `energy_remaining_Wh`, pese a su nombre interno, no es la energía disponible
  para descargar: es la energía que falta para completar la carga.

## Consultar resultados

Listar las sesiones más recientes:

```bash
ls -lt ~/battery-logs/
```

Ver un resumen:

```bash
cat ~/battery-logs/battery_OLPC000123_20260907_102915_summary.txt
```

Ver las últimas muestras de un CSV:

```bash
tail -n 10 ~/battery-logs/battery_OLPC000123_20260907_102915.csv
```

Los archivos CSV también pueden abrirse con LibreOffice Calc o importarse en una
herramienta de análisis de datos.

## Errores comunes

### `ERROR: sudo privileges are required.`

El usuario no pudo autenticarse con `sudo` o no tiene permisos para usarlo.

### `ERROR: No battery detected.`

No se encontró ningún directorio `BAT*` en `/sys/class/power_supply/`. Comprueba
los dispositivos disponibles con:

```bash
ls /sys/class/power_supply/
```

### Algunos valores muestran `N/A`

No todos los BMS o controladores exponen `power_now`, `current_now`, información
de energía, fabricante, modelo o número de serie. El monitor calcula corriente o
potencia cuando puede; los demás campos que no estén disponibles permanecen como
`N/A`.

### No se generó el resumen

El CSV se crea al comenzar la sesión, pero el resumen depende de que el proceso
reciba `SIGINT` (`Ctrl+C`) o `SIGTERM`. Una terminación forzada con `SIGKILL`, un
apagado abrupto o una pérdida de energía no permite ejecutar esa rutina final.

## Limitaciones conocidas

- Solo se monitorea la primera batería `BAT*` encontrada.
- El intervalo de 5 segundos es fijo durante cada ejecución.
- El formato CSV no escapa comillas internas que pudieran aparecer en valores de
  fabricante o modelo.
- El ancho de la interfaz está pensado para una terminal de aproximadamente 80
  columnas; valores largos pueden desalinear la presentación.
- La exactitud depende completamente de los valores reportados por el hardware y
  el kernel.

## Archivo principal

```text
olpc-battery-monitor.sh
```
