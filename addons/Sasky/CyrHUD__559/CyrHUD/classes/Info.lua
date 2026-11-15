-- This file is part of CyrHUD
--
-- (C) 2015 Scott Yeskie (Sasky)
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

CyrHUD = CyrHUD or {}

local AD = ALLIANCE_ALDMERI_DOMINION
local DC = ALLIANCE_DAGGERFALL_COVENANT
local EP = ALLIANCE_EBONHEART_PACT

CyrHUD.colors = {}
local colors = CyrHUD.colors

--Transparent BG colors
colors.blackTrans = ZO_ColorDef:New(0, 0, 0, .5)
colors.greenTrans = ZO_ColorDef:New(.2, .5, .2, .6)
colors.greyTrans = ZO_ColorDef:New(.5, .5, .5, .3)
colors.invisible = ZO_ColorDef:New(0,0,0,0)
colors.redTrans = ZO_ColorDef:New(.5, 0, 0, .3)

--Colors 
colors.blue = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_ALLIANCE, ALLIANCE_DAGGERFALL_COVENANT)) -- DC color
colors.red = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_ALLIANCE, ALLIANCE_EBONHEART_PACT)) -- EP color
colors.white = ZO_ColorDef:New(.8, .8, .8, 1)
colors.black = ZO_ColorDef:New(0, 0, 0, 1)
colors.yellow = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_ALLIANCE, ALLIANCE_ALDMERI_DOMINION)) -- AD color
colors.green = ZO_ColorDef:New("2FC821") --  47, 200, 33, 1

CyrHUD.width = 280

CyrHUD.info = {}
CyrHUD.info.underAttack = "/esoui/art/mappins/ava_attackburst_64.dds"
CyrHUD.info.defendedColor = colors.greenTrans
CyrHUD.info.newAttackColor = colors.redTrans
CyrHUD.info.endAttackColor = colors.greyTrans
CyrHUD.info.defaultBGColor = colors.blackTrans
CyrHUD.info.invisColor = colors.invisible
CyrHUD.info.linkColor = colors.green
CyrHUD.info.fontMain = GetString(SI_CYRHUD_FONT)
CyrHUD.info.fontSmall = GetString(SI_CYRHUD_FONT_SMALL)
CyrHUD.info[ALLIANCE_NONE] = {}
CyrHUD.info[ALLIANCE_NONE].color = colors.white
CyrHUD.info[4] = {}
CyrHUD.info[4].color = colors.black
CyrHUD.info[AD] = {}
CyrHUD.info[AD].color = colors.yellow
CyrHUD.info[AD].flag = "/esoui/art/ava/ava_hud_emblem_aldmeri.dds" --"/esoui/art/ava/ava_allianceflag_aldmeri.dds"
CyrHUD.info[DC] = {}
CyrHUD.info[DC].color = colors.blue
CyrHUD.info[DC].flag = "/esoui/art/ava/ava_hud_emblem_daggerfall.dds" --"/esoui/art/ava/ava_allianceflag_daggerfall.dds"
CyrHUD.info[EP] = {}
CyrHUD.info[EP].color = colors.red
CyrHUD.info[EP].flag = "/esoui/art/ava/ava_hud_emblem_ebonheart.dds" --"/esoui/art/ava/ava_allianceflag_ebonheart.dds"
CyrHUD.icons = {}
CyrHUD.icons[KEEPTYPE_KEEP] = "/esoui/art/mappins/ava_largekeep_neutral.dds"
CyrHUD.icons[KEEPTYPE_OUTPOST] = "/esoui/art/mappins/ava_outpost_neutral.dds"
CyrHUD.icons[KEEPTYPE_IMPERIAL_CITY_DISTRICT] = "/esoui/art/mappins/ava_imperialdistrict_neutral.dds"
CyrHUD.icons[KEEPTYPE_TOWN] = "/esoui/art/mappins/ava_town_neutral.dds"
CyrHUD.icons[KEEPTYPE_MILEGATE] = "/esoui/art/mappins/ava_milegate_passable.dds" 
CyrHUD.icons[KEEPTYPE_MILEGATE+555] = "/esoui/art/mappins/ava_milegate_center_destroyed.dds"
CyrHUD.icons[KEEPTYPE_MILEGATE+999] = "/esoui/art/mappins/ava_milegate_not_passable.dds" 
CyrHUD.icons[KEEPTYPE_BRIDGE] = "/esoui/art/mappins/ava_bridge_passable.dds"
CyrHUD.icons[KEEPTYPE_BRIDGE+999] = "/esoui/art/mappins/ava_bridge_not_passable.dds"
CyrHUD.icons[KEEPTYPE_ARTIFACT_GATE] = "/esoui/art/icons/mapkey/mapkey_artifactgate_open.dds"
CyrHUD.icons[KEEPTYPE_ARTIFACT_GATE+999] = "/esoui/art/icons/mapkey/mapkey_artifactgate_closed.dds"
CyrHUD.icons[KEEPTYPE_ARTIFACT_KEEP*MAP_PIN_TYPE_ARTIFACT_KEEP_ALDMERI_DOMINION] = "/esoui/art/mappins/ava_artifacttemple_aldmeri.dds"
CyrHUD.icons[KEEPTYPE_ARTIFACT_KEEP*MAP_PIN_TYPE_ARTIFACT_KEEP_DAGGERFALL_COVENANT] = "/esoui/art/mappins/ava_artifacttemple_daggerfall.dds"
CyrHUD.icons[KEEPTYPE_ARTIFACT_KEEP*MAP_PIN_TYPE_ARTIFACT_KEEP_EBONHEART_PACT] = "/esoui/art/mappins/ava_artifacttemple_ebonheart.dds"

