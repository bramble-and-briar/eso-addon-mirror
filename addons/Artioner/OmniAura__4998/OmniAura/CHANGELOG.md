# Changelog

## 1.1.1

- Revisión según las normas de ESOUI: la tecla del editor llama a `OmniAura.ToggleEditor()` (ya no hay funciones globales sueltas).
- Los eventos de combate descartan los errores con el filtro `REGISTER_FILTER_IS_ERROR` en vez de comprobarlo en Lua.
- Quitadas las comprobaciones de existencia de funciones y objetos del juego (`CHAT_ROUTER`, `GetClassName`, `FRAGMENT_GROUP`...) y de los módulos propios del addon.
- Se usan las constantes actuales (`COMBAT_MECHANIC_FLAGS_*`, `SetDefaultText`) en vez de los alias de compatibilidad.
- Los nombres de recursos (salud, magia, aguante, definitiva), armas y líneas de habilidad del catálogo salen de los textos del propio juego.
- Quitado del selector de sonidos `SKILL_GAINED`, que ya no existe en el juego.
- Aviso sobre el uso de IA y créditos en el README.

## 1.1.0

- Nuevo trigger **Habilidad en mis barras (acumulaciones)**: muestra las acumulaciones y el tiempo que el juego pinta sobre una habilidad de tus barras (p. ej. Latigazo ardiente → Azote poderoso), aunque no haya un buff que los lleve. Plantilla «Acumulaciones de una habilidad de mis barras».
- `{stacks}` muestra también una sola acumulación (antes solo aparecía a partir de 2).
- Los textos de la apariencia (texto central, de esquina, etc.) se pueden dejar vacíos; antes volvía el texto por defecto.

## 1.0.0 — primera versión pública

### Editor
- Ventana de edición (`/omni`, tecla configurable o *Ajustes → Add-Ons → OmniAura*), centrada, plegable y movible desde su barra de título.
- Lista de auras con icono, nombre y papelera (borrado con confirmación).
- Botón de ayuda (**?**) que abre la sección de OmniAura en *Ajustes → Add-Ons*: descripción, guía de uso, consejos y comandos de chat (sin LibAddonMenu se muestra en una ventana).
- Plantillas para crear auras: buff en mí, mi debuff en el objetivo, buff que me falta, recurso, proc de set/habilidad y estado de combate.
- Formulario organizado en apartados (General, Cuándo se muestra con Efectos vigilados / Añadir efecto / Opciones, y Apariencia) que solo muestra las opciones que tienen sentido para cada aura.
- Botón **Ubicar en pantalla** (al final de Apariencia): cierra el editor y muestra solo el aura que editas sobre la interfaz de juego para moverla y redimensionarla (esquina amarilla para el tamaño); «Listo» vuelve a abrir el editor.
- Mientras el editor está abierto, las auras activas se ocultan; solo se ve la que estás ubicando.
- **Ubicar auras**: oculta el editor y muestra la interfaz de juego normal para colocar y redimensionar todas las auras a la vez; se termina con «Listo» o Esc.

### Qué se puede vigilar (triggers)
- **Buff / debuff** en ti, tu objetivo o un jefe: activo o que falta, solo los tuyos, acumulaciones mínimas.
- **Recurso**: salud, magia, aguante o definitiva, por valor o porcentaje.
- **Proc / evento de combate**: muestra el aura durante N segundos (procs de sets, cooldowns internos).
- **Estado de combate**: dentro o fuera de combate.
- Varios triggers por aura, con lógica "todos" o "alguno", y condición de carga (siempre, solo en combate, solo fuera).
- **Usar en**: cada aura puede usarse en todos tus personajes o solo en uno.

### Elegir habilidades sin escribir IDs
- Buscador en todas las habilidades del juego, agrupadas por nombre. No se ofrecen las entradas de las habilidades pasivas en sí (solo modifican estadísticas y nunca aparecen como efecto); los bufos que activan sí, porque son efectos aparte.
- Catálogo completo con categorías: bufos/perjuicios, las 7 clases, armas, armadura, gremios, mundo, guerra de alianzas, raciales, Mundus, compañeros, equipo y consumibles; con filtro por nombre y descripción emergente.
- Atajos: efectos activos ahora, habilidades de tus barras y efectos/procs recientes.
- Un aura puede vigilar varios efectos (se muestra si hay cualquiera de ellos); al añadir por nombre no se duplican IDs.

### Cómo se ve (displays)
- Icono (temporizador, acumulaciones, sombreado de duración, gris cuando falta, borde).
- Icono + texto encima.
- Barra (progreso de duración o de recurso, icono opcional).
- Texto.
- Colores con el selector del juego, textos con plantillas (`{name} {time} {stacks} {value} {max} {percent}`) y sonido al aparecer.

### Otros
- Idiomas: español, inglés, alemán y francés (según el idioma del cliente).
- Ventana de bienvenida al instalar y de novedades al actualizar.
- Donación de oro al autor desde el editor o los ajustes (solo megaservidor EU).
- Comandos de chat `/omni` para usuarios avanzados.
- Licencia GPL-3.0.
