# Nirnhoned Metrics

*[English](README.md) · Español*

![Nirnhoned Metrics](screenshots/01-group-damage.png)

**Un medidor de daño y sanación para The Elder Scrolls Online.** Barras de colores con el daño o la sanación total, el DPS/HPS y el porcentaje del grupo de cada jugador en cada combate, además del desglose de tus propias habilidades. Todo en una ventana pequeña que puedes mover, redimensionar y configurar.

Versión actual: **1.0.0** (ver [CHANGELOG.md](CHANGELOG.md)).

<details>
<summary><b>Capturas</b> (5)</summary>
<br>
<table>
<tr>
<td align="center"><a href="screenshots/01-group-damage.png"><img src="screenshots/01-group-damage.png" width="260" alt="Daño del grupo"></a><br><sub>Daño del grupo</sub></td>
<td align="center"><a href="screenshots/02-rest-of-group.png"><img src="screenshots/02-rest-of-group.png" width="260" alt="Resto del grupo contra un jefe"></a><br><sub>Resto del grupo contra un jefe</sub></td>
<td align="center"><a href="screenshots/03-group-healing.png"><img src="screenshots/03-group-healing.png" width="260" alt="Sanación del grupo"></a><br><sub>Sanación del grupo</sub></td>
</tr>
<tr>
<td align="center"><a href="screenshots/04-my-abilities-damage.png"><img src="screenshots/04-my-abilities-damage.png" width="260" alt="Mis habilidades: daño"></a><br><sub>Mis habilidades: daño</sub></td>
<td align="center"><a href="screenshots/05-my-abilities-healing.png"><img src="screenshots/05-my-abilities-healing.png" width="260" alt="Mis habilidades: sanación"></a><br><sub>Mis habilidades: sanación</sub></td>
</tr>
</table>
</details>

## Uso

