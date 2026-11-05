-- =========================================================
-- MugShot - Localisation  (Localisation.lua)
-- Multi-language dictionary for French (fr) and English (en).
-- Automatically selects language via GetCVar("language.2").
-- =========================================================

local MugShot = MugShot

local strings = {
    en = {
        ENABLED                 = "|c9b00afMugShot|r enabled.",
        DISABLED                = "|c9b00afMugShot|r disabled.",
        DISABLED_HELP           = "MugShot is disabled in settings; use /mugshot toggle to enable",
        FRAME_LOCKED            = "|c9b00afMugShot|r: frame locked. Position saved.",
        FRAME_UNLOCKED          = "|c9b00afMugShot|r: frame unlocked (repositioning mode). Mouse cursor active. Drag the frame, then retype |c00ffcc/mugshot move|r to lock.",
        DEBUG_SHOWN             = "|c9b00afMugShot|r DEBUG: frame shown — position offsetX=%s offsetY=%s",
        DEBUG_HIDDEN            = "|c9b00afMugShot|r DEBUG: debug mode disabled.",
        POSITION_RESET          = "|c9b00afMugShot|r: position reset to TOPLEFT (100, 200) and frame unlocked.",
        STATUS_HEADER           = "|c9b00af[MugShot Status]|r",
        STATUS_ENABLED_LOCKED   = "  Enabled: %s | Locked: %s",
        STATUS_FRAME_POS        = "  Frame: IsHidden=%s | Pos: (offX=%s, offY=%s)",
        STATUS_TARGET           = "  Target 'reticleover': %s (name: %s)",
        STATUS_TARGET_NONE      = "none",
        STATUS_NATIVE_HOOKED    = "  Native frame hooked: %s",
        DRAG_ME_TITLE           = "[MugShot] Drag me!",
        UNKNOWN                 = "Unknown",
        MOCK_ENEMY_NAME         = "Target Iron Atronach, Trial",
        PREVIEW_ENEMY_BTN       = "[Preview: ENEMY (Click for Player)]",
        PREVIEW_PLAYER_BTN      = "[Preview: PLAYER (Click for Enemy)]",
        HODOR_ICONS_ENABLED     = "|c9b00afMugShot|r: HodorReflexes / LibCustomIcons & Names enabled.",
        HODOR_ICONS_DISABLED    = "|c9b00afMugShot|r: Custom portraits & names disabled (showing class icon).",
        TRIAL_FILTER_ENABLED    = "|c9b00afMugShot|r: Trial filter |c00ff00enabled|r (enemies only in Trials).",
        TRIAL_FILTER_DISABLED   = "|c9b00afMugShot|r: Trial filter |cff5555disabled|r (all targets shown in Trials).",
        GROUP_DEBUFFS_ENABLED   = "|c9b00afMugShot|r: Group & Companion major debuffs tracking |c00ff00enabled|r.",
        GROUP_DEBUFFS_DISABLED  = "|c9b00afMugShot|r: Group & Companion major debuffs tracking |cff5555disabled|r.",
        LAYOUT_CLASSIC          = "|c9b00afMugShot|r: Layout set to |c00ffccClassic|r (clean 2-line target style, no Line 3).",
        LAYOUT_COMPACT          = "|c9b00afMugShot|r: Layout set to |c00ffccCompact|r (3 lines with Line 3 privileged debuffs).",
        CMD_HELP_TITLE          = "|c9b00af[MugShot]|r Commands:",
        CMD_HELP_TOGGLE         = "  • |cffffff/mugshot toggle|r [on|off] : Enable / disable MugShot",
        CMD_HELP_MOVE           = "  • |cffffff/mugshot move|r : Toggle frame repositioning mode",
        CMD_HELP_RESET          = "  • |cffffff/mugshot reset|r : Reset position to default (centered top, 0, 88)",
        CMD_HELP_LAYOUT         = "  • |cffffff/mugshot layout|r [classic|compact] : Switch frame layout (classic: 2 lines, compact: 3 lines)",
        CMD_HELP_CLASSIC        = "  • |cffffff/mugshot classic|r [on|off] : Toggle classic 2-line layout without Line 3",
        CMD_HELP_TRIAL          = "  • |cffffff/mugshot trial|r [on|off] : Filter enemies only in Trials",
        CMD_HELP_DEBUFFS        = "  • |cffffff/mugshot debuffs|r [on|off] : Track team debuffs in group/companion",
        CMD_HELP_HODOR          = "  • |cffffff/mugshot hodor|r : Toggle custom Hodor avatars",
        CMD_HELP_HELP           = "  • |cffffff/mugshot help|r : Show this help message",
        CMD_UNKNOWN             = "|c9b00afMugShot|r: Unknown subcommand '%s'. Type |cffffff/mugshot help|r.",
    },
    fr = {
        ENABLED                 = "|c9b00afMugShot|r activé.",
        DISABLED                = "|c9b00afMugShot|r désactivé.",
        DISABLED_HELP           = "MugShot est désactivé dans les paramètres ; tapez /mugshot toggle pour l'activer",
        FRAME_LOCKED            = "|c9b00afMugShot|r : cadre verrouillé. Position enregistrée.",
        FRAME_UNLOCKED          = "|c9b00afMugShot|r : cadre déverrouillé (mode déplacement). Curseur de souris activé. Déplacez le cadre puis retapez |c00ffcc/mugshot move|r pour verrouiller.",
        DEBUG_SHOWN             = "|c9b00afMugShot|r DEBUG: cadre affiché — position offsetX=%s offsetY=%s",
        DEBUG_HIDDEN            = "|c9b00afMugShot|r DEBUG: mode debug désactivé.",
        POSITION_RESET          = "|c9b00afMugShot|r : position réinitialisée à TOPLEFT (100, 200) et cadre déverrouillé.",
        STATUS_HEADER           = "|c9b00af[Statut MugShot]|r",
        STATUS_ENABLED_LOCKED   = "  Actif : %s | Verrouillé : %s",
        STATUS_FRAME_POS        = "  Cadre : IsHidden=%s | Pos : (offX=%s, offY=%s)",
        STATUS_TARGET           = "  Cible 'reticleover' : %s (nom : %s)",
        STATUS_TARGET_NONE      = "aucun",
        STATUS_NATIVE_HOOKED    = "  Cadre natif lié : %s",
        DRAG_ME_TITLE           = "[MugShot] Déplacez-moi !",
        UNKNOWN                 = "Inconnu",
        MOCK_ENEMY_NAME         = "Atronach de fer, épreuve",
        PREVIEW_ENEMY_BTN       = "[Mode Aperçu : ENNEMI (Cliquer pour Joueur)]",
        PREVIEW_PLAYER_BTN      = "[Mode Aperçu : JOUEUR (Cliquer pour Ennemi)]",
        HODOR_ICONS_ENABLED     = "|c9b00afMugShot|r : Portraits et noms personnalisés Hodor / LibCustomNames activés.",
        HODOR_ICONS_DISABLED    = "|c9b00afMugShot|r : Portraits et noms personnalisés désactivés (affichage de la classe).",
        TRIAL_FILTER_ENABLED    = "|c9b00afMugShot|r : Filtre Épreuve |c00ff00activé|r (ennemis uniquement en Raid).",
        TRIAL_FILTER_DISABLED   = "|c9b00afMugShot|r : Filtre Épreuve |cff5555désactivé|r (toutes les cibles affichées en Raid).",
        GROUP_DEBUFFS_ENABLED   = "|c9b00afMugShot|r : Suivi des débuffs majeurs en groupe/compagnon |c00ff00activé|r.",
        GROUP_DEBUFFS_DISABLED  = "|c9b00afMugShot|r : Suivi des débuffs majeurs en groupe/compagnon |cff5555désactivé|r.",
        LAYOUT_CLASSIC          = "|c9b00afMugShot|r : Disposition |c00ffccClassique|r (2 lignes, style épuré sans Ligne 3).",
        LAYOUT_COMPACT          = "|c9b00afMugShot|r : Disposition |c00ffccCompacte|r (3 lignes avec débuffs privilégiés en Ligne 3).",
        CMD_HELP_TITLE          = "|c9b00af[MugShot]|r Commandes :",
        CMD_HELP_TOGGLE         = "  • |cffffff/mugshot toggle|r [on|off] : Activer / désactiver l'addon",
        CMD_HELP_MOVE           = "  • |cffffff/mugshot move|r : Mode déplacement (verrouiller / déverrouiller)",
        CMD_HELP_RESET          = "  • |cffffff/mugshot reset|r : Réinitialiser la position par défaut (haut centré, 0, 88)",
        CMD_HELP_LAYOUT         = "  • |cffffff/mugshot layout|r [classic|compact] : Changer la disposition (classic: 2 lignes, compact: 3 lignes)",
        CMD_HELP_CLASSIC        = "  • |cffffff/mugshot classic|r [on|off] : Activer le mode classique 2 lignes sans Ligne 3",
        CMD_HELP_TRIAL          = "  • |cffffff/mugshot trial|r [on|off] : Filtre ennemis en Épreuve",
        CMD_HELP_DEBUFFS        = "  • |cffffff/mugshot debuffs|r [on|off] : Débuffs d'équipe en groupe/compagnon",
        CMD_HELP_HODOR          = "  • |cffffff/mugshot hodor|r : Portraits personnalisés Hodor",
        CMD_HELP_HELP           = "  • |cffffff/mugshot help|r : Afficher ce message d'aide",
        CMD_UNKNOWN             = "|c9b00afMugShot|r : Sous-commande inconnue '%s'. Tapez |cffffff/mugshot help|r.",
    },
}

-- Detect client language
function MugShot.InitLanguage()
    local lang = "en"
    local cvarLang = (GetCVar and (GetCVar("Language.2") or GetCVar("language.2")))
    if cvarLang then
        cvarLang = string.lower(cvarLang)
        if strings[cvarLang] then
            lang = cvarLang
        end
    end

    MugShot.currentLang = lang
    MugShot.strings = strings
    MugShot.L = strings[lang] or strings.en
    return lang
end

local lang = MugShot.InitLanguage()

-- Helper to retrieve text, format with args, and fall back to en / key
function MugShot.GetText(key, ...)
    local dict = MugShot.L
    local str = dict and dict[key]
    if not str then
        str = strings.en and strings.en[key]
    end
    if not str then
        return key or ""
    end
    if select("#", ...) > 0 then
        return string.format(str, ...)
    end
    return str
end

MugShot.logger:Info("=== Localisation loaded (language: %s) ===", lang)
