TeamShadowsManager = TeamShadowsManager or {}

local PBT = TeamShadowsManager

PBT.Strings = {
    tab_markers = { fr = "MARKERS", en = "MARKERS" },
    tab_countdown = { fr = "DÉCOMPTE & ANNONCE", en = "COUNTDOWN & ALERT" },
    tab_timers = { fr = "TIMERS", en = "TIMERS" },
    panel_active_marker = { fr = "MARKER ACTIF", en = "ACTIVE MARKER" },
    panel_icons = { fr = "ICÔNES", en = "ICONS" },
    panel_saved_markers = { fr = "MARKERS ENREGISTRÉS", en = "SAVED MARKERS" },
    panel_packs_share = { fr = "PACKS & PARTAGE", en = "PACKS & SHARING" },
    panel_packs_share_zone = { fr = "PACKS & PARTAGE — %s", en = "PACKS & SHARING — %s" },
    panel_group_countdown = { fr = "DÉCOMPTE GROUPE", en = "GROUP COUNTDOWN" },
    panel_visual_alert = { fr = "ANNONCE VISUELLE", en = "VISUAL ALERT" },
    panel_boss_timers = { fr = "TIMERS BOSS", en = "BOSS TIMERS" },
    panel_target_dummy = { fr = "MANNEQUIN D'ENTRAÎNEMENT", en = "TARGET DUMMY" },
    panel_dummy = { fr = "MANNEQUIN", en = "TARGET DUMMY" },
    countdown_enabled = { fr = "Décompte activé", en = "Countdown enabled" },
    broadcast_group = { fr = "Diffuser au groupe", en = "Broadcast to group" },
    countdown_duration = { fr = "Durée du décompte", en = "Countdown duration" },
    local_delay = { fr = "Mon délai (local)", en = "My delay (local)" },
    unlock_move = { fr = "Déverrouiller (déplacer)", en = "Unlock (move)" },
    field_text_role = { fr = "Texte / rôle", en = "Text / role" },
    field_color = { fr = "Couleur", en = "Color" },
    field_size = { fr = "Taille", en = "Size" },
    field_duration = { fr = "Durée", en = "Duration" },
    field_height = { fr = "Hauteur", en = "Height" },
    placement_enabled = { fr = "Placement activé", en = "Placement enabled" },
    button_place = { fr = "PLACER (visée réticule)", en = "PLACE (reticle aim)" },
    button_clear_screen = { fr = "VIDER L'ÉCRAN", en = "CLEAR SCREEN" },
    button_edit = { fr = "MODIFIER", en = "EDIT" },
    button_finish_edit = { fr = "FIN MODIF", en = "FINISH EDIT" },
    button_delete = { fr = "SUPPRIMER", en = "DELETE" },
    button_export = { fr = "EXPORTER", en = "EXPORT" },
    button_import = { fr = "IMPORTER", en = "IMPORT" },
    button_save_pack = { fr = "SAUVER PACK", en = "SAVE PACK" },
    button_delete_pack = { fr = "SUPPR. PACK", en = "DELETE PACK" },
    button_confirm = { fr = "CONFIRMER ?", en = "CONFIRM?" },
    button_send_group = { fr = "ENVOYER AU GROUPE", en = "SEND TO GROUP" },
    dialog_received = { fr = "CONFIGURATION RECUE", en = "CONFIGURATION RECEIVED" },
    button_accept_save = { fr = "ACCEPTER ET ENREGISTRER", en = "ACCEPT AND SAVE" },
    button_accept_session = { fr = "JUSQU'A DECONNEXION", en = "UNTIL LOGOUT" },
    button_refuse = { fr = "REFUSER", en = "DECLINE" },
    button_show_icon = { fr = "VOIR ICÔNE", en = "SHOW ICON" },
    button_hide_icon = { fr = "MASQUER ICÔNE", en = "HIDE ICON" },
    button_accept_present = { fr = "ACCEPTER (DEJA PRESENT)", en = "ACCEPT (ALREADY SAVED)" },
    button_accept_replace = { fr = "ACCEPTER ET REMPLACER", en = "ACCEPT AND REPLACE" },
    button_start_countdown = { fr = "LANCER LE DÉCOMPTE", en = "START COUNTDOWN" },
    countdown_help = { fr = "Le décompte est commun au groupe. \"Mon délai\" ne change que ton écran.", en = "The countdown is shared with the group. \"My delay\" only changes your display." },
    countdown_color = { fr = "Couleur décompte", en = "Countdown color" },
    go_color = { fr = "Couleur GO", en = "GO color" },
    sounds = { fr = "Sons", en = "Sounds" },
    alert_scale = { fr = "Échelle de l'annonce", en = "Alert scale" },
    screen_logo = { fr = "Logo à l'écran", en = "On-screen logo" },
    logo_size = { fr = "Taille du logo", en = "Logo size" },
    automatic_boss_timers = { fr = "Timers boss automatiques", en = "Automatic boss timers" },
    instance_boss_timers = { fr = "Timers de cette instance", en = "Timers for this instance" },
    included_bosses = { fr = "Boss pris en compte", en = "Included bosses" },
    no_automatic_boss = { fr = "Aucun boss automatique configuré ici.", en = "No automatic boss is configured here." },
    bahsei_menu_instruction = { fr = "Bahsei HM : utilisez /tsm bahsei pour appeler les renforts du portail.", en = "Bahsei HM: use /tsm bahsei to call portal reinforcements." },
    unknown_instance = { fr = "Instance non reconnue", en = "Unknown instance" },
    open_eso_settings = { fr = "OUVRIR LES RÉGLAGES ESO (détails)", en = "OPEN ESO SETTINGS (details)" },
    dummy_timer_duration = { fr = "Durée du timer mannequin", en = "Target dummy timer duration" },
    dummy_auto_timer = { fr = "Auto-timer après reset mannequin", en = "Auto timer after target dummy reset" },
    default_values = { fr = "Valeurs par défaut", en = "Default values" },
    edit_number = { fr = "MODIF #%d", en = "EDIT #%d" },
    edit_prefix = { fr = "MODIF ", en = "EDIT " },
    text_value = { fr = "Texte : %s", en = "Text: %s" },
    included = { fr = "Pris en compte : %s", en = "Included: %s" },
    no_boss_timer = { fr = "Aucun timer boss appelé ici.", en = "No boss timer is used here." },
    marker_count = { fr = "%d marker%s — page %d/%d", en = "%d marker%s — page %d/%d" },
    sent_by = { fr = "Envoye par : %s", en = "Sent by: %s" },
    destination = { fr = "Destination : %s / emplacement %d", en = "Destination: %s / slot %d" },
    share_type = { fr = "Configuration", en = "Configuration" },
    pack = { fr = "Pack", en = "Pack" },
    marker_pack = { fr = "Pack de markers", en = "Marker pack" },
    already_saved_warning = { fr = "Ce pack est deja enregistre : aucune copie supplementaire ne sera creee.", en = "This pack is already saved: no additional copy will be created." },
    replacement_warning = { fr = "ATTENTION : les trois emplacements sont occupes. L'emplacement 1 sera remplace uniquement apres confirmation.", en = "WARNING: all three slots are occupied. Slot 1 will only be replaced after confirmation." },
    waiting_choice = { fr = "Aucune donnee ne sera importee avant ton choix.", en = "No data will be imported before you choose." },
    settings_generic = { fr = "Reglages generiques", en = "General settings" },
    addon_enabled = { fr = "Addon active", en = "Addon enabled" },
    window_unlocked = { fr = "Fenetre deverrouillee", en = "Window unlocked" },
    menu_logo_button = { fr = "Bouton menu logo", en = "Logo menu button" },
    menu_logo_tooltip = { fr = "Affiche ton logo à l'écran. Clic gauche : ouvre la fenêtre indépendante Team Shadows Manager.", en = "Displays your logo on screen. Left click opens the standalone Team Shadows Manager window." },
    menu_logo_size = { fr = "Taille bouton logo", en = "Logo button size" },
    menu_logo_size_tooltip = { fr = "Taille du bouton logo visible à l'écran.", en = "Size of the on-screen logo button." },
    countdown_sounds = { fr = "Sons du compte à rebours", en = "Countdown sounds" },
    boss_timers_toggle = { fr = "ON / OFF timers boss", en = "Boss timers ON / OFF" },
    custom_countdown = { fr = "Décompte personnalisé", en = "Custom countdown" },
    custom_countdown_toggle = { fr = "ON / OFF décompte personnalisé", en = "Custom countdown ON / OFF" },
    group_countdown = { fr = "Décompte groupe", en = "Group countdown" },
    my_delay = { fr = "Mon délai", en = "My delay" },
    group_broadcast = { fr = "Diffusion groupe", en = "Group broadcast" },
    broadcast_countdown = { fr = "Diffuser le décompte au groupe", en = "Broadcast countdown to group" },
    receive_markers = { fr = "Recevoir les markers", en = "Receive markers" },
    marker_icon = { fr = "Icone marker", en = "Marker icon" },
    marker_text = { fr = "Texte marker", en = "Marker text" },
    marker_size = { fr = "Taille marker", en = "Marker size" },
    marker_duration = { fr = "Duree marker", en = "Marker duration" },
    place_aimed_marker = { fr = "Placer marker vise", en = "Place aimed marker" },
    visual_alert = { fr = "Annonce visuelle", en = "Visual alert" },
    test_alert = { fr = "Test annonce 3 sec", en = "Test 3-second alert" },
    ui_size = { fr = "Taille UI", en = "UI size" },
    red_intensity = { fr = "Intensite rouge", en = "Red intensity" },
    green_intensity = { fr = "Intensite vert", en = "Green intensity" },
    reset_red = { fr = "Remettre rouge par defaut", en = "Restore default red" },
    target_dummy = { fr = "Mannequin", en = "Target dummy" },
    target_dummy_timer = { fr = "Timer mannequin", en = "Target dummy timer" },
    prebuff_boss_timers = { fr = "Timers prebuff boss", en = "Boss prebuff timers" },
    boss_timers_tooltip = { fr = "Active uniquement les timers automatiques des boss qui apparaissent, reviennent après une invulnérabilité ou ont une narration longue.", en = "Only enables automatic timers for bosses that spawn, return after invulnerability, or have a long narration." },
    custom_countdown_tooltip = { fr = "Active le décompte groupe lancé par raccourci ou depuis le gestionnaire.", en = "Enables the group countdown started by a keybind or from the manager." },
    group_countdown_tooltip = { fr = "Durée envoyée à tout le groupe par le raid lead.", en = "Duration sent to the whole group by the raid leader." },
    my_delay_tooltip = { fr = "Corrige uniquement ton affichage local. -2 affiche ton GO 2 secondes plus tôt. +2 affiche ton GO 2 secondes plus tard.", en = "Only adjusts your local display. -2 shows GO 2 seconds earlier; +2 shows it 2 seconds later." },
    group_countdown_description = { fr = "Le décompte groupe est commun. Mon délai ne modifie que ton écran.", en = "The group countdown is shared. My delay only changes your screen." },
    broadcast_tooltip = { fr = "Envoie le décompte aux joueurs qui utilisent Team Shadows Manager.", en = "Sends the countdown to players using Team Shadows Manager." },
    receive_markers_tooltip = { fr = "Désactivé pour le moment : les markers se partagent par Exporter / Importer pour éviter les pings instables.", en = "Currently disabled: markers are shared through Export / Import to avoid unstable pings." },
    marker_icon_tooltip = { fr = "Texture Team Shadows affichee au sol par le marker.", en = "Team Shadows texture displayed on the ground by the marker." },
    marker_text_tooltip = { fr = "Auto numerote les markers de 1 a 10, ou force un role precis.", en = "Automatically numbers markers from 1 to 10, or forces a specific role." },
    marker_size_tooltip = { fr = "Taille du carre visible dans le monde.", en = "Size of the square visible in the world." },
    marker_duration_tooltip = { fr = "Temps d'affichage du marker.", en = "How long the marker remains visible." },
    aimed_marker_tooltip = { fr = "Vise le sol avec le reticule puis valide pour enregistrer le marker.", en = "Aim at the ground with the reticle, then confirm to save the marker." },
    visual_settings_description = { fr = "Reglages de l'affichage de l'annonce au centre de l'ecran.", en = "Display settings for the alert shown at the center of the screen." },
    alert_test_tooltip = { fr = "Affiche une demo 3, 2, 1, GO avec les couleurs actuelles.", en = "Displays a 3, 2, 1, GO preview using the current colors." },
    preview_pull = { fr = "Apercu: PULL 3 / GO", en = "Preview: PULL 3 / GO" },
    color_intensity_help = { fr = "Regle l'intensite du rouge et du vert du chiffre du timer.", en = "Adjusts the red and green intensity of the timer number." },
    dummy_timer_tooltip = { fr = "Duree du countdown lance apres une sortie de combat contre un mannequin.", en = "Duration of the countdown started after leaving combat with a target dummy." },
    dummy_auto_tooltip = { fr = "Lance le timer mannequin a la sortie de combat si le combat precedent etait contre un mannequin.", en = "Starts the target dummy timer after combat if the previous fight was against a target dummy." },
    dummy_auto_lam = { fr = "Auto timer apres reset mannequin", en = "Auto timer after target dummy reset" },
    portal = { fr = "PORTAIL", en = "PORTAL" },
    place_icon = { fr = "PLACER ICON", en = "PLACE ICON" },
    ready = { fr = "PRET", en = "READY" },
    free_zone_prefix = { fr = "Libre - %s", en = "Free - %s" },
    binding_group_countdown = { fr = "Team Shadows Manager : décompte groupe", en = "Team Shadows Manager: group countdown" },
    binding_open_menu = { fr = "Team Shadows Manager : ouvrir le menu", en = "Team Shadows Manager: open menu" },
    binding_toggle_boss = { fr = "Team Shadows Manager : ON / OFF timer boss", en = "Team Shadows Manager: boss timer ON / OFF" },
    binding_toggle_countdown = { fr = "Team Shadows Manager : ON / OFF décompte", en = "Team Shadows Manager: countdown ON / OFF" },
    binding_place_marker = { fr = "Team Shadows Manager : placer un marker", en = "Team Shadows Manager: place marker" },
    binding_bahsei_call = { fr = "Team Shadows Manager : Bahsei, appeler les renforts portail", en = "Team Shadows Manager: Bahsei, call portal reinforcements" },
    group_share_description = { fr = "Partage volontaire de packs de markers entre les membres du groupe.", en = "Voluntary sharing of marker packs between group members." },
    bahsei_settings = { fr = "Bahsei HM — portail", en = "Bahsei HM — portal" },
    panel_rockgrove_options = { fr = "OPTIONS ROCHEBOSQUE", en = "ROCKGROVE OPTIONS" },
    rockgrove_options_enabled = { fr = "Options du raid activées", en = "Trial options enabled" },
    bahsei_wall_arrows = { fr = "Flèches murales du portail", en = "Portal wall arrows" },
    bahsei_wall_arrows_tooltip = { fr = "Affiche autour de la salle une flèche rouge dans le sens du portail et une flèche verte dans le sens de fuite des DD.", en = "Displays a red arrow around the room in the portal direction and a green arrow in the DD escape direction." },
    bahsei_ghost_call = { fr = "Appel automatique des renforts", en = "Automatic reinforcement call" },
    bahsei_ghost_call_tooltip = { fr = "Le joueur seul dans le portail compte les morts des fantômes et appelle le groupe au seuil choisi.", en = "The solo player in the portal counts ghost deaths and calls the group at the selected threshold." },
    bahsei_ghost_counter_enabled = { fr = "Compteur partagé des fantômes", en = "Shared ghost counter" },
    bahsei_ghost_receive = { fr = "Recevoir le compteur et l'appel", en = "Receive counter and descend call" },
    bahsei_ghost_total = { fr = "Fantômes au départ : 24 (8 × 3 zones)", en = "Starting ghosts: 24 (8 × 3 sections)" },
    bahsei_ghost_threshold = { fr = "Appeler quand il en reste", en = "Call when this many remain" },
    bahsei_ghost_counter = { fr = "FANTÔMES : %d/%d", en = "GHOSTS: %d/%d" },
    bahsei_descend_alert = { fr = "DESCENDEZ AU PORTAIL — %d FANTÔMES\nAppel de %s", en = "DESCEND TO THE PORTAL — %d GHOSTS\nCall from %s" },
    bahsei_call_sent = { fr = "Appel portail envoyé : %d fantômes restants.", en = "Portal call sent: %d ghosts remaining." },
    bahsei_call_failed = { fr = "Appel portail non envoyé", en = "Portal call was not sent" },
    bahsei_not_in_rockgrove = { fr = "Commande disponible uniquement à Rochebosque.", en = "This command is only available in Rockgrove." },
    bahsei_world_drawing_missing = { fr = "Flèches Bahsei indisponibles : Combat Alerts n'est pas actif.", en = "Bahsei arrows unavailable: Combat Alerts is not active." },
    bahsei_preview_shown = { fr = "Aperçu des flèches Bahsei affiché pendant 9 secondes.", en = "Bahsei arrow preview displayed for 9 seconds." },
    boss_timer_details = {
        fr = [[|c55FF55Pris en compte|r
Pas-des-Nuées : Z'Maja après le Royaume des ombres
Salles de la Fabrication : Fabricants chasseurs-tueurs / Factotum du Pinacle / Récupérateur, Réducteur et Réacteur
Asile sanctuaire : Saint Olms le Juste / 4e atterrissage après les sauts
Gueule de Lorkhaj : Zhaj'hassa l'Oublié / Rakkhat
Archive æthérienne : Varlariel
Sollance : Lokkestiiz / Yolnahkriin / Nahviintaas / portail PV de Nahviintaas
Égide de Kyne : Seigneur Falgravn / retour après la mort des 3 adds du sous-sol
Récif des Voiles funestes : Taleria Née-des-marées / annonce d'exécution uniquement
Bord de la folie : Yaseyla l'Exarchanique / phases de PV
Rochebosque : Bahsei HM — /tsm bahsei appelle les renforts du portail
Infinite Archive : timers manuels uniquement, pops aleatoires non forces
Mannequin : reset/sortie combat apres mannequin actif]],
        en = [[|c55FF55Included|r
Cloudrest: Z'Maja pull after Shadow Realm
Halls of Fabrication: Hunter-Killer Fabricants / Pinnacle Factotum / Triplets
Asylum Sanctorium: Saint Olms / 4th landing after jumps
Maw of Lorkhaj: Zhaj'hassa / Rakkhat
Aetherian Archive: Varlariel
Sunspire: Lokkestiiz / Yolnahkriin / Nahviintaas / Nahviintaas portal HP
Kyne's Aegis: Lord Falgravn / return after the 3 basement adds die
Dreadsail Reef: Taleria / execute alert only
Sanity's Edge: Exarchanic Yaseyla / HP phases
Rockgrove: Bahsei HM — /tsm bahsei calls portal reinforcements
Infinite Archive: manual timers only; random spawns are not forced
Target dummy: reset/leaving combat after an active target dummy]],
    },
}