CyrHUD.icons["lowPopBonus"] = "/esoui/art/ava/overview_icon_underdog_population.dds"
CyrHUD.icons["lowScoreBonus"] = "/esoui/art/ava/overview_icon_underdog_score.dds"

CyrHUD.icons[10 + RESOURCETYPE_FOOD] = "/esoui/art/mappins/ava_farm_neutral.dds"
CyrHUD.icons[10 + RESOURCETYPE_ORE] = "/esoui/art/mappins/ava_mine_neutral.dds"
CyrHUD.icons[10 + RESOURCETYPE_WOOD] = "/esoui/art/mappins/ava_lumbermill_neutral.dds"
CyrHUD.icons["offSiege"] = "/esoui/art/icons/ava_siege_weapon_001.dds"
CyrHUD.icons["defSiege"] = "/esoui/art/icons/ava_siege_weapon_002.dds"
CyrHUD.icons["scrollAD"] = "/esoui/art/campaign/overview_scrollicon_aldmeri.dds"
CyrHUD.icons["scrollEP"] = "/esoui/art/campaign/overview_scrollicon_ebonheart.dds"
CyrHUD.icons["scrollDC"] = "/esoui/art/campaign/overview_scrollicon_daggerfall.dds"
CyrHUD.icons["ConnectedKeep"] = "/CyrHUD/textures/keep_connected_to_fast_travel_network.dds" 
CyrHUD.icons["DisconnectedKeep"] = "/CyrHUD/textures/keep_disconnected_from_fast_travel_network.dds"
CyrHUD.icons["arrow"] = "/esoui/art/unitattributevisualizer/attributebar_arrow.dds"

CyrHUD.icons[ALLIANCE_ALDMERI_DOMINION] = "EsoUI/Art/AvA/avaCaptureBar_allianceBadge_aldmeri.dds"
CyrHUD.icons[ALLIANCE_EBONHEART_PACT] = "EsoUI/Art/AvA/avaCaptureBar_allianceBadge_ebonheart.dds"
CyrHUD.icons[ALLIANCE_DAGGERFALL_COVENANT] = "EsoUI/Art/AvA/avaCaptureBar_allianceBadge_daggerfall.dds"

CyrHUD.icons["emperor"] = "esoui/art/campaign/gamepad/gp_overview_menuicon_emperor.dds"

CyrHUD.info["gauge"] = {}
CyrHUD.info["gauge"][0] = {}
CyrHUD.info["gauge"][1] = {}
CyrHUD.info["gauge"][2] = {}
CyrHUD.info["gauge"][3] = {}

CyrHUD.info["gauge"][0][0] = {}
CyrHUD.info["gauge"][0][1] = {}
CyrHUD.info["gauge"][0][2] = {}
CyrHUD.info["gauge"][0][3] = {}

