--- @class Srendarr
local Srendarr = _G['Srendarr'] -- grab addon table from global
local GetAbilityName = GetAbilityName

-- CONST DECLARATIONS : referenced locally in other files when needed --
Srendarr.AURA_UPDATE_RATE = 0.05
Srendarr.CAST_UPDATE_RATE = 0.02
Srendarr.MIN_TIMER = 1.4

Srendarr.NUM_DISPLAY_FRAMES = 62 -- 58
Srendarr.GROUP_START_FRAME = 15  -- 11
Srendarr.GROUP_END_FRAME = 38    -- 34
Srendarr.GROUP_DSTART_FRAME = 39 -- 35
Srendarr.GROUP_DEND_FRAME = 62   -- 58

Srendarr.GROUP_BUFFS = 15
Srendarr.RAID_BUFFS = 16
Srendarr.GROUP_DEBUFFS = 17
Srendarr.RAID_DEBUFFS = 18

Srendarr.GroupEnabled = true
Srendarr.IsPlayerGrouped = false
Srendarr.SampleAurasActive = false
Srendarr.KeybindVisibility = true
Srendarr.IsCasting = false

Srendarr.GROUP_PLAYER_SHORT = 1 -- categories to divide up auras for positioning in
Srendarr.GROUP_PLAYER_LONG = 2  -- the (player chosen) display frames
Srendarr.GROUP_PLAYER_TOGGLED = 3
Srendarr.GROUP_PLAYER_PASSIVE = 4
Srendarr.GROUP_PLAYER_DEBUFF = 5
Srendarr.GROUP_PLAYER_GROUND = 6
Srendarr.GROUP_PLAYER_MAJOR = 7
Srendarr.GROUP_PLAYER_MINOR = 8
Srendarr.GROUP_PLAYER_ENCHANT = 9
Srendarr.GROUP_TARGET_BUFF = 10
Srendarr.GROUP_TARGET_DEBUFF = 11
Srendarr.ExtraFrame1 = 12
Srendarr.ExtraFrame2 = 13
Srendarr.ExtraFrame3 = 14
Srendarr.GROUP_CDTRACKER = 100
Srendarr.GROUP_CDBAR = 101
Srendarr.GROUP_GROUP1 = 200
Srendarr.GROUP_GROUP2 = 201
Srendarr.GROUP_GROUP3 = 202
Srendarr.GROUP_GROUP4 = 203
Srendarr.GROUP_GROUP5 = 204
Srendarr.GROUP_GROUP6 = 205
Srendarr.GROUP_GROUP7 = 206
Srendarr.GROUP_GROUP8 = 207
Srendarr.GROUP_GROUP9 = 208
Srendarr.GROUP_GROUP10 = 209
Srendarr.GROUP_GROUP11 = 210
Srendarr.GROUP_GROUP12 = 211
Srendarr.GROUP_GROUP13 = 212
Srendarr.GROUP_GROUP14 = 213
Srendarr.GROUP_GROUP15 = 214
Srendarr.GROUP_GROUP16 = 215
Srendarr.GROUP_GROUP17 = 216
Srendarr.GROUP_GROUP18 = 217
Srendarr.GROUP_GROUP19 = 218
Srendarr.GROUP_GROUP20 = 219
Srendarr.GROUP_GROUP21 = 220
Srendarr.GROUP_GROUP22 = 221
Srendarr.GROUP_GROUP23 = 222
Srendarr.GROUP_GROUP24 = 223
Srendarr.GROUP_GROUPD1 = 224
Srendarr.GROUP_GROUPD2 = 225
Srendarr.GROUP_GROUPD3 = 226
Srendarr.GROUP_GROUPD4 = 227
Srendarr.GROUP_GROUPD5 = 228
Srendarr.GROUP_GROUPD6 = 229
Srendarr.GROUP_GROUPD7 = 230
Srendarr.GROUP_GROUPD8 = 231
Srendarr.GROUP_GROUPD9 = 232
Srendarr.GROUP_GROUPD10 = 233
Srendarr.GROUP_GROUPD11 = 234
Srendarr.GROUP_GROUPD12 = 235
Srendarr.GROUP_GROUPD13 = 236
Srendarr.GROUP_GROUPD14 = 237
Srendarr.GROUP_GROUPD15 = 238
Srendarr.GROUP_GROUPD16 = 239
Srendarr.GROUP_GROUPD17 = 240
Srendarr.GROUP_GROUPD18 = 241
Srendarr.GROUP_GROUPD19 = 242
Srendarr.GROUP_GROUPD20 = 243
Srendarr.GROUP_GROUPD21 = 244
Srendarr.GROUP_GROUPD22 = 245
Srendarr.GROUP_GROUPD23 = 246
Srendarr.GROUP_GROUPD24 = 247

Srendarr.AURA_TYPE_TIMED = 1
Srendarr.AURA_TYPE_TOGGLED = 2
Srendarr.AURA_TYPE_PASSIVE = 3
Srendarr.DEBUFF_TYPE_PASSIVE = 4
Srendarr.DEBUFF_TYPE_TIMED = 5

Srendarr.TYPE_ENCHANT = 1
Srendarr.TYPE_SPECIAL = 2
Srendarr.TYPE_COOLDOWN = 3
Srendarr.TYPE_RELEASE = 4
Srendarr.TYPE_TARGET_DEBUFF = 5
Srendarr.TYPE_TARGET_AURA = 6
Srendarr.TYPE_GRIM = 7
Srendarr.TYPE_CASTBAR = 8

Srendarr.AURA_HEIGHT = 40

Srendarr.AURA_STYLE_FULL = 1
Srendarr.AURA_STYLE_ICON = 2
Srendarr.AURA_STYLE_MINI = 3
Srendarr.AURA_STYLE_GROUPB = 4
Srendarr.AURA_STYLE_GROUPD = 5

Srendarr.AURA_GROW_UP = 1
Srendarr.AURA_GROW_DOWN = 2
Srendarr.AURA_GROW_LEFT = 3
Srendarr.AURA_GROW_RIGHT = 4
Srendarr.AURA_GROW_CENTERUP = 5
Srendarr.AURA_GROW_CENTERDOWN = 6
Srendarr.AURA_GROW_CENTERLEFT = 7
Srendarr.AURA_GROW_CENTERRIGHT = 8

Srendarr.AURA_SORT_NAMEASC = 1
Srendarr.AURA_SORT_TIMEASC = 2
Srendarr.AURA_SORT_CASTASC = 3
Srendarr.AURA_SORT_NAMEDESC = 4
Srendarr.AURA_SORT_TIMEDESC = 5
Srendarr.AURA_SORT_CASTDESC = 6

Srendarr.AURA_TIMERLOC_HIDDEN = 1
Srendarr.AURA_TIMERLOC_OVER = 2
Srendarr.AURA_TIMERLOC_ABOVE = 3
Srendarr.AURA_TIMERLOC_BELOW = 4

Srendarr.STR_PROMBYID = 'ProminentByID'
Srendarr.STR_BLOCKBYID = 'BlockByID'
Srendarr.STR_GROUPBUFFBYID = 'GroupBuffByID'
Srendarr.STR_GROUPDEBUFFBYID = 'GroupDebuffByID'

Srendarr.maxSearchStage = 6          -- number * 50k (currently 300000) is the highest ability ID Srendarr will search for - increases with game updates (Phinix) - last highest 272637 on 8-26-26
Srendarr.maxAbilityID = 300000       -- addon will not look for abilities with ID above this limit (Phinix)
Srendarr.castBarID = 916120          -- unique ID so castbar sample can show in menus (Phinix)

Srendarr.equippedSets = {}           -- track equipped sets with enough pieces to allow cooldowns to proc for event filters (Phinix)
Srendarr.equippedSpecial = {}        -- separate table for tracking special case gear sets like Bahsei's Mania (Phinix)
Srendarr.OnPlayerActivatedAlive = {} -- placeholder (Phinix)
Srendarr.OnEquipChange = {}          -- placeholder (Phinix)

function Srendarr.ZOSName(abilityID) -- formats the name for the passed abilityID and removes gender tags
    return zo_strformat('<<t:1>>', GetAbilityName(abilityID))
end

-- register our new default sound with LibMediaProvider (cannot be a localized name for internal constant refs)
LibMediaProvider:Register('sound', 'Srendarr Ability Proc', SOUNDS.DEATH_RECAP_KILLING_BLOW_SHOWN)