PBT.ZoneNames = {
    free = { fr = "Zone libre / actuelle", en = "Free / current zone" },
    aetherianArchive = { fr = "Archive æthérienne", en = "Aetherian Archive" },
    sanctumOphidia = { fr = "Sanctum Ophidia", en = "Sanctum Ophidia" },
    helRaCitadel = { fr = "Citadelle d'Hel Ra", en = "Hel Ra Citadel" },
    mawOfLorkhaj = { fr = "Gueule de Lorkhaj", en = "Maw of Lorkhaj" },
    hallsOfFabrication = { fr = "Salles de la Fabrication", en = "Halls of Fabrication" },
    asylumSanctorium = { fr = "Asile sanctuaire", en = "Asylum Sanctorium" },
    cloudrest = { fr = "Pas-des-Nuées", en = "Cloudrest" },
    sunspire = { fr = "Sollance", en = "Sunspire" },
    kynesAegis = { fr = "Égide de Kyne", en = "Kyne's Aegis" },
    rockgrove = { fr = "Rochebosque", en = "Rockgrove" },
    dreadsailReef = { fr = "Récif des Voiles funestes", en = "Dreadsail Reef" },
    sanitysEdge = { fr = "Bord de la folie", en = "Sanity's Edge" },
    lucentCitadel = { fr = "Citadelle lucide", en = "Lucent Citadel" },
    osseinCage = { fr = "Cage d'Ossein", en = "Ossein Cage" },
    infiniteArchive = { fr = "Archive infinie", en = "Infinite Archive" },
}

