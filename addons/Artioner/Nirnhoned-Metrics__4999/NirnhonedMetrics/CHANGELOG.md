# Changelog

## 1.2.1

### Correcciones
- El DPS (o HPS) del pie es ahora la suma del DPS de todas las barras de la vista: yendo solo coincide con el de tu barra. En la 1.2.0 se dividía el total entre la duración de todo el combate y salía algo menor.

## 1.2.0

### Novedades
- El pie muestra, junto a la duración, el DPS (o HPS) total del combate. Se puede quitar en *Ajustes → Texto*.
- Iconos de la cabecera configurables en *Ajustes → Ventana → Iconos de la barra de título*: una casilla por icono. Los demás se recolocan sin dejar huecos y las líneas separadoras solo aparecen entre grupos con algún icono.
- Opción *Ocultar* en el menú del clic derecho, para cuando el icono de cerrar está oculto.
- Valores de las barras configurables en *Ajustes → Texto*: tres desplegables (valor 1, valor 2 y valor 3) con oculto, total, DPS/HPS o porcentaje. Las barras muestran `valor1 (valor2, valor3)`, saltando los ocultos. Sugerencia de un usuario de ESOUI.
- Las casillas anteriores (mostrar total, DPS y porcentaje) se convierten solas en los desplegables nuevos.

### Cambios
- Ancho mínimo de la ventana: 280 px, para que los iconos de la cabecera no tapen el título.

### Correcciones
- Los nombres largos de las barras y el título ya no se parten en varias líneas que se solapan con la fila siguiente: se cortan con puntos suspensivos.

## 1.1.0

### Novedades
- Título de la ventana configurable en *Ajustes → Ventana*: el del addon o uno propio, con un color o con códigos de color de ESO (`|cRRGGBB...|r`).
- La ventana se pliega (solo queda la cabecera) y se despliega con la flecha de la cabecera, el menú del clic derecho o los ajustes.
- Los iconos de la cabecera van en tres grupos separados por una línea: daño y sanación · grupo y mis habilidades · el resto.

### Cambios
- Librerías necesarias: LibAddonMenu-2.0 r43 o posterior y LibGroupCombatStats 2026-10-04 o posterior.
- Las teclas llaman a funciones de la tabla `NirnhonedMetrics` en vez de crear funciones globales.
- Los eventos de combate ya filtrados por el juego no se vuelven a comprobar en Lua.

## 1.0.0 — primera versión pública

### Medidor
- Ventana con barras de colores ordenadas de mayor a menor: posición, icono de clase, nombre y `total (DPS, %)`, como `4.43M (53.4K, 9.5%)`.
- Barras con aspecto de barra de progreso (borde, carril, brillo y sombra) o planas, a elegir en los ajustes.
- Cabecera con el nombre del addon y una fila de iconos: daño, sanación, grupo, mis habilidades, combates, reiniciar, candado, ajustes y cerrar.
- Menú completo con clic derecho: vista, combates anteriores, reiniciar, bloquear y ajustes.
- Pie de la ventana con un reloj y la duración del combate, y qué combate se está viendo.
- Tamaño del texto de las barras y del título configurable; las barras y la cabecera crecen si el texto no cabe.
- Descripción emergente en cada barra con el detalle (total, DPS, porcentaje; en habilidades también golpes, críticos, golpe medio y máximo).
- Se mueve arrastrándola desde cualquier parte y se redimensiona con la esquina inferior derecha o los bordes derecho e inferior (desbloqueada); rueda del ratón para desplazar las barras.
- Solo se ve con la interfaz de juego (también con el cursor activo), no en menús.

### Datos
- Tu daño exacto a partir de los eventos de combate, incluido opcionalmente el de tus mascotas.
- Daño del grupo mediante LibGroupCombatStats: cada miembro con Nirnhoned Metrics comparte su daño y aparece con su daño, DPS y porcentaje aproximados. Tu DPS se comparte con el grupo (se puede desactivar).
- **Sanación**: cambia entre medir daño o sanación. Tu sanación es exacta (con sobrecuración); la del grupo llega por LibGroupCombatStats (HPS aproximado). Tu HPS también se comparte.
- **Resto del grupo** en combates de jefe: estimación del daño de quienes no lo comparten, a partir de la vida que pierden los jefes.
- Vista **Mis habilidades**: tu daño o tu sanación por habilidad, con colores por tipo de daño.
- Inicio y fin de combate automáticos (el combate empieza con tu primer golpe, que también cuenta), con espera configurable antes de cerrar el combate; si estás muerto y tu grupo sigue luchando, el combate continúa.
- Historial de los últimos combates (10 por defecto), con el nombre del jefe o del objetivo principal.

### Ajustes
- Panel en *Ajustes → Add-Ons*: ventana, estilo de barra, tamaños de texto, barras, colores por clase o color único, colores por tipo de daño, textos visibles, nombres de personaje o @cuenta, ocultar en PvP, mostrar solo en combate, mascotas, espera de fin de combate, historial, compartir DPS y resto del grupo.
- Teclas para mostrar/ocultar, cambiar de vista y reiniciar.
- Comandos de chat `/nm`.

### Otros
- Librerías necesarias: LibAddonMenu-2.0 y LibGroupCombatStats.
- Idiomas: español, inglés, alemán y francés (según el idioma del cliente).
- Ventana de bienvenida al instalar y de novedades al actualizar.
- Donación de oro al autor desde los ajustes (solo megaservidor EU).
- Licencia GPL-3.0.
