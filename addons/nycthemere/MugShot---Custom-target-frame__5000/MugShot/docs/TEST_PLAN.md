# MugShot — Plan de Test & Stratégie Qualité

Ce document définit la stratégie de test globale pour l'addon Elder Scrolls Online **MugShot**. Il détaille la pyramide de tests, les suites de tests automatisées hors-ligne, le prévisualiseur graphique interactif, ainsi que le protocole de recette manuelle en jeu pour les déploiements et mises à jour d'API.

---

## 1. Philosophie & Pyramide de Test

L'environnement ESO impose une approche à trois piliers :
1. **Tests Automatisés Hors-Ligne (CLI Lua)** : Exécutables sans lancer le client de jeu grâce au harnais de simulation (`EsoMock.lua`). Ils couvrent la logique métier, la transformation des données, la gestion d'état, les réglages et l'intégration interne (399 tests unitaires).
2. **Prévisualisation Graphique Interactive Hors-Ligne (Love2D Live UI)** : Permet de valider visuellement et dynamiquement le layout des contrôles, le défilement fluide des décomptes de buffs, l'étirement adaptatif sans icône, et le mode déplacement `/mugshot move` avec hot-reload immédiat.
3. **Protocole de Recette Manuelle En Jeu (Boîte Noire)** : Validation finale indispensable dans le moteur réel d'ESO (rendu des textures `.dds`, réactivité de la souris et scènes d'interface en raid).

```text
               ▲
              / \     Recette Manuelle en Jeu (Boîte Noire)
             /   \    - Raids (Rockgrove/Sanity's Edge), mannequins réels
            /─────\   - Scènes HUD (inventaire, carte, dialogue)
           /       \
          /         \  Prévisualisation Graphique Interactive (Love2D / tests/preview)
         /           \ - LayoutSolver ESO, Hot-Reload automatique (300ms), défilement live
        /─────────────\
       /               \ Tests d'Intégration & Mocks (tests/EsoMock.lua)
      /                 \- EsoAdapter, NativeFrameBridge, EventBindings, View, Main
     /───────────────────\
    /                     \ Tests Unitaires Purs (Lua Standard CLI)
   /                       \- TargetState, TargetPolicy, Presentation, Portraits, Localisation
  /─────────────────────────\
```

---

## 2. Suites de Tests Automatisées

L'ensemble des tests s'exécute d'une seule commande depuis la racine de l'addon :
```bash
lua tests/run.lua
```

### Inventaire des Suites