PBT.ZoneCases = {
    cloudrest = { fr = "Pull de Z'Maja après le Royaume des ombres", en = "Z'Maja pull after Shadow Realm" },
    hallsOfFabrication = { fr = "Chasseurs-tueurs, Pinnacle, Triplets", en = "Hunter-Killer, Pinnacle, Triplets" },
    asylumSanctorium = { fr = "4e atterrissage d'Olms", en = "Olms 4th landing" },
    mawOfLorkhaj = { fr = "Zhaj'hassa, Rakkhat", en = "Zhaj'hassa, Rakkhat" },
    aetherianArchive = { fr = "Varlariel", en = "Varlariel" },
    sunspire = { fr = "Lokkestiiz, Yolnahkriin, Nahviintaas", en = "Lokkestiiz, Yolnahkriin, Nahviintaas" },
    kynesAegis = { fr = "Retour de Falgravn depuis le sous-sol", en = "Falgravn return from basement" },
    dreadsailReef = { fr = "Exécution de Taleria", en = "Taleria execute" },
    sanitysEdge = { fr = "PV de Yaseyla", en = "Yaseyla HP" },
    rockgrove = { fr = "Bahsei HM : /tsm bahsei", en = "Bahsei HM: /tsm bahsei" },
    infiniteArchive = { fr = "Timers manuels", en = "Manual timers" },
}

