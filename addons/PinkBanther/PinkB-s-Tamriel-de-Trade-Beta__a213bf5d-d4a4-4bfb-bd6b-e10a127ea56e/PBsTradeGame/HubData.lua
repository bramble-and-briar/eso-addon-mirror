-- Phase 6: all prices are real gold, derived once at order time.
local K={version=5,minChapter=3,size=5,maximumSize=9,chapterSize={[3]=5,[4]=7,[5]=9},constructionSlots=2,maxLevel=3,
    eventChance=.10,eventGap=5,eventSeed=73129,eventLogLimit=6,
    policies={
        {id="balanced",name="均衡運営",income=1,upkeep=1,abilities={},description="収益・維持費・能力を均衡させる"},
        {id="commerce",name="商業振興",income=1.10,upkeep=1.15,abilities={commerce=1.10},description="収益+10%、商業力+10%、維持費+15%"},
        {id="security",name="安全優先",income=.95,upkeep=1,abilities={logistics=1.10},adverse=.5,description="収益-5%、物流力+10%、不利な事件の影響を半減"},
        {id="research",name="情報投資",income=.95,upkeep=1.05,abilities={information=1.15},description="情報力+15%、収益-5%、維持費+5%"},
    },
    events={
        {id="merchants",name="隊商の来訪",duration=3,income=1.15,upkeep=1,description="拠点収益+15%"},
        {id="fair",name="交易博覧会",duration=2,income=1.10,upkeep=1,abilities={influence=1.10},description="収益・影響力+10%"},
        {id="shortage",name="資材の品薄",duration=2,income=1,upkeep=1.20,adverse=true,description="維持費+20%（施設は失われません）"},
        {id="repairs",name="街路の補修",duration=2,income=.85,upkeep=1,adverse=true,description="収益-15%（施設は失われません）"},
        {id="scholars",name="旅の学者団",duration=3,income=1,upkeep=1,abilities={information=1.10},description="情報力+10%"},
    },
    blueprints={
        bank={name="商業金庫設計",categories={jewelry=true,market=true}},
        market={name="広域市場設計",categories={market=true,farm=true}},
        warehouse={name="隊商物流設計",categories={port=true,caravan=true}},
        tavern={name="情報交換所設計",categories={books=true,tavern=true}},
        guildhall={name="使節庁舎設計",categories={mages=true,fighters=true}},
        exchange={name="清算取引設計",categories={market=true,jewelry=true}},
        bureau={name="諜報庁設計",categories={books=true,alchemy=true}},
        embassy={name="外交院設計",categories={mages=true,fighters=true}},
        gate={name="次元門設計",categories={mages=true,caravan=true}},
        aether={name="異界市設計",categories={mages=true,market=true}},
        pact={name="契約金庫設計",categories={mages=true,jewelry=true}},
    },blueprintBonus=.10,supplyPerProperty=.025,supplyLimit=4,
    -- A facility family softens the stance it answers: each stance is eased by up to
    -- stanceReliefMax, scaled by that ability's coverage (ability / (ability + threshold)).
    stanceAbility={vault="capital",courier="logistics",bloc="influence",opinion="information"},stanceReliefMax=.5,
    battle={threshold={[3]=35,[4]=70,[5]=120},pressurePenalty=.20,valuePenalty=.15,
        pressureBonus=.10,idleRelief=.10,enemyWaitBonus=.10,playerWaitRelief=.10,resistanceRelief=.10,
        styles={steady="influence",wealth="capital",aggressive="logistics",information="information",subversion="information",dominion="influence"},
        specialist=1.4},
    upgradeShare=.65,upgradePeriods=2,moveShare=.10,movePeriods=1,
    demolitionRefund=.40,cancelRefund=.25,levelAbilityStep=.60,
    roadIncome=.05,adjacencyIncome=.04,maximumLayoutIncome=.25,districtChapter=4,maximumDistricts=3,
    adjacency={
        {a="exchange",b="bank",name="清算網",abilities={capital=5,commerce=3}},
        {a="bureau",b="tavern",name="諜報連絡",abilities={information=5}},
        {a="embassy",b="guildhall",name="外交使節",abilities={influence=5}},
        {a="gate",b="warehouse",name="次元物流",abilities={logistics=6}},
        {a="aether",b="market",name="異界販路",abilities={commerce=6}},
        {a="pact",b="bank",name="異界信用",abilities={capital=5,influence=3}},
        {a="market",b="warehouse",name="隊商流通",abilities={commerce=3,logistics=3}},
        {a="bank",b="market",name="取引信用",abilities={capital=3,commerce=2}},
        {a="tavern",b="guildhall",name="商人の情報網",abilities={information=3,influence=2}},
        {a="bank",b="guildhall",name="融資協定",abilities={capital=2,influence=3}},
    },
    districts={
        {id="arcane",name="次元交易区",needs={gate=1,aether=1,pact=1},abilities={capital=10,commerce=10,logistics=10},income=.10,color={.35,.55,.85,1}},
        {id="diplomatic",name="外交街",needs={embassy=1,bureau=1,guildhall=1},abilities={influence=15,information=10},income=.10,color={.65,.52,.75,1}},
        {id="finance",name="金融街",needs={bank=2,guildhall=1},abilities={capital=15,influence=5},income=.10,color={.70,.57,.28,1}},
        {id="trade",name="交易区",needs={market=2,warehouse=1},abilities={commerce=12,logistics=8},income=.10,color={.30,.65,.53,1}},
        {id="information",name="情報街",needs={tavern=2,guildhall=1},abilities={information=15,influence=5},income=.10,color={.50,.45,.70,1}},
    },
    decoration={seed=24691,plainShare=70,treeShare=15},
    -- Prices are a share of the company's own wealth (Model.HubCostBase), not of the market mean,
    -- which the ultra-priced chapter-5 strongholds skew by four orders of magnitude.
    costShare=.0025,minimumCost=5000000,maximumCost=1e20,assetShare=1,
    -- Capacity: buildings may cover only this share of the plots; the rest stays green space.
    capacityShare=.6,
    upkeepShare=.006,incomeShare=.018,growthPerBuilding=1,
    abilities={{id="capital",name="資本力"},{id="commerce",name="商業力"},
        {id="logistics",name="物流力"},{id="information",name="情報力"},{id="influence",name="影響力"}},
    facilities={
        {id="bank",name="交易銀行",short="銀行",periods=2,cost=1.4,height=50,color={.64,.54,.33,1},abilities={capital=12,influence=2}},
        {id="market",name="青銅屋根の市場",short="市場",periods=2,cost=1,height=30,color={.24,.52,.45,1},abilities={commerce=12}},
        {id="warehouse",name="隊商倉庫",short="倉庫",periods=2,cost=.8,height=38,color={.52,.37,.23,1},abilities={logistics=12}},
        {id="tavern",name="交易路の酒場",short="酒場",periods=2,cost=.9,height=42,color={.52,.25,.24,1},abilities={information=10,commerce=3}},
        {id="guildhall",name="使節商館",short="商館",periods=3,cost=1.3,height=60,color={.34,.38,.59,1},abilities={influence=12,information=2}},
        {id="exchange",asset="bank",tint={1,.88,.60,1},name="金衡取引所",short="取引所",minChapter=4,periods=3,cost=2.8,income=1.25,upkeep=1.7,abilities={capital=22,commerce=8}},
        {id="bureau",name="梟羽情報局",short="情報局",minChapter=4,periods=3,cost=2.4,income=.9,upkeep=.9,abilities={information=24,logistics=4}},
        {id="embassy",asset="guildhall",tint={.72,1,.94,1},name="白環大使館",short="大使館",minChapter=4,periods=3,cost=2.6,income=1,upkeep=1.2,abilities={influence=24,information=4}},
        {id="gate",name="星渡り交易門",short="交易門",minChapter=5,periods=4,cost=4,income=1.1,upkeep=1.6,abilities={logistics=28,information=8}},
        {id="aether",asset="market",tint={.60,.86,1,1},name="エセリアル市場",short="異界市場",minChapter=5,periods=4,cost=4.2,income=1.25,upkeep=1.7,abilities={commerce=28,capital=8}},
        {id="pact",asset="bank",tint={.72,.55,.88,1},name="黒曜契約銀行",short="契約銀行",minChapter=5,periods=4,cost=4.4,income=1.1,upkeep=1.6,abilities={capital=26,influence=10}},
    }}
K.policyById={}; for _,p in ipairs(K.policies) do K.policyById[p.id]=p end
K.eventById={}; for _,e in ipairs(K.events) do K.eventById[e.id]=e end
K.byId={}; for _,f in ipairs(K.facilities) do K.byId[f.id]=f end
PBTrade.HubData=K
