--[[
-------------------------------------------------------------------------------
-- WritWorthy
-------------------------------------------------------------------------------
-- Original author: ziggr (project started 2017-02-12)
--
-- Current maintainer: Sharlikran (contributions since 2022-11-12)
-- Contributor: jogietze (formerly otac0n) — GitHub PR contributions
--
-- ----------------------------------------------------------------------------
-- Unless otherwise stated, portions of this software are © ziggr and may
-- be subject to “All Rights Reserved” status due to the absence of a public
-- open-source license declaration.
--
-- ----------------------------------------------------------------------------
-- Contributions by Sharlikran are licensed under the BSD 3-Clause License:
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice,
--    this list of conditions and the following disclaimer.
--
-- 2. Redistributions in binary form must reproduce the above copyright notice,
--    this list of conditions and the following disclaimer in the documentation
--    and/or other materials provided with the distribution.
--
-- 3. Neither the name of the author "Sharlikran" nor the names of previous
--    contributors may be used to endorse or promote products derived from this
--    software without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES ARE DISCLAIMED. IN NO EVENT SHALL THE
-- COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING IN
-- ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
-- OF SUCH DAMAGE.
--
-- Maintainer Notice:
-- Redistribution of this software outside of ESOUI.com (including Bethesda.net
-- or other platforms) is discouraged unless authorized by the current
-- maintainer. Please do not redistribute or fork without attribution,
-- permission, and license compliance.
-------------------------------------------------------------------------------
]]
local WritWorthy = _G["WritWorthy"] -- defined in WritWorthy_Define.lua

-- When M.M. doesn't come up with a price for these crafting
-- materials, supply a hardcoded one.