PBT.MarkerTextureLabels = {
    fr = { "Carré rouge", "Carré bleu", "Carré jaune", "Carré vert", "Carré orange", "Carré rose", "Marker bleu clair", "Carré MT", "Carré OT", "Flèche", "Flèche verte", "Shadow", "Bûche", "Fish", "Hyxtra", "Lexi", "Og", "Ogu", "Ray-me", "Ronce", "Selegnar", "Sla-anesh", "Tim" },
    en = { "Red square", "Blue square", "Yellow square", "Green square", "Orange square", "Pink square", "Light blue marker", "MT square", "OT square", "Arrow", "Green arrow", "Shadow", "Log", "Fish", "Hyxtra", "Lexi", "Og", "Ogu", "Ray-me", "Ronce", "Selegnar", "Sla-anesh", "Tim" },
}

local literalKeys = {}
for key, values in pairs(PBT.Strings) do
    if values.fr and literalKeys[values.fr] == nil then literalKeys[values.fr] = key end
    if values.en and literalKeys[values.en] == nil then literalKeys[values.en] = key end
end

function PBT.GetLanguage()
    local language = PBT.savedVars and PBT.savedVars.language or PBT.pendingLanguage or "fr"
    return language == "en" and "en" or "fr"
end

function PBT.GetString(key, ...)
    local entry = PBT.Strings[key]
    if not entry then return tostring(key or "") end
    local value = entry[PBT.GetLanguage()] or entry.fr or tostring(key)
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, value, ...)
        if ok then return formatted end
    end
    return value
