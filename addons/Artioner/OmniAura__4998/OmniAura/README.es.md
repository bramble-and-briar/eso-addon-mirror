# OmniAura

*[English](README.md) · Español*

![OmniAura](screenshots/01-help.png)

**Tus propios avisos en pantalla para The Elder Scrolls Online.** Vigila buffs, debuffs, recursos, procs de sets y el estado de combate, y muéstralos como iconos, barras o textos justo donde quieras, todo desde un editor visual dentro del juego y sin escribir ni un solo ID.

Versión actual: **1.0.0** (ver [CHANGELOG.md](CHANGELOG.md)).

<details>
<summary><b>Capturas</b> (9)</summary>
<br>
<table>
<tr>
<td align="center"><a href="screenshots/01-help.png"><img src="screenshots/01-help.png" width="260" alt="Ayuda en Ajustes"></a><br><sub>Ayuda en Ajustes</sub></td>
<td align="center"><a href="screenshots/02-chat-commands.png"><img src="screenshots/02-chat-commands.png" width="260" alt="Comandos de chat"></a><br><sub>Comandos de chat</sub></td>
<td align="center"><a href="screenshots/03-editor.png"><img src="screenshots/03-editor.png" width="260" alt="Editor"></a><br><sub>Editor</sub></td>
</tr>
<tr>
<td align="center"><a href="screenshots/04-watched-effects.png"><img src="screenshots/04-watched-effects.png" width="260" alt="Efectos vigilados y opciones"></a><br><sub>Efectos vigilados y opciones</sub></td>
<td align="center"><a href="screenshots/05-position-on-screen.png"><img src="screenshots/05-position-on-screen.png" width="260" alt="Ubicar en pantalla"></a><br><sub>Ubicar en pantalla</sub></td>
<td align="center"><a href="screenshots/06-icon-with-text.png"><img src="screenshots/06-icon-with-text.png" width="260" alt="Icono con texto"></a><br><sub>Icono con texto</sub></td>
</tr>
<tr>
<td align="center"><a href="screenshots/07-bar.png"><img src="screenshots/07-bar.png" width="260" alt="Barra"></a><br><sub>Barra</sub></td>
<td align="center"><a href="screenshots/08-catalog-buffs.png"><img src="screenshots/08-catalog-buffs.png" width="260" alt="Catálogo: bufos"></a><br><sub>Catálogo: bufos</sub></td>
<td align="center"><a href="screenshots/09-catalog-gear.png"><img src="screenshots/09-catalog-gear.png" width="260" alt="Catálogo: equipo y sets"></a><br><sub>Catálogo: equipo y sets</sub></td>
</tr>
</table>
</details>

## Uso

- `/omni` abre y cierra el editor. También desde *Ajustes → Add-Ons → OmniAura* o con una tecla en *Controles → OmniAura*.
- **+ Nueva aura...** crea un aura a partir de una plantilla.
- En las auras de buff y proc, los efectos se eligen con el buscador, el **catálogo** o los atajos (efectos actuales, habilidades de tus barras, recientes). Un aura con varios efectos se muestra si hay *cualquiera* de ellos.
- El botón **Ubicar en pantalla** (al final de Apariencia) cierra el editor y muestra el aura que editas sobre la interfaz de juego: se arrastra para moverla, su esquina amarilla cambia el tamaño y «Listo» vuelve al editor.
- **Ubicar auras** (debajo de la lista) oculta el editor y muestra la interfaz de juego normal para colocar todas las auras a la vez; se termina con «Listo» o Esc.
- La flecha junto a la X pliega el editor. Mientras está abierto, las auras activas no se muestran.

### Comandos de chat (avanzado)

```
/omni                    abre/cierra el editor
/omni list               lista las auras numeradas
/omni show|on|off|del|copy <n>
/omni set <n> <ruta> <valor>   p. ej. set 1 display.type bar
/omni scan [player|target]     efectos actuales con su ID
/omni log                registra los IDs de las habilidades que usas
/omni unlock | lock      entrar/salir del modo «Ubicar auras»
/omni reset confirm      borra todas las auras
```

## Desarrollo

Enlaza la carpeta del proyecto en la de AddOns del juego (PowerShell):

```powershell
New-Item -ItemType Junction `
  -Path "$env:USERPROFILE\Documents\Elder Scrolls Online\live\AddOns\OmniAura" `
  -Target "D:\Projects\ESO Addons\OmniAura"
```

- Cambios en archivos `.lua` existentes: `/reloadui`.
- Archivos nuevos o cambios en `OmniAura.txt`: hay que **cerrar el juego del todo** y volver a abrirlo.
- Errores: con LibDebugLogger instalado quedan en `SavedVariables/LibDebugLogger.lua`.

### Estructura

```
OmniAura.txt            manifiesto
OmniAura.lua            namespace, SavedVariables, arranque, bienvenida
lang/*.lua              textos (en = base; es, de, fr sobrescriben)
Core/Utils.lua          parseo, rutas, formato de tiempo, plantillas de texto
Core/Triggers.lua       tipos de trigger (buff, resource, proc, combat)
Core/Recent.lua         efectos/habilidades vistos recientemente
Core/AbilityIndex.lua   índice de todas las habilidades del juego (búsqueda y catálogo)
Core/Engine.lua         evaluación de auras cada 100 ms; alta/copia/borrado
Core/Commands.lua       comandos /omni
Display/Displays.lua    tipos de display (icon, icontext, bar, text), mover y redimensionar
Editor/Editor.lua       ventana del editor (formulario generado desde esquemas)
Editor/Catalog.lua      ventana del catálogo de habilidades
Editor/Settings.lua     panel de LibAddonMenu, donaciones, bienvenida/novedades
Bindings.xml            tecla para abrir el editor
```

- **Trigger nuevo:** `OA.Triggers.types.<nombre> = { Prepare, Register, Unregister, Check }` y sus campos en `TRIGGER_FIELDS` del editor.
- **Display nuevo:** `NewType("<nombre>")` con `Build`, `Configure`, `Update` y `SetBoxSize`, y sus campos en `DISPLAY_FIELDS`.
- **Opción del formulario:** una línea en el esquema; `show = function(ctx)` la oculta cuando no aplica.

### Publicar una versión

1. Subir `OA.version` en `OmniAura.lua` y `## Version` / `## AddOnVersion` en `OmniAura.txt`.
2. Actualizar `L.CHANGELOG` en los cuatro `lang/*.lua` (es lo que ve el jugador al actualizar) y `CHANGELOG.md`.
3. Revisar `## APIVersion` (en el juego: `/script d(GetAPIVersion())`).
4. Empaquetar la carpeta `OmniAura/` en un zip (el zip debe contener la carpeta, no los archivos sueltos).

## Apoyo

Los errores e ideas son bienvenidos en [Issues](../../issues).

Si te gusta OmniAura, puedes apoyarlo:
- En [Ko-fi](https://ko-fi.com/artion).
- Con oro dentro del juego a **@Artioner** (megaservidor EU), con el botón *Donar oro* del editor.

## Licencia

Copyright (C) 2026 @Artioner. OmniAura es software libre bajo la [GNU General Public License v3.0](LICENSE): puedes redistribuirlo y modificarlo con esas condiciones, manteniendo el crédito del autor y publicando tus cambios con la misma licencia.
