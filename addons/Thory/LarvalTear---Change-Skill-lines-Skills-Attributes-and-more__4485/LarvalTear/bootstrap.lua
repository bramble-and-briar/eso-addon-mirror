LarvalTearMod = {}

local LTM = LarvalTearMod

-- SavedVariables schema
LTM.SAVED_VARS_SCHEMA_VERSION = 11

-- Common
LTM.Common = {
    Domains = {},
    Log = {},
    LoggerState = {},
    SkillSettings = {},
    Util = {},
}

-- Core
LTM.Core = {
    Pipeline = {},
}

-- Modules
LTM.Modules = {
    -- Apply pipeline
    ApplyCooldownGate = {},
    ApplyPrecheck = {},
    ApplyPrecheckDecision = {},
    ApplyPrecheckGate = {},
    ApplyStartState = {},
    PipelineContext = {},
    PipelineFinalize = {},
    PipelinePlanner = {},
    ActiveSkillRestore = {},
    SkillPointInputProvider = {},
    SkillPointEvaluator = {},
    SkillPointRunAudit = {},

    -- Build / role state
    BuildCodec = {},
    BuildStore = {},
    RoleApply = {},
    RoleState = {},

    -- Skill / subclass / respec
    RespecObserver = {},
    ClassLineHelper = {},
    SkillApply = {},
    ClassMasteryLookup = {},
    ClassMasteryApply = {},
    PassiveSnapshotApply = {},
    SkillPassive = {},
    SkillPassiveApply = {},
    SkillRespecApply = {},
    SkillRespecConstants = {},
    SkillRespecCompletion = {},
    SkillRespecClassMasteryReduce = {},
    SkillRespecClassMasteryPurchase = {},
    SkillRespecLogging = {},
    SkillRespecMorph = {},
    SkillRespecPlanner = {},
    SkillRespecPostCommit = {},
    SkillRespecPurchase = {},
    SkillRespecSubclassOps = {},
    SkillRespecVerify = {},
    SkillRestore = {},
    SkillSnapshotAudit = {},
    TransformSkills = {},
    SubclassApply = {},
    SubclassPlanner = {},
    SubclassSnapshot = {},
    SubclassVerify = {},

    -- Champion
    ChampionApply = {},
    ChampionChange = {},

    -- Attribute
    AttributeApply = {},
    AttributeRetry = {},
    AttributeScene = {},
    AttributeSnapshot = {},

    -- Equipment
    EquipmentApply = {},
    EquipmentChange = {},
    EquipmentDeposit = {},
    EquipmentFetch = {},
    GearLinkSummary = {},

    -- QuickSlot / food
    AutoRefill = {},
    FoodHelper = {},
    RecipeStore = {},
    RecipeWatcher = {},
    AlchemyRecipe = {},
    EnchantRecipe = {},
    ScribingRecipe = {},
    QuickslotApply = {},
    QuickslotFetch = {},
    QuickslotGate = {},
    QuickslotInventory = {},
    QuickslotProfiles = {},
    QuickslotSnapshot = {},

    -- Settings
    SettingsPanel = {},
}

-- UI
LTM.UI = {
    ApplyProgress = {},
    Dialogs = {},
    Dispatch = {},
    SkillSettings = {},
    QuickSettings = {
        ProfileFacade = {},
    },
    StationLauncher = {},
    Strings = {},
}

-- Data / constants
LTM.SubclassNameHelper = {}

-- Localization
LTM.Localization = {}
LTM.SubclassNameLocalization = {}

-- Debug
LTM.debugFlags = {}