end

function PBT.HasLocalizedLiteral(text)
    return type(text) == "string" and literalKeys[text] ~= nil
end

function PBT.LocalizeLiteral(text)
    local key = type(text) == "string" and literalKeys[text] or nil
    return key and PBT.GetString(key) or text
end

function PBT.GetLocalizedZoneName(zoneKey, fallback)
    local entry = PBT.ZoneNames[tostring(zoneKey or "")]
    return entry and (entry[PBT.GetLanguage()] or entry.fr) or fallback or tostring(zoneKey or "")
end

function PBT.GetLocalizedZoneCases(zoneKey, fallback)
    local entry = PBT.ZoneCases[tostring(zoneKey or "")]
    return entry and (entry[PBT.GetLanguage()] or entry.fr) or fallback or ""
end

function PBT.SetLanguage(language)
    language = language == "en" and "en" or "fr"
    PBT.pendingLanguage = language
    if PBT.savedVars then PBT.savedVars.language = language end
    if PBT.UI and PBT.UI.ApplyLanguage then PBT.UI:ApplyLanguage() end
    if PBT.RefreshBindingStrings then PBT.RefreshBindingStrings() end
    if PBT.GroupShare and PBT.GroupShare.RefreshLanguage then PBT.GroupShare:RefreshLanguage() end
    if PBT.markerTextureDropdownOption then
        PBT.markerTextureDropdownOption.choices = PBT.MarkerTextureLabels[language]
    end
    if CALLBACK_MANAGER and CALLBACK_MANAGER.FireCallbacks and PBT.settingsPanel then
        CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", PBT.settingsPanel)
    end
