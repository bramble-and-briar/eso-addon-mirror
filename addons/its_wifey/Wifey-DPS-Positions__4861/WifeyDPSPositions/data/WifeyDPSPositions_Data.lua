-- WifeyDPSPositions_Data.lua
WifeyDPSPositions = WifeyDPSPositions or {}
local DDP = WifeyDPSPositions

DDP.version = "1.6.11"
DDP.positions = {
	[636] = { mechOrder = {"2Groups"}, mechanics = {["2Groups"] = {"Upstairs","Upstairs","Upstairs","Upstairs","Downstairs","Downstairs","Downstairs","Downstairs"}} },
	[725] = {
        mechOrder = {"2Groups", "Runner"},
        mechanics = {
            ["2Groups"] = {"Exit","Exit","Exit","Exit","Entrance","Entrance","Entrance","Entrance"},
            ["Runner"] = {"LEFT", "MIDDLE", "RIGHT", "BACKUP"},
        },
    },
	[975] = {
        mechOrder = {"Portals", "2Groups"},
        mechanics = {
            ["Portals"] = {"N","S","W","E"},
            ["2Groups"] = {"Left","Left","Left","Left","Right","Right","Right","Right",},
        },
    },
    [1000] = { mechOrder = {"Positions"}, mechanics = {["Positions"] = {"1","2","3","4","5","6","7","8"}} },
    [1051] = { mechOrder = {"Portals", "Orbs"}, mechanics = {["Portals"] = {"P1","P1","P2","P2","BACKUP"}, ["Orbs"] = {"Orbs"}} },
    [1121] = {
        mechOrder = {"Tombs", "Head&Wing", "Portals", "Positions(HM)", "Tombs(HM)"},
        mechanics = {
            ["Tombs"] = {"T1","T2","T3"},
            ["Head&Wing"] = {"Head","Head","Head","Head","Wing","Wing","Wing","Wing"},
            ["Portals"] = {"P.Left","P.Middle","P.Right"},
            ["Positions(HM)"] = {"1","2","3","4","5","6","7","8"},
            ["Tombs(HM)"] = {"T1A","T1B","T2A","T2B","T3A","T3B"},
        },
    },
    [1196] = {
        mechOrder = {"Yandir", "Boat", "Line", "Stack(HM)"},
        mechanics = {
            ["Yandir"] = {"1","2","3","4","5","6","7","8"},
            ["Boat"] = {"Boat"},
            ["Line"] = {"Line1","Line2","Line3","Line4","Line5"},
            ["Stack(HM)"] = {"1","1","2","2","3","3","4","4"},
        },
    },
    [1263] = { mechOrder = {"Kite"}, mechanics = {["Kite"] = {"Kite"}} },
    [1344] = {
        mechOrder = {"Twins", "Interrupts", "Reefs", "Bridges", "Interrupts(HM)"},
        mechanics = {
            ["Interrupts"] = {"Exit.R & Swap","Exit.L & Swap","Entrance.R","Entrance.L"},
            ["Reefs"] = {"1-2-5-8","1-2-5-8","3-6-9","3-6-9","4-7-10","4-7-10"},
            ["Bridges"] = {"B1","B1","B2","B2","B3","B3"},
            ["Twins"] = {"FIRE","FIRE","FIRE","FIRE","ICE","ICE","ICE","ICE"},
            ["Interrupts(HM)"] = {"Exit.R","Exit.L","Entrance.R","Entrance.L","Exit.R","Exit.L","Entrance.R","Entrance.L"},
        },
    },
    [1427] = {
        mechOrder = {"Portals", "2Groups", "Ansuul Portal"},
        mechanics = {
            ["Portals"] = {"P1","P1","P1","P1","P2","P2","P2","P2"},
            ["2Groups"] = {"Left","Left","Left","Left","Right","Right","Right","Right"},
            ["Ansuul Portal"] = {"+Portal","+Portal","+Portal"},
        },
    },
    [1478] = {
        mechOrder = {"2Groups", "Mirrors"},
        mechanics = {
            ["2Groups"] = {"Dark","Dark","Dark","Dark","Light","Light","Light","Light"},
            ["Mirrors"] = {"N","S","E","W","NE","SE","SW","NW"},
        },
    },
	[1548] = {
        mechOrder = {"Portal", "2Groups", "HM CURSE", "HM PORTALS"},
        mechanics = {
            ["Portal"] = {"P","P","P","P","P","Healer"},
            ["2Groups"] = {"Left","Left","Left","Left","Right","Right","Right","Right"},
            -- HM CURSE is the source-of-truth board. All 12 players are assigned here.
            ["HM CURSE"] = {
                "B TANK","B HEALER","B CURSE 1","B CURSE 2","B CURSE 3","B CURSE 4",
                "R TANK","R HEALER","R CURSE 1","R CURSE 2","R CURSE 3","R CURSE 4",
            },
            -- HM PORTALS is derived from HM CURSE so the same people can never drift to the wrong side.
            ["HM PORTALS"] = {
                "B DRAGON","B DRAGON","B DRAGON",
                "B CHANNELER","B CHANNELER","B CHANNELER",
                "R DRAGON","R DRAGON","R DRAGON",
                "R CHANNELER","R CHANNELER","R CHANNELER",
            },
        },
    },
}
