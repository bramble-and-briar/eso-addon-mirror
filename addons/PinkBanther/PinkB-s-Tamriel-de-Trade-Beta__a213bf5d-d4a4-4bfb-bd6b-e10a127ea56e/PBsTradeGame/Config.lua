PBTrade = {}
PBTrade.Config = {
    addonId = "PBsTradeGame", title = "PB's Tamriel de Trade",
    displayTitle = "タムリエル交易戦", version = "0.25.2", scene = "pbTradeGame",
    playerId = "player", neutralId = "neutral", schemaVersion = 11,
    savedVariables="PBsTradeGameSavedVariables",
    -- Seconds, not frames. A fixed simulation step keeps 30/60/120fps equivalent.
    battle = {
        step = 1 / 60, maxFrameDelta = 0.25, duration = 150,
        gaugeLimit = 100, initialGauge = 0, maxVelocity = 8,
        pressureAcceleration = 4.0, baseAcceleration = 0.20, drag = 0.65,
        -- Border speed multiplier: centreSpeed at the middle rising to edgeSpeed at either end.
        -- paceScale sets the overall tempo: holding a lead of 30% of the value decides in ~30s.
        centerSpeed = .75, edgeSpeed = 2.4, edgeCurve = 1.8, paceScale = 2.0,
        -- Idle pressure: when the side being pushed has not funded or used a tactic for
        -- idleGrace seconds, extra acceleration toward its loss ramps up over idleRamp.
        idleGrace = 4, idleRamp = 4, idleAcceleration = 2.6,
        -- Negotiation calendar: a day passes after turnsPerDay player actions or daySeconds,
        -- whichever comes first.
        turnsPerDay = 3, daySeconds = 15,
        momentumPerFunding = 0.65, maxMomentum = 2.6, momentumDecay = 0.13,
        priceFloor = 500, playerWait = 2.6, enemyWait = 4.0, enemyOpeningWait = 4.0,
        fundingProfitFactor = 3, fundingValueFactor = 0.025,
        fatiguePerRequest = 0.32, reserveProfitFactor = 14,
        openingEnemyBidFactor = 0.035, enemyBudgetFactor = 0.30,
        enemyBidFactor = 0.025, enemyBidVariation = 0.5,
        -- Treasury menu: amount that closes the bid gap (rounded up to two significant
        -- digits) plus neighbouring round steps on the 1-2-2.5-5 ladder.
        treasuryStepsEachSide = 2, treasuryMinimum = 100, treasuryLeadShare = .05, riskMax = 128,
        logLimit = 6, bandAnimationSeconds = 1.8, bandGlowWidth = 96, bandTipWidth=72,
    },
    independence = {safeThreshold=24, chancePerPoint=.0075, maxChance=.78,
        reacquireRisk=38, passiveRecovery=4, stabilizeCost=500, stabilizeAmount=32},
    -- Each real ESO place among a group's members raises its funding multiplier (capped).
    groups = {accelerationBonus=.35, maxDiscoveriesPerRequest=1, landmarkBonusPerMember=.1, landmarkBonusMax=.5},
    tactics = {aiUseChance=.22, effectLimit=12},
    -- Tactic banner: seconds for the move, the opponent's reaction and the verdict.
    -- Two lines over the battle title; the negotiation keeps running underneath.
    tacticScene = {intro=.9, react=1.3, result=2.6, typeSpeed=34},
    campaign = {startingCash = 6500, unlockOwnedStep = 2, chapterOneAssets=500000,
        chapterTwoAlly = "regional_auridon",
        -- Entering chapter 5, this share of every property not already Molag Bal's defects to it
        -- at random (the player's holdings included). Runs once per save.
        molagTakeoverChapter = 5, molagTakeoverShare = .70, molagCompany = "molag",
        -- Reprice the three outer headquarters and final stronghold once as shares of chapter 5's target.
        -- Molag Bal also receives enough real cash to back the larger defensive bids.
        molagHeadquartersAssetShares = {.008, .015, .030, .080},
        molagHeadquartersProfitYield = .065,
        molagTreasuryShare = .62,
        molagFortificationVersion = 3,
        -- First launch asks for the player's company name; these are one-press alternatives.
        companyNameMaxChars = 16,
        companyNameCandidates = {"薄紅の羅針商会","暁鐘交易組合","銀帆の天秤商会","翠星交易社","黒檀と琥珀商会","蒼鷺の隊商組合"}},
    economy = {profitShare=.45,reserveRecoveryPeriods=4,enemyProfitShare=.35,
        rebuildThreshold=1000,rebuildGrant=2500,rebuildReputationCost=8,debtPaymentShare=.25,
        -- Rescue loan follows the market: available when funding power falls below
        -- rebuildTargetShare of the cheapest buyable property, and lends at least its full value.
        rebuildTargetShare=.6,rebuildGrantShare=1.0,
        -- Every settlement compounds every business, including neutral and hostile targets.
        -- Rivals reinvest faster, so postponing an acquisition makes it materially dearer.
        marketGrowth=.020,playerGrowthBonus=.004,neutralGrowthBonus=.002,enemyGrowthBonus=.008,
        maximumPropertyValue=100000000000000,maximumExpectedProfit=10000000000000},
    -- Rival trading, once per settlement: each active rival may buy one neutral or rival property.
    -- Only `samples` random properties are examined per rival, so the cost stays tiny.
    rivals = {tradeChance = .45, samples = 6, priceFactor = .9, maxCashShare = .5,
        sellerShare = .6, biasWeight = 1.5, reportLines = 3,maxDealsPerPeriod=4},
    counterattack = {baseChance = .20, aggressionWeight = .30, maxChance = .78,
        minimumCash = 500, riskWeight = .4, headquartersWeight = .3, valueWeight=1.20,
        -- Avoid a loss spiral when only a handful of holdings remain. Full pressure returns at
        -- nine properties; this changes attack frequency, never the strength of an attack rolled.
        portfolioChanceFloor=.35,portfolioChanceStep=.08,
        -- Later chapters field richer, faster and more experienced acquisition teams.  These
        -- multipliers apply only when the player is defending; ordinary acquisitions keep their
        -- existing balance.  Tactic is an additive chance per enemy decision.
        chapter={
            [1]={chance=0,opening=.90,budget=.90,wait=1.05,acceleration=0,tactic=0,label="探りの買収"},
            [2]={chance=.04,opening=1.10,budget=1.15,wait=.95,acceleration=.05,tactic=.03,label="組織的攻勢"},
            [3]={chance=.08,opening=1.40,budget=1.75,wait=.80,acceleration=.16,tactic=.08,label="広域買収網"},
            [4]={chance=.12,opening=1.65,budget=1.80,wait=.72,acceleration=.20,tactic=.14,label="教団総力戦"},
            [5]={chance=.18,opening=2.10,budget=2.35,wait=.62,acceleration=.32,tactic=.22,label="異界資本侵攻"},
        }},
    enemyGroups={
        chance={.03,.05,.07,.09,.12},maxUses={1,1,1,2,2},capShare={.05,.07,.09,.12,.16},
        contributionShare=.18,bonusEffect=.45,riskFactor=.50,acceleration=.16,effectSeconds=8,
        -- Use a group call as a counterstroke, not while the player is already being crushed.
        maximumEnemyLeadShare=.05,
    },
    -- Every ten settlements the board chooses a policy after learning the new market event.
    strategy = {interval = 10},
    -- Negotiation stances (Data.stances). From minChapter, rivals guard routine properties with
    -- their house stance at routineShare, neutral owners at neutralShare, and critical
    -- negotiations always (with `criticalHits` counters needed). Breaking one swings the border.
    stances = {minChapter=2, routineShare=.6, neutralShare=.3, criticalHits=2, breakVelocity=2.2, pressureCap=.10, criticalCapShare=1.2, extraStanceTighten=.5,
        house={wealth="vault",aggressive="courier",subversion="bloc",information="opinion"}},
    -- Routine acquisitions may be delegated, but chapter targets, headquarters and the final
    -- stronghold are always fought by the player in the realtime negotiation screen.
    delegation = {minimumChapter=2, successCostShare=.60, failureCostShare=.10,
        baseChance=.62, reputationWeight=.002, defenseWeight=.15, minimumChance=.35, maximumChance=.90,
        stancePenalty=.18},
    -- Critical negotiations escalate on these negotiation days. Reinforcements are paid from
    -- the rival's actual company cash and group reserves, so weakening it beforehand matters.
    criticalBattle = {days={2,4,6}, reinforcementShares={.04,.06,.08},
        acceleration={.20,.35,.55}, effectSeconds=18, finalStrongholdMultiplier=1.5,
        names={"外郭契約を発動","服従の鎖を解放","最後の勅令を宣言"}},
    input = {deadzone = 0.45, firstRepeat = 0.32, repeatDelay = 0.15, imeCommitDelay = 0.35},
    ui = {width = 1240, height = 780, updateMs = 33, fullRefreshSeconds = .25,
        -- Battle popups above the coin bays: fade in, hold (shorter while more are queued), fade out.
        popupFadeIn = .15, popupHold = 2.2, popupBusyHold = .9, popupFadeOut = .25, popupWideHold = 2.8, pageSize = 10, mapPageSize = 8, keybindHeight = 48},
    theme = {
        background={.035,.047,.045,1}, panel={.075,.090,.084,1},
        parchment={.18,.185,.157,1}, text={.83,.81,.72,1},
        gold={.61,.53,.36,1}, edge={.26,.28,.235,1},
        row={.11,.13,.115,1}, selected={.28,.29,.22,1},
        own={.12,.25,.23,1}, enemy={.29,.16,.17,1},
        neutral={.23,.22,.16,1}, locked={.12,.135,.125,1},
        ally={.12,.24,.34,1}, allyText={.58,.84,1,1},
    },
    coins = {limit = 640, createPerFrame = 64, columns = 16, minUnit = 25, valueDivisor = 240,
        -- Every payment lands within its own duration: a dense opening volley whose share grows
        -- with the amount, then a tail whose gaps widen until the final coin. The duration grows
        -- on a log scale from minDuration (a single coin unit) to duration (durationFullUnits+).
        duration = 4, minDuration = 1.0, durationFullUnits = 240, fastFlight = .28, slowFlight = .55, finalFlight = .70,
        volleyWindow = .35, volleyShareMin = .40, volleyShareMax = .70, tailPower = 2.2,
        deceleration = 2, minimumSprites = 8, width = 44, height = 22, stackStep = 8,
        pileWidth = 270, floorY = 202, tipY = 58, viewportHeight = 248,
        -- Stack scroll (px/s): the plate slides down smoothly while the tip stays in view.
        scrollFollowRate = 7, scrollMinSpeed = 240, scrollMaxSpeed = 1200, scrollMaxLag = 4000,
        -- The stack follows the camera immediately; the stone plate may trail it by at most
        -- this much, preventing the plate from visually outrunning the bottom coins.
        plinthLagFactor = .25, plinthMaxLag = 44,
        -- Beyond visualLinearUnits coins the drawn height grows logarithmically.
        -- visualMaxUnits keeps the drawn height inside scrollMaxLag so the plate never jumps.
        visualLinearUnits = 320, visualLogGain = 2, visualMaxUnits = 7800,
        -- Back, middle, front: staggered ranks form a rounded bundle of coin pillars.
        ranks = {{count=5,x=30,y=-44,scale=.90,shade=.82},
            {count=6,x=9,y=-22,scale=.96,shade=.92},
            {count=5,x=30,y=0,scale=1,shade=1}},
        pillarSpacing = 44, plinthWidth = 302, plinthHeight = 96, plinthOffsetY = -52,
        maxFalling = 72, burstSprites = 96,
        soundEnabled = true, soundKey = "ITEM_MONEY_CHANGED"},
    -- Group funding: "<group>を知るもの来たれ！" is called for `seconds`, then the coins fall.
    groupCall = {seconds = 1.5},
    -- Taking every headquarters of a rival dissolves it: all its properties and this share of its cash.
    -- Headquarters are defended by the whole group: the negotiation is valued at hqValueShare (1 = all) of
    -- the company's total assets (cash + property values), and property reserves back its bids.
    takeover = {cashShare = .5, hqValueShare = 1.0},
    -- Post-campaign free trade. The true ending is tied to a final acquisition rather than
    -- an unknowable number of live ESO locations; these fields remain save-compatible.
    endless = {independenceShare = .15, independenceRisk = 40},
    -- Real ESO places are priced by what they are, read from their names (first match wins).
    -- mult scales the average value of the regular properties at that moment (so prices follow
    -- the market as periods pass); yield is profit per value. Unmatched places get mult 1.
    -- `base` is only a fallback when no average can be taken. Bump `version` to re-price saves.
    canonical = {version = 5, base = 9000, jitter = .15, defaultYield = .06,
        -- Exact localized-name overrides are checked after punctuation/space normalization.
        -- They enter the market at this fixed value; later settlements and investment can grow it.
        -- Raw value is converted by Money below: 100,000,000,000,000 x 10,000 = 100京.
        specialValues = { ["トールドライオク"]={value=100000000000000,yield=.06,label="最終物件",category="market",finalAcquisition=true} },
        houseRegions = {[1]="auridon",[2]="glenumbra"},
        tiers = {
        {label="銀行", mult=24, yield=.09, category="market", words={"銀行","両替","金庫","bank","vault","exchequer"}},
        {label="宮殿・王城", mult=18, yield=.05, category="fighters", words={"宮殿","王宮","王城","城","palace","castle","citadel","keep"}},
        {label="大聖堂・神殿", mult=10, yield=.05, category="books", words={"大聖堂","神殿","聖堂","寺院","祠堂","cathedral","temple","chapel","shrine"}},
        {label="闘技場", mult=9, yield=.08, category="fighters", words={"闘技場","アリーナ","arena","colosseum"}},
        {label="ギルド会館", mult=7, yield=.07, category="mages", words={"ギルド","会館","guild","hall"}},
        {label="港湾", mult=6, yield=.07, category="port", words={"港","埠頭","波止場","harbor","harbour","dock","port","wharf"}},
        {label="市場・交易所", mult=5, yield=.08, category="market", words={"市場","交易所","商館","商店","バザール","market","bazaar","trading","emporium"}},
        {label="図書館・学院", mult=4.5, yield=.05, category="books", words={"図書館","書庫","学院","アカデミー","library","archive","academy","college"}},
        {label="鉱山・採石場", mult=4, yield=.08, category="mine", words={"鉱山","採掘","採石","坑道","mine","quarry"}},
        {label="街・都市", mult=3.5, yield=.06, category="market", words={"街","都","市","町","城下","city","town","village","ward","district"}},
        {label="工房・鍛冶場", mult=3, yield=.07, category="forge", words={"鍛冶","工房","鋳造","forge","smithy","workshop","foundry"}},
        {label="灯台・砦", mult=2.5, yield=.05, category="fighters", words={"灯台","砦","要塞","見張り","塔","lighthouse","fort","tower","outpost","watch"}},
        {label="宿屋", mult=1.4, yield=.07, category="inn", words={"宿","旅籠","inn","lodge"}},
        {label="酒場", mult=1.2, yield=.08, category="tavern", words={"酒場","パブ","亭","tavern","pub","alehouse"}},
        {label="農場・牧場", mult=1, yield=.06, category="farm", words={"農場","農園","果樹園","牧場","ぶどう園","farm","orchard","ranch","vineyard","plantation"}},
        {label="野営地・遺跡", mult=.6, yield=.03, category="caravan", words={"野営","遺跡","廃墟","洞窟","洞穴","camp","ruin","ruins","cave","grotto","barrow"}},
    }},
    -- Alliances with rival companies: formed in domestic affairs, strained by buying the ally's
    -- properties or leaning on its funds, broken when trust reaches zero.
    alliance = {maxAlliances = 2, startTrust = 70, maxTrust = 100, costShare = .02, minimumCost = 2000,
        baseChance = .25, reputationWeight = .005, powerWeight = .3, aggressionWeight = .25,
        fundShare = .06, fundMinimum = 500, fundTrust = 12, acquireTrust = 35, trustRecovery = 6,
        refuses = {molag = true}},
    -- Domestic affairs (内政), between the defense check and the settlement: a few costed actions.
    admin = {actions = 3,
        investCostShare = .12, investRepeatSurcharge = .5, investValueGain = .10, investProfitGain = .12,
        lobbyCostShare = .03, lobbyMinimumCost = 500, lobbyAmount = 30,
        guardCostShare = .01, guardMinimumCost = 1000, guardPeriods = 2, guardChanceFactor = .5,
        repayCashShare = .5, repayReputation = 2,
        -- Divest: a property leaves the company for a share of its value.
        divestShare = .8, divestRisk = 20,
        -- Bond: cash now, repaid with interest from settlements; capped by a debt ceiling.
        bondShare = .15, bondMinimum = 2500, bondInterest = .10, bondDebtCap = .6,
        -- Sabotage: drain a rival's cash; failure is a scandal that invites counterattacks.
        sabotageCostShare = .01, sabotageMinimumCost = 1000, sabotageDrain = .12,
        sabotageBaseChance = .8, sabotageDefenseWeight = .4, scandalReputation = 5, scandalChanceFactor = 1.5,
        -- Hire: a seasoned negotiator joins the next negotiation (opening momentum, quicker messengers).
        hireCostShare = .015, hireMinimumCost = 1500, hireMomentum = 1.2, hireWaitFactor = .75, hireSeconds = 60},
    -- Opening narration: seconds per character (punctuation adds pauses), background fade and drift.
    opening = {fontSize = 34, charSeconds = .055, fadeSeconds = .7, driftSeconds = 9, driftZoom = .06},
    uiSounds={counterattackWarning="GENERAL_ALERT_ERROR",counterattack="AVA_KEEP_CAPTURED",takeover="GUILD_KEEP_CLAIMED",openingStart="BOOK_OPEN",openingPage="BOOK_PAGE_TURN",openingEnd="BOOK_CLOSE",groupDiscovery="SKILL_LINE_ADDED",groupCall="ANTIQUITIES_FANFARE_COMPLETED",tactic="DUEL_START",tacticSuccess="TELVAR_GAINED",tacticFail="GENERAL_ALERT_ERROR",discovery="ACHIEVEMENT_AWARDED",defection="GENERAL_ALERT_ERROR",statusPositive="TELVAR_GAINED",statusNegative="GENERAL_ALERT_ERROR",
        chapter="QUEST_OBJECTIVE_STARTED",ending="ACHIEVEMENT_AWARDED",settlement="TELVAR_GAINED"},
}
-- v0.17.1 changes every economic unit to 10,000 of the former unit.  `Money` may add a
-- stable sub-10,000 remainder so catalog prices look like negotiated figures rather than
-- round debug values.  The same key always yields the same amount on every client.
local C=PBTrade.Config
C.currencyScale=10000; C.currencyVersion=1
function C.Money(value,key)
    local raw=1.0*(value or 0)*C.currencyScale
    -- Lua 5.4's math.floor converts to a signed integer and wraps values above 2^63-1.
    -- ESO uses doubles, but keeping the shared model portable prevents late-campaign goals
    -- late-campaign totals from becoming negative in desktop tests and tooling.
    local outsideInteger=math.maxinteger and (raw>math.maxinteger or raw<math.mininteger)
    local scaled=outsideInteger and raw or math.floor(raw+.5)
    if scaled==0 or not key then return scaled end
    local hash=23; key=tostring(key)
    for i=1,#key do hash=(hash*131+key:byte(i))%C.currencyScale end
    return scaled+hash
end
C.battle.treasuryMinimum=C.Money(C.battle.treasuryMinimum)
C.independence.stabilizeCost=C.Money(C.independence.stabilizeCost)
C.campaign.startingCash=C.Money(C.campaign.startingCash,"player:cash")
C.campaign.chapterOneAssets=C.Money(C.campaign.chapterOneAssets)
C.economy.rebuildThreshold=C.Money(C.economy.rebuildThreshold)
C.economy.rebuildGrant=C.Money(C.economy.rebuildGrant)
C.economy.maximumPropertyValue=C.Money(C.economy.maximumPropertyValue)
C.economy.maximumExpectedProfit=C.Money(C.economy.maximumExpectedProfit)
C.counterattack.minimumCash=C.Money(C.counterattack.minimumCash)
C.canonical.base=C.Money(C.canonical.base)
for _,special in pairs(C.canonical.specialValues) do special.value=C.Money(special.value) end
C.alliance.minimumCost=C.Money(C.alliance.minimumCost)
C.alliance.fundMinimum=C.Money(C.alliance.fundMinimum)
C.admin.lobbyMinimumCost=C.Money(C.admin.lobbyMinimumCost)
C.admin.guardMinimumCost=C.Money(C.admin.guardMinimumCost)
C.admin.bondMinimum=C.Money(C.admin.bondMinimum)
C.admin.sabotageMinimumCost=C.Money(C.admin.sabotageMinimumCost)
C.admin.hireMinimumCost=C.Money(C.admin.hireMinimumCost)