end


function PBT.RefreshBindingStrings()
    if not SafeAddString then return end
    SafeAddString(SI_BINDING_NAME_PBT_GROUP_COUNTDOWN, PBT.GetString("binding_group_countdown"), 2)
    SafeAddString(SI_BINDING_NAME_PBT_OPEN_SETTINGS, PBT.GetString("binding_open_menu"), 2)
    SafeAddString(SI_BINDING_NAME_PBT_TOGGLE_BOSS_TIMERS, PBT.GetString("binding_toggle_boss"), 2)
    SafeAddString(SI_BINDING_NAME_PBT_TOGGLE_GROUP_COUNTDOWN, PBT.GetString("binding_toggle_countdown"), 2)
    SafeAddString(SI_BINDING_NAME_PBT_RENDEZVOUS, PBT.GetString("binding_place_marker"), 2)
    SafeAddString(SI_BINDING_NAME_PBT_BAHSEI_CALL_REINFORCEMENTS, PBT.GetString("binding_bahsei_call"), 2)
end

local chatExact = {
    ["menu indisponible: LibAddonMenu-2.0 n'est pas active."] = "menu unavailable: LibAddonMenu-2.0 is not active.",
    ["timers boss ON."] = "boss timers ON.", ["timers boss OFF."] = "boss timers OFF.",
    ["décompte personnalisé ON."] = "custom countdown ON.", ["décompte personnalisé OFF."] = "custom countdown OFF.",
    ["placement marker OFF."] = "marker placement OFF.", ["position joueur indisponible."] = "player position unavailable.",
    ["marker introuvable."] = "marker not found.", ["aucun marker enregistre."] = "no saved marker.",
    ["partage direct des markers desactive: utilise Exporter / Importer."] = "direct marker sharing is disabled: use Export / Import.",
    ["marker non affiche: LibTeamShadows doit etre actif."] = "marker not displayed: LibTeamShadows must be active.",
    ["code export prepare: copie/colle le code chez les autres joueurs."] = "export code ready: copy and paste it to the other players.",
    ["ouvre l'onglet Import puis clique Exporter pour partager la liste."] = "open the Import tab, then click Export to share the list.",
    ["markers enregistres effaces."] = "saved markers cleared.",
    ["fenetre deverrouillee."] = "window unlocked.", ["fenetre verrouillee."] = "window locked.",
    ["timers actifs: aucune instance reconnue ici."] = "active timers: no recognized instance here.",
    ["timers actifs pour cette instance:"] = "active timers for this instance:",
    ["utilisation: /pbtscale 1.0  (min 0.5, max 2.5)"] = "usage: /pbtscale 1.0  (min 0.5, max 2.5)",
    ["utilisation: /pbtcolor 1 0 0  (valeurs RGB entre 0 et 1)"] = "usage: /pbtcolor 1 0 0  (RGB values between 0 and 1)",
    ["utilisation: /pbttimer z'maja 21"] = "usage: /pbttimer z'maja 21",
    ["boss inconnu. Utilise /pbtlist pour voir les cles, ou /pbtalias pour ajouter un nom."] = "unknown boss. Use /pbtlist to view keys, or /pbtalias to add a name.",
    ["utilisation: /pbtia tho'at replicanum | frost atronach | mantikora | dragon | marauder bittog"] = "usage: /pbtia tho'at replicanum | frost atronach | mantikora | dragon | marauder bittog",
    ["utilisation: /pbtalias z'maja = Nom exact vu en jeu"] = "usage: /pbtalias z'maja = Exact name shown in game",
    ["boss ou alias invalide."] = "invalid boss or alias.",
    ["utilisation: /pbtpracticetime 6"] = "usage: /pbtpracticetime 6",
    ["utilisation: /pbtgeneric 8"] = "usage: /pbtgeneric 8",
    ["utilisation: /pbtolms 10"] = "usage: /pbtolms 10",
    ["bouton menu logo remis au centre."] = "logo menu button reset to center.",
    ["capture narration activee."] = "narration capture enabled.", ["capture narration desactivee."] = "narration capture disabled.",
    ["dernieres narrations:"] = "latest narrations:", ["boss detectes par le client:"] = "bosses detected by the client:",
    ["partage impossible : tu n'es pas dans un groupe."] = "sharing unavailable: you are not in a group.",
    ["aucun pack selectionne."] = "no pack selected.",
    ["le pack selectionne est vide ou invalide"] = "the selected pack is empty or invalid",
    ["variables non pretes"] = "saved variables are not ready",
    ["partage invalide"] = "invalid share",
    ["destination incompatible"] = "incompatible destination",
    ["confirmation de remplacement requise"] = "replacement confirmation required",
    ["partage impossible : le pack depasse 6000 caracteres."] = "sharing unavailable: the pack exceeds 6000 characters.",
    ["partage impossible : LibGroupBroadcast 91 ou superieur est indisponible."] = "sharing unavailable: LibGroupBroadcast 91 or newer is unavailable.",
    ["partage impossible : le protocole est desactive dans LibGroupBroadcast."] = "sharing unavailable: the protocol is disabled in LibGroupBroadcast.",
    ["pack place dans la file d'envoi du groupe."] = "pack queued for group delivery.",
    ["l'envoi du pack a echoue."] = "pack delivery failed.",
    ["partage indisponible : LibGroupBroadcast 91 ou superieur est requis."] = "sharing unavailable: LibGroupBroadcast 91 or newer is required.",
    ["partage accepte"] = "share accepted", ["partage refuse"] = "share declined", ["partage refuse."] = "share declined.",
}