WritWorthy.FALLBACK_PRICE = {
  -- NPC crafting vendor sells these at 15g each.

  -- Some trait stones sell for so little that
  -- some trading guilds won't have any sales
  -- of these for weeks at a time.

  -- Most of these prices are PC NA Master Merchant,
  -- circa 2018-07, rounded to some nearby multiple
  -- of 5 or 10 or whatever.

  -- Jewelry fallbacks are either:
  -- 10x their corresponding blacksmithing material,
  -- since it takes 10x grains/dust to create one
  -- refined/trait/improvement material, or for
  -- jewelry trait stones gated behind PvP or
  -- other long-duration grinds, 10 * Potent Nirncrux.

  ["acai berry"] = 5,
  ["adamantite"] = 15,
  ["alchemical resin"] = 52,
  ["alkahest"] = 5,
  ["almandine"] = 5,
  ["amber marble"] = 35,
  ["amethyst"] = 5,
  ["ancestor silk"] = 40,
  ["ancient sandstone"] = 25,
  ["antimony"] = 300,
  ["apples"] = 5,
  ["argentum"] = 10,
  ["ash canvas"] = 50,
  ["aurbic amber"] = 8250,
  ["auric tusk"] = 100,
  ["azure plasm"] = 10,
  ["bananas"] = 5,
  ["barley"] = 5,
  ["beetle scuttle"] = 76,
  ["beets"] = 5,
  ["bervez juice"] = 50,
  ["bittergreen"] = 5,
  ["black beeswax"] = 100,
  ["blessed thistle"] = 73,
  ["bloodroot flux"] = 175,
  ["bloodstone"] = 5,
  ["blue entoloma"] = 51,
  ["boiled carapace"] = 50,
  ["bone"] = 15,
  ["bugloss"] = 196,
  ["butterfly wing"] = 54,
  ["carnelian"] = 5,
  ["carrots"] = 5,
  ["cassiterite"] = 40,
  ["charcoal of remorse"] = 75,
  ["chaurus egg"] = 192,
  ["cheese"] = 5,
  ["chromium"] = 73000,
  ["chysolite"] = 5,
  ["citrine"] = 5,
  ["clam gall"] = 474,
  ["clear water"] = 5,
  ["cobalt"] = 450,
  ["coffee"] = 5,
  ["columbine"] = 852,
  ["comberry"] = 5,
  ["copper"] = 15,
  ["corn flower"] = 63,
  ["corn"] = 5,
  ["corundum"] = 15,
  ["crawlers"] = 5,
  ["crimson nirnroot"] = 142,
  ["culanda lacquer"] = 3250,
  ["cultivated cryptpods"] = 5000,
  ["daedra heart"] = 15,
  ["daedra-blood maggots"] = 5000,
  ["dawn-prism"] = 20000,
  ["defiled whiskers"] = 150,
  ["dekeipa"] = 5,
  ["deni"] = 5,
  ["denima"] = 5,
  ["desecrated grave soil"] = 100,
  ["deteri"] = 15,
  ["diamond"] = 5,
  ["dibellium"] = 12000,
  ["distilled slowsilver"] = 150,
  ["dragon bone"] = 1000,
  ["dragon rheum"] = 3598,
  ["dragon scute"] = 150,
  ["dragon's bile"] = 83,
  ["dragon's blood"] = 3081,
  ["dragonthorn"] = 49,
  ["dreugh wax"] = 4000,
  ["dwarven oil"] = 35,
  ["dwemer frame"] = 300,
  ["eagle feather"] = 150,
  ["elegant lining"] = 125,
  ["embroidery"] = 15,
  ["emerald"] = 15,
  ["emetic russula"] = 94,
  ["ferrous salts"] = 25,
  ["fine chalk"] = 75,
  ["fire opal"] = 5,
  ["fish"] = 5,
  ["fleshfly larva"] = 36,
  ["flint"] = 15,
  ["flour"] = 25,
  ["fortified nirncrux"] = 750,
  ["fossilized verminous bones"] = 5000,
  ["frost mirriam"] = 75,
  ["game"] = 5,
  ["garlic"] = 5,
  ["garnet"] = 5,
  ["gilding wax"] = 20000,
  ["ginger"] = 5,
  ["ginkgo"] = 5,
  ["ginseng"] = 5,
  ["goldscale"] = 100,
  ["grain solvent"] = 500,
  ["greens"] = 5,
  ["grinstones"] = 3500,
  ["gryphon plume"] = 1000,
  ["guarana"] = 5,
  ["guts"] = 15,
  ["hakeijo"] = 11000,
  ["haoko"] = 10,
  ["hemming"] = 15,
  ["honey"] = 5,
  ["honing stone"] = 20,
  ["imp stool"] = 55,
  ["infected flesh"] = 750,
  ["iridium"] = 3750,
  ["isinglass"] = 5,
  ["itade"] = 30,
  ["jade"] = 5,
  ["jasmine"] = 5,
  ["jazbay grapes"] = 5,
  ["jehade"] = 9,
  ["kaderi"] = 5,
  ["kuoko"] = 5,
  ["kuta"] = 2250,
  ["lady's smock"] = 50,
  ["laurel"] = 30,
  ["lemon"] = 5,
  ["leviathan scrimshaw"] = 750,
  ["lion fang"] = 150,
  ["lorkhan's tears"] = 20,
  ["lotus"] = 5,
  ["luminous russula"] = 52,
  ["lustrous sphalerite"] = 175,
  ["makderi"] = 30,
  ["makko"] = 5,
  ["makkoma"] = 5,
  ["malachite"] = 175,
  ["manganese"] = 15,
  ["mastic"] = 500,
  ["meip"] = 5,
  ["melon"] = 5,
  ["metheglin"] = 5,
  ["millet"] = 5,
  ["minotaur bezoar"] = 75,
  ["mint"] = 5,
  ["molybdenum"] = 15,
  ["moonstone"] = 15,
  ["mountain flower"] = 137,
  ["mudcrab chitin"] = 844,
  ["namira's rot"] = 64,
  ["nickel"] = 15,
  ["night pumice"] = 2000,
  ["nightshade"] = 89,
  ["nirnroot"] = 45,
  ["obsidian"] = 15,
  ["oko"] = 44,
  ["okoma"] = 5,
  ["okori"] = 15,
  ["oru"] = 5,
  ["oxblood fungus"] = 50,
  ["palladium"] = 15,
  ["pearl sand"] = 100,
  ["perfect roe"] = 10000,
  ["pitch"] = 50,
  ["platinum"] = 20,
  ["polished scarab elytra"] = 300,
  ["polished shilling"] = 75,
  ["potash"] = 100,
  ["potato"] = 5,
  ["potent nirncrux"] = 13000,
  ["poultry"] = 5,
  ["powdered mother of pearl"] = 957,
  ["pristine shroud"] = 50,
  ["pumpkin"] = 5,
  ["quartz"] = 5,
  ["radish"] = 5,
  ["rakeipa"] = 175,
  ["red meat"] = 5,
  ["refined bonemold resin"] = 5000,
  ["rejera"] = 10,
  ["rekuta"] = 50,
  ["repora"] = 160,
  ["rice"] = 5,
  ["rogue's soot"] = 85,
  ["rose"] = 5,
  ["rosin"] = 2500,
  ["rubedite"] = 10,
  ["rubedo leather"] = 15,
  ["ruby ash"] = 20,
  ["ruby"] = 5,
  ["rye"] = 5,
  ["saltrice"] = 5,
  ["sapphire"] = 5,
  ["sardonyx"] = 5,
  ["scrib jelly"] = 342,
  ["sea serpent hide"] = 300,
  ["seasoning"] = 5,
  ["seaweed"] = 5,
  ["slaughterstone"] = 6500,
  ["small game"] = 30,
  ["spider egg"] = 53,
  ["stalhrim shard"] = 3000,
  ["star sapphire"] = 75,
  ["starmetal"] = 15,
  ["stinkhorn"] = 59,
  ["surilie grapes"] = 5,
  ["taderi"] = 25,
  ["tainted blood"] = 100,
  ["tempered brass"] = 400,
  ["tempering alloy"] = 5000,
  ["tenebrous cord"] = 175,
  ["terne"] = 1250,
  ["titanium"] = 2500,
  ["tomato"] = 5,
  ["torchbug thorax"] = 965,
  ["turpen"] = 25,
  ["turquoise"] = 5,
  ["vile coagulant"] = 223,
  ["violet coprinus"] = 596,
  ["vitrified malondo"] = 600,
  ["volcanic viridian"] = 250,
  ["warrior's heart ashes"] = 400,
  ["water hyacinth"] = 52,
  ["wheat"] = 5,
  ["white cap"] = 40,
  ["white meat"] = 25,
  ["winter's grave tongue"] = 5000,
  ["wolfsbane incense"] = 200,
  ["worms"] = 25,
  ["wormwood"] = 56,
  ["wrought ferrofungus"] = 250,
  ["yeast"] = 5,
  ["yerba mate"] = 5,
  ["zinc"] = 350,
  ["zircon"] = 21000,
}

