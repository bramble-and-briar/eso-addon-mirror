local strings =
{
    SI_AAB_PANEL_DESCRIPTION =
        "Ajoute une animation de rebond et un effet lumineux personnalisable à votre barre d'action. " ..
        "Compatible avec FancyActionbar+, Bandits UI, LUI Extended, Ability Framework " ..
        "(y compris les Style Packs personnalisés), AlphaGear, Azurah et l'interface par défaut.",

    SI_AAB_SUB_BOUNCE          = "Animation de rebond",
    SI_AAB_SUB_BOUNCE_TT       = "Réglages de l'animation d'écrasement et d'agrandissement de vos icônes de compétences.",

    SI_AAB_ANIM_STYLE          = "Style d'animation",
    SI_AAB_ANIM_STYLE_TT       = "Quelle animation est jouée lors de l'utilisation ou du proc d'une compétence. " ..
                                        "Bounce : rétrécir + grandir. Flash : clignotement. " ..
                                        "Shake : oscillation horizontale. Tilt : brève rotation.",
    SI_AAB_ANIM_BOUNCE         = "Bounce",
    SI_AAB_ANIM_FLASH          = "Flash",
    SI_AAB_ANIM_SHAKE          = "Shake",
    SI_AAB_ANIM_TILT           = "Tilt",
    SI_AAB_SUB_GLOW            = "Effet lumineux",
    SI_AAB_SUB_GLOW_TT         = "Surbrillance colorée qui apparaît brièvement quand vous appuyez sur une compétence.",
    SI_AAB_SUB_PULSE           = "Pulsation de proc",
    SI_AAB_SUB_PULSE_TT        = "Effet lumineux continu lorsqu'une compétence est procée et prête à être utilisée.",

    SI_AAB_BOUNCE_ENABLE       = "Activer le rebond",
    SI_AAB_BOUNCE_ENABLE_TT    = "Interrupteur principal pour l'animation de rebond. Désactivé, aucune icône ne s'animera.",
    SI_AAB_BOUNCE_ON_PROC      = "Rebond sur proc",
    SI_AAB_BOUNCE_ON_PROC_TT   = "Joue aussi l'animation quand une compétence proce (Fragments de Cristal, " ..
                                        "Volonté de l'Assassin, Concentration Sinistre...), pas seulement à la pression.",

    SI_AAB_BOUNCE_GROW         = "Échelle d'agrandissement",
    SI_AAB_BOUNCE_GROW_TT      = "À quel point l'icône grandit au sommet du rebond. 1,10 = 10% plus grand que la normale. " ..
                                        "Plus haut = plus visible.",
    SI_AAB_BOUNCE_SHRINK       = "Échelle de rétrécissement",
    SI_AAB_BOUNCE_SHRINK_TT    = "À quel point l'icône rétrécit au début du rebond. 0,90 = 10% plus petit que la normale. " ..
                                        "Plus bas = écrasement plus net.",
    SI_AAB_BOUNCE_RESET        = "Durée de retour (ms)",
    SI_AAB_BOUNCE_RESET_TT     = "Temps que met l'icône à revenir à sa taille normale après le sommet. " ..
                                        "Plus bas = plus réactif.",

    SI_AAB_GLOW_ENABLE         = "Activer la lueur",
    SI_AAB_GLOW_ENABLE_TT      = "Interrupteur principal pour l'effet lumineux. Désactivé, aucune lueur n'apparaîtra à la pression.",
    SI_AAB_GLOW_COLOR          = "Couleur de la lueur",
    SI_AAB_GLOW_COLOR_TT       = "Couleur de l'effet lumineux. Le curseur alpha (A) contrôle la luminosité maximale.",
    SI_AAB_GLOW_DURATION       = "Durée de la lueur (ms)",
    SI_AAB_GLOW_DURATION_TT    = "Temps de disparition de la lueur déclenchée par la pression. Plus haut = reste visible plus longtemps.",
    SI_AAB_GLOW_PADDING        = "Marge de la lueur (px)",
    SI_AAB_GLOW_PADDING_TT     = "Pixels supplémentaires que la lueur dépasse autour de l'icône. " ..
                                        "Plus haut = halo plus large.",
    SI_AAB_GLOW_INTENSITY      = "Intensité du glow",
    SI_AAB_GLOW_INTENSITY_TT   = "Multiplicateur de luminosité. 1.00 = défaut, plus haut = plus brillant. " ..
                                        "Affecte le glow d'appui, la pulsation de proc et les consommables.",

    SI_AAB_PULSE_ENABLE        = "Activer la pulsation de proc",
    SI_AAB_PULSE_ENABLE_TT     = "Quand une compétence proce, la lueur continue de pulser jusqu'à utilisation ou expiration du proc.",
    SI_AAB_PROC_VANILLA_GLOW       = "Lueur de proc ESO d'origine",
    SI_AAB_PROC_VANILLA_GLOW_TT    = "Affiche la lueur d'origine d'ESO qui apparaît sur une compétence dès qu'elle proce. " ..
                                        "Désactivez pour n'utiliser que la pulsation de proc de cet addon et garder la barre épurée. " ..
                                        "Réactiver nécessite un rechargement de l'UI pour restaurer la texture d'origine.",
    SI_AAB_PULSE_STOP_ON_PRESS          = "Arrêter à la pression",
    SI_AAB_PULSE_STOP_ON_PRESS_TT       = "Arrête la pulsation dès que vous appuyez sur la compétence procée, sans attendre " ..
                                        "l'événement de fin de proc du jeu (qui peut être en retard d'une frame).",
    SI_AAB_PULSE_STYLE         = "Style de pulsation",
    SI_AAB_PULSE_STYLE_TT      = "Doux : fondu d'apparition et de disparition.\n" ..
                                        "Clignotant : marche/arrêt clairement visible.\n" ..
                                        "Stroboscope : scintillement rapide et agressif pour une attention maximale.",
    SI_AAB_PULSE_STYLE_SMOOTH  = "Doux",
    SI_AAB_PULSE_STYLE_BLINK   = "Clignotant",
    SI_AAB_PULSE_STYLE_STROBE  = "Stroboscope",
    SI_AAB_PULSE_SMOOTH_DUR    = "Doux : durée de pulsation (ms)",
    SI_AAB_PULSE_SMOOTH_DUR_TT = "Durée d'un cycle de fondu en mode Doux. Ne s'applique qu'avec le style Doux.",
    SI_AAB_PULSE_BLINK_INT     = "Clignotant : intervalle (ms)",
    SI_AAB_PULSE_BLINK_INT_TT  = "Temps entre marche et arrêt en mode Clignotant. Plus bas = clignotement plus rapide. " ..
                                        "Ne s'applique qu'avec le style Clignotant.",
    SI_AAB_PULSE_STROBE_INT    = "Stroboscope : intervalle (ms)",
    SI_AAB_PULSE_STROBE_INT_TT = "Temps entre marche et arrêt en mode Stroboscope. Valeurs très basses = scintillement agressif. " ..
                                        "Ne s'applique qu'avec le style Stroboscope.",
    SI_AAB_PULSE_MIN_ALPHA     = "Alpha minimum de pulsation",
    SI_AAB_PULSE_MIN_ALPHA_TT  = "Visibilité la plus basse atteinte par la pulsation. " ..
                                        "0 = totalement transparent, 1 = toujours pleinement visible.",
    SI_AAB_PULSE_MAX_ALPHA     = "Alpha maximum de pulsation",
    SI_AAB_PULSE_MAX_ALPHA_TT  = "Visibilité la plus haute atteinte au sommet de la pulsation. 1 = totalement opaque.",
    SI_AAB_PULSE_COLOR_CYCLE   = "Cycle de couleurs",
    SI_AAB_PULSE_COLOR_CYCLE_TT= "Alterne la pulsation entre la couleur principale et la couleur secondaire ci-dessous " ..
                                        "pour un effet de clignotement bicolore.",
    SI_AAB_PULSE_COLOR_SECOND  = "Couleur secondaire",
    SI_AAB_PULSE_COLOR_SECOND_TT = "Seconde couleur utilisée lorsque le Cycle de couleurs est activé.",

    SI_AAB_SUB_ULT             = "Ultime",
    SI_AAB_SUB_ULT_TT          = "Réglages dédiés à l'emplacement d'ultime, indépendants du bounce et du glow des emplacements normaux.",

    SI_AAB_ULT_HEADER_EFFECTS  = "Effets sur l'ultime",
    SI_AAB_ULT_BOUNCE_ENABLE   = "Bounce sur l'ultime",
    SI_AAB_ULT_BOUNCE_ENABLE_TT= "Joue aussi l'animation de rebond sur l'emplacement d'ultime.",
    SI_AAB_ULT_GLOW_ENABLE     = "Glow sur l'ultime",
    SI_AAB_ULT_GLOW_ENABLE_TT  = "Effet lumineux à la pression sur l'emplacement d'ultime.",
    SI_AAB_ULT_GLOW_COLOR      = "Couleur du glow d'ultime",
    SI_AAB_ULT_GLOW_COLOR_TT   = "Couleur du glow à la pression sur l'ultime. Le curseur alpha (A) contrôle la luminosité.",
    SI_AAB_ULT_GLOW_DURATION   = "Durée du glow d'ultime (ms)",
    SI_AAB_ULT_GLOW_DURATION_TT= "Temps de fondu du glow à la pression sur l'ultime.",
    SI_AAB_ULT_GLOW_PADDING    = "Intensité du glow ultime (px)",
    SI_AAB_ULT_GLOW_PADDING_TT = "Pixels supplémentaires que le glow ultime dépasse les bords de l'icône. " ..
                                        "Plus haut = halo plus large/intense, plus bas = plus discret.",
    SI_AAB_ULT_GLOW_INTENSITY  = "Luminosité du glow d'ultime",
    SI_AAB_ULT_GLOW_INTENSITY_TT = "Multiplicateur de luminosité du glow à la pression sur l'ultime. " ..
                                        "1.00 = défaut, plus haut = plus intense.",

    SI_AAB_ULT_HEADER_READY    = "Bordure d'ultime prête",
    SI_AAB_ULT_VANILLA_SHIMMER = "Scintillement ESO original",
    SI_AAB_ULT_VANILLA_SHIMMER_TT = "Affiche le scintillement/halo doré original d'ESO sur l'emplacement d'ultime dès qu'elle est prête. " ..
                                        "Fonctionne en parallèle de la bordure personnalisée ci-dessous - l'un ou l'autre, ou les deux. " ..
                                        "Désactiver ensuite nécessite un /reloadui pour effacer complètement les textures.",
    SI_AAB_ULT_BORDER_STYLE       = "Style de bordure prête",
    SI_AAB_ULT_BORDER_STYLE_TT    = "Choisit quelle bordure marque l'emplacement d'ultime. \"Personnalisée\" utilise la bordure lumineuse colorée de cet add-on avec toutes les options de pulsation/clignotement/arc-en-ciel ci-dessous. \"Manette\" affiche une bordure de progression qui se remplit du bas vers le haut à mesure que l'ultime se charge. Passer en mode Manette désactive les options personnalisées ci-dessous.",
    SI_AAB_ULT_BORDER_CUSTOM      = "Personnalisée (bordure lumineuse)",
    SI_AAB_ULT_BORDER_CONTROLLER  = "Manette (bordure de progression)",
    SI_AAB_ULTCTRL_STYLE          = "Texture de bordure",
    SI_AAB_ULTCTRL_STYLE_TT       = "Quelle texture de cadre utilise la bordure de progression manette.",
    SI_AAB_ULTCTRL_STYLE_BEVEL    = "Biseau (3D métallique)",
    SI_AAB_ULTCTRL_STYLE_FLAT     = "Plat (ligne nette)",
    SI_AAB_ULTCTRL_STYLE_SLEEK    = "Fin (double ligne)",
    SI_AAB_ULTCTRL_STYLE_CHAMFER  = "Chanfrein (anguleux)",
    SI_AAB_ULTCTRL_STYLE_DOUBLE   = "Double (anneau jumeau)",
    SI_AAB_ULTCTRL_GLOWSTYLE      = "Style de lueur",
    SI_AAB_ULTCTRL_GLOWSTYLE_TT   = "Forme de la lueur affichée quand l'ultime est prêt.",
    SI_AAB_ULTCTRL_GLOWSTYLE_SOFT = "Douce (halo large)",
    SI_AAB_ULTCTRL_GLOWSTYLE_SHARP = "Nette (bord serré)",
    SI_AAB_ULTCTRL_GLOWSTYLE_RING = "Anneau (aura externe)",
    SI_AAB_ULTCTRL_THICKNESS      = "Épaisseur de bordure",
    SI_AAB_ULTCTRL_THICKNESS_TT   = "Épaisseur du trait de la bordure, en pixels. Faible pour un contour fin, élevé pour un cadre épais.",
    SI_AAB_ULTCTRL_CORNER         = "Longueur des coins",
    SI_AAB_ULTCTRL_CORNER_TT      = "Jusqu'où les coins haut et bas s'étendent vers l'intérieur, en pourcentage de la largeur. Plus bas = crochet plus ouvert, plus haut = cadre plus fermé.",
    SI_AAB_ULTCTRL_PADDING        = "Espacement de bordure",
    SI_AAB_ULTCTRL_PADDING_TT     = "Écart entre l'emplacement et la bordure, en pixels.",
    SI_AAB_ULTCTRL_TRACK          = "Afficher le fond",
    SI_AAB_ULTCTRL_TRACK_TT       = "Affiche le cadre sombre non rempli derrière la progression, pour toujours voir le contour complet.",
    SI_AAB_ULTCTRL_COLORSHIFT     = "Dégradé de charge",
    SI_AAB_ULTCTRL_COLORSHIFT_TT  = "Fait passer la couleur de la bordure de la couleur de charge à la couleur prête au fur et à mesure du remplissage.",
    SI_AAB_ULTCTRL_CHARGECOLOR    = "Couleur de charge",
    SI_AAB_ULTCTRL_CHARGECOLOR_TT = "Couleur de la bordure à 0% quand le dégradé est activé. La couleur prête est la couleur de bordure ci-dessus.",
    SI_AAB_ULTCTRL_GLOWFULL       = "Lueur quand plein",
    SI_AAB_ULTCTRL_GLOWFULL_TT    = "Ajoute une lueur additive vive et une brève pulsation dès que l'ultime est pleinement chargé.",
    SI_AAB_ULTCTRL_GLOWINT        = "Intensité de la lueur",
    SI_AAB_ULTCTRL_GLOWINT_TT     = "Luminosité de la lueur affichée quand l'ultime est prêt.",
    SI_AAB_ULTCTRL_RAINBOW        = "Arc-en-ciel quand plein",
    SI_AAB_ULTCTRL_RAINBOW_TT     = "Fait défiler la bordure de progression à travers l'arc-en-ciel une fois l'ultime entièrement chargé. Utilise les curseurs de saturation et de luminosité de la section de la bordure personnalisée.",
    SI_AAB_ULT_ENABLE          = "Activer la bordure d'ultime prête",
    SI_AAB_ULT_ENABLE_TT       = "Affiche une bordure colorée autour de votre emplacement d'ultime dès que vous avez " ..
                                        "assez d'énergie ultime pour utiliser la compétence équipée.",
    SI_AAB_ULT_COLOR           = "Couleur de la bordure",
    SI_AAB_ULT_COLOR_TT        = "Couleur de la bordure d'ultime prête. Le curseur alpha (A) contrôle sa luminosité.",
    SI_AAB_ULT_PULSE           = "Pulsation de la bordure",
    SI_AAB_ULT_PULSE_TT        = "Si activé, la bordure pulse doucement pour attirer le regard. " ..
                                        "Si désactivé, elle reste à luminosité constante.",
    SI_AAB_ULT_PULSE_MODE      = "Animation de la bordure",
    SI_AAB_ULT_PULSE_MODE_TT   = "Doux : fondu progressif d'entrée et de sortie.\n" ..
                                        "Clignotement : bascule marche/arrêt nette et bien visible.",
    SI_AAB_ULT_BLINK_INT       = "Intervalle de clignotement (ms)",
    SI_AAB_ULT_BLINK_INT_TT    = "Temps entre marche et arrêt en mode Clignotement. Plus bas = clignotement plus rapide. " ..
                                        "S'applique uniquement quand l'animation de la bordure est réglée sur Clignotement.",
    SI_AAB_ULT_COLOR_CYCLE     = "Cycle de couleurs",
    SI_AAB_ULT_COLOR_CYCLE_TT  = "Alterne la bordure de l'ultime entre la couleur principale et la couleur secondaire " ..
                                        "ci-dessous au lieu d'un simple marche/arrêt. S'applique uniquement en mode Clignotement.",
    SI_AAB_ULT_COLOR_SECOND    = "Couleur secondaire",
    SI_AAB_ULT_COLOR_SECOND_TT = "Seconde couleur utilisée pour la bordure de l'ultime lorsque le Cycle de couleurs est activé.",
    SI_AAB_ULT_PADDING         = "Marge de la bordure (px)",
    SI_AAB_ULT_PADDING_TT      = "Pixels supplémentaires que la bordure dépasse autour de l'icône. " ..
                                        "Plus haut = halo plus large.",

    SI_AAB_ULT_PULSE_DUR       = "Durée de pulsation (ms)",
    SI_AAB_ULT_PULSE_DUR_TT    = "Durée d'un cycle de fondu. Plus bas = pulsation plus rapide.",
    SI_AAB_ULT_PULSE_MIN       = "Pulsation : visibilité min. (alpha)",
    SI_AAB_ULT_PULSE_MIN_TT    = "Valeur minimale d'opacité de la pulsation. " ..
                                        "Plus bas = contraste plus fort.",
    SI_AAB_ULT_INTENSITY       = "Intensité du glow",
    SI_AAB_ULT_INTENSITY_TT    = "Multiplicateur de luminosité. 1.00 = défaut, plus haut = plus brillant.",

    SI_AAB_SUB_FRAME           = "Apparence du cadre",
    SI_AAB_SUB_FRAME_TT        = "Contrôle le cadre dessiné autour de chaque icône de compétence.",
    SI_AAB_THIN_FRAME          = "Utiliser un cadre fin personnalisé",
    SI_AAB_THIN_FRAME_TT       = "Remplace le cadre de compétence standard 64px par un cadre fin personnalisé " ..
                                        "(dessiné depuis CustomEdge.dds et CustomCenter.dds). Les effets lumineux passent au-dessus. " ..
                                        "Un rechargement de l'interface est nécessaire pour appliquer complètement.",
    SI_AAB_FRAME_ALPHA         = "Opacité du cadre",
    SI_AAB_FRAME_ALPHA_TT      = "0 = cadre complètement invisible (look épuré, lueur uniquement). " ..
                                        "1 = opacité maximale. Valeurs plus basses = cadre plus fin/atténué.",
    SI_AAB_EDGE_STYLE          = "Style de cadre",
    SI_AAB_EDGE_STYLE_TT       = "Sélectionne la texture du cadre personnalisé. " ..
                                        "Classique = cadre d'origine, EldenRingUI = assorti à l'addon EldenRingUI.",
    SI_AAB_EDGE_CLASSIC        = "Classique",
    SI_AAB_EDGE_V2             = "EldenRingUI",
    SI_AAB_EDGE_PURPLE         = "Cadres violets",
    SI_AAB_EDGE_RED            = "Cadres rouges",
    SI_AAB_EDGE_BLUE           = "Cadres bleus",
    SI_AAB_EDGE_AQUA           = "Cadres turquoise",
    SI_AAB_EDGE_DARKRED        = "Cadres rouge foncé",
    SI_AAB_EDGE_DARKPURPLE     = "Cadres violet foncé",
    SI_AAB_RELOAD_NOTE         = "Un rechargement de l'interface (/reloadui) est nécessaire pour appliquer entièrement.",
    SI_AAB_FRAME_THEME_NOTE    = "|cAAAAAACréateurs d'UI souhaitant leur propre thème, contactez |r|cFFFFFFhaze.3169|r|cAAAAAA sur Discord. Des idées pour d'autres thèmes ? Écrivez aussi là-bas !|r",
    SI_AAB_RELOAD_UI           = "Recharger l'interface",
    SI_AAB_RELOAD_UI_TT        = "Recharge l'interface pour appliquer entièrement les changements de cadre.",

    SI_AAB_DBG_ON              = "activé",
    SI_AAB_DBG_OFF             = "désactivé",
    SI_AAB_DBG_FRAME           = "Cadre",
    SI_AAB_DBG_THINFRAME       = "cadre fin",
    SI_AAB_DBG_STYLE           = "style",
    SI_AAB_DBG_TEMPLATE        = "modèle",
    SI_AAB_DBG_ALPHA           = "opacité",
    SI_AAB_DBG_BOUNCE          = "Rebond",
    SI_AAB_DBG_ACTIVE          = "actif",
    SI_AAB_DBG_ONPROC          = "sur proc",
    SI_AAB_DBG_ULTI            = "ulti",
    SI_AAB_DBG_GLOWPULSE       = "Lueur / Pulsation",
    SI_AAB_DBG_GLOW            = "lueur",
    SI_AAB_DBG_PULSE           = "pulsation",
    SI_AAB_DBG_PULSEMODE       = "mode pulsation",
    SI_AAB_DBG_COLORCYCLE      = "cycle couleur",
    SI_AAB_DBG_VANILLAPROC     = "lueur proc vanilla",
    SI_AAB_DBG_ULTFRAME        = "Cadre ultime",
    SI_AAB_DBG_READY           = "prêt",
    SI_AAB_DBG_MODE            = "mode",
    SI_AAB_DBG_VANILLASHIMMER  = "scintillement vanilla",
    SI_AAB_DBG_SERVER          = "Serveur",

    SI_AAB_EXPIRE_DESC         = "Joue une animation sur l'icône de compétence lorsque l'effet d'une compétence équipée expire (par ex. un buff ou un DoT).",
    SI_AAB_EXPIRE_ENABLE       = "Animation à l'expiration",
    SI_AAB_EXPIRE_ENABLE_TT    = "Joue une animation lorsque l'effet d'une compétence équipée expire - vous savez ainsi quand relancer.",
    SI_AAB_EXPIRE_STYLE        = "Style d'animation d'expiration",
    SI_AAB_EXPIRE_STYLE_TT     = "Animation jouée lorsqu'un effet expire. Choisissez 'Identique à l'animation d'appui' pour réutiliser le style ci-dessus.",
    SI_AAB_EXPIRE_STYLE_INHERIT = "Identique à l'animation d'appui",
    SI_AAB_EXPIRE_STRENGTH       = "Intensité de l'animation d'expiration",
    SI_AAB_EXPIRE_STRENGTH_TT    = "Multiplicateur de l'intensité de l'animation d'expiration. 1.00 = identique à l'animation d'appui, 2.00 = mouvement doublé.",
    SI_AAB_EXPIRE_GLOW_ENABLE    = "Lueur d'expiration",
    SI_AAB_EXPIRE_GLOW_ENABLE_TT = "Affiche en plus une lueur colorée sur l'icône lorsque l'effet expire.",
    SI_AAB_EXPIRE_GLOW_COLOR     = "Couleur de la lueur d'expiration",
    SI_AAB_EXPIRE_GLOW_COLOR_TT  = "Couleur de la lueur affichée à l'expiration d'un effet - choisissez-la distincte de la lueur d'appui.",
    SI_AAB_DBG_EXPIRE          = "à l'expiration",
    SI_AAB_DBG_EXPIRE_HEAD     = "Vérification expiration (barre active)",
    SI_AAB_DBG_DURATION        = "durée",
    SI_AAB_DBG_TRACKING        = "suivi",

    SI_AAB_PULSE_STYLE_RAINBOW = "Arc-en-ciel",
    SI_AAB_ULT_RAINBOW_SAT     = "Saturation arc-en-ciel",
    SI_AAB_ULT_RAINBOW_SAT_TT  = "Saturation des couleurs arc-en-ciel. 0 = niveaux de gris, 1 = couleur pleine.",
    SI_AAB_ULT_RAINBOW_LIGHT   = "Luminosité arc-en-ciel",
    SI_AAB_ULT_RAINBOW_LIGHT_TT= "Luminosité des couleurs arc-en-ciel. 0 = noir, 0.5 = pleine luminosité, 1 = blanc.",
    SI_AAB_DBG_RAINBOW_SAT     = "rainbow sat",
    SI_AAB_DBG_RAINBOW_LIGHT   = "rainbow lum",
    SI_AAB_CONF_HEAD           = "Vérification des conflits",
    SI_AAB_CONF_FOUND          = "Autres addons de barre d'action actifs :",
    SI_AAB_CONF_HINT           = "En cas de bordures/lueurs en double, désactive l'un d'eux pour tester.",
    SI_AAB_CONF_NONE           = "Aucun addon de barre d'action concurrent connu détecté.",
    SI_AAB_CONF_HOOKS          = "Hooks propres",
    SI_AAB_CONF_OK             = "ok",
    SI_AAB_CONF_MISSING        = "manquant",
    SI_AAB_CONF_OVERRIDDEN     = "manquant (écrasé ?)",
    SI_AAB_CONF_ULTFRAME       = "Cadre ultime d'origine",
    SI_AAB_CONF_VISIBLE        = "visible (autre addon ?)",
    SI_AAB_CONF_SUPPRESSED     = "masqué",
    SI_AAB_DBG_PROGRESS        = "progression",
    SI_AAB_DBG_BORDER          = "bordure",
    SI_AAB_DBG_VISIBLE         = "visible",
    SI_AAB_DBG_TEXTURE         = "texture",
    SI_AAB_DBG_THICKNESS       = "épaisseur",
    SI_AAB_DBG_PADDING         = "marge",
    SI_AAB_DBG_COLORSHIFT      = "dégradé",
    SI_AAB_DBG_FULLGLOW        = "lueur pleine",
    SI_AAB_DBG_GLOWSTYLE       = "style de lueur",
    SI_AAB_DBG_RAINBOW         = "arc-en-ciel",

    -- animation de fin liée à la durée
    SI_AAB_EXPIRE_SCALE_DESC       = "Lie la longueur de l'animation d'expiration à la durée de la capacité. Les buffs courts clignotent vite, les longs s'étirent un peu plus.",
    SI_AAB_EXPIRE_SCALE_ENABLE     = "Adapter à la durée",
    SI_AAB_EXPIRE_SCALE_ENABLE_TT  = "Si activé, l'animation d'expiration est étirée ou compressée selon la durée de la capacité équipée.",
    SI_AAB_EXPIRE_SCALE_REF        = "Durée de référence (ms)",
    SI_AAB_EXPIRE_SCALE_REF_TT     = "La durée jouée à vitesse normale. Les capacités plus longues sont plus lentes, les plus courtes plus rapides.",
    SI_AAB_EXPIRE_SCALE_MIN        = "Facteur de vitesse min.",
    SI_AAB_EXPIRE_SCALE_MIN_TT     = "Limite basse du facteur de temps, pour que les capacités très courtes restent visibles.",
    SI_AAB_EXPIRE_SCALE_MAX        = "Facteur de vitesse max.",
    SI_AAB_EXPIRE_SCALE_MAX_TT     = "Limite haute du facteur de temps, pour que les capacités très longues ne traînent pas.",
    SI_AAB_EXPIRE_OVERRIDE_CLEAR   = "Effacer les surcharges",
    SI_AAB_EXPIRE_OVERRIDE_CLEAR_TT= "Supprime chaque moment de declenchement defini via /aab setend.",
    SI_AAB_EXPIRE_OVERRIDE_NOTE    = "Moment de declenchement par capacite dans le chat : /aab id liste les ID equipes, puis /aab setend <id> <ms|auto> - l'animation de fin se declenche alors ce nombre de ms apres l'incantation.",

    -- aperçu des commandes
    SI_AAB_CMD_HEAD    = "Commandes",
    SI_AAB_CMD_PANEL   = "ouvrir le panneau de réglages",
    SI_AAB_CMD_INFO    = "ouvrir directement l'onglet Info",

    SI_AAB_CMD_ID      = "lister les ID de capacités équipées dans le chat",
    SI_AAB_CMD_SETEND  = "definir quand l'animation de fin se declenche (ms apres l'incantation)",
    SI_AAB_CMD_DEBUG   = "afficher l'état complet",
    SI_AAB_ID_HINT     = "Definir le declenchement : /aab setend <id> <ms|auto>  (ms apres incantation)",
    SI_AAB_SETEND_BADID  = "ID de capacité invalide. /aab id les liste.",
    SI_AAB_SETEND_BADVAL = "Valeur invalide. Utilisez des millisecondes ou 'auto'.",
    SI_AAB_SETEND_SET    = "L'animation de fin de %s (id %d) se declenchera %dms apres l'incantation.",
    SI_AAB_SETEND_CLEARED= "Declenchement pour l'id %d efface (retour a la duree de la capacite).",

    -- fenêtre d'aide / diagnostic

    SI_AAB_CMD_LIST           = "afficher cette liste de commandes",

    SI_AAB_TRACE_ON           = "Trace d'expiration ACTIVEE - schedule/resync/fire seront journalises.",
    SI_AAB_TRACE_OFF          = "Trace d'expiration DESACTIVEE.",

    SI_AAB_SUB_PERF             = "Performance",
    SI_AAB_SUB_PERF_TT          = "Optimisations optionnelles. Toutes DESACTIVEES par defaut - activez seulement ce dont vous avez besoin.",
    SI_AAB_PERF_DESC            = "Ces options changent l'efficacite INTERNE de l'addon, pas ce qu'il affiche. La plupart des joueurs ne verront pas de difference ; activez-les pour gagner des fps dans les gros combats (Trials, Cyrodiil).",
    SI_AAB_PERF_EFFECTID        = "Filtrer les evenements d'effet par ID",
    SI_AAB_PERF_EFFECTID_TT     = "Au lieu de reagir a chaque buff/debuff sur vous, n'ecouter que vos capacites equipees. Plus grosse economie en combat charge. Applique en direct.",
    SI_AAB_PERF_SLOTMAP         = "Recherche d'emplacement rapide",
    SI_AAB_PERF_SLOTMAP_TT      = "Table de correspondance preconstruite au lieu de parcourir tous les emplacements a chaque evenement. O(1) au lieu d'une boucle.",
    SI_AAB_PERF_COMBAT          = "Animer seulement en combat",
    SI_AAB_PERF_COMBAT_TT       = "Suspendre toutes les animations hors combat. Economise du travail en ville. Reprend des le debut du combat.",
    SI_AAB_PERF_RAINBOW         = "Mises a jour arc-en-ciel economes",
    SI_AAB_PERF_RAINBOW_TT      = "Mettre a jour la bordure ultime arc-en-ciel ~30x/s au lieu de 200x. Aspect identique, ~85% de mises a jour en moins.",
    SI_AAB_PERF_STYLEHOOK       = "Hook de style unique",
    SI_AAB_PERF_STYLEHOOK_TT    = "Fusionner deux hooks de style en un seul quand le cadre fin est actif. Necessite un rechargement.",
    SI_AAB_PERF_TLCACHE         = "Limiter le cache d'animation",
    SI_AAB_PERF_TLCACHE_TT      = "Limiter les timelines d'animation en cache par bouton pour garder la memoire basse lors de longues sessions.",
    SI_AAB_PERF_NOTE            = "Aucune de ces options ne change l'apparence. Si quelque chose se comporte mal, desactivez l'option correspondante.",

    SI_AAB_SUB_PRESETS          = "Presets",
    SI_AAB_SUB_PRESETS_TT       = "Basculer rapidement entre des looks preconfigures.",
    SI_AAB_PRESETS_DESC         = "Un clic regle plusieurs options d'effet a la fois. Seul le look change - vos couleurs et options de performance restent inchangees.",
    SI_AAB_PRESET_MINIMAL       = "Minimal",
    SI_AAB_PRESET_MINIMAL_TT    = "Juste le rebond a l'incantation. Halo, pulsation, expiration et bar-swap desactives. Look le plus leger.",
    SI_AAB_PRESET_STANDARD      = "Standard",
    SI_AAB_PRESET_STANDARD_TT   = "Rebond, halo, pulsation et expiration actifs. Le look equilibre par defaut.",
    SI_AAB_PRESET_FLASHY        = "Flashy",
    SI_AAB_PRESET_FLASHY_TT     = "Tout activer, plus le flash de bar-swap et le cycle de couleurs. Effet maximal.",
    SI_AAB_PRESETS_NOTE         = "Les presets sont un point de depart - ajustez ensuite tout dans les sous-menus ci-dessous.",


    SI_AAB_SUB_CONTACT            = "Contacter le créateur",
    SI_AAB_SUB_CONTACT_TT         = "Soutenez le créateur avec un don en jeu.",
    SI_AAB_CONTACT_DESC           = "L'addon vous plaît ? Les dons en jeu sont les bienvenus - Potions, Or et Ressources d'artisanat aident tous ! Cliquez ci-dessous pour ouvrir un courrier adressé à @haze068.",
    SI_AAB_CONTACT_DONATE_BTN     = "Faire un don par courrier",
    SI_AAB_CONTACT_DONATE_BTN_TT  = "Ouvre le panneau de courrier avec le destinataire et le titre pré-remplis.",

    SI_AAB_SUB_INFO               = "Info",
    SI_AAB_SUB_INFO_TT            = "Notes de compatibilité pour utiliser AnimatedActionBar+ avec d'autres addons.",
    SI_AAB_INFO_THINFRAMES        = "Si vous utilisez l'option \"Frame Appearance: Thin Frames\" de cet addon, désactivez les options suivantes dans FancyActionBar+ sous UI Customization -> Custom Frames Keyboard :\n\n" ..
                                        "  - \"Hide Default Frames\"\n" ..
                                        "  - \"Use Thin Frames\"\n\n" ..
                                        "Si les deux addons dessinent des cadres fins en même temps, les cadres se doublent ou se décalent.",
    SI_AAB_INFO_GAMEPAD           = "Vous jouez à la manette ?\n\n" ..
                                        "Si vos compétences sont décalées, mal alignées ou affichées incorrectement, désactivez le \"Gamepad Mode\" dans FancyActionBar+.\n\n" ..
                                        "Les joueurs à la manette devraient également désactiver \"Use Thin Frame\" dans FancyActionBar+ et dans AnimatedActionBar+ pour un résultat optimal.\n\n" ..
                                        "Si le problème persiste, contactez-moi sur Discord (haze.3169) afin que nous puissions le résoudre ensemble.",

    SI_AAB_DLG_TITLE              = "AnimatedActionBar+",
    SI_AAB_DLG_BODY               = "Merci d'avoir installé AnimatedActionBar+ !\n\n" ..
                                        "Vous utilisez le style de cadre \"Thin Frames\" avec FancyActionBar+ ? Veuillez lire la note de compatibilité.\n\n" ..
                                        "Vous jouez à la manette ? Consultez également l'onglet \"Info\".\n\n" ..
                                        "Ouvrez les paramètres et consultez l'onglet \"Info\" pour les détails.",
    SI_AAB_DLG_OK                 = "Compris",
}

for stringId, stringValue in pairs(strings) do
    ZO_CreateStringId(stringId, stringValue)
    SafeAddVersion(stringId, 2)
end