local chatPatterns = {
    { "^marker (%d+) enregistre%.$", "marker %1 saved." },
    { "^(%d+) markers importes$", "%1 markers imported" },
    { "^timer mannequin regle sur ([%d%.]+)s%.$", "target dummy timer set to %1s." },
    { "^test decompte groupe envoye: ([%d%.]+)s$", "group countdown test sent: %1s" },
    { "^zone ESO: (.+) / id (.+)$", "ESO zone: %1 / id %2" },
    { "^taille reglee sur ([%d%.]+)%.$", "size set to %1." },
    { "^couleur reglee sur ([%d%.]+) ([%d%.]+) ([%d%.]+)%.$", "color set to %1 %2 %3." },
    { "^(.+) regle sur ([%d%.]+)s%.$", "%1 set to %2s." },
    { "^alias ajoute: (.+) %-> (.+)%.$", "alias added: %1 -> %2." },
    { "^pack deja enregistre dans l'emplacement (%d+)$", "pack already saved in slot %1" },
    { "^pack accepte et enregistre dans l'emplacement (%d+)$", "pack accepted and saved in slot %1" },
    { "^pack accepte jusqu'a la deconnexion$", "pack accepted until logout" },
    { "^pack (%d+) enregistre$", "pack %1 saved" },
    { "^pack (%d+) supprime$", "pack %1 deleted" },
}

function PBT.LocalizeChatMessage(message)
    message = tostring(message or "")
    if PBT.GetLanguage() ~= "en" then return message end
    if chatExact[message] then return chatExact[message] end
    for _, data in ipairs(chatPatterns) do
        local translated, count = message:gsub(data[1], data[2])
        if count > 0 then return translated end
    end
    return message
end
