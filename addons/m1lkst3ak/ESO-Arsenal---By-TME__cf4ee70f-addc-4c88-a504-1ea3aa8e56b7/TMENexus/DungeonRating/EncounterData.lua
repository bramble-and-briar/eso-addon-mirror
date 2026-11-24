-- Curated IDs and annotations extracted from CrutchAlerts 2.28.2, alerts/AbilityData.lua
-- Supplemental dungeon event IDs from zones/dungeons/BedlamVeil.lua and CoralAerie.lua
-- Attribution: Kyzderp / CrutchAlerts contributors. Not a full boss database.
-- Informational mechanics are NOT automatically mechanic failures.
DungeonRatingEncounterData = {
  [126] = { -- Elden Hollow I
    [9944] = {name="Necrotic Burst (Canonreeve Oraneth)", alert="MECHANIC"},
  },
  [146] = { -- Wayrest Sewers I
    [5699] = {name="Shadowstep (Allene Pellingare)", alert="MECHANIC"},
  },
  [1009] = { -- Fang Lair
    [96826] = {name="Impaling Shards (Thurvokun)", alert="MECHANIC"},
    [97022] = {name="Wraith Speed", alert="MECHANIC"},
    [98597] = {name="Haunting Spectre (Sabina)", alert="MECHANIC"},
    [102615] = {name="Spectral Chains (Sabina)", alert="MECHANIC"},
  },
  [1080] = { -- Frostvault
    [113465] = {name="Reckless Charge (Warlord Tzogvin)", alert="MECHANIC"},
  },
  [1229] = { -- The Cauldron
    [146179] = {name="Galvanic Blow (Baron Zaudrus conal that applies Galvanic Burst)", alert="MECHANIC"},
    [146314] = {name="Execute (Taskmaster Viccia interruptible \"oneshot\" but is blockable)", alert="INTERRUPT"},
  },
  [1267] = { -- Red Petal Bastion
    [154369] = {name="Opalescent Impale", alert="MECHANIC"},
    [157573] = {name="Dire Gaze (watcher interruptible)", alert="INTERRUPT"},
  },
  [1268] = { -- The Dread Cellar
    [155184] = {name="Catastrophe (Magma Incarnate)", alert="MECHANIC"},
    [156509] = {name="Deluge of Pain (Scorion Broodlord interruptible)", alert="INTERRUPT"},
  },
  [1301] = { -- Coral Aerie
    [158700] = {name="Gryphon Ofallo", alert="MECHANIC"},
    [158715] = {name="Gryphon Iliata", alert="MECHANIC"},
    [158716] = {name="Gryphon Mafremare", alert="MECHANIC"},
    [163184] = {name="Gryphon Ofallo HM", alert="MECHANIC"},
    [163185] = {name="Gryphon Iliata HM", alert="MECHANIC"},
    [163188] = {name="Gryphon Mafremare HM", alert="MECHANIC"},
    [163597] = {name="Gryphon Kargaeda HM", alert="MECHANIC"},
    [168947] = {name="Lingering Current", alert="MECHANIC"},
  },
  [1302] = { -- Shipwright's Regret
    [163676] = {name="Jet (Numirril when he jets to a player)", alert="MECHANIC"},
    [164480] = {name="Smash (Drowned Hulk)", alert="MECHANIC"},
    [165021] = {name="Jet (Numirril when he jets away)", alert="MECHANIC"},
    [167906] = {name="Jet (Numirril when he jets to the edge to go into immune phase)", alert="MECHANIC"},
  },
  [1360] = { -- Earthen Root Enclave
    [116859] = {name="Crush (Monstrous Bear)", alert="MECHANIC"},
    [170650] = {name="Wild Stampede (Static Stampede, GAINED / DURATION tho)", alert="MECHANIC"},
    [170830] = {name="Petrify (1 second cast, and the 11 second channel)", alert="MECHANIC"},
    [171127] = {name="Guttural Roar (5 seconds channel of the cone probably)", alert="MECHANIC"},
    [172410] = {name="Crumble (Archdruid Devyric rock pillar things)", alert="MECHANIC"},
  },
  [1361] = { -- Graven Deep
    [171935] = {name="Necrotic Rain (Varzunon)", alert="MECHANIC"},
  },
  [1390] = { -- Scrivener's Hall
    [182334] = {name="Rain of Fire (Valinna)", alert="MECHANIC"},
    [182393] = {name="Immolation Trap (Valinna)", alert="MECHANIC"},
  },
  [1470] = { -- Oathsworn Pit
    [203989] = {name="Hurl Axe (Anthelmir's Construct)", alert="MECHANIC"},
  },
  [1471] = { -- Bedlam Veil
    [206488] = {name="Glass Stomp (Shattered Champion)", alert="MECHANIC"},
    [207005] = {name="Malediction (The Blind)", alert="MECHANIC"},
    [213837] = {name="Besiege — The Blind (boss health threshold check)", alert="MECHANIC"},
  },
  [1496] = { -- Exiled Redoubt
    [223935] = {name="Six Sword Assault (Squall)", alert="MECHANIC"},
    [224463] = {name="Summon Fire Atro (Squall, first one)", alert="MECHANIC"},
    [224473] = {name="Summon Ice Atro (Squall, first)", alert="MECHANIC"},
    [224476] = {name="Summon Shock Atro (Squall, first)", alert="MECHANIC"},
    [230349] = {name="Summon Fire Atro (Squall, next 3)", alert="MECHANIC"},
    [230383] = {name="Summon Ice Atro (Squall, second)", alert="MECHANIC"},
    [230386] = {name="Summon Shock Atro (Squall, second)", alert="MECHANIC"},
  },
  [1497] = { -- Lep Seclusa
    [109231] = {name="Bog Slam (Argonian Behemoth)", alert="MECHANIC"},
    [224822] = {name="Blast Powder (Noriwen)", alert="MECHANIC"},
    [226181] = {name="Venom Eruption (Garvin the Tracker)", alert="MECHANIC"},
    [229247] = {name="Forbidden Knowledge (Orpheon the Tactician)", alert="MECHANIC"},
    [233821] = {name="Cyclone (Flame Gryphon)", alert="MECHANIC"},
  },
  [1552] = { -- Black Gem Foundry
    [240363] = {name="Soul Focus (Black Gem Monstrosity, initial 2750 begin, then 7000 begin)", alert="MECHANIC"},
    [240426] = {name="Seismic Splinters", alert="MECHANIC"},
    [240665] = {name="Charged Lightning?", alert="MECHANIC"},
    [241326] = {name="Annihilation", alert="MECHANIC"},
    [241327] = {name="Annihilation", alert="MECHANIC"},
    [241328] = {name="Annihilation", alert="MECHANIC"},
    [241329] = {name="Annihilation", alert="MECHANIC"},
    [241685] = {name="Fluctuating Esseence GRN [sic] (3000 when the fountains become green)", alert="MECHANIC"},
    [241854] = {name="Soulbinding Slam (High Soulbinder Vykand)", alert="MECHANIC"},
    [241863] = {name="Soul Cascade (Vykand)", alert="MECHANIC"},
    [246168] = {name="Acute Enervation (initial targeting of first, for some reason is 500 then 2800, but then not another ~1s until the real cast)", alert="MECHANIC"},
  },
}
