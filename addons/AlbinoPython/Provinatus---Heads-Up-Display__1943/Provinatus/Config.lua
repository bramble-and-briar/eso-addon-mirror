ProvinatusConfig = {
  Name = "Provinatus",
  FriendlyName = "Provinatus",
  Author = "AlbinoPython",
  Version = "2.6.3",
  Website = "http://www.esoui.com/downloads/info1943-Provinatus.html",
  Feedback = "https://www.esoui.com/portal.php?uid=25876&a=listbugs",
  SlashCommand = "/provinatus",
  AccountWideVars = true,
  PrintInfoAtStart = false,
  Antiquities = {
    Enabled = false,
    Alpha = 1,
    Size = 20
  },
  AVA = {
    Enabled = false,
    OnlyUnderAttack,
    Alpha = 1,
    Size = 24,
    Objectives = false
  },
  Chat = {
    SaveChatCommands = false
  },
  Combat = {
    Enabled = false,
    Size = 24,
    Alpha = 1
  },
  Companion = {
    Enabled = false,
    Size = 24,
    Color = {
      r = 1,
      g = 1,
      b = 1,
      a = 1
    },
    BackgroundEnabled = false,
    BackgroundColor = {
      r = 0,
      g = 1,
      b = 0,
      a = 1
    },
    BackgroundTexture = "/art/fx/texture/aoe_circle.dds"
  },
  Compass = {
    Color = {
      r = 1,
      g = 1,
      b = 1
    },
    Alpha = 1,
    Size = 350,
    AlwaysOn = false,
    LockToHUD = true,
    Font = "ZoFontAnnounceMedium"
  },
  DaedricAnchors = {
    Enabled = false,
    Size = 24,
    Alpha = 1
  },
  Display = {
    RefreshRate = 60,
    Size = 350,
    X = 0,
    Y = 0,
    Offset = true,
    Fade = false,
    MinFade = 0.25,
    MaxDistance = 100,
    ShowDistant = true,
    ProjectionCode = 1, -- See Projection.lua for possible values
    Orthomultiplier = 1,
    LogToChat = false,
    TranslateDistance = 10,
    SizeChangeAmount = 10,
  },
  DropMarker = {
    -- Drop marker is enabled by virtue of having the hotkey setup
    Size = 24,
    Alpha = 1
  },
  DungeonChampions = {
    Enabled = false,
    ShowDefeated = false,
    Size = 24,
    Alpha = 1
  },
  HarvensPins = {
    Enabled = false,
    Size = 35,
    Alpha = 1
  },
  HarvestMap = {
    Enabled = false,
    Size = 24,
    Alpha = 1,
    Distance = 100,
    OnlySpawned = true
  },
  LoreBooks = {
    Enabled = false,
    ShowCollected = false,
    EideticMemory = false,
    Size = 24,
    Alpha = 1
  },
  MapPins = {
    Enabled = false,
    Size = 24,
    Alpha = 1,
    PinTypes = {
      KnownSkyShards = {
        MenuTitle = "Known SkyShards",
        Enabled = false,
        Texture = "/esoui/art/tutorial/gamepad/achievement_categoryicon_skyshards.dds",
        PinName = "pinType_Skyshards_done"
      },
      UnknownSkyShards = {
        MenuTitle = "Unknown SkyShards",
        Enabled = false,
        Texture = "/MapPins/Skyshard_1.dds",
        PinName = "pinType_Skyshards"
      },
      Chests = {
        MenuTitle = "Treasure Chests",
        Enabled = false,
        Texture = "/MapPins/Chest_1.dds",
        PinName = "pinType_Treasure_Chests"
      },
      LoreBooks = {
        MenuTitle = "Lore Books",
        Enabled = false,
        Texture = "/MapPins/Lorebook_1.dds",
        PinName = "pinType_Lore_books"
      },
      DelveBosses = {
        MenuTitle = "Undefeated Bosses",
        Enabled = false,
        Texture = "/esoui/art/icons/poi/poi_groupboss_incomplete.dds",
        PinName = "pinType_Delve_bosses"
      },
      DelveBossesDefeated = {
        MenuTitle = "Defeated Bosses",
        Enabled = false,
        Texture = "/esoui/art/icons/poi/poi_groupboss_complete.dds",
        PinName = "pinType_Delve_bosses_done"
      },
      TreasureMaps = {
        MenuTitle = "Treasure Maps",
        Enabled = false,
        Texture = "/MapPins/Treasure_1.dds",
        PinName = "pinType_Treasure_Maps"
      }
    }
  },
  MyIcon = {
    Enabled = false,
    Size = 24,
    Alpha = 1
  },
  POI = {
    Enabled = false,
    ShowDiscovered = false,
    Size = 24,
    Alpha = 1
  },
  Pointer = {
    -- Controls transparency of the central crown pointer thing.
    Enabled = true,
    Alpha = 1,
    Size = 50
  },
  Psijic = {
    Enabled = false,
    Alpha = 1,
    Size = 24
  },
  Quest = {
    Enabled = false,
    ShowInactive = false,
    Size = 24,
    Alpha = 1,
    InactiveSize = 24,
    InactiveAlpha = 1
  },
  RallyPoint = {
    Enabled = true,
    Size = 50,
    Alpha = 1
  },
  ServicePins = {
    Enabled = false,
    Size = 24,
    Alpha = 1
  },
  Skyshards = {
    Enabled = false,
    ShowCollected = false,
    Collected = {
      Size = 24,
      Alpha = 1
    },
    Uncollected = {
      Size = 24,
      Alpha = 1
    }
  },
  Team = {
    Enabled = true,
    ShowRoleIcons = false,
    Growth = {
      Enabled = false,
      MaxSize = 4,
      OnlyInCombat = true
    },
    Lifebars = {
      Enabled = true,
      OnlyInCombat = true
    },
    Leader = {
      Size = 50,
      Alpha = 1,
      DrawOnTop = false,
      OnlyWhenDead = false
    },
    Teammate = {
      Size = 24,
      Alpha = 1,
      OnlyWhenDead = false
    }
  },
  TreasureMaps = {
    Enabled = false,
    Size = 24,
    Alpha = 1
  },
  Waypoint = {
    Enabled = false,
    Size = 24,
    Alpha = 1
  },
  WorldEvent = {
    Enabled = false,
    Size = 50,
    Alpha = 1
  }
}