CyrHUD.info["gauge"][1][0] = {}
CyrHUD.info["gauge"][1][0]["100"] = "/CyrHUD/textures/gauge_AD_full.dds"
CyrHUD.info["gauge"][1][0]["83.333"] = "/CyrHUD/textures/gauge_AD_full.dds"
CyrHUD.info["gauge"][1][0]["66.666"] = "/CyrHUD/textures/gauge_AD_near_full.dds"
CyrHUD.info["gauge"][1][0]["51"] = "/CyrHUD/textures/gauge_AD_above.dds"
CyrHUD.info["gauge"][1][0]["49"] = "/CyrHUD/textures/gauge_AD_below.dds"
CyrHUD.info["gauge"][1][0]["33.333"] = "/CyrHUD/textures/gauge_AD_below.dds"
CyrHUD.info["gauge"][1][0]["16.666"] = "/CyrHUD/textures/gauge_AD_near_empty.dds"


CyrHUD.info["gauge"][2][0] = {}
CyrHUD.info["gauge"][2][0]["100"] = "/CyrHUD/textures/gauge_EP_full.dds"
CyrHUD.info["gauge"][2][0]["83.333"] = "/CyrHUD/textures/gauge_EP_full.dds"
CyrHUD.info["gauge"][2][0]["66.666"] = "/CyrHUD/textures/gauge_EP_near_full.dds"
CyrHUD.info["gauge"][2][0]["51"] = "/CyrHUD/textures/gauge_EP_above.dds"
CyrHUD.info["gauge"][2][0]["49"] = "/CyrHUD/textures/gauge_EP_below.dds"
CyrHUD.info["gauge"][2][0]["33.333"] = "/CyrHUD/textures/gauge_EP_below.dds"
CyrHUD.info["gauge"][2][0]["16.666"] = "/CyrHUD/textures/gauge_EP_near_empty.dds"


CyrHUD.info["gauge"][3][0] = {}
CyrHUD.info["gauge"][3][0]["100"] = "/CyrHUD/textures/gauge_DC_full.dds"
CyrHUD.info["gauge"][3][0]["83.333"] = "/CyrHUD/textures/gauge_DC_full.dds"
CyrHUD.info["gauge"][3][0]["66.666"] = "/CyrHUD/textures/gauge_DC_near_full.dds"
CyrHUD.info["gauge"][3][0]["51"] = "/CyrHUD/textures/gauge_DC_above.dds"
CyrHUD.info["gauge"][3][0]["49"] = "/CyrHUD/textures/gauge_DC_below.dds"
CyrHUD.info["gauge"][3][0]["33.333"] = "/CyrHUD/textures/gauge_DC_below.dds"
CyrHUD.info["gauge"][3][0]["16.666"] = "/CyrHUD/textures/gauge_DC_near_empty.dds"


CyrHUD.info["gauge"][0][0]["100"] = "/CyrHUD/textures/gauge_neutral.dds"


--For no icon fallback
setmetatable(CyrHUD.icons, {__index = function(_,k)
    CyrHUD:error("Bad icon lookup: " .. k)
    return "/esoui/art/mappins/ava_largekeep_neutral.dds"
end})

-- 05/07/2026 defensive fix:
-- CyrHUD.info is indexed all over the addon by alliance-like values that
-- come from live game state (self.defender, holdingAlliance, attackingAlliance,
-- self.UnderdogleaderAlliance, an emperor's alliance, etc.), almost always
-- immediately followed by `.color:UnpackRGBA()`. Only ALLIANCE_NONE, AD, DC,
-- EP, and the special value 4 are pre-populated above -- any other value
-- (an unexpected/future alliance id, a sentinel the addon doesn't know about)
-- would index CyrHUD.info to nil and then crash the calling code with
-- "attempt to index a nil value" on the very next `.color` access, breaking
-- whatever label update was in progress. CyrHUD.icons already has exactly
-- this kind of safety net (see just above); CyrHUD.info did not. We add the
-- same pattern here: log the bad lookup once (via CyrHUD:error, which
-- de-duplicates repeats) and hand back a safe neutral-colored default instead
-- of nil, so a single unexpected value degrades gracefully instead of
-- breaking a whole update pass.
setmetatable(CyrHUD.info, {__index = function(t,k)
    if type(k) == "number" or type(k) == "string" then
        CyrHUD:error("Bad alliance/info lookup: " .. tostring(k))
    end
    return { color = CyrHUD.colors.white }
end})