- `/nm` muestra y oculta el medidor. También con una tecla en *Controles → Nirnhoned Metrics*.
- Cada barra muestra `4.43M (53.4K, 9.5%)`: daño total, DPS y porcentaje del grupo, ordenados de mayor a menor, con el icono y el color de la clase.
- La barra de título muestra el nombre del addon y los iconos: **Daño**, **Sanación**, **Grupo**, **Mis habilidades**, combates anteriores, reiniciar, candado, ajustes y cerrar. El clic derecho en el medidor abre el menú completo.
- El pie de la ventana muestra la duración del combate (con un reloj) y qué combate se está viendo.
- **Daño / Sanación:** cambia lo que se mide. En sanación se ve el HPS y, en la descripción emergente, la sobrecuración.
- **Mis habilidades** muestra tu daño o tu sanación por habilidad (y por mascota) con colores por tipo de daño. Al pasar el ratón por una barra se ven los golpes, el porcentaje de críticos, el golpe medio y el máximo.
- El candado desbloquea la ventana: se mueve arrastrándola desde cualquier parte y cambia de tamaño con los bordes o la esquina inferior derecha. La rueda del ratón desplaza las barras si no caben.
- **Grupo:** ESO solo informa a cada jugador de su propio daño, así que cada miembro mide el suyo y lo comparte mediante [LibGroupCombatStats](https://github.com/m00nyONE/LibGroupCombatStats). Los miembros con Nirnhoned Metrics aparecen con su barra; tus cifras son exactas y las suyas aproximadas (la librería envía el DPS en miles y el daño en decenas de miles).
- **Resto del grupo:** en combates de jefe, la vida que pierden los jefes menos el daño ya conocido da una barra estimada con el daño de quienes no lo comparten (sin desglose por jugador).
- Ajustes en *Ajustes → Add-Ons → Nirnhoned Metrics*.

### Librerías necesarias

Minion las instala solas:
- [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html): los ajustes.
- [LibGroupCombatStats](https://github.com/m00nyONE/LibGroupCombatStats): compartir el daño con el grupo (trae consigo LibGroupBroadcast y LibCombat).

### Comandos de chat

```
/nm                          muestra/oculta el medidor
/nm mode [group|abilities]   cambia la vista
/nm damage | healing         mide el daño o la sanación
/nm reset                    borra todos los combates
/nm lock | unlock            bloquea o desbloquea la ventana
/nm resetpos                 devuelve la ventana a su posición inicial
/nm settings                 abre los ajustes
```

## Desarrollo

Enlaza la carpeta del proyecto en la de AddOns del juego (PowerShell). El enlace se tiene que llamar `NirnhonedMetrics`, igual que el manifiesto:

```powershell
New-Item -ItemType Junction `
  -Path "$env:USERPROFILE\Documents\Elder Scrolls Online\live\AddOns\NirnhonedMetrics" `
  -Target "D:\Projects\ESO Addons\Nirnhoned Metrics"
```

- Cambios en archivos `.lua` existentes: `/reloadui`.
- Archivos nuevos o cambios en `NirnhonedMetrics.txt`: hay que **cerrar el juego del todo** y volver a abrirlo.
- Errores: con LibDebugLogger instalado quedan en `SavedVariables/LibDebugLogger.lua`.

### Estructura

```
NirnhonedMetrics.txt    manifiesto
NirnhonedMetrics.lua    namespace, SavedVariables (valores por defecto), arranque, bienvenida
lang/*.lua              textos (en = base; es, de, fr sobrescriben)
Core/Utils.lua          formato de números y tiempo, colores, iconos de clase
Core/Fight.lua          eventos de combate: tu daño por habilidad, inicio/fin de combate, historial
Core/Group.lua          daño del grupo (LibGroupCombatStats) y estimación del resto del grupo
Core/Commands.lua       comandos /nm y funciones de las teclas
UI/Meter.lua            ventana: cabecera, barras, menú, pie con la duración, mover y redimensionar
UI/Settings.lua         panel de LibAddonMenu, ayuda, donaciones, bienvenida/novedades
Bindings.xml            teclas
```

- **Cómo se mide:** `EVENT_COMBAT_EVENT` filtrado a ti y a tus mascotas. Un combate empieza al entrar en combate (o con tu primer golpe) y termina unos segundos después de salir (`combatEndDelay`); si estás muerto y tu grupo sigue luchando, se espera. Tu DPS se calcula desde tu primer golpe hasta el último.
- **Grupo:** `Core/Group.lua` copia en el combate los datos de LibGroupCombatStats que cambiaron después de empezar el combate, para no mezclar datos del combate anterior. El resto del grupo se estima con la vida que pierden los jefes (`EVENT_POWER_UPDATE` de `boss*`, solo bajadas) menos tu daño a los jefes y el de los miembros conocidos.
- **Opción nueva:** valor por defecto en `NM.defaults` (`NirnhonedMetrics.lua`), control en `UI/Settings.lua` y textos en los cuatro `lang/*.lua`.

### Publicar una versión

1. Subir `NM.version` en `NirnhonedMetrics.lua` y `## Version` / `## AddOnVersion` en `NirnhonedMetrics.txt`.
2. Actualizar `L.CHANGELOG` en los cuatro `lang/*.lua` (es lo que ve el jugador al actualizar) y `CHANGELOG.md`.
3. Revisar `## APIVersion` (en el juego: `/script d(GetAPIVersion())`).
4. Empaquetar en un zip con la carpeta `NirnhonedMetrics/` dentro (el zip debe contener la carpeta, no los archivos sueltos, y la carpeta debe llamarse igual que el manifiesto).

## Apoyo

Los errores e ideas son bienvenidos en [Issues](../../issues).

Si te gusta Nirnhoned Metrics, puedes apoyarlo:
- En [Ko-fi](https://ko-fi.com/artion).
- Con oro dentro del juego a **@Artioner** (megaservidor EU), con el botón *Donar oro* de los ajustes.

## Licencia

Copyright (C) 2026 @Artioner. Nirnhoned Metrics es software libre bajo la [GNU General Public License v3.0](LICENSE): puedes redistribuirlo y modificarlo con esas condiciones, manteniendo el crédito del autor y publicando tus cambios con la misma licencia.