-- The above table initially has keys for our internal material names, not
-- item IDs. Add item_id keys so that we can look things up by (disassembled)
-- item_links, matching MMPrice() API as well as the links that the ZOS recipe
-- ingredient API returns.
--
-- Do NOT use item_link as a key: the ZOS recipe ingredient API will return
-- links with slightly varying digits in insignificant positions that will
-- will cause lookup failures.
--
function WritWorthy.PopulateTableWithItemIds()
  if WritWorthy.FALLBACK_PRICE.filled_with_item_id_goodness then
    return
  end
  local name_list = {}
  -- Do this in two passes because I'm not sure how
  -- Lua handles "modifying a table while you're
  -- iterating over it."
  for name, _ in pairs(WritWorthy.FALLBACK_PRICE) do
    if type(name) == "string" and name ~= "filled_with_item_id_goodness" then
      table.insert(name_list, name)
    end
  end
  for _, name in ipairs(name_list) do
    local link = WritWorthy.FindLink(name)
    local w = link and WritWorthy.Util.ToWritFields(link)
    if w and w.item_id then
      WritWorthy.FALLBACK_PRICE[w.item_id] = WritWorthy.FALLBACK_PRICE[name]
    end
  end
  WritWorthy.FALLBACK_PRICE.filled_with_item_id_goodness = true
end

-- If the material is in the FALLBACK_PRICE table, return its fallback price.
-- If not, return nil.
function WritWorthy.FallbackPrice(link)
  local w = WritWorthy.Util.ToWritFields(link)
  if not WritWorthy.FALLBACK_PRICE[w.item_id] then
    WritWorthy.PopulateTableWithItemIds()
  end
  -- d("fallback:"..tostring(WritWorthy.FALLBACK_PRICE[w.item_id])
  --    .." item_id:"..tostring(w.item_id).." link:"..tostring(link))
  return WritWorthy.FALLBACK_PRICE[w.item_id]
end