| Suite                 | Fichier                                                                 | Rôle & Périmètre                                                                                                                                                       |
|:----------------------|:------------------------------------------------------------------------|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **TargetState**       | [`tests/TargetStateTest.lua`](../tests/TargetStateTest.lua)             | Cycle de vie de l'état canonique, initialisation, reset atomique, incrémentation de génération.                                                                        |
| **TargetPolicy**      | [`tests/TargetPolicyTest.lua`](../tests/TargetPolicyTest.lua)           | Pattern Strategy : règles de visibilité conditionnelles (`exists == true`), cible vivante, filtre d'ennemis en Épreuve (`onlyHostileInTrials`) et extensibilité `RegisterStrategy`. |
| **Presentation**      | [`tests/PresentationTest.lua`](../tests/PresentationTest.lua)           | Formatage des nombres (`2.1m`), Flyweight timers (`TIMER_STRINGS`), buffer Zero-GC réutilisable in-place et rendu sans troncature artificielle.                        |
| **Portraits**         | [`tests/PortraitsTest.lua`](../tests/PortraitsTest.lua)                 | Résolution dynamique des portraits (boss d'épreuves, collectibles compagnons/assistants, compétences de familiers), fallbacks de classe et mannequins.                 |
| **Localisation**      | [`tests/LocalisationTest.lua`](../tests/LocalisationTest.lua)           | Intégrité des dictionnaires bilingues (en / fr), parité des clés, formattage avec arguments, et fallbacks.                                                             |
| **TargetController**  | [`tests/TargetControllerTest.lua`](../tests/TargetControllerTest.lua)   | Orchestration complète, gestion des modes déplacement et debug, mise à jour dynamique des réactions, détection de raid, et **barrière de génération (Generation Fence)**. |
| **EsoAdapter**        | [`tests/EsoAdapterTest.lua`](../tests/EsoAdapterTest.lua)               | Extraction sécurisée de l'identité, vie, bouclier, détection raid (`IsInTrial`), filtrage `castByPlayer` anti-encombrement en raid et tri ascendant des durées.        |
| **NativeFrameBridge** | [`tests/NativeFrameBridgeTest.lua`](../tests/NativeFrameBridgeTest.lua) | Suppression réversible du cadre natif (`ZO_TargetUnitFramereticleover`), respect des masquages par d'autres addons (`_wasHiddenByUs`), et résilience en cas d'absence. |
| **EventBindings**     | [`tests/EventBindingsTest.lua`](../tests/EventBindingsTest.lua)         | Inscription/désinscription des événements ESO, transition de zone (`EVENT_PLAYER_ACTIVATED`), filtres de puissance et d'unitTag, ticker d'effets 250ms.                 |
| **Settings**          | [`tests/SettingsTest.lua`](../tests/SettingsTest.lua)                   | Chargement, fusion récursive des options par défaut, migration automatique de schéma (`schemaVersion`), et persistance `Set()`.                                        |
| **TargetFrameView**   | [`tests/TargetFrameViewTest.lua`](../tests/TargetFrameViewTest.lua)     | Hiérarchie de contrôles UI, barres de santé/bouclier, badges d'alliance et de race, pool dynamique de buffs, Dirty Flags C++ UI et bordure cyan en mode déplacement.     |
| **MainIntegration**   | [`tests/MainIntegrationTest.lua`](../tests/MainIntegrationTest.lua)     | Démarrage via `EVENT_ADD_ON_LOADED`, enregistrement des commandes à deux mots (`/mugshot toggle|move|reset|trial|hodor|help`) et vérification de non-régression.      |

---

## 3. Prévisualisation Graphique Hors-Ligne (Love2D Live UI Preview)

Situé dans [`tests/preview/`](../tests/preview/README.md), ce harnais visuel permet de valider le comportement du cadre de cible en temps réel sans lancer le client ESO.

### Lancement
```bash
python tests/preview.py
# ou double-clic sur tests/preview.bat
```

### Fonctionnalités Clés
- **100 % Connecté au Moteur Réel** : Alimente directement `TargetController` via les événements ESO réels (`EVENT_RETICLE_TARGET_CHANGED`, `EVENT_POWER_UPDATE`, etc.).
- **Hot-Reloading à Chaud** : Surveille les 16 fichiers sources de l'addon toutes les 300ms ; toute sauvegarde (`Ctrl+S`) dans l'éditeur met à jour la fenêtre Love2D instantanément.
- **Scénarios & Contrôles** :
  - `[1-5]` : Bascule entre Boss (*Oaxiltso*), Compagnon (*Bastian*), Familier (*Familier instable*), Aperçu Joueur (`/mugshot move`), et Cible Sans Icône (étirement 100% de la jauge).
  - `[Gauche]` / `[Droite]` : Animation des PV en direct.
  - `[S]` : Sur-bouclier dynamique.
  - `[+]` / `[-]` : Ajout / retrait dynamique de buffs et débuffs.
  - `[T]` : Stress-test de 14 effets sur 2 rangées pour valider le passage à la ligne (10 slots/ligne) et l'expansion en hauteur du cadre.
  - `[M]` : Exécution réelle de la commande `/mugshot move`.
  - `[X]` : Exécution réelle de la commande `/mugshot trial` (bascule du filtre de raid).
  - `[R]` : Exécution réelle de la commande `/mugshot reset`.

---

## 4. Protocole de Recette Manuelle En Jeu (Boîte Noire)

Cette checklist doit être validée avant chaque publication de version ou mise à jour d'APIVersion.

### Étape 1 : Premier Lancement (Profil Vierge)
1. Supprimer ou renommer temporairement `SavedVariables/MugShotSV.lua`.
2. Se connecter sur un personnage en jeu.
3. Vérifier l'absence d'erreurs d'interface (UI Errors / BugCatcher).
4. Vérifier que le cadre se positionne par défaut à `TOPLEFT (100, 200)`.

### Étape 2 : Commandes Slash à Deux Mots & Mode Déplacement
1. **`/mugshot move` (Déverrouillage)** :
   * Le curseur de la souris doit apparaître (`SetGameCameraUIMode(true)`).
   * Le cadre affiche une prévisualisation **WYSIWYG** du joueur actuel (nom, santé, bouclier, icône de classe/avatar).
   * Une bordure cyan lumineuse entoure la barre de vie et le cadre de portrait.
   * Si le joueur n'a aucun buff, 3 icônes d'exemples doivent s'afficher.
2. **Glisser-Déplacer (Drag & Drop)** :
   * Cliquer et maintenir le bouton gauche sur n'importe quelle partie du cadre (barre de vie, portrait, conteneur de buffs).
   * Déplacer le cadre vers un nouvel endroit. Le déplacement doit être fluide et bloqué aux bords de l'écran (`ClampedToScreen`).
3. **`/mugshot move` (Verrouillage)** :
   * La caméra revient en mode normal.
   * La position doit être conservée et persistée dans `MugShotSV`.
4. **`/mugshot reset`** :
   * Vérifier que le cadre revient instantanément aux coordonnées `(100, 200)` et que le mode déplacement s'active.
5. **`/mugshot toggle [on|off]` (Désactivation/Réactivation)** :
   * Taper `/mugshot toggle` : le cadre MugShot disparaît, et le cadre de cible d'origine d'ESO réapparaît immédiatement sous le réticule.
   * Retapez `/mugshot toggle` : MugShot reprend le contrôle et masque à nouveau le cadre natif.
6. **`/mugshot trial [on|off]` (Filtre d'ennemis en Épreuve)** :
   * Taper `/mugshot trial on` en raid : le ciblage d'un allié masque la frame MugShot pour éviter la pollution visuelle.
   * Cibler un boss ou mob hostile : MugShot s'affiche normalement.

### Étape 3 : Scénarios de Combat & Ciblage
1. **Mannequin de raid (Target Dummy)** :
   * Cibler un *Target Iron Atronach* : vérifier le portrait spécifique, la barre rouge foncé, et le texte `21m/21m`.
2. **Transition Neutre → Hostile** :
   * Cibler un PNJ neutre (barre jaune `255, 215, 0`).
   * Attaquer le PNJ : au premier impact de dégâts, la barre doit immédiatement basculer en rouge vif sans désélectionner la cible.
3. **Ciblage Joueur & Avatars Hodor** :
   * Cibler un autre joueur ayant un avatar HodorReflexes / LibCustomIcons configuré : le portrait personnalisé et ses coordonnées UV doivent s'afficher.
   * Taper `/mugshot hodor` : le portrait doit basculer instantanément sur l'icône de classe native gamepad sans recharger l'interface.
4. **Bouclier d'absorption (Damage Shield)** :
   * Cibler une unité disposant d'un bouclier (ou soi-même en mode `/mugshot move` avec un bouclier actif) :
   * La jauge cyan translucide doit se superposer sur la barre de vie.
   * Le texte doit inclure la valeur entre crochets (ex: `24.3k/24.3k [3.6k]`).
5. **Comptes à rebours des Buffs/Debuffs** :
   * Appliquer un effet avec durée (ex: dot ou vulnérabilité) :
   * Le décompte doit s'égrener chaque seconde de façon fluide (géré par le ticker 250ms).
   * L'icône doit disparaître ou le slot se vider à l'expiration.

### Étape 4 : Intégration des Scènes HUD
1. Avoir une cible sous le réticule.
2. Appuyer sur `Entrée` pour ouvrir le chat : le cadre MugShot **doit rester visible** (`HUD_UI_SCENE`).
3. Ouvrir l'inventaire (`I`) ou la carte (`M`) : le cadre doit se masquer proprement avec le reste du HUD de combat.

---

## 5. Maintenance des Versions d'API

Lors de la sortie d'un nouveau patch majeur ou d'une mise à jour de l'API (ex: `101051` vers `101052`) :
1. Mettre à jour `## APIVersion` dans [`MugShot.txt`](../MugShot.txt).
2. Lancer la suite de test locale : `lua tests/run.lua`.
3. Vérifier les warnings de dépréciation d'API dans `EsoMock.lua`.
4. Effectuer une passe de recette manuelle complète sur le serveur PTS ou Live.
