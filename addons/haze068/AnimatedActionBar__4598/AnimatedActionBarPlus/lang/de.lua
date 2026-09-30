local strings =
{
    SI_AAB_PANEL_DESCRIPTION =
        "Fügt deiner Aktionsleiste eine Bounce-Animation und einen anpassbaren Glow-Effekt hinzu. " ..
        "Funktioniert zusammen mit FancyActionbar+, Bandits UI, LUI Extended, Ability Framework " ..
        "(inkl. eigener Style Packs), AlphaGear, Azurah und der Standard-Benutzeroberfläche.",

    SI_AAB_SUB_BOUNCE          = "Bounce-Animation",
    SI_AAB_SUB_BOUNCE_TT       = "Einstellungen für die Schrumpf-und-Wachs-Animation deiner Fähigkeitssymbole.",

    SI_AAB_ANIM_STYLE          = "Animations-Stil",
    SI_AAB_ANIM_STYLE_TT       = "Welche Animation beim Drücken/Procken einer Fähigkeit abgespielt wird. " ..
                                        "Bounce: Schrumpfen + Wachsen. Flash: Helligkeits-Blink. " ..
                                        "Shake: horizontales Wackeln. Tilt: kurze Drehung.",
    SI_AAB_ANIM_BOUNCE         = "Bounce",
    SI_AAB_ANIM_FLASH          = "Flash",
    SI_AAB_ANIM_SHAKE          = "Shake",
    SI_AAB_ANIM_TILT           = "Tilt",
    SI_AAB_SUB_GLOW            = "Glow-Effekt",
    SI_AAB_SUB_GLOW_TT         = "Ein farbiger Lichtschein, der beim Drücken über dein Fähigkeitssymbol einblendet.",
    SI_AAB_SUB_PULSE           = "Proc-Pulsieren",
    SI_AAB_SUB_PULSE_TT        = "Dauerhafter Glow-Effekt, solange eine Fähigkeit proc't und einsatzbereit ist.",

    SI_AAB_BOUNCE_ENABLE       = "Bounce aktivieren",
    SI_AAB_BOUNCE_ENABLE_TT    = "Hauptschalter für die Bounce-Animation. Wenn aus, animieren sich keine Symbole.",
    SI_AAB_BOUNCE_ON_PROC      = "Bounce bei Procs",
    SI_AAB_BOUNCE_ON_PROC_TT   = "Spielt die Bounce-Animation auch, wenn eine Fähigkeit proc't (z.B. Kristallfragmente, " ..
                                        "Wille des Assassinen, Grimmiger Fokus), nicht nur beim Drücken.",

    SI_AAB_BOUNCE_GROW         = "Wachstums-Skala",
    SI_AAB_BOUNCE_GROW_TT      = "Wie stark das Symbol am Höhepunkt der Bounce-Animation wächst. 1.10 = 10% größer als normal. " ..
                                        "Höher = auffälliger.",
    SI_AAB_BOUNCE_SHRINK       = "Schrumpf-Skala",
    SI_AAB_BOUNCE_SHRINK_TT    = "Wie stark das Symbol zu Beginn der Animation schrumpft. 0.90 = 10% kleiner als normal. " ..
                                        "Niedriger = härteres Stauchen.",
    SI_AAB_BOUNCE_RESET        = "Reset-Dauer (ms)",
    SI_AAB_BOUNCE_RESET_TT     = "Wie lange das Symbol braucht, um nach dem Höhepunkt zur Normalgröße zurückzukehren. " ..
                                        "Niedriger = knackiger.",

    SI_AAB_GLOW_ENABLE         = "Glow aktivieren",
    SI_AAB_GLOW_ENABLE_TT      = "Hauptschalter für den Glow-Effekt. Wenn aus, wird beim Drücken kein Glow gezeichnet.",
    SI_AAB_GLOW_COLOR          = "Glow-Farbe",
    SI_AAB_GLOW_COLOR_TT       = "Farbe des Glow-Effekts. Der Alpha-Regler (A) steuert die maximale Helligkeit.",
    SI_AAB_GLOW_DURATION       = "Glow-Dauer (ms)",
    SI_AAB_GLOW_DURATION_TT    = "Wie lange der Druck-Glow zum Ausblenden braucht. Höher = bleibt länger sichtbar.",
    SI_AAB_GLOW_PADDING        = "Glow-Abstand (px)",
    SI_AAB_GLOW_PADDING_TT     = "Zusätzliche Pixel, die der Glow über die Symbolränder hinaus reicht. " ..
                                        "Höher = größerer Lichthof um das Symbol.",
    SI_AAB_GLOW_INTENSITY      = "Glow-Stärke",
    SI_AAB_GLOW_INTENSITY_TT   = "Helligkeits-Multiplikator des Glows. 1.00 = Standard, höher = heller/intensiver. " ..
                                        "Wirkt auf Druck-Glow, Proc-Pulsieren und Verbrauchsgüter-Glow.",

    SI_AAB_PULSE_ENABLE        = "Proc-Pulsieren aktivieren",
    SI_AAB_PULSE_ENABLE_TT     = "Wenn eine Fähigkeit proc't, pulsiert der Glow weiter, bis die Fähigkeit benutzt wird oder ausläuft.",
    SI_AAB_PROC_VANILLA_GLOW       = "Vanilla-ESO-Proc-Glow",
    SI_AAB_PROC_VANILLA_GLOW_TT    = "Zeigt das originale ESO-Aufleuchten, das auf einer Fähigkeit erscheint, sobald sie proc't. " ..
                                        "Zum Abschalten deaktivieren, um nur das Proc-Pulsieren dieses Addons zu nutzen und die Leiste sauber zu halten. " ..
                                        "Wieder einschalten erfordert einen UI-Reload, um die Originaltextur wiederherzustellen.",
    SI_AAB_PULSE_STOP_ON_PRESS          = "Beim Drücken stoppen",
    SI_AAB_PULSE_STOP_ON_PRESS_TT       = "Stoppt das Pulsieren sofort beim Drücken der proc'd Fähigkeit, statt auf das Proc-Ende-Event " ..
                                        "des Spiels zu warten (das einen Frame zu spät kommen kann).",
    SI_AAB_PULSE_STYLE         = "Pulsier-Stil",
    SI_AAB_PULSE_STYLE_TT      = "Sanft: weiches Ein- und Ausblenden.\n" ..
                                        "Blinker: klar sichtbares An/Aus.\n" ..
                                        "Stroboskop: schnelles, aggressives Flackern für maximale Aufmerksamkeit.",
    SI_AAB_PULSE_STYLE_SMOOTH  = "Sanft",
    SI_AAB_PULSE_STYLE_BLINK   = "Blinker",
    SI_AAB_PULSE_STYLE_STROBE  = "Stroboskop",
    SI_AAB_PULSE_SMOOTH_DUR    = "Sanft: Pulsier-Dauer (ms)",
    SI_AAB_PULSE_SMOOTH_DUR_TT = "Länge eines Ein-/Ausblend-Zyklus im Sanft-Modus. Greift nur wenn Pulsier-Stil auf Sanft steht.",
    SI_AAB_PULSE_BLINK_INT     = "Blinker: Intervall (ms)",
    SI_AAB_PULSE_BLINK_INT_TT  = "Zeit zwischen An und Aus im Blinker-Modus. Niedriger = schnelleres Blinken. " ..
                                        "Greift nur wenn Pulsier-Stil auf Blinker steht.",
    SI_AAB_PULSE_STROBE_INT    = "Stroboskop: Intervall (ms)",
    SI_AAB_PULSE_STROBE_INT_TT = "Zeit zwischen An und Aus im Stroboskop-Modus. Sehr niedrige Werte erzeugen ein hartes Flackern. " ..
                                        "Greift nur wenn Pulsier-Stil auf Stroboskop steht.",
    SI_AAB_PULSE_MIN_ALPHA     = "Minimale Sichtbarkeit (Alpha)",
    SI_AAB_PULSE_MIN_ALPHA_TT  = "Niedrigster Sichtbarkeitswert, auf den das Pulsieren ausblendet. " ..
                                        "0 = komplett transparent am Dimm-Punkt, 1 = immer voll sichtbar.",
    SI_AAB_PULSE_MAX_ALPHA     = "Maximale Sichtbarkeit (Alpha)",
    SI_AAB_PULSE_MAX_ALPHA_TT  = "Höchster Sichtbarkeitswert, den das Pulsieren am Peak erreicht. 1 = komplett deckend.",
    SI_AAB_PULSE_COLOR_CYCLE   = "Farbwechsel",
    SI_AAB_PULSE_COLOR_CYCLE_TT= "Wechselt das Pulsieren zwischen der primären Glow-Farbe und der Sekundärfarbe unten " ..
                                        "für einen Zwei-Farben-Blink-Effekt.",
    SI_AAB_PULSE_COLOR_SECOND  = "Sekundärfarbe",
    SI_AAB_PULSE_COLOR_SECOND_TT = "Zweite Farbe, die genutzt wird, wenn Farbwechsel aktiv ist.",

    SI_AAB_SUB_ULT             = "Ultimative",
    SI_AAB_SUB_ULT_TT          = "Eigene Einstellungen für den Ultimativ-Slot, unabhängig von Bounce und Glow der normalen Slots.",

    SI_AAB_ULT_HEADER_EFFECTS  = "Ultimativ-Effekte",
    SI_AAB_ULT_BOUNCE_ENABLE   = "Bounce auf Ultimativ",
    SI_AAB_ULT_BOUNCE_ENABLE_TT= "Spielt die Bounce-Animation auch auf dem Ultimativ-Slot ab.",
    SI_AAB_ULT_GLOW_ENABLE     = "Glow auf Ultimativ",
    SI_AAB_ULT_GLOW_ENABLE_TT  = "Glow-Effekt beim Drücken auf dem Ultimativ-Slot.",
    SI_AAB_ULT_GLOW_COLOR      = "Ultimativ-Glow-Farbe",
    SI_AAB_ULT_GLOW_COLOR_TT   = "Farbe des Glow-Effekts auf dem Ultimativ-Slot. Der Alpha-Regler (A) steuert die Helligkeit.",
    SI_AAB_ULT_GLOW_DURATION   = "Ultimativ-Glow-Dauer (ms)",
    SI_AAB_ULT_GLOW_DURATION_TT= "Wie lange der Ultimativ-Glow zum Ausblenden braucht.",
    SI_AAB_ULT_GLOW_PADDING    = "Ultimativ-Glow-Stärke (px)",
    SI_AAB_ULT_GLOW_PADDING_TT = "Zusätzliche Pixel, die der Ultimativ-Glow über die Symbolränder hinaus reicht. " ..
                                        "Höher = größerer/stärkerer Lichthof, niedriger = dezenter.",
    SI_AAB_ULT_GLOW_INTENSITY  = "Ultimativ-Glow-Helligkeit",
    SI_AAB_ULT_GLOW_INTENSITY_TT = "Helligkeits-Multiplikator des Ultimativ-Glows beim Wirken. " ..
                                        "1.00 = Standard, höher = heller/intensiver.",

    SI_AAB_ULT_HEADER_READY    = "Ultimativ-Bereit-Rahmen",
    SI_AAB_ULT_VANILLA_SHIMMER = "Standard-ESO Bereit-Schimmern",
    SI_AAB_ULT_VANILLA_SHIMMER_TT = "Zeigt das originale goldene Schimmern/Glow von ESO auf dem Ultimativ-Slot, sobald die Ulti bereit ist. " ..
                                        "Funktioniert zusammen mit dem eigenen Bereit-Rahmen unten - eines oder beides aktivierbar. " ..
                                        "Deaktivieren nach einer aktiven Sitzung erfordert /reloadui, damit die Texturen vollständig verschwinden.",
    SI_AAB_ULT_BORDER_STYLE       = "Bereit-Rahmen-Stil",
    SI_AAB_ULT_BORDER_STYLE_TT    = "Legt fest, welcher Rahmen den Ultimativ-Slot markiert. \"Eigener\" nutzt den farbigen Glow-Rahmen dieses Addons mit allen Puls-/Blink-/Regenbogen-Optionen unten. \"Controller\" zeigt eine Fortschritts-Border, die sich beim Aufladen der Ulti von unten nach oben füllt. Bei Controller sind die eigenen Optionen unten deaktiviert.",
    SI_AAB_ULT_BORDER_CUSTOM      = "Eigener (Glow-Rahmen)",
    SI_AAB_ULT_BORDER_CONTROLLER  = "Controller (Fortschritts-Border)",
    SI_AAB_ULTCTRL_STYLE          = "Rahmen-Textur",
    SI_AAB_ULTCTRL_STYLE_TT       = "Welche Rahmen-Textur die Controller-Fortschritts-Border verwendet.",
    SI_AAB_ULTCTRL_STYLE_BEVEL    = "Bevel (metallisch 3D)",
    SI_AAB_ULTCTRL_STYLE_FLAT     = "Flat (saubere Linie)",
    SI_AAB_ULTCTRL_STYLE_SLEEK    = "Sleek (dünne Doppellinie)",
    SI_AAB_ULTCTRL_STYLE_CHAMFER  = "Chamfer (kantig)",
    SI_AAB_ULTCTRL_STYLE_DOUBLE   = "Double (Doppelring)",
    SI_AAB_ULTCTRL_GLOWSTYLE      = "Leucht-Stil",
    SI_AAB_ULTCTRL_GLOWSTYLE_TT   = "Form des Scheins, während die Ulti bereit ist.",
    SI_AAB_ULTCTRL_GLOWSTYLE_SOFT = "Soft (breiter Schein)",
    SI_AAB_ULTCTRL_GLOWSTYLE_SHARP = "Sharp (enge Kante)",
    SI_AAB_ULTCTRL_GLOWSTYLE_RING = "Ring (Außen-Aura)",
    SI_AAB_ULTCTRL_THICKNESS      = "Rahmendicke",
    SI_AAB_ULTCTRL_THICKNESS_TT   = "Wie dick die Rahmenlinie ist, in Pixeln. Niedrig für eine dünne Kontur, hoch für einen kräftigen Rahmen.",
    SI_AAB_ULTCTRL_CORNER         = "Ecken-Länge",
    SI_AAB_ULTCTRL_CORNER_TT      = "Wie weit die oberen und unteren Ecken-Stege nach innen reichen, in Prozent der Slotbreite. Niedriger = offenere Klammer, höher = geschlossenerer Rahmen.",
    SI_AAB_ULTCTRL_PADDING        = "Rahmenabstand",
    SI_AAB_ULTCTRL_PADDING_TT     = "Abstand zwischen Slot und Rahmen, in Pixeln.",
    SI_AAB_ULTCTRL_TRACK          = "Hintergrundschiene zeigen",
    SI_AAB_ULTCTRL_TRACK_TT       = "Zeigt den dunklen, ungefüllten Rahmen hinter dem Fortschritt, damit die volle Kontur immer sichtbar ist.",
    SI_AAB_ULTCTRL_COLORSHIFT     = "Farbverlauf beim Laden",
    SI_AAB_ULTCTRL_COLORSHIFT_TT  = "Blendet die Rahmenfarbe beim Aufladen von der Ladefarbe zur Bereit-Farbe über.",
    SI_AAB_ULTCTRL_CHARGECOLOR    = "Ladefarbe",
    SI_AAB_ULTCTRL_CHARGECOLOR_TT = "Rahmenfarbe bei 0%, wenn der Farbverlauf aktiv ist. Die Bereit-Farbe ist die Rahmenfarbe oben.",
    SI_AAB_ULTCTRL_GLOWFULL       = "Leuchten bei voll",
    SI_AAB_ULTCTRL_GLOWFULL_TT    = "Fügt einen hellen, additiven Schein und einen kurzen Puls hinzu, sobald die Ulti voll geladen ist.",
    SI_AAB_ULTCTRL_GLOWINT        = "Leucht-Intensität",
    SI_AAB_ULTCTRL_GLOWINT_TT     = "Helligkeit des Scheins, während die Ulti bereit ist.",
    SI_AAB_ULTCTRL_RAINBOW        = "Regenbogen bei voller Ulti",
    SI_AAB_ULTCTRL_RAINBOW_TT     = "Lässt die Fortschritts-Border durch den Regenbogen wandern, sobald die Ulti voll geladen ist. Nutzt die Sättigungs- und Helligkeits-Regler aus dem Custom-Rahmen-Bereich.",
    SI_AAB_ULT_ENABLE          = "Ultimativ-Bereit-Rahmen aktivieren",
    SI_AAB_ULT_ENABLE_TT       = "Zeigt einen farbigen Rahmen um deinen Ultimativ-Slot, sobald du genug " ..
                                        "Ultimativ-Energie hast, um die belegte Fähigkeit einzusetzen.",
    SI_AAB_ULT_COLOR           = "Rahmenfarbe",
    SI_AAB_ULT_COLOR_TT        = "Farbe des Ultimativ-Bereit-Rahmens. Der Alpha-Regler (A) steuert die Helligkeit.",
    SI_AAB_ULT_PULSE           = "Rahmen pulsieren",
    SI_AAB_ULT_PULSE_TT        = "Wenn aktiv, pulsiert der Rahmen sanft, um die Aufmerksamkeit zu erregen. " ..
                                        "Wenn aus, bleibt er bei konstanter Helligkeit.",
    SI_AAB_ULT_PULSE_MODE      = "Rahmen-Animation",
    SI_AAB_ULT_PULSE_MODE_TT   = "Sanft: weiches Ein- und Ausblenden.\n" ..
                                        "Blinken: klar sichtbares hartes An/Aus.",
    SI_AAB_ULT_BLINK_INT       = "Blink-Intervall (ms)",
    SI_AAB_ULT_BLINK_INT_TT    = "Zeit zwischen An und Aus im Blink-Modus. Niedriger = schnelleres Blinken. " ..
                                        "Gilt nur, wenn die Rahmen-Animation auf Blinken steht.",
    SI_AAB_ULT_COLOR_CYCLE     = "Farbwechsel",
    SI_AAB_ULT_COLOR_CYCLE_TT  = "Wechselt den Ulti-Rahmen zwischen der primären Farbe und der Sekundärfarbe " ..
                                        "unten, statt nur an/aus zu schalten. Gilt nur im Blink-Modus.",
    SI_AAB_ULT_COLOR_SECOND    = "Sekundärfarbe",
    SI_AAB_ULT_COLOR_SECOND_TT = "Zweite Farbe für den Ulti-Rahmen, wenn Farbwechsel aktiv ist.",
    SI_AAB_ULT_PADDING         = "Rahmen-Abstand (px)",
    SI_AAB_ULT_PADDING_TT      = "Zusätzliche Pixel, die der Rahmen über die Symbolränder hinaus reicht. " ..
                                        "Höher = größerer Lichthof.",

    SI_AAB_ULT_PULSE_DUR       = "Pulse-Dauer (ms)",
    SI_AAB_ULT_PULSE_DUR_TT    = "Länge eines Ein-/Ausblend-Zyklus. Niedriger = schnelleres Pulsieren.",
    SI_AAB_ULT_PULSE_MIN       = "Pulse: Min-Sichtbarkeit (Alpha)",
    SI_AAB_ULT_PULSE_MIN_TT    = "Niedrigster Sichtbarkeitswert, auf den das Pulsieren abdunkelt. " ..
                                        "Niedriger = stärkerer Pulse-Kontrast.",
    SI_AAB_ULT_INTENSITY       = "Glow-Stärke",
    SI_AAB_ULT_INTENSITY_TT    = "Helligkeits-Multiplikator des Glows. 1.00 = Standard, höher = heller/intensiver.",

    SI_AAB_SUB_FRAME           = "Rahmen-Darstellung",
    SI_AAB_SUB_FRAME_TT        = "Steuert den Rahmen um jedes Fähigkeitssymbol.",
    SI_AAB_THIN_FRAME          = "Dünnen Custom-Rahmen verwenden",
    SI_AAB_THIN_FRAME_TT       = "Ersetzt den Standard-64px-Fähigkeitsrahmen durch einen dünnen Custom-Rahmen " ..
                                        "(gezeichnet aus CustomEdge.dds und CustomCenter.dds). Glow-Effekte werden darüber gezeichnet. " ..
                                        "Ein UI-Neuladen ist erforderlich, damit Änderungen vollständig greifen.",
    SI_AAB_FRAME_ALPHA         = "Rahmen-Deckkraft",
    SI_AAB_FRAME_ALPHA_TT      = "0 = Rahmen komplett unsichtbar (cleanes Aussehen, nur Glow). " ..
                                        "1 = volle Deckkraft. Niedrigere Werte machen den Rahmen dünner/blasser.",
    SI_AAB_EDGE_STYLE          = "Rahmen-Stil",
    SI_AAB_EDGE_STYLE_TT       = "Wählt die Textur für den Custom-Rahmen. " ..
                                        "Klassisch = bisheriger Rahmen, EldenRingUI = passend zum EldenRingUI-Addon.",
    SI_AAB_EDGE_CLASSIC        = "Klassisch",
    SI_AAB_EDGE_V2             = "EldenRingUI",
    SI_AAB_EDGE_PURPLE         = "Lila Rahmen",
    SI_AAB_EDGE_RED            = "Rote Rahmen",
    SI_AAB_EDGE_BLUE           = "Blaue Rahmen",
    SI_AAB_EDGE_AQUA           = "Türkise Rahmen",
    SI_AAB_EDGE_DARKRED        = "Dunkelrote Rahmen",
    SI_AAB_EDGE_DARKPURPLE     = "Dunkellila Rahmen",
    SI_AAB_RELOAD_NOTE         = "Ein UI-Neuladen (/reloadui) ist erforderlich, damit diese Änderung vollständig wirkt.",
    SI_AAB_FRAME_THEME_NOTE    = "|cAAAAAAUI-Creator, die ein eigenes Theme möchten, kontaktiert bitte |r|cFFFFFFhaze.3169|r|cAAAAAA auf Discord. Ideen für weitere Themes? Meldet euch ebenfalls dort!|r",
    SI_AAB_RELOAD_UI           = "UI neu laden",
    SI_AAB_RELOAD_UI_TT        = "Lädt die Oberfläche neu, um Rahmen-Änderungen vollständig zu übernehmen.",

    SI_AAB_DBG_ON              = "an",
    SI_AAB_DBG_OFF             = "aus",
    SI_AAB_DBG_FRAME           = "Rahmen",
    SI_AAB_DBG_THINFRAME       = "dünner rahmen",
    SI_AAB_DBG_STYLE           = "stil",
    SI_AAB_DBG_TEMPLATE        = "template",
    SI_AAB_DBG_ALPHA           = "deckkraft",
    SI_AAB_DBG_BOUNCE          = "Bounce",
    SI_AAB_DBG_ACTIVE          = "aktiv",
    SI_AAB_DBG_ONPROC          = "auf proc",
    SI_AAB_DBG_ULTI            = "ulti",
    SI_AAB_DBG_GLOWPULSE       = "Glow / Pulse",
    SI_AAB_DBG_GLOW            = "glow",
    SI_AAB_DBG_PULSE           = "pulse",
    SI_AAB_DBG_PULSEMODE       = "pulse-modus",
    SI_AAB_DBG_COLORCYCLE      = "farbcycle",
    SI_AAB_DBG_VANILLAPROC     = "vanilla proc-glow",
    SI_AAB_DBG_ULTFRAME        = "Ulti-Rahmen",
    SI_AAB_DBG_READY           = "bereit",
    SI_AAB_DBG_MODE            = "modus",
    SI_AAB_DBG_VANILLASHIMMER  = "vanilla schimmern",
    SI_AAB_DBG_SERVER          = "Server",

    SI_AAB_EXPIRE_DESC         = "Spielt eine Animation auf dem Fähigkeiten-Symbol ab, wenn der Effekt einer geslotteten Fähigkeit ausläuft (z.B. ein Buff oder DoT).",
    SI_AAB_EXPIRE_ENABLE       = "Animation beim Auslaufen",
    SI_AAB_EXPIRE_ENABLE_TT    = "Spielt eine Animation ab, wenn der Effekt einer geslotteten Fähigkeit ausläuft - so weißt du, wann neu gecastet werden muss.",
    SI_AAB_EXPIRE_STYLE        = "Auslauf-Animationsstil",
    SI_AAB_EXPIRE_STYLE_TT     = "Welche Animation beim Auslaufen eines Effekts abgespielt wird. Wähle 'Wie Druck-Animation', um den Stil von oben zu übernehmen.",
    SI_AAB_EXPIRE_STYLE_INHERIT = "Wie Druck-Animation",
    SI_AAB_EXPIRE_STRENGTH       = "Auslauf-Animationsstärke",
    SI_AAB_EXPIRE_STRENGTH_TT    = "Multiplikator für die Stärke der Auslauf-Animation. 1.00 = wie die Druck-Animation, 2.00 = doppelte Bewegung.",
    SI_AAB_EXPIRE_GLOW_ENABLE    = "Auslauf-Glow",
    SI_AAB_EXPIRE_GLOW_ENABLE_TT = "Zusätzlich einen farbigen Glow auf dem Symbol aufblitzen lassen, wenn der Effekt ausläuft.",
    SI_AAB_EXPIRE_GLOW_COLOR     = "Auslauf-Glow-Farbe",
    SI_AAB_EXPIRE_GLOW_COLOR_TT  = "Farbe des Glows beim Auslaufen eines Effekts - am besten deutlich anders als der Druck-Glow.",
    SI_AAB_DBG_EXPIRE          = "beim auslaufen",
    SI_AAB_DBG_EXPIRE_HEAD     = "Expire-Check (aktive Leiste)",
    SI_AAB_DBG_DURATION        = "dauer",
    SI_AAB_DBG_TRACKING        = "läuft",

    SI_AAB_PULSE_STYLE_RAINBOW = "Smooth-Rainbow",
    SI_AAB_ULT_RAINBOW_SAT     = "Rainbow-Sättigung",
    SI_AAB_ULT_RAINBOW_SAT_TT  = "Sättigung der Regenbogenfarben. 0 = Graustufen, 1 = volle Farbe.",
    SI_AAB_ULT_RAINBOW_LIGHT   = "Rainbow-Helligkeit",
    SI_AAB_ULT_RAINBOW_LIGHT_TT= "Helligkeit der Regenbogenfarben. 0 = schwarz, 0.5 = volle Helligkeit, 1 = weiß.",
    SI_AAB_DBG_RAINBOW_SAT     = "rainbow sättigung",
    SI_AAB_DBG_RAINBOW_LIGHT   = "rainbow hell",
    SI_AAB_CONF_HEAD           = "Konflikt-Check",
    SI_AAB_CONF_FOUND          = "Andere Action-Bar-Addons aktiv:",
    SI_AAB_CONF_HINT           = "Bei doppelten Rahmen/Glows eines davon testweise deaktivieren.",
    SI_AAB_CONF_NONE           = "Keine bekannten konkurrierenden Action-Bar-Addons gefunden.",
    SI_AAB_CONF_HOOKS          = "Eigene Hooks",
    SI_AAB_CONF_OK             = "ok",
    SI_AAB_CONF_MISSING        = "fehlt",
    SI_AAB_CONF_OVERRIDDEN     = "fehlt (überschrieben?)",
    SI_AAB_CONF_ULTFRAME       = "Ulti-Vanilla-Rahmen",
    SI_AAB_CONF_VISIBLE        = "sichtbar (Fremd-Addon?)",
    SI_AAB_CONF_SUPPRESSED     = "unterdrückt",
    SI_AAB_DBG_PROGRESS        = "fortschritt",
    SI_AAB_DBG_BORDER          = "border",
    SI_AAB_DBG_VISIBLE         = "sichtbar",
    SI_AAB_DBG_TEXTURE         = "textur",
    SI_AAB_DBG_THICKNESS       = "dicke",
    SI_AAB_DBG_PADDING         = "abstand",
    SI_AAB_DBG_COLORSHIFT      = "farbverlauf",
    SI_AAB_DBG_FULLGLOW        = "voll-glow",
    SI_AAB_DBG_GLOWSTYLE       = "glow-stil",
    SI_AAB_DBG_RAINBOW         = "regenbogen",

    -- dauer-gekoppelte end-animation
    SI_AAB_EXPIRE_SCALE_DESC       = "Koppelt die Länge der Ablauf-Animation an die Wirkdauer des Skills. Kurze Buffs blitzen schnell auf, lange laufen etwas gedehnter aus.",
    SI_AAB_EXPIRE_SCALE_ENABLE     = "An Dauer koppeln",
    SI_AAB_EXPIRE_SCALE_ENABLE_TT  = "Wenn aktiv, wird die Ablauf-Animation je nach Wirkdauer des geslotteten Skills gestreckt oder gestaucht.",
    SI_AAB_EXPIRE_SCALE_REF        = "Referenzdauer (ms)",
    SI_AAB_EXPIRE_SCALE_REF_TT     = "Die Dauer, bei der die Animation in Normalgeschwindigkeit läuft. Längere Skills laufen langsamer, kürzere schneller ab.",
    SI_AAB_EXPIRE_SCALE_MIN        = "Min. Zeitfaktor",
    SI_AAB_EXPIRE_SCALE_MIN_TT     = "Untergrenze des Zeitfaktors, damit sehr kurze Skills nicht zu schnell zum Sehen aufblitzen.",
    SI_AAB_EXPIRE_SCALE_MAX        = "Max. Zeitfaktor",
    SI_AAB_EXPIRE_SCALE_MAX_TT     = "Obergrenze des Zeitfaktors, damit sehr lange Skills sich nicht ewig hinziehen.",
    SI_AAB_EXPIRE_OVERRIDE_CLEAR   = "Alle Overrides löschen",
    SI_AAB_EXPIRE_OVERRIDE_CLEAR_TT= "Entfernt jeden per /aab setend gesetzten Feuer-Zeitpunkt.",
    SI_AAB_EXPIRE_OVERRIDE_NOTE    = "Feuer-Zeitpunkt pro Skill im Chat setzen: /aab id listet die geslotteten Ability-IDs, dann /aab setend <id> <ms|auto> - die End-Animation feuert dann so viele ms nach dem Cast.",

    -- befehls-übersicht
    SI_AAB_CMD_HEAD    = "Befehle",
    SI_AAB_CMD_PANEL   = "Einstellungsfenster öffnen",
    SI_AAB_CMD_INFO    = "direkt den Info-Tab öffnen",

    SI_AAB_CMD_ID      = "geslottete Ability-IDs im Chat anzeigen",
    SI_AAB_CMD_SETEND  = "festlegen, wann die End-Animation eines Skills feuert (ms nach Cast)",
    SI_AAB_CMD_DEBUG   = "kompletten Status-Dump ausgeben",
    SI_AAB_ID_HINT     = "Feuer-Zeitpunkt setzen mit: /aab setend <id> <ms|auto>  (ms nach Cast)",
    SI_AAB_SETEND_BADID  = "Ungültige Ability-ID. /aab id listet sie auf.",
    SI_AAB_SETEND_BADVAL = "Ungültiger Wert. Nutze Millisekunden oder 'auto'.",
    SI_AAB_SETEND_SET    = "End-Animation für %s (id %d) feuert jetzt %dms nach dem Cast.",
    SI_AAB_SETEND_CLEARED= "Feuer-Override für id %d gelöscht (zurück auf die Skill-Dauer).",

    -- hilfe-/diagnosefenster

    SI_AAB_CMD_LIST           = "diese Befehlsliste anzeigen",

    SI_AAB_TRACE_ON           = "Ablauf-Trace AN - schedule/resync/fire werden geloggt.",
    SI_AAB_TRACE_OFF          = "Ablauf-Trace AUS.",

    SI_AAB_SUB_PERF             = "Performance",
    SI_AAB_SUB_PERF_TT          = "Optionale Optimierungen. Alle standardmäßig AUS - nur bei Bedarf zuschalten.",
    SI_AAB_PERF_DESC            = "Diese Optionen ändern WIE effizient das Addon intern arbeitet, nicht was es anzeigt. Die meisten merken keinen Unterschied; aktiviere sie, wenn du in großen Kämpfen (Trials, Cyrodiil) noch fps rausholen willst.",
    SI_AAB_PERF_EFFECTID        = "Effekt-Events nach Ability-ID filtern",
    SI_AAB_PERF_EFFECTID_TT     = "Statt auf jeden Buff/Debuff auf dir zu reagieren, nur auf deine geslotteten Skills hören. Größte Ersparnis in vollen Kämpfen. Greift sofort.",
    SI_AAB_PERF_SLOTMAP         = "Schneller Slot-Lookup",
    SI_AAB_PERF_SLOTMAP_TT      = "Vorgebaute Lookup-Tabelle statt bei jedem Effekt-Event alle Slots zu durchsuchen. O(1) statt Schleife.",
    SI_AAB_PERF_COMBAT          = "Nur im Kampf animieren",
    SI_AAB_PERF_COMBAT_TT       = "Alle Animationen außerhalb des Kampfes aussetzen. Spart Arbeit in Städten/Hubs. Kommt bei Kampfbeginn sofort zurück.",
    SI_AAB_PERF_RAINBOW         = "Sparsame Rainbow-Updates",
    SI_AAB_PERF_RAINBOW_TT      = "Den smooth-rainbow Ulti-Rahmen ~30x/Sek statt 200x aktualisieren. Sieht identisch aus, ~85% weniger Updates.",
    SI_AAB_PERF_STYLEHOOK       = "Einzelner Style-Hook",
    SI_AAB_PERF_STYLEHOOK_TT    = "Zwei Ability-Style-Hooks zu einem zusammenfassen, wenn der schlanke Rahmen an ist. Braucht Reload.",
    SI_AAB_PERF_TLCACHE         = "Animations-Cache begrenzen",
    SI_AAB_PERF_TLCACHE_TT      = "Gecachte Animations-Timelines pro Button begrenzen, hält den Speicher bei langen Sessions mit Dauer-Skalierung niedrig.",
    SI_AAB_PERF_NOTE            = "Keine dieser Optionen ändert das Aussehen. Falls sich etwas seltsam verhält, die passende Option wieder ausschalten.",

    SI_AAB_SUB_PRESETS          = "Presets",
    SI_AAB_SUB_PRESETS_TT       = "Schnell zwischen voreingestellten Looks wechseln.",
    SI_AAB_PRESETS_DESC         = "Ein Klick setzt mehrere Effekt-Optionen auf einmal. Nur der Look ändert sich - deine Farben und Performance-Optionen bleiben wie sie sind.",
    SI_AAB_PRESET_MINIMAL       = "Minimal",
    SI_AAB_PRESET_MINIMAL_TT    = "Nur der Bounce beim Casten. Glow, Pulse, Expire und Bar-Swap aus. Leichtester Look.",
    SI_AAB_PRESET_STANDARD      = "Standard",
    SI_AAB_PRESET_STANDARD_TT   = "Bounce, Glow, Pulse und Expire an. Der ausgewogene Standard-Look.",
    SI_AAB_PRESET_FLASHY        = "Flashy",
    SI_AAB_PRESET_FLASHY_TT     = "Alles an, plus Bar-Swap-Flash und Farbwechsel. Maximaler Effekt.",
    SI_AAB_PRESETS_NOTE         = "Presets sind ein Startpunkt - alles Weitere feinst du danach in den Untermenüs unten ab.",


    SI_AAB_SUB_CONTACT            = "Ersteller kontaktieren",
    SI_AAB_SUB_CONTACT_TT         = "Unterstütze den Ersteller mit einer Ingame-Spende.",
    SI_AAB_CONTACT_DESC           = "Gefällt dir das Addon? Ingame-Spenden sind sehr willkommen - Tränke, Gold und Handwerks-Ressourcen helfen alle! Klick unten, um eine Mail an @haze068 zu öffnen.",
    SI_AAB_CONTACT_DONATE_BTN     = "Per Ingame-Mail spenden",
    SI_AAB_CONTACT_DONATE_BTN_TT  = "Öffnet das Ingame-Mailfenster mit vorausgefülltem Empfänger und Titel.",

    SI_AAB_SUB_INFO               = "Info",
    SI_AAB_SUB_INFO_TT            = "Kompatibilitäts-Hinweise zur Nutzung von AnimatedActionBar+ zusammen mit anderen Addons.",
    SI_AAB_INFO_THINFRAMES        = "Wenn du die Option \"Frame Appearance: Thin Frames\" aus diesem Addon nutzt, deaktiviere bitte in FancyActionBar+ unter UI Customization -> Custom Frames Keyboard folgendes:\n\n" ..
                                        "  - \"Hide Default Frames\"\n" ..
                                        "  - \"Use Thin Frames\"\n\n" ..
                                        "Zeichnen beide Addons gleichzeitig schlanke Rahmen, kommt es zu doppelten oder versetzten Rahmen.",
    SI_AAB_INFO_GAMEPAD           = "Spielst du mit Controller?\n\n" ..
                                        "Wenn deine Fähigkeiten verschoben, versetzt oder anderweitig falsch dargestellt werden, deaktiviere bitte in FancyActionBar+ den \"Gamepad Mode\".\n\n" ..
                                        "Controller-Spieler sollten außerdem \"Use Thin Frame\" sowohl in FancyActionBar+ als auch in AnimatedActionBar+ deaktivieren, um das beste Ergebnis zu erhalten.\n\n" ..
                                        "Sollte das Problem danach immer noch bestehen, kontaktiere mich bitte über Discord (haze.3169), damit wir das gemeinsam beheben können.",

    SI_AAB_DLG_TITLE              = "AnimatedActionBar+",
    SI_AAB_DLG_BODY               = "Danke fürs Installieren von AnimatedActionBar+!\n\n" ..
                                        "Nutzt du den Rahmen-Stil \"Thin Frames\" zusammen mit FancyActionBar+? Dann lies bitte den Kompatibilitäts-Hinweis.\n\n" ..
                                        "Spielst du mit Controller? Dann schau bitte ebenfalls in den \"Info\"-Tab.\n\n" ..
                                        "Öffne die Einstellungen und schau dir dafür den \"Info\"-Tab an. Gib /aabcmds im Chat ein für eine Liste aller Befehle.",
    SI_AAB_DLG_OK                 = "Verstanden",
}

for stringId, stringValue in pairs(strings) do
    ZO_CreateStringId(stringId, stringValue)
    SafeAddVersion(stringId, 2)
end