local defaults =
{
    -- last logged in character
    lastCharname            = '',
    -- general
    enchantAltIcons         = false,
    auraCooldown            = true,
    auraBorder              = true,
    auraBackground          = true,
    hideFullBar             = false,
    consolidateEnabled      = true,
    shortBuffThreshold      = 60,
    procEnableAnims         = true,
    grimProcAnims           = true,
    gearProcAnims           = true,
    gearProcCDText          = false,
    procPlaySound           = 'Srendarr Ability Proc', -- can be set to None by user
    procModifier            = true,
    procVolume              = 100,
    groupAuraMode           = 1,
    raidAuraMode            = 1,
    passiveEffectsAsPassive = true,
    showCombatEvents        = false,
    disableSpamControl      = false,
    setIdDebug              = false,
    manualDebug             = true,
    onlyPlayerDebug         = false,
    showNoNames             = false,
    showVerboseDebug        = false,
    displayAbilityID        = false,
    hideOnDeadTargets       = false,
    showTenths              = 5,
    showSSeconds            = true,
    showSeconds             = false,
    onlyTargetMajor         = false,
    frameVersion            = 0,
    numChecksPVP            = 3,
    auraGroups              =
    {
        [Srendarr.GROUP_PLAYER_SHORT]   = 6, -- (1) set the displayFrame that will display this grouping
        [Srendarr.GROUP_PLAYER_LONG]    = 3, -- (2) multiple groupings can go to a given frame
        [Srendarr.GROUP_PLAYER_TOGGLED] = 3, -- (3)
        [Srendarr.GROUP_PLAYER_PASSIVE] = 3, -- (4) a setting of 0 means don't display this grouping at all
        [Srendarr.GROUP_PLAYER_DEBUFF]  = 7, -- (5)
        [Srendarr.GROUP_PLAYER_GROUND]  = 8, -- (6)
        [Srendarr.GROUP_PLAYER_MAJOR]   = 6, -- (7)
        [Srendarr.GROUP_PLAYER_MINOR]   = 6, -- (8)
        [Srendarr.GROUP_PLAYER_ENCHANT] = 1, -- (9)
        [Srendarr.GROUP_TARGET_BUFF]    = 5, -- (10)
        [Srendarr.GROUP_TARGET_DEBUFF]  = 8, -- (11)
        [Srendarr.GROUP_CDTRACKER]      = 4, -- (100)
        [Srendarr.GROUP_CDBAR]          = 0, -- (101)
        [Srendarr.ExtraFrame1]          = 0,
        [Srendarr.ExtraFrame2]          = 0,
        [Srendarr.ExtraFrame3]          = 0,
        [Srendarr.GROUP_GROUP1]         = 15,
        [Srendarr.GROUP_GROUP2]         = 16,
        [Srendarr.GROUP_GROUP3]         = 17,
        [Srendarr.GROUP_GROUP4]         = 18,
        [Srendarr.GROUP_GROUP5]         = 19,
        [Srendarr.GROUP_GROUP6]         = 20,
        [Srendarr.GROUP_GROUP7]         = 21,
        [Srendarr.GROUP_GROUP8]         = 22,
        [Srendarr.GROUP_GROUP9]         = 23,
        [Srendarr.GROUP_GROUP10]        = 24,
        [Srendarr.GROUP_GROUP11]        = 25,
        [Srendarr.GROUP_GROUP12]        = 26,
        [Srendarr.GROUP_GROUP13]        = 27,
        [Srendarr.GROUP_GROUP14]        = 28,
        [Srendarr.GROUP_GROUP15]        = 29,
        [Srendarr.GROUP_GROUP16]        = 30,
        [Srendarr.GROUP_GROUP17]        = 31,
        [Srendarr.GROUP_GROUP18]        = 32,
        [Srendarr.GROUP_GROUP19]        = 33,
        [Srendarr.GROUP_GROUP20]        = 34,
        [Srendarr.GROUP_GROUP21]        = 35,
        [Srendarr.GROUP_GROUP22]        = 36,
        [Srendarr.GROUP_GROUP23]        = 37,
        [Srendarr.GROUP_GROUP24]        = 38,
        [Srendarr.GROUP_GROUPD1]        = 39,
        [Srendarr.GROUP_GROUPD2]        = 40,
        [Srendarr.GROUP_GROUPD3]        = 41,
        [Srendarr.GROUP_GROUPD4]        = 42,
        [Srendarr.GROUP_GROUPD5]        = 43,
        [Srendarr.GROUP_GROUPD6]        = 44,
        [Srendarr.GROUP_GROUPD7]        = 45,
        [Srendarr.GROUP_GROUPD8]        = 46,
        [Srendarr.GROUP_GROUPD9]        = 47,
        [Srendarr.GROUP_GROUPD10]       = 48,
        [Srendarr.GROUP_GROUPD11]       = 49,
        [Srendarr.GROUP_GROUPD12]       = 50,
        [Srendarr.GROUP_GROUPD13]       = 51,
        [Srendarr.GROUP_GROUPD14]       = 52,
        [Srendarr.GROUP_GROUPD15]       = 53,
        [Srendarr.GROUP_GROUPD16]       = 54,
        [Srendarr.GROUP_GROUPD17]       = 55,
        [Srendarr.GROUP_GROUPD18]       = 56,
        [Srendarr.GROUP_GROUPD19]       = 57,
        [Srendarr.GROUP_GROUPD20]       = 58,
        [Srendarr.GROUP_GROUPD21]       = 59,
        [Srendarr.GROUP_GROUPD22]       = 60,
        [Srendarr.GROUP_GROUPD23]       = 61,
        [Srendarr.GROUP_GROUPD24]       = 62,
    },
    grimTracker             =
    {                                        -- track stacks for refreshing expired Grim Focus morphs when recast (Phinix)
        [122585] = { stacks = 0, slot = 0 }, -- Grim Focus
        [122586] = { stacks = 0, slot = 0 }, -- Merciless Resolve
        [122587] = { stacks = 0, slot = 0 }, -- Relentless Focus
    },

    prominentDB             = {}, -- tables for custom aura placement through Prominent system
    groupBuffWhitelist      = {}, -- list of buffs that are filtered to group frames
    groupDebuffWhitelist    = {}, -- list of debuffs that are filtered to group frames
    blacklist               = {}, -- list of auras that are to be blacklisted from display
    updateDB                = {}, -- temp table for Major/Minor database update export
    toggled                 = {}, -- temp table for toggledAuras patch export (GetToggled)

    -- filters
    filtersGroup            =
    {
        groupBuffsEnabled    = false,
        groupDebuffsEnabled  = false,
        groupBuffBlacklist   = false,
        groupDebuffBlacklist = true,
        groupBuffDuration    = true,
        groupDebuffDuration  = true,
        groupBuffOnlyPlayer  = false,
        groupBuffThreshold   = 45,
        groupDebuffThreshold = 45,
    },
    filtersPlayer           =
    {
        esoplus       = true, -- as these are filters, false means DO show this filter category
        cyrodiil      = false,
        disguise      = false,
        mundusBoon    = false,
        soulSummons   = false,
        vampLycan     = false,
        vampLycanBite = false,
    },
    filtersTarget           =
    {
        esoplus           = true, -- as these are filters, false means DO show this filter category
        cyrodiil          = false,
        disguise          = false,
        majorEffects      = false,
        minorEffects      = false,
        mundusBoon        = false,
        soulSummons       = false,
        vampLycan         = false,
        vampLycanBite     = false,
        onlyPlayerDebuffs = true,
    },
    castBar                 =
    {
        enabled    = true,
        base       = { point = BOTTOM, x = 0, y = -160, alpha = 1.0, calpha = 1.0, scale = 1.0 },
        nameShow   = true,
        nameFont   = 'Univers 67',
        nameStyle  = 'soft-shadow-thick',
        nameSize   = 15,
        nameColor  = { 0.9, 0.9, 0.9, 1.0 },
        timerShow  = true,
        timerFont  = 'Univers 67',
        timerStyle = 'soft-shadow-thick',
        timerSize  = 15,
        timerColor = { 0.9, 0.9, 0.9, 1.0 },
        barReverse = false, -- bar alignment direction
        barGloss   = true,
        barWidth   = 255,
        barColor   = { r1 = 0, g1 = 0.1843, b1 = 0.5098, r2 = 0.3215, g2 = 0.8431, b2 = 1 },
    },
    displayFrames           =
    {
        -- https://wiki.esoui.com/Control:SetAnchor
        [1] =
        {
            base              = { point = BOTTOM, x = 273.1, y = -22.6, alpha = 1.0, calpha = 1.0, scale = 1.15, id = 1 },
            style             = Srendarr.AURA_STYLE_ICON, -- FULL|ICON|MINI|GROUP|AURA_STYLE_GROUPB|AURA_STYLE_GROUPD
            auraGrowth        = Srendarr.AURA_GROW_RIGHT, -- UP|DOWN|LEFT|LEFTCENTER|RIGHT|RIGHTCENTER (valid choices vary based on style)
            auraPadding       = 4,
            auraFadeTime      = 0,
            auraSort          = Srendarr.AURA_SORT_TIMEASC, -- NAME|TIME|CAST + ASC|DESC
            auraClassOverride = 3,                          -- whether all auras in this frame should be treated as buffs or debuffs regardless of type. 3 is off.
            hideFullBar       = false,                      -- in styles with a timer bar, only show the aura name instead
            auraCooldown      = true,                       -- use animated timer aura icon display for this frame
            auraBorder        = true,                       -- use the game's default icon border when not using Srendarr's black background
            auraBackground    = true,                       -- show a black contrast background behind icon mode auras
            highlightToggled  = true,                       -- shows the same 'toggled on' highlight action buttons do on toggles
            -- 	enableTooltips		= false,						-- show mouseover tooltip for auraName in ICON mode
            nameFont          = 'Univers 67',
            nameStyle         = 'soft-shadow-thick',
            nameSize          = 16,
            nameColor         = { 0.9, 0.9, 0.9, 1.0 },
            timerFont         = 'Univers 67',
            timerStyle        = 'soft-shadow-thick',
            timerSize         = 14,
            timerColor        = { 0.9, 0.9, 0.9, 1.0 },
            timerLocation     = Srendarr.AURA_TIMERLOC_ABOVE, -- ABOVE|BELOW|OVER|HIDDEN (valid choices based on style)
            timerHMS          = true,
            barReverse        = true,                         -- bar alignment direction (and icon placement in the FULL style)
            barGloss          = true,
            barWidth          = 160,
            cooldownColors    =
            {
                [Srendarr.AURA_TYPE_TIMED]   = { r1 = 0, g1 = 1, b1 = 0 },
                [Srendarr.DEBUFF_TYPE_TIMED] = { r1 = 0.6667, g1 = 0, b1 = 1 },
            },
            barColors         =
            {
                [Srendarr.AURA_TYPE_TIMED]     = { r1 = 0, g1 = 0.1843, b1 = 0.5098, r2 = 0.3215, g2 = 0.8431, b2 = 1 },
                [Srendarr.AURA_TYPE_TOGGLED]   = { r1 = 0.7764, g1 = 0.6000, b1 = 0.1137, r2 = 0.9725, g2 = 0.8745, b2 = 0.2941 },
                [Srendarr.AURA_TYPE_PASSIVE]   = { r1 = 0.4196, g1 = 0.3803, b1 = 0.2313, r2 = 0.4196, g2 = 0.3803, b2 = 0.2313 },
                [Srendarr.DEBUFF_TYPE_PASSIVE] = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
                [Srendarr.DEBUFF_TYPE_TIMED]   = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
            },
        },
        [2] =
        {
            base              = { point = BOTTOM, x = -269.6, y = -22.6, alpha = 1.0, calpha = 1.0, scale = 1.15, id = 2 },
            style             = Srendarr.AURA_STYLE_ICON, -- FULL|ICON|MINI|GROUP|AURA_STYLE_GROUPB|AURA_STYLE_GROUPD
            auraGrowth        = Srendarr.AURA_GROW_LEFT,  -- UP|DOWN|LEFT|RIGHT|CENTERLEFT|CENTERRIGHT (valid choices vary based on style)
            auraPadding       = 4,
            auraFadeTime      = 0,
            auraSort          = Srendarr.AURA_SORT_TIMEASC, -- NAME|TIME|CAST + ASC|DESC
            auraClassOverride = 3,                          -- whether all auras in this frame should be treated as buffs or debuffs regardless of type. 3 is off.
            hideFullBar       = false,                      -- in styles with a timer bar, only show the aura name instead
            auraCooldown      = true,                       -- use animated timer aura icon display for this frame
            auraBorder        = true,                       -- use the game's default icon border when not using Srendarr's black background
            auraBackground    = true,                       -- show a black contrast background behind icon mode auras
            highlightToggled  = true,                       -- shows the same 'toggled on' highlight action buttons do on toggles
            -- 	enableTooltips		= false,						-- show mouseover tooltip for auraName in ICON mode
            nameFont          = 'Univers 67',
            nameStyle         = 'soft-shadow-thick',
            nameSize          = 16,
            nameColor         = { 0.9, 0.9, 0.9, 1.0 },
            timerFont         = 'Univers 67',
            timerStyle        = 'soft-shadow-thick',
            timerSize         = 14,
            timerColor        = { 0.9, 0.9, 0.9, 1.0 },
            timerLocation     = Srendarr.AURA_TIMERLOC_OVER, -- ABOVE|BELOW|OVER|HIDDEN (valid choices based on style)
            timerHMS          = true,
            barReverse        = true,                        -- bar alignment direction (and icon placement in the FULL style)
            barGloss          = true,
            barWidth          = 160,
            cooldownColors    =
            {
                [Srendarr.AURA_TYPE_TIMED]   = { r1 = 0, g1 = 1, b1 = 0 },
                [Srendarr.DEBUFF_TYPE_TIMED] = { r1 = 0.6667, g1 = 0, b1 = 1 },
            },
            barColors         =
            {
                [Srendarr.AURA_TYPE_TIMED]     = { r1 = 0, g1 = 0.1843, b1 = 0.5098, r2 = 0.3215, g2 = 0.8431, b2 = 1 },
                [Srendarr.AURA_TYPE_TOGGLED]   = { r1 = 0.7764, g1 = 0.6000, b1 = 0.1137, r2 = 0.9725, g2 = 0.8745, b2 = 0.2941 },
                [Srendarr.AURA_TYPE_PASSIVE]   = { r1 = 0.4196, g1 = 0.3803, b1 = 0.2313, r2 = 0.4196, g2 = 0.3803, b2 = 0.2313 },
                [Srendarr.DEBUFF_TYPE_PASSIVE] = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
                [Srendarr.DEBUFF_TYPE_TIMED]   = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
            },
        },
        [3] =
        {
            base              = { point = TOPRIGHT, x = -259.2, y = 6.2, alpha = 1.0, calpha = 1.0, scale = 1.0, id = 3 },
            style             = Srendarr.AURA_STYLE_ICON, -- FULL|ICON|MINI|GROUP|AURA_STYLE_GROUPB|AURA_STYLE_GROUPD
            auraGrowth        = Srendarr.AURA_GROW_LEFT,  -- UP|DOWN|LEFT|RIGHT|CENTERLEFT|CENTERRIGHT (valid choices vary based on style)
            auraPadding       = 4,
            auraFadeTime      = 0,
            auraSort          = Srendarr.AURA_SORT_TIMEASC, -- NAME|TIME|CAST + ASC|DESC
            auraClassOverride = 3,                          -- whether all auras in this frame should be treated as buffs or debuffs regardless of type. 3 is off.
            hideFullBar       = false,                      -- in styles with a timer bar, only show the aura name instead
            auraCooldown      = false,                      -- use animated timer aura icon display for this frame
            auraBorder        = true,                       -- use the game's default icon border when not using Srendarr's black background
            auraBackground    = true,                       -- show a black contrast background behind icon mode auras
            highlightToggled  = true,                       -- shows the same 'toggled on' highlight action buttons do on toggles
            -- 	enableTooltips		= true,							-- show mouseover tooltip for auraName in ICON mode
            nameFont          = 'Univers 67',
            nameStyle         = 'soft-shadow-thick',
            nameSize          = 16,
            nameColor         = { 0.9, 0.9, 0.9, 1.0 },
            timerFont         = 'Univers 67',
            timerStyle        = 'soft-shadow-thick',
            timerSize         = 14,
            timerColor        = { 0.9, 0.9, 0.9, 1.0 },
            timerLocation     = Srendarr.AURA_TIMERLOC_BELOW, -- ABOVE|BELOW|OVER|HIDDEN (valid choices based on style)
            timerHMS          = true,
            barReverse        = true,                         -- bar alignment direction (and icon placement in the FULL style)
            barGloss          = true,
            barWidth          = 160,
            cooldownColors    =
            {
                [Srendarr.AURA_TYPE_TIMED]   = { r1 = 0, g1 = 1, b1 = 0 },
                [Srendarr.DEBUFF_TYPE_TIMED] = { r1 = 0.6667, g1 = 0, b1 = 1 },
            },
            barColors         =
            {
                [Srendarr.AURA_TYPE_TIMED]     = { r1 = 0, g1 = 0.1843, b1 = 0.5098, r2 = 0.3215, g2 = 0.8431, b2 = 1 },
                [Srendarr.AURA_TYPE_TOGGLED]   = { r1 = 0.7764, g1 = 0.6000, b1 = 0.1137, r2 = 0.9725, g2 = 0.8745, b2 = 0.2941 },
                [Srendarr.AURA_TYPE_PASSIVE]   = { r1 = 0.4196, g1 = 0.3803, b1 = 0.2313, r2 = 0.4196, g2 = 0.3803, b2 = 0.2313 },
                [Srendarr.DEBUFF_TYPE_PASSIVE] = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
                [Srendarr.DEBUFF_TYPE_TIMED]   = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
            },
        },
        [4] =
        {
            base              = { point = CENTER, x = -251.5, y = 275.1, alpha = 1.0, calpha = 1.0, scale = 1.0, id = 4 },
            style             = Srendarr.AURA_STYLE_FULL, -- FULL|ICON|MINI|GROUP|AURA_STYLE_GROUPB|AURA_STYLE_GROUPD
            auraGrowth        = Srendarr.AURA_GROW_UP,    -- UP|DOWN|LEFT|RIGHT|CENTERLEFT|CENTERRIGHT (valid choices vary based on style)
            auraPadding       = 4,
            auraFadeTime      = 0,
            auraSort          = Srendarr.AURA_SORT_TIMEASC, -- NAME|TIME|CAST + ASC|DESC
            auraClassOverride = 3,                          -- whether all auras in this frame should be treated as buffs or debuffs regardless of type. 3 is off.
            hideFullBar       = true,                       -- in styles with a timer bar, only show the aura name instead
            auraCooldown      = true,                       -- use animated timer aura icon display for this frame
            auraBorder        = true,                       -- use the game's default icon border when not using Srendarr's black background
            auraBackground    = true,                       -- show a black contrast background behind icon mode auras
            highlightToggled  = true,                       -- shows the same 'toggled on' highlight action buttons do on toggles
            -- 	enableTooltips		= true,							-- show mouseover tooltip for auraName in ICON mode
            nameFont          = 'Univers 67',
            nameStyle         = 'soft-shadow-thick',
            nameSize          = 16,
            nameColor         = { 0.9, 0.9, 0.9, 1.0 },
            timerFont         = 'Univers 67',
            timerStyle        = 'soft-shadow-thick',
            timerSize         = 14,
            timerColor        = { 0.9, 0.9, 0.9, 1.0 },
            timerLocation     = Srendarr.AURA_TIMERLOC_OVER, -- ABOVE|BELOW|OVER|HIDDEN (valid choices based on style)
            timerHMS          = true,
            barReverse        = true,                        -- bar alignment direction (and icon placement in the FULL style)
            barGloss          = true,
            barWidth          = 160,
            cooldownColors    =
            {
                [Srendarr.AURA_TYPE_TIMED]   = { r1 = 0, g1 = 1, b1 = 0 },
                [Srendarr.DEBUFF_TYPE_TIMED] = { r1 = 0.6667, g1 = 0, b1 = 1 },
            },
            barColors         =
            {
                [Srendarr.AURA_TYPE_TIMED]     = { r1 = 0, g1 = 0.1843, b1 = 0.5098, r2 = 0.3215, g2 = 0.8431, b2 = 1 },
                [Srendarr.AURA_TYPE_TOGGLED]   = { r1 = 0.7764, g1 = 0.6000, b1 = 0.1137, r2 = 0.9725, g2 = 0.8745, b2 = 0.2941 },
                [Srendarr.AURA_TYPE_PASSIVE]   = { r1 = 0.4196, g1 = 0.3803, b1 = 0.2313, r2 = 0.4196, g2 = 0.3803, b2 = 0.2313 },
                [Srendarr.DEBUFF_TYPE_PASSIVE] = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
                [Srendarr.DEBUFF_TYPE_TIMED]   = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
            },
        },
        [5] =
        {
            base              = { point = TOP, x = -129.1, y = 99.3, alpha = 1.0, calpha = 1.0, scale = 0.55, id = 5 },
            style             = Srendarr.AURA_STYLE_ICON, -- FULL|ICON|MINI|GROUP|AURA_STYLE_GROUPB|AURA_STYLE_GROUPD
            auraGrowth        = Srendarr.AURA_GROW_RIGHT, -- UP|DOWN|LEFT|RIGHT|CENTERLEFT|CENTERRIGHT (valid choices vary based on style)
            auraPadding       = 2,
            auraFadeTime      = 0,
            auraSort          = Srendarr.AURA_SORT_TIMEASC, -- NAME|TIME|CAST + ASC|DESC
            auraClassOverride = 3,                          -- whether all auras in this frame should be treated as buffs or debuffs regardless of type. 3 is off.
            hideFullBar       = false,                      -- in styles with a timer bar, only show the aura name instead
            auraCooldown      = false,                      -- use animated timer aura icon display for this frame
            auraBorder        = true,                       -- use the game's default icon border when not using Srendarr's black background
            auraBackground    = true,                       -- show a black contrast background behind icon mode auras
            highlightToggled  = true,                       -- shows the same 'toggled on' highlight action buttons do on toggles
            -- 	enableTooltips		= true,							-- show mouseover tooltip for auraName in ICON mode
            nameFont          = 'Univers 67',
            nameStyle         = 'soft-shadow-thick',
            nameSize          = 16,
            nameColor         = { 0.9, 0.9, 0.9, 1.0 },
            timerFont         = 'Univers 67',
            timerStyle        = 'soft-shadow-thick',
            timerSize         = 12,
            timerColor        = { 0.9, 0.9, 0.9, 1.0 },
            timerLocation     = Srendarr.AURA_TIMERLOC_ABOVE, -- ABOVE|BELOW|OVER|HIDDEN (valid choices based on style)
            timerHMS          = false,
            barReverse        = true,                         -- bar alignment direction (and icon placement in the FULL style)
            barGloss          = true,
            barWidth          = 160,
            cooldownColors    =
            {
                [Srendarr.AURA_TYPE_TIMED]   = { r1 = 0, g1 = 1, b1 = 0 },
                [Srendarr.DEBUFF_TYPE_TIMED] = { r1 = 0.6667, g1 = 0, b1 = 1 },
            },
            barColors         =
            {
                [Srendarr.AURA_TYPE_TIMED]     = { r1 = 0, g1 = 0.1843, b1 = 0.5098, r2 = 0.3215, g2 = 0.8431, b2 = 1 },
                [Srendarr.AURA_TYPE_TOGGLED]   = { r1 = 0.7764, g1 = 0.6000, b1 = 0.1137, r2 = 0.9725, g2 = 0.8745, b2 = 0.2941 },
                [Srendarr.AURA_TYPE_PASSIVE]   = { r1 = 0.4196, g1 = 0.3803, b1 = 0.2313, r2 = 0.4196, g2 = 0.3803, b2 = 0.2313 },
                [Srendarr.DEBUFF_TYPE_PASSIVE] = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
                [Srendarr.DEBUFF_TYPE_TIMED]   = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
            },
        },
        [6] =
        {
            base              = { point = BOTTOMRIGHT, x = -8.2, y = -36.5, alpha = 1.0, calpha = 1.0, scale = 1.0, id = 6 },
            style             = Srendarr.AURA_STYLE_FULL, -- FULL|ICON|MINI|GROUP|AURA_STYLE_GROUPB|AURA_STYLE_GROUPD
            auraGrowth        = Srendarr.AURA_GROW_UP,    -- UP|DOWN|LEFT|RIGHT|CENTERLEFT|CENTERRIGHT (valid choices vary based on style)
            auraPadding       = 4,
            auraFadeTime      = 0,
            auraSort          = Srendarr.AURA_SORT_TIMEASC, -- NAME|TIME|CAST + ASC|DESC
            auraClassOverride = 3,                          -- whether all auras in this frame should be treated as buffs or debuffs regardless of type. 3 is off.
            hideFullBar       = true,                       -- in styles with a timer bar, only show the aura name instead
            auraCooldown      = true,                       -- use animated timer aura icon display for this frame
            auraBorder        = true,                       -- use the game's default icon border when not using Srendarr's black background
            auraBackground    = true,                       -- show a black contrast background behind icon mode auras
            highlightToggled  = true,                       -- shows the same 'toggled on' highlight action buttons do on toggles
            -- 	enableTooltips		= false,						-- show mouseover tooltip for auraName in ICON mode
            nameFont          = 'Univers 67',
            nameStyle         = 'soft-shadow-thick',
            nameSize          = 16,
            nameColor         = { 0.9, 0.9, 0.9, 1.0 },
            timerFont         = 'Univers 67',
            timerStyle        = 'soft-shadow-thick',
            timerSize         = 14,
            timerColor        = { 0.9, 0.9, 0.9, 1.0 },
            timerLocation     = Srendarr.AURA_TIMERLOC_OVER, -- ABOVE|BELOW|OVER|HIDDEN (valid choices based on style)
            timerHMS          = true,
            barReverse        = true,                        -- bar alignment direction (and icon placement in the FULL style)
            barGloss          = true,
            barWidth          = 160,
            cooldownColors    =
            {
                [Srendarr.AURA_TYPE_TIMED]   = { r1 = 0, g1 = 1, b1 = 0 },
                [Srendarr.DEBUFF_TYPE_TIMED] = { r1 = 0.6667, g1 = 0, b1 = 1 },
            },
            barColors         =
            {
                [Srendarr.AURA_TYPE_TIMED]     = { r1 = 0, g1 = 0.1843, b1 = 0.5098, r2 = 0.3215, g2 = 0.8431, b2 = 1 },
                [Srendarr.AURA_TYPE_TOGGLED]   = { r1 = 0.7764, g1 = 0.6000, b1 = 0.1137, r2 = 0.9725, g2 = 0.8745, b2 = 0.2941 },
                [Srendarr.AURA_TYPE_PASSIVE]   = { r1 = 0.4196, g1 = 0.3803, b1 = 0.2313, r2 = 0.4196, g2 = 0.3803, b2 = 0.2313 },
                [Srendarr.DEBUFF_TYPE_PASSIVE] = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
                [Srendarr.DEBUFF_TYPE_TIMED]   = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
            },
        },
        [7] =
        {
            base              = { point = TOPRIGHT, x = -259.2, y = 213.9, alpha = 1.0, calpha = 1.0, scale = 1.0, id = 7 },
            style             = Srendarr.AURA_STYLE_ICON, -- FULL|ICON|MINI|GROUP|AURA_STYLE_GROUPB|AURA_STYLE_GROUPD
            auraGrowth        = Srendarr.AURA_GROW_LEFT,  -- UP|DOWN|LEFT|RIGHT|CENTERLEFT|CENTERRIGHT (valid choices vary based on style)
            auraPadding       = 4,
            auraFadeTime      = 0,
            auraSort          = Srendarr.AURA_SORT_TIMEASC, -- NAME|TIME|CAST + ASC|DESC
            auraClassOverride = 3,                          -- whether all auras in this frame should be treated as buffs or debuffs regardless of type. 3 is off.
            hideFullBar       = false,                      -- in styles with a timer bar, only show the aura name instead
            auraCooldown      = true,                       -- use animated timer aura icon display for this frame
            auraBorder        = true,                       -- use the game's default icon border when not using Srendarr's black background
            auraBackground    = true,                       -- show a black contrast background behind icon mode auras
            highlightToggled  = true,                       -- shows the same 'toggled on' highlight action buttons do on toggles
            -- 	enableTooltips		= true,							-- show mouseover tooltip for auraName in ICON mode
            nameFont          = 'Univers 67',
            nameStyle         = 'soft-shadow-thick',
            nameSize          = 16,
            nameColor         = { 0.9, 0.9, 0.9, 1.0 },
            timerFont         = 'Univers 67',
            timerStyle        = 'soft-shadow-thick',
            timerSize         = 14,
            timerColor        = { 0.9, 0.9, 0.9, 1.0 },
            timerLocation     = Srendarr.AURA_TIMERLOC_ABOVE, -- ABOVE|BELOW|OVER|HIDDEN (valid choices based on style)
            timerHMS          = true,
            barReverse        = true,                         -- bar alignment direction (and icon placement in the FULL style)
            barGloss          = true,
            barWidth          = 160,
            cooldownColors    =
            {
                [Srendarr.AURA_TYPE_TIMED]   = { r1 = 0, g1 = 1, b1 = 0 },
                [Srendarr.DEBUFF_TYPE_TIMED] = { r1 = 0.6667, g1 = 0, b1 = 1 },
            },
            barColors         =
            {
                [Srendarr.AURA_TYPE_TIMED]     = { r1 = 0, g1 = 0.1843, b1 = 0.5098, r2 = 0.3215, g2 = 0.8431, b2 = 1 },
                [Srendarr.AURA_TYPE_TOGGLED]   = { r1 = 0.7764, g1 = 0.6000, b1 = 0.1137, r2 = 0.9725, g2 = 0.8745, b2 = 0.2941 },
                [Srendarr.AURA_TYPE_PASSIVE]   = { r1 = 0.4196, g1 = 0.3803, b1 = 0.2313, r2 = 0.4196, g2 = 0.3803, b2 = 0.2313 },
                [Srendarr.DEBUFF_TYPE_PASSIVE] = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
                [Srendarr.DEBUFF_TYPE_TIMED]   = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
            },
        },
        [8] =
        {
            base              = { point = CENTER, x = 251.4, y = 275.1, alpha = 1.0, calpha = 1.0, scale = 1.0, id = 8 },
            style             = Srendarr.AURA_STYLE_FULL, -- FULL|ICON|MINI|GROUP|AURA_STYLE_GROUPB|AURA_STYLE_GROUPD
            auraGrowth        = Srendarr.AURA_GROW_UP,    -- UP|DOWN|LEFT|RIGHT|CENTERLEFT|CENTERRIGHT (valid choices vary based on style)
            auraPadding       = 4,
            auraFadeTime      = 0,
            auraSort          = Srendarr.AURA_SORT_TIMEASC, -- NAME|TIME|CAST + ASC|DESC
            auraClassOverride = 5,                          -- whether all auras in this frame should be treated as buffs or debuffs regardless of type. 3 is off.
            hideFullBar       = true,                       -- in styles with a timer bar, only show the aura name instead
            auraCooldown      = true,                       -- use animated timer aura icon display for this frame
            auraBorder        = true,                       -- use the game's default icon border when not using Srendarr's black background
            auraBackground    = true,                       -- show a black contrast background behind icon mode auras
            highlightToggled  = true,                       -- shows the same 'toggled on' highlight action buttons do on toggles
            -- 	enableTooltips		= false,						-- show mouseover tooltip for auraName in ICON mode
            nameFont          = 'Univers 67',
            nameStyle         = 'soft-shadow-thick',
            nameSize          = 16,
            nameColor         = { 0.9, 0.9, 0.9, 1.0 },
            timerFont         = 'Univers 67',
            timerStyle        = 'soft-shadow-thick',
            timerSize         = 14,
            timerColor        = { 0.9, 0.9, 0.9, 1.0 },
            timerLocation     = Srendarr.AURA_TIMERLOC_OVER, -- ABOVE|BELOW|OVER|HIDDEN (valid choices based on style)
            timerHMS          = true,
            barReverse        = false,                       -- bar alignment direction (and icon placement in the FULL style)
            barGloss          = true,
            barWidth          = 160,
            cooldownColors    =
            {
                [Srendarr.AURA_TYPE_TIMED]   = { r1 = 0, g1 = 1, b1 = 0 },
                [Srendarr.DEBUFF_TYPE_TIMED] = { r1 = 0.6667, g1 = 0, b1 = 1 },
            },
            barColors         =
            {
                [Srendarr.AURA_TYPE_TIMED]     = { r1 = 0, g1 = 0.1843, b1 = 0.5098, r2 = 0.3215, g2 = 0.8431, b2 = 1 },
                [Srendarr.AURA_TYPE_TOGGLED]   = { r1 = 0.7764, g1 = 0.6000, b1 = 0.1137, r2 = 0.9725, g2 = 0.8745, b2 = 0.2941 },
                [Srendarr.AURA_TYPE_PASSIVE]   = { r1 = 0.4196, g1 = 0.3803, b1 = 0.2313, r2 = 0.4196, g2 = 0.3803, b2 = 0.2313 },
                [Srendarr.DEBUFF_TYPE_PASSIVE] = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
                [Srendarr.DEBUFF_TYPE_TIMED]   = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
            },
        },
        [9] =
        {
            base              = { point = BOTTOM, x = -623.2, y = -282.7, alpha = 1.0, calpha = 1.0, scale = 1.1, id = 9 },
            style             = Srendarr.AURA_STYLE_FULL, -- FULL|ICON|MINI|GROUP|AURA_STYLE_GROUPB|AURA_STYLE_GROUPD
            auraGrowth        = Srendarr.AURA_GROW_UP,    -- UP|DOWN|LEFT|RIGHT|CENTERLEFT|CENTERRIGHT (valid choices vary based on style)
            auraPadding       = 4,
            auraFadeTime      = 0,
            auraSort          = Srendarr.AURA_SORT_TIMEASC, -- NAME|TIME|CAST + ASC|DESC
            auraClassOverride = 3,                          -- whether all auras in this frame should be treated as buffs or debuffs regardless of type. 3 is off.
            hideFullBar       = true,                       -- in styles with a timer bar, only show the aura name instead
            auraCooldown      = true,                       -- use animated timer aura icon display for this frame
            auraBorder        = true,                       -- use the game's default icon border when not using Srendarr's black background
            auraBackground    = true,                       -- show a black contrast background behind icon mode auras
            highlightToggled  = true,                       -- shows the same 'toggled on' highlight action buttons do on toggles
            -- 	enableTooltips		= false,						-- show mouseover tooltip for auraName in ICON mode
            nameFont          = 'Univers 67',
            nameStyle         = 'soft-shadow-thick',
            nameSize          = 16,
            nameColor         = { 0.9, 0.9, 0.9, 1.0 },
            timerFont         = 'Univers 67',
            timerStyle        = 'soft-shadow-thick',
            timerSize         = 14,
            timerColor        = { 0.9, 0.9, 0.9, 1.0 },
            timerLocation     = Srendarr.AURA_TIMERLOC_OVER, -- ABOVE|BELOW|OVER|HIDDEN (valid choices based on style)
            timerHMS          = true,
            barReverse        = false,                       -- bar alignment direction (and icon placement in the FULL style)
            barGloss          = true,
            barWidth          = 160,
            cooldownColors    =
            {
                [Srendarr.AURA_TYPE_TIMED]   = { r1 = 0, g1 = 1, b1 = 0 },
                [Srendarr.DEBUFF_TYPE_TIMED] = { r1 = 0.6667, g1 = 0, b1 = 1 },
            },
            barColors         =
            {
                [Srendarr.AURA_TYPE_TIMED]     = { r1 = 0, g1 = 0.1843, b1 = 0.5098, r2 = 0.3215, g2 = 0.8431, b2 = 1 },
                [Srendarr.AURA_TYPE_TOGGLED]   = { r1 = 0.7764, g1 = 0.6000, b1 = 0.1137, r2 = 0.9725, g2 = 0.8745, b2 = 0.2941 },
                [Srendarr.AURA_TYPE_PASSIVE]   = { r1 = 0.4196, g1 = 0.3803, b1 = 0.2313, r2 = 0.4196, g2 = 0.3803, b2 = 0.2313 },
                [Srendarr.DEBUFF_TYPE_PASSIVE] = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
                [Srendarr.DEBUFF_TYPE_TIMED]   = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
            },
        },
        [10] =
        {
            base              = { point = CENTER, x = -108.9, y = -169.7, alpha = 1.0, calpha = 1.0, scale = 0.8, id = 10 },
            style             = Srendarr.AURA_STYLE_FULL, -- FULL|ICON|MINI|GROUP|AURA_STYLE_GROUPB|AURA_STYLE_GROUPD
            auraGrowth        = Srendarr.AURA_GROW_UP,    -- UP|DOWN|LEFT|RIGHT|CENTERLEFT|CENTERRIGHT (valid choices vary based on style)
            auraPadding       = 4,
            auraFadeTime      = 0,
            auraSort          = Srendarr.AURA_SORT_TIMEASC, -- NAME|TIME|CAST + ASC|DESC
            auraClassOverride = 3,                          -- whether all auras in this frame should be treated as buffs or debuffs regardless of type. 3 is off.
            hideFullBar       = false,                      -- in styles with a timer bar, only show the aura name instead
            auraCooldown      = true,                       -- use animated timer aura icon display for this frame
            auraBorder        = true,                       -- use the game's default icon border when not using Srendarr's black background
            auraBackground    = true,                       -- show a black contrast background behind icon mode auras
            highlightToggled  = true,                       -- shows the same 'toggled on' highlight action buttons do on toggles
            -- 	enableTooltips		= false,						-- show mouseover tooltip for auraName in ICON mode
            nameFont          = 'Univers 67',
            nameStyle         = 'soft-shadow-thick',
            nameSize          = 16,
            nameColor         = { 0.9, 0.9, 0.9, 1.0 },
            timerFont         = 'Univers 67',
            timerStyle        = 'soft-shadow-thick',
            timerSize         = 14,
            timerColor        = { 0.9, 0.9, 0.9, 1.0 },
            timerLocation     = Srendarr.AURA_TIMERLOC_OVER, -- ABOVE|BELOW|OVER|HIDDEN (valid choices based on style)
            timerHMS          = true,
            barReverse        = true,                        -- bar alignment direction (and icon placement in the FULL style)
            barGloss          = true,
            barWidth          = 160,
            cooldownColors    =
            {
                [Srendarr.AURA_TYPE_TIMED]   = { r1 = 0, g1 = 1, b1 = 0 },
                [Srendarr.DEBUFF_TYPE_TIMED] = { r1 = 0.6667, g1 = 0, b1 = 1 },
            },
            barColors         =
            {
                [Srendarr.AURA_TYPE_TIMED]     = { r1 = 0, g1 = 0.1843, b1 = 0.5098, r2 = 0.3215, g2 = 0.8431, b2 = 1 },
                [Srendarr.AURA_TYPE_TOGGLED]   = { r1 = 0.7764, g1 = 0.6000, b1 = 0.1137, r2 = 0.9725, g2 = 0.8745, b2 = 0.2941 },
                [Srendarr.AURA_TYPE_PASSIVE]   = { r1 = 0.4196, g1 = 0.3803, b1 = 0.2313, r2 = 0.4196, g2 = 0.3803, b2 = 0.2313 },
                [Srendarr.DEBUFF_TYPE_PASSIVE] = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
                [Srendarr.DEBUFF_TYPE_TIMED]   = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
            },
        },
        [11] =
        {
            base              = { point = RIGHT, x = -485, y = 47, alpha = 1.0, calpha = 1.0, scale = 0.8, id = 11 },
            style             = Srendarr.AURA_STYLE_FULL, -- FULL|ICON|MINI|GROUP|AURA_STYLE_GROUPB|AURA_STYLE_GROUPD
            auraGrowth        = Srendarr.AURA_GROW_UP,    -- UP|DOWN|LEFT|RIGHT|CENTERLEFT|CENTERRIGHT (valid choices vary based on style)
            auraPadding       = 4,
            auraFadeTime      = 0,
            auraSort          = Srendarr.AURA_SORT_TIMEASC, -- NAME|TIME|CAST + ASC|DESC
            auraClassOverride = 3,                          -- whether all auras in this frame should be treated as buffs or debuffs regardless of type. 3 is off.
            hideFullBar       = false,                      -- in styles with a timer bar, only show the aura name instead
            auraCooldown      = true,                       -- use animated timer aura icon display for this frame
            auraBorder        = true,                       -- use the game's default icon border when not using Srendarr's black background
            auraBackground    = true,                       -- show a black contrast background behind icon mode auras
            highlightToggled  = true,                       -- shows the same 'toggled on' highlight action buttons do on toggles
            -- 	enableTooltips		= false,						-- show mouseover tooltip for auraName in ICON mode
            nameFont          = 'Univers 67',
            nameStyle         = 'soft-shadow-thick',
            nameSize          = 16,
            nameColor         = { 0.9, 0.9, 0.9, 1.0 },
            timerFont         = 'Univers 67',
            timerStyle        = 'soft-shadow-thick',
            timerSize         = 14,
            timerColor        = { 0.9, 0.9, 0.9, 1.0 },
            timerLocation     = Srendarr.AURA_TIMERLOC_OVER, -- ABOVE|BELOW|OVER|HIDDEN (valid choices based on style)
            timerHMS          = true,
            barReverse        = true,                        -- bar alignment direction (and icon placement in the FULL style)
            barGloss          = true,
            barWidth          = 160,
            cooldownColors    =
            {
                [Srendarr.AURA_TYPE_TIMED]   = { r1 = 0, g1 = 1, b1 = 0 },
                [Srendarr.DEBUFF_TYPE_TIMED] = { r1 = 0.6667, g1 = 0, b1 = 1 },
            },
            barColors         =
            {
                [Srendarr.AURA_TYPE_TIMED]     = { r1 = 0, g1 = 0.1843, b1 = 0.5098, r2 = 0.3215, g2 = 0.8431, b2 = 1 },
                [Srendarr.AURA_TYPE_TOGGLED]   = { r1 = 0.7764, g1 = 0.6000, b1 = 0.1137, r2 = 0.9725, g2 = 0.8745, b2 = 0.2941 },
                [Srendarr.AURA_TYPE_PASSIVE]   = { r1 = 0.4196, g1 = 0.3803, b1 = 0.2313, r2 = 0.4196, g2 = 0.3803, b2 = 0.2313 },
                [Srendarr.DEBUFF_TYPE_PASSIVE] = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
                [Srendarr.DEBUFF_TYPE_TIMED]   = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
            },
        },
        [12] =
        {
            base              = { point = RIGHT, x = -320, y = 47, alpha = 1.0, calpha = 1.0, scale = 0.8, id = 12 },
            style             = Srendarr.AURA_STYLE_FULL, -- FULL|ICON|MINI|GROUP|AURA_STYLE_GROUPB|AURA_STYLE_GROUPD
            auraGrowth        = Srendarr.AURA_GROW_UP,    -- UP|DOWN|LEFT|RIGHT|CENTERLEFT|CENTERRIGHT (valid choices vary based on style)
            auraPadding       = 4,
            auraFadeTime      = 0,
            auraSort          = Srendarr.AURA_SORT_TIMEASC, -- NAME|TIME|CAST + ASC|DESC
            auraClassOverride = 3,                          -- whether all auras in this frame should be treated as buffs or debuffs regardless of type. 3 is off.
            hideFullBar       = false,                      -- in styles with a timer bar, only show the aura name instead
            auraCooldown      = true,                       -- use animated timer aura icon display for this frame
            auraBorder        = true,                       -- use the game's default icon border when not using Srendarr's black background
            auraBackground    = true,                       -- show a black contrast background behind icon mode auras
            highlightToggled  = true,                       -- shows the same 'toggled on' highlight action buttons do on toggles
            -- 	enableTooltips		= false,						-- show mouseover tooltip for auraName in ICON mode
            nameFont          = 'Univers 67',
            nameStyle         = 'soft-shadow-thick',
            nameSize          = 16,
            nameColor         = { 0.9, 0.9, 0.9, 1.0 },
            timerFont         = 'Univers 67',
            timerStyle        = 'soft-shadow-thick',
            timerSize         = 14,
            timerColor        = { 0.9, 0.9, 0.9, 1.0 },
            timerLocation     = Srendarr.AURA_TIMERLOC_OVER, -- ABOVE|BELOW|OVER|HIDDEN (valid choices based on style)
            timerHMS          = true,
            barReverse        = true,                        -- bar alignment direction (and icon placement in the FULL style)
            barGloss          = true,
            barWidth          = 160,
            cooldownColors    =
            {
                [Srendarr.AURA_TYPE_TIMED]   = { r1 = 0, g1 = 1, b1 = 0 },
                [Srendarr.DEBUFF_TYPE_TIMED] = { r1 = 0.6667, g1 = 0, b1 = 1 },
            },
            barColors         =
            {
                [Srendarr.AURA_TYPE_TIMED]     = { r1 = 0, g1 = 0.1843, b1 = 0.5098, r2 = 0.3215, g2 = 0.8431, b2 = 1 },
                [Srendarr.AURA_TYPE_TOGGLED]   = { r1 = 0.7764, g1 = 0.6000, b1 = 0.1137, r2 = 0.9725, g2 = 0.8745, b2 = 0.2941 },
                [Srendarr.AURA_TYPE_PASSIVE]   = { r1 = 0.4196, g1 = 0.3803, b1 = 0.2313, r2 = 0.4196, g2 = 0.3803, b2 = 0.2313 },
                [Srendarr.DEBUFF_TYPE_PASSIVE] = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
                [Srendarr.DEBUFF_TYPE_TIMED]   = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
            },
        },
        [13] =
        {
            base              = { point = RIGHT, x = -485, y = 189, alpha = 1.0, calpha = 1.0, scale = 0.8, id = 13 },
            style             = Srendarr.AURA_STYLE_FULL, -- FULL|ICON|MINI|GROUP|AURA_STYLE_GROUPB|AURA_STYLE_GROUPD
            auraGrowth        = Srendarr.AURA_GROW_UP,    -- UP|DOWN|LEFT|RIGHT|CENTERLEFT|CENTERRIGHT (valid choices vary based on style)
            auraPadding       = 4,
            auraFadeTime      = 0,
            auraSort          = Srendarr.AURA_SORT_TIMEASC, -- NAME|TIME|CAST + ASC|DESC
            auraClassOverride = 3,                          -- whether all auras in this frame should be treated as buffs or debuffs regardless of type. 3 is off.
            hideFullBar       = false,                      -- in styles with a timer bar, only show the aura name instead
            auraCooldown      = true,                       -- use animated timer aura icon display for this frame
            auraBorder        = true,                       -- use the game's default icon border when not using Srendarr's black background
            auraBackground    = true,                       -- show a black contrast background behind icon mode auras
            highlightToggled  = true,                       -- shows the same 'toggled on' highlight action buttons do on toggles
            -- 	enableTooltips		= false,						-- show mouseover tooltip for auraName in ICON mode
            nameFont          = 'Univers 67',
            nameStyle         = 'soft-shadow-thick',
            nameSize          = 16,
            nameColor         = { 0.9, 0.9, 0.9, 1.0 },
            timerFont         = 'Univers 67',
            timerStyle        = 'soft-shadow-thick',
            timerSize         = 14,
            timerColor        = { 0.9, 0.9, 0.9, 1.0 },
            timerLocation     = Srendarr.AURA_TIMERLOC_OVER, -- ABOVE|BELOW|OVER|HIDDEN (valid choices based on style)
            timerHMS          = true,
            barReverse        = true,                        -- bar alignment direction (and icon placement in the FULL style)
            barGloss          = true,
            barWidth          = 160,
            cooldownColors    =
            {
                [Srendarr.AURA_TYPE_TIMED]   = { r1 = 0, g1 = 1, b1 = 0 },
                [Srendarr.DEBUFF_TYPE_TIMED] = { r1 = 0.6667, g1 = 0, b1 = 1 },
            },
            barColors         =
            {
                [Srendarr.AURA_TYPE_TIMED]     = { r1 = 0, g1 = 0.1843, b1 = 0.5098, r2 = 0.3215, g2 = 0.8431, b2 = 1 },
                [Srendarr.AURA_TYPE_TOGGLED]   = { r1 = 0.7764, g1 = 0.6000, b1 = 0.1137, r2 = 0.9725, g2 = 0.8745, b2 = 0.2941 },
                [Srendarr.AURA_TYPE_PASSIVE]   = { r1 = 0.4196, g1 = 0.3803, b1 = 0.2313, r2 = 0.4196, g2 = 0.3803, b2 = 0.2313 },
                [Srendarr.DEBUFF_TYPE_PASSIVE] = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
                [Srendarr.DEBUFF_TYPE_TIMED]   = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
            },
        },
        [14] =
        {
            base              = { point = RIGHT, x = -320, y = 189, alpha = 1.0, calpha = 1.0, scale = 0.8, id = 14 },
            style             = Srendarr.AURA_STYLE_FULL, -- FULL|ICON|MINI|GROUP|AURA_STYLE_GROUPB|AURA_STYLE_GROUPD
            auraGrowth        = Srendarr.AURA_GROW_UP,    -- UP|DOWN|LEFT|RIGHT|CENTERLEFT|CENTERRIGHT (valid choices vary based on style)
            auraPadding       = 4,
            auraFadeTime      = 0,
            auraSort          = Srendarr.AURA_SORT_TIMEASC, -- NAME|TIME|CAST + ASC|DESC
            auraClassOverride = 3,                          -- whether all auras in this frame should be treated as buffs or debuffs regardless of type. 3 is off.
            hideFullBar       = false,                      -- in styles with a timer bar, only show the aura name instead
            auraCooldown      = true,                       -- use animated timer aura icon display for this frame
            auraBorder        = true,                       -- use the game's default icon border when not using Srendarr's black background
            auraBackground    = true,                       -- show a black contrast background behind icon mode auras
            highlightToggled  = true,                       -- shows the same 'toggled on' highlight action buttons do on toggles
            -- 	enableTooltips		= false,						-- show mouseover tooltip for auraName in ICON mode
            nameFont          = 'Univers 67',
            nameStyle         = 'soft-shadow-thick',
            nameSize          = 16,
            nameColor         = { 0.9, 0.9, 0.9, 1.0 },
            timerFont         = 'Univers 67',
            timerStyle        = 'soft-shadow-thick',
            timerSize         = 14,
            timerColor        = { 0.9, 0.9, 0.9, 1.0 },
            timerLocation     = Srendarr.AURA_TIMERLOC_OVER, -- ABOVE|BELOW|OVER|HIDDEN (valid choices based on style)
            timerHMS          = true,
            barReverse        = true,                        -- bar alignment direction (and icon placement in the FULL style)
            barGloss          = true,
            barWidth          = 160,
            cooldownColors    =
            {
                [Srendarr.AURA_TYPE_TIMED]   = { r1 = 0, g1 = 1, b1 = 0 },
                [Srendarr.DEBUFF_TYPE_TIMED] = { r1 = 0.6667, g1 = 0, b1 = 1 },
            },
            barColors         =
            {
                [Srendarr.AURA_TYPE_TIMED]     = { r1 = 0, g1 = 0.1843, b1 = 0.5098, r2 = 0.3215, g2 = 0.8431, b2 = 1 },
                [Srendarr.AURA_TYPE_TOGGLED]   = { r1 = 0.7764, g1 = 0.6000, b1 = 0.1137, r2 = 0.9725, g2 = 0.8745, b2 = 0.2941 },
                [Srendarr.AURA_TYPE_PASSIVE]   = { r1 = 0.4196, g1 = 0.3803, b1 = 0.2313, r2 = 0.4196, g2 = 0.3803, b2 = 0.2313 },
                [Srendarr.DEBUFF_TYPE_PASSIVE] = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
                [Srendarr.DEBUFF_TYPE_TIMED]   = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
            },
        },
        [15] =
        {                                                   -- Settings used for all group buff frames (Phinix)
            base              = { point = TOPLEFT, x = 0, y = 0, alpha = 1.0, calpha = 1.0, scale = 0.6, id = 15 },
            style             = Srendarr.AURA_STYLE_GROUPB, -- FULL|ICON|MINI|GROUP|AURA_STYLE_GROUPB|AURA_STYLE_GROUPD
            auraGrowth        = Srendarr.AURA_GROW_RIGHT,   -- UP|DOWN|LEFT|RIGHT|CENTERLEFT|CENTERRIGHT (valid choices vary based on style)
            auraPadding       = 2,
            auraFadeTime      = 0,
            auraSort          = Srendarr.AURA_SORT_TIMEASC, -- NAME|TIME|CAST + ASC|DESC
            auraClassOverride = 3,                          -- whether all auras in this frame should be treated as buffs or debuffs regardless of type. 3 is off.
            hideFullBar       = false,                      -- in styles with a timer bar, only show the aura name instead
            auraCooldown      = true,                       -- use animated timer aura icon display for this frame
            auraBorder        = true,                       -- use the game's default icon border when not using Srendarr's black background
            auraBackground    = true,                       -- show a black contrast background behind icon mode auras
            highlightToggled  = true,                       -- shows the same 'toggled on' highlight action buttons do on toggles
            -- 	enableTooltips		= false,						-- show mouseover tooltip for auraName in ICON mode
            nameFont          = 'Univers 67',
            nameStyle         = 'soft-shadow-thick',
            nameSize          = 16,
            nameColor         = { 0.9, 0.9, 0.9, 1.0 },
            timerFont         = 'Univers 67',
            timerStyle        = 'soft-shadow-thick',
            timerSize         = 12,
            timerColor        = { 0.9, 0.9, 0.9, 1.0 },
            timerLocation     = Srendarr.AURA_TIMERLOC_ABOVE, -- ABOVE|BELOW|OVER|HIDDEN (valid choices based on style)
            timerHMS          = true,
            barReverse        = true,                         -- bar alignment direction (and icon placement in the FULL style)
            barGloss          = true,
            barWidth          = 160,
            cooldownColors    =
            {
                [Srendarr.AURA_TYPE_TIMED]   = { r1 = 0, g1 = 1, b1 = 0 },
                [Srendarr.DEBUFF_TYPE_TIMED] = { r1 = 0.6667, g1 = 0, b1 = 1 },
            },
            barColors         =
            {
                [Srendarr.AURA_TYPE_TIMED]     = { r1 = 0, g1 = 0.1843, b1 = 0.5098, r2 = 0.3215, g2 = 0.8431, b2 = 1 },
                [Srendarr.AURA_TYPE_TOGGLED]   = { r1 = 0.7764, g1 = 0.6000, b1 = 0.1137, r2 = 0.9725, g2 = 0.8745, b2 = 0.2941 },
                [Srendarr.AURA_TYPE_PASSIVE]   = { r1 = 0.4196, g1 = 0.3803, b1 = 0.2313, r2 = 0.4196, g2 = 0.3803, b2 = 0.2313 },
                [Srendarr.DEBUFF_TYPE_PASSIVE] = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
                [Srendarr.DEBUFF_TYPE_TIMED]   = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
            },
        },
        [16] =
        {                                                   -- Settings used for all raid buff frames (Phinix)
            base              = { point = TOPLEFT, x = 0, y = 0, alpha = 1.0, calpha = 1.0, scale = 0.4, id = 16 },
            style             = Srendarr.AURA_STYLE_GROUPB, -- FULL|ICON|MINI|GROUP|AURA_STYLE_GROUPB|AURA_STYLE_GROUPD
            auraGrowth        = Srendarr.AURA_GROW_RIGHT,   -- UP|DOWN|LEFT|RIGHT|CENTERLEFT|CENTERRIGHT (valid choices vary based on style)
            auraPadding       = 2,
            auraFadeTime      = 0,
            auraSort          = Srendarr.AURA_SORT_TIMEASC, -- NAME|TIME|CAST + ASC|DESC
            auraClassOverride = 3,                          -- whether all auras in this frame should be treated as buffs or debuffs regardless of type. 3 is off.
            hideFullBar       = false,                      -- in styles with a timer bar, only show the aura name instead
            auraCooldown      = true,                       -- use animated timer aura icon display for this frame
            auraBorder        = true,                       -- use the game's default icon border when not using Srendarr's black background
            auraBackground    = true,                       -- show a black contrast background behind icon mode auras
            highlightToggled  = true,                       -- shows the same 'toggled on' highlight action buttons do on toggles
            -- 	enableTooltips		= false,						-- show mouseover tooltip for auraName in ICON mode
            nameFont          = 'Univers 67',
            nameStyle         = 'soft-shadow-thick',
            nameSize          = 16,
            nameColor         = { 0.9, 0.9, 0.9, 1.0 },
            timerFont         = 'Univers 67',
            timerStyle        = 'soft-shadow-thick',
            timerSize         = 11,
            timerColor        = { 0.9, 0.9, 0.9, 1.0 },
            timerLocation     = Srendarr.AURA_TIMERLOC_OVER, -- ABOVE|BELOW|OVER|HIDDEN (valid choices based on style)
            timerHMS          = true,
            barReverse        = true,                        -- bar alignment direction (and icon placement in the FULL style)
            barGloss          = true,
            barWidth          = 160,
            cooldownColors    =
            {
                [Srendarr.AURA_TYPE_TIMED]   = { r1 = 0, g1 = 1, b1 = 0 },
                [Srendarr.DEBUFF_TYPE_TIMED] = { r1 = 0.6667, g1 = 0, b1 = 1 },
            },
            barColors         =
            {
                [Srendarr.AURA_TYPE_TIMED]     = { r1 = 0, g1 = 0.1843, b1 = 0.5098, r2 = 0.3215, g2 = 0.8431, b2 = 1 },
                [Srendarr.AURA_TYPE_TOGGLED]   = { r1 = 0.7764, g1 = 0.6000, b1 = 0.1137, r2 = 0.9725, g2 = 0.8745, b2 = 0.2941 },
                [Srendarr.AURA_TYPE_PASSIVE]   = { r1 = 0.4196, g1 = 0.3803, b1 = 0.2313, r2 = 0.4196, g2 = 0.3803, b2 = 0.2313 },
                [Srendarr.DEBUFF_TYPE_PASSIVE] = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
                [Srendarr.DEBUFF_TYPE_TIMED]   = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
            },
        },
        [17] =
        {                                                   -- Settings used for all group debuff frames (Phinix)
            base              = { point = RIGHT, x = 0, y = 0, alpha = 1.0, calpha = 1.0, scale = 0.6, id = 15 },
            style             = Srendarr.AURA_STYLE_GROUPD, -- FULL|ICON|MINI|GROUP|AURA_STYLE_GROUPB|AURA_STYLE_GROUPD
            auraGrowth        = Srendarr.AURA_GROW_RIGHT,   -- UP|DOWN|LEFT|RIGHT|CENTERLEFT|CENTERRIGHT (valid choices vary based on style)
            auraPadding       = 2,
            auraFadeTime      = 0,
            auraSort          = Srendarr.AURA_SORT_TIMEASC, -- NAME|TIME|CAST + ASC|DESC
            auraClassOverride = 3,                          -- whether all auras in this frame should be treated as buffs or debuffs regardless of type. 3 is off.
            hideFullBar       = false,                      -- in styles with a timer bar, only show the aura name instead
            auraCooldown      = true,                       -- use animated timer aura icon display for this frame
            auraBorder        = true,                       -- use the game's default icon border when not using Srendarr's black background
            auraBackground    = true,                       -- show a black contrast background behind icon mode auras
            highlightToggled  = true,                       -- shows the same 'toggled on' highlight action buttons do on toggles
            -- 	enableTooltips		= false,						-- show mouseover tooltip for auraName in ICON mode
            nameFont          = 'Univers 67',
            nameStyle         = 'soft-shadow-thick',
            nameSize          = 16,
            nameColor         = { 0.9, 0.9, 0.9, 1.0 },
            timerFont         = 'Univers 67',
            timerStyle        = 'soft-shadow-thick',
            timerSize         = 12,
            timerColor        = { 0.9, 0.9, 0.9, 1.0 },
            timerLocation     = Srendarr.AURA_TIMERLOC_ABOVE, -- ABOVE|BELOW|OVER|HIDDEN (valid choices based on style)
            timerHMS          = true,
            barReverse        = true,                         -- bar alignment direction (and icon placement in the FULL style)
            barGloss          = true,
            barWidth          = 160,
            cooldownColors    =
            {
                [Srendarr.AURA_TYPE_TIMED]   = { r1 = 0.6667, g1 = 0, b1 = 1 },
                [Srendarr.DEBUFF_TYPE_TIMED] = { r1 = 0.6667, g1 = 0, b1 = 1 },
            },
            barColors         =
            {
                [Srendarr.AURA_TYPE_TIMED]     = { r1 = 0, g1 = 0.1843, b1 = 0.5098, r2 = 0.3215, g2 = 0.8431, b2 = 1 },
                [Srendarr.AURA_TYPE_TOGGLED]   = { r1 = 0.7764, g1 = 0.6000, b1 = 0.1137, r2 = 0.9725, g2 = 0.8745, b2 = 0.2941 },
                [Srendarr.AURA_TYPE_PASSIVE]   = { r1 = 0.4196, g1 = 0.3803, b1 = 0.2313, r2 = 0.4196, g2 = 0.3803, b2 = 0.2313 },
                [Srendarr.DEBUFF_TYPE_PASSIVE] = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
                [Srendarr.DEBUFF_TYPE_TIMED]   = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
            },
        },
        [18] =
        {                                                   -- Settings used for all raid debuff frames (Phinix)
            base              = { point = RIGHT, x = 0, y = 0, alpha = 1.0, calpha = 1.0, scale = 0.4, id = 16 },
            style             = Srendarr.AURA_STYLE_GROUPD, -- FULL|ICON|MINI|GROUP|AURA_STYLE_GROUPB|AURA_STYLE_GROUPD
            auraGrowth        = Srendarr.AURA_GROW_RIGHT,   -- UP|DOWN|LEFT|RIGHT|CENTERLEFT|CENTERRIGHT (valid choices vary based on style)
            auraPadding       = 2,
            auraFadeTime      = 0,
            auraSort          = Srendarr.AURA_SORT_TIMEASC, -- NAME|TIME|CAST + ASC|DESC
            auraClassOverride = 3,                          -- whether all auras in this frame should be treated as buffs or debuffs regardless of type. 3 is off.
            hideFullBar       = false,                      -- in styles with a timer bar, only show the aura name instead
            auraCooldown      = true,                       -- use animated timer aura icon display for this frame
            auraBorder        = true,                       -- use the game's default icon border when not using Srendarr's black background
            auraBackground    = true,                       -- show a black contrast background behind icon mode auras
            highlightToggled  = true,                       -- shows the same 'toggled on' highlight action buttons do on toggles
            -- 	enableTooltips		= false,						-- show mouseover tooltip for auraName in ICON mode
            nameFont          = 'Univers 67',
            nameStyle         = 'soft-shadow-thick',
            nameSize          = 16,
            nameColor         = { 0.9, 0.9, 0.9, 1.0 },
            timerFont         = 'Univers 67',
            timerStyle        = 'soft-shadow-thick',
            timerSize         = 11,
            timerColor        = { 0.9, 0.9, 0.9, 1.0 },
            timerLocation     = Srendarr.AURA_TIMERLOC_OVER, -- ABOVE|BELOW|OVER|HIDDEN (valid choices based on style)
            timerHMS          = true,
            barReverse        = true,                        -- bar alignment direction (and icon placement in the FULL style)
            barGloss          = true,
            barWidth          = 160,
            cooldownColors    =
            {
                [Srendarr.AURA_TYPE_TIMED]   = { r1 = 0.6667, g1 = 0, b1 = 1 },
                [Srendarr.DEBUFF_TYPE_TIMED] = { r1 = 0.6667, g1 = 0, b1 = 1 },
            },
            barColors         =
            {
                [Srendarr.AURA_TYPE_TIMED]     = { r1 = 0, g1 = 0.1843, b1 = 0.5098, r2 = 0.3215, g2 = 0.8431, b2 = 1 },
                [Srendarr.AURA_TYPE_TOGGLED]   = { r1 = 0.7764, g1 = 0.6000, b1 = 0.1137, r2 = 0.9725, g2 = 0.8745, b2 = 0.2941 },
                [Srendarr.AURA_TYPE_PASSIVE]   = { r1 = 0.4196, g1 = 0.3803, b1 = 0.2313, r2 = 0.4196, g2 = 0.3803, b2 = 0.2313 },
                [Srendarr.DEBUFF_TYPE_PASSIVE] = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
                [Srendarr.DEBUFF_TYPE_TIMED]   = { r1 = 0.5098, g1 = 0, b1 = 0.1843, r2 = 1, g2 = 0, b2 = 0.8431 },
            },
        },
    },
}

function Srendarr:GetDefaults()
    return defaults
end