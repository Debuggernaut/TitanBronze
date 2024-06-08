---@diagnostic disable: duplicate-set-field
--[[
-- **************************************************************************
-- * TitanBronze.lua
-- *
-- * By: The Titan Panel Development Team
-- **************************************************************************
--]]

-- ******************************** Constants *******************************
local TITAN_BRONZE_ID = "Bronze";
local TITAN_BUTTON = "TitanPanel"..TITAN_BRONZE_ID.."Button"
local TITAN_BRONZE_COUNT_FORMAT = "%d";
local TITAN_BRONZE_VERSION = TITAN_VERSION;
local TITAN_BRONZE_SPACERBAR = "-----------------------";
local TITAN_BRONZE_BLUE = {r=0.4,b=1,g=0.4};
local TITAN_BRONZE_RED = {r=1,b=0,g=0};
local TITAN_BRONZE_GREEN = {r=0,b=0,g=1};
local updateTable = {TITAN_BRONZE_ID, TITAN_PANEL_UPDATE_TOOLTIP };

-- ******************************** Variables *******************************
local BRONZE_INITIALIZED = false;
local BRONZE_INDEX = "";
local BRONZE_COLOR;
local BRONZE_SESS_STATUS;
local BRONZE_PERHOUR_STATUS;
local BRONZE_STARTINGBRONZE;
local BRONZE_SESSIONSTART;
local TitanBronze = LibStub("AceAddon-3.0"):NewAddon("TitanBronze")
local AceTimer = LibStub("AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(TITAN_ID, true)
local BronzeTimer = {};
local BronzeTimerRunning = false
local _G = getfenv(0);
local realmName = GetRealmName();
local realmNames = GetAutoCompleteRealms();

-- English faction for indexing and sorting and coloring
local TITAN_ALLIANCE = "Alliance"
local TITAN_HORDE = "Horde"

--[[  debug
local FACTION_ALLIANCE = "Alliance_debug"
local FACTION_HORDE = "Horde_debug"
--]]
-- ******************************** Functions *******************************

local function GetIndexInfo(info)
	local character, charserver, char_faction = string.match(info, '(.*)_(.*)::(.*)')
	return character, charserver, char_faction
end

--[[
Add commas or period in the value given as needed
--]]
local function comma_value(amount)
	local formatted = amount
	local k
	local sep = (TitanGetVar(TITAN_BRONZE_ID, "UseSeperatorComma") and "UseComma" or "UsePeriod")
	while true do
		if sep == "UseComma" then formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2') end
		if sep == "UsePeriod" then formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1.%2') end
		if (k==0) then
			break
		end
	end
	return formatted
end

--[[
Take the 'amount' of gold and make it into a nice, colorful string of g s c (gold silver copper)
--]]
local function NiceCash(value, show_zero, show_neg)
	local neg1 = ""
	local neg2 = ""
	local agold = 10000;
	local asilver = 100;
	local outstr = "";
	local gold = 0;
	local gold_str = ""
	local gc = "|cFFFFFF00"
	local silver = 0;
	local silver_str = ""
	local sc = "|cFFCCCCCC"
	local copper = 0;
	local copper_str = ""
	local cc = "|cFFFF6600"
	local amount = (value or 0)
	local cash = (amount or 0)
	local font_size = TitanPanelGetVar("FontSize")
	local icon_pre = "|TInterface\\MoneyFrame\\"
	local icon_post = ":"..font_size..":"..font_size..":2:0|t"
	local g_icon = icon_pre.."UI-BronzeIcon"..icon_post
	local s_icon = icon_pre.."UI-SilverIcon"..icon_post
	local c_icon = icon_pre.."UI-CopperIcon"..icon_post
	-- build the coin label strings based on the user selections
	local show_labels = TitanGetVar(TITAN_BRONZE_ID, "ShowCoinLabels")
	local show_icons = TitanGetVar(TITAN_BRONZE_ID, "ShowCoinIcons")
	local c_lab = (show_labels and L["TITAN_BRONZE_COPPER"]) or (show_icons and c_icon) or ""
	local s_lab = (show_labels and L["TITAN_BRONZE_SILVER"]) or (show_icons and s_icon) or ""
	local g_lab = (show_labels and L["TITAN_BRONZE_BRONZE"]) or (show_icons and g_icon) or ""

	-- show the money in highlight or coin color based on user selection
	if TitanGetVar(TITAN_BRONZE_ID, "ShowColoredText") then
		gc = "|cFFFFFF00"
		sc = "|cFFCCCCCC"
		cc = "|cFFFF6600"
	else
		gc = _G["HIGHLIGHT_FONT_COLOR_CODE"]
		sc = _G["HIGHLIGHT_FONT_COLOR_CODE"]
		cc = _G["HIGHLIGHT_FONT_COLOR_CODE"]
	end

	if show_neg then
		if amount < 0 then
			neg1 = "|cFFFF6600" .."("..FONT_COLOR_CODE_CLOSE
			neg2 = "|cFFFF6600" ..")"..FONT_COLOR_CODE_CLOSE
		else
			neg2 = " " -- need to pad for other negative numbers
		end
	end
	if amount < 0 then
		amount = amount * -1
	end

	if amount == 0 then
		if show_zero then
			copper_str = cc..(amount or "?")..c_lab..""..FONT_COLOR_CODE_CLOSE
		end
	elseif amount > 0 then
		-- figure out the gold - silver - copper components
		gold = 0--(math.floor(amount / agold) or 0)
		amount = amount - (gold * agold);
		silver = 0--(math.floor(amount / asilver) or 0)
		copper = amount - (silver * asilver)
		-- now make the coin strings
		if gold > 0 then
			gold_str = gc..(comma_value(gold) or "?")..g_lab.." "..FONT_COLOR_CODE_CLOSE
			silver_str = sc..(string.format("%02d", silver) or "?")..s_lab.." "..FONT_COLOR_CODE_CLOSE
			copper_str = cc..(string.format("%02d", copper) or "?")..c_lab..""..FONT_COLOR_CODE_CLOSE
		elseif (silver > 0) then
			silver_str = sc..(silver or "?")..s_lab.." "..FONT_COLOR_CODE_CLOSE
			copper_str = cc..(string.format("%02d", copper) or "?")..c_lab..""..FONT_COLOR_CODE_CLOSE
		elseif (copper > 0) then
			copper_str = cc..(copper or "?")..c_lab..""..FONT_COLOR_CODE_CLOSE
		end
	end

	if TitanGetVar(TITAN_BRONZE_ID, "ShowBronzeOnly") then
		silver_str = ""
		copper_str = ""
		-- special case for those who want to show only gold
		if gold == 0 then
			if show_zero then
				gold_str = gc.."0"..g_lab.." "..FONT_COLOR_CODE_CLOSE
			end
		end
	end

	-- build the return string
	outstr = outstr
		..neg1
		..gold_str
		..silver_str
		..copper_str
		..neg2
--[[
SC.Print("Acc cash:"
..(gold or "?").."g "
..(silver or "?").."s "
..(copper or "?").."c "
..(outstr or "?")
);
--]]
	return outstr, cash, gold, silver, copper
end

local function ShowMenuButtons(faction)
	local info = {};
	local name = GetUnitName("player");
	local server = realmName;
	for index, money in pairs(BronzeSave) do
		local character, charserver, char_faction = GetIndexInfo(index) --string.match(index, "(.*)_(.*)::"..faction);
		if character 
		and (char_faction == faction) 
		then
			info.text = character.." - "..charserver;
			info.value = character;
			info.keepShownOnClick = true;
			info.checked = function()
				local rementry = character.."_"..charserver.."::"..faction;
				return BronzeSave[rementry].show
			end
			info.func = function()
				local rementry = character.."_"..charserver.."::"..faction;
				BronzeSave[rementry].show = not BronzeSave[rementry].show;
				TitanPanelButton_UpdateButton(TITAN_BRONZE_ID)
			end
			TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());
		end
	end
end

local function DeleteMenuButtons(faction)
	local info = {};
	local name = GetUnitName("player");
	local server = realmName;
	for index, money in pairs(BronzeSave) do
		local character, charserver, char_faction = GetIndexInfo(index) --string.match(index, "(.*)_(.*)::"..faction);
		info.notCheckable = true
		if character 
		and (char_faction == faction) 
		then
			info.text = character.." - "..charserver;
			info.value = character;
			info.func = function()
				local rementry = character.."_"..charserver.."::"..faction;
				BronzeSave[rementry] = nil;
				TitanPanelButton_UpdateButton(TITAN_BRONZE_ID)
			end
			-- cannot delete current character
			if name == character and server == charserver then
				info.disabled = 1;
			else
				info.disabled = nil;
			end
			TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());
		end
	end
end

local function ShowProperLabels(chosen)
	if chosen == "ShowCoinNone" then
		TitanSetVar(TITAN_BRONZE_ID, "ShowCoinNone", true);
		TitanSetVar(TITAN_BRONZE_ID, "ShowCoinLabels", false);
		TitanSetVar(TITAN_BRONZE_ID, "ShowCoinIcons", false);
	end
	if chosen == "ShowCoinLabels" then
		TitanSetVar(TITAN_BRONZE_ID, "ShowCoinNone", false);
		TitanSetVar(TITAN_BRONZE_ID, "ShowCoinLabels", true);
		TitanSetVar(TITAN_BRONZE_ID, "ShowCoinIcons", false);
	end
	if chosen == "ShowCoinIcons" then
		TitanSetVar(TITAN_BRONZE_ID, "ShowCoinNone", false);
		TitanSetVar(TITAN_BRONZE_ID, "ShowCoinLabels", false);
		TitanSetVar(TITAN_BRONZE_ID, "ShowCoinIcons", true);
	end
	TitanPanelButton_UpdateButton(TITAN_BRONZE_ID);
end

local function Seperator(chosen)
	if chosen == "UseSeperatorComma" then
		TitanSetVar(TITAN_BRONZE_ID, "UseSeperatorComma", true);
		TitanSetVar(TITAN_BRONZE_ID, "UseSeperatorPeriod", false);
	end
	if chosen == "UseSeperatorPeriod" then
		TitanSetVar(TITAN_BRONZE_ID, "UseSeperatorComma", false);
		TitanSetVar(TITAN_BRONZE_ID, "UseSeperatorPeriod", true);
	end
	TitanPanelButton_UpdateButton(TITAN_BRONZE_ID);
end

local function Merger(chosen)
	if chosen == "MergeServers" then
		TitanSetVar(TITAN_BRONZE_ID, "MergeServers", true);
		TitanSetVar(TITAN_BRONZE_ID, "SeparateServers", false);
		TitanSetVar(TITAN_BRONZE_ID, "AllServers", false);
	end
	if chosen == "SeparateServers" then
		TitanSetVar(TITAN_BRONZE_ID, "MergeServers", false);
		TitanSetVar(TITAN_BRONZE_ID, "SeparateServers", true);
		TitanSetVar(TITAN_BRONZE_ID, "AllServers", false);
	end
	if chosen == "AllServers" then
		TitanSetVar(TITAN_BRONZE_ID, "MergeServers", false);
		TitanSetVar(TITAN_BRONZE_ID, "SeparateServers", false);
		TitanSetVar(TITAN_BRONZE_ID, "AllServers", true);
	end
	TitanPanelButton_UpdateButton(TITAN_BRONZE_ID);
end

--[[
-- *******************************************************************************************
-- NAME: TitanPanelBronzeGPH_Toggle()
-- DESC: This toggles if the player wants to see the gold/hour stats
-- *******************************************************************************************
--]]
function TitanPanelBronzeGPH_Toggle()
	TitanToggleVar(TITAN_BRONZE_ID, "DisplayBronzePerHour")

	if TitanGetVar(TITAN_BRONZE_ID, "DisplayBronzePerHour") then
		if BronzeTimerRunning then
			-- Do not create a new one
		else
			BronzeTimer = AceTimer:ScheduleRepeatingTimer(TitanPanelPluginHandle_OnUpdate, 1, updateTable)
			BronzeTimerRunning = true
		end
	elseif BronzeTimer and not TitanGetVar(TITAN_BRONZE_ID, "DisplayBronzePerHour") then
		AceTimer:CancelTimer(BronzeTimer)
		BronzeTimerRunning = false
	end
end

local function DisplayOptions()

	local info = {};
	info.notCheckable = true
	info.text = L["TITAN_BRONZE_SORT_BY"];
	info.value = "Sorting";
	info.hasArrow = 1;
	TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());

	TitanPanelRightClickMenu_AddSeparator(TitanPanelRightClickMenu_GetDropdownLevel());

	-- Which characters to show 
	--  - Separate : this server
	--  - Merge : connected / merged servers
	--  - All : any server
	local info = {};
	info.text = L["TITAN_BRONZE_SEPARATE"];
	info.checked = TitanGetVar(TITAN_BRONZE_ID, "SeparateServers");
	info.func = function()
		Merger("SeparateServers")
	end
	TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());

	local info = {};
	info.text = L["TITAN_BRONZE_MERGE"];
	info.checked = TitanGetVar(TITAN_BRONZE_ID, "MergeServers");
	info.func = function()
		Merger("MergeServers")
	end
	TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());

	local info = {};
	info.text = L["TITAN_BRONZE_ALL"];
	info.checked = TitanGetVar(TITAN_BRONZE_ID, "AllServers");
	info.func = function()
		Merger("AllServers")
	end
	TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());

	TitanPanelRightClickMenu_AddSeparator(TitanPanelRightClickMenu_GetDropdownLevel());

	-- Option to ignore faction - per 9.2.5 changes
	local info = {};
	info.text = L["TITAN_BRONZE_IGNORE_FACTION"];
	info.checked = TitanGetVar(TITAN_BRONZE_ID, "IgnoreFaction");
	info.func = function()
		TitanToggleVar(TITAN_BRONZE_ID, "IgnoreFaction");
		TitanPanelButton_UpdateButton(TITAN_BRONZE_ID);
	end
	TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());

	TitanPanelRightClickMenu_AddSeparator(TitanPanelRightClickMenu_GetDropdownLevel());

	-- What labels to show next to money none / text / icon
	local info = {};
	info.text = L["TITAN_BRONZE_COIN_NONE"];
	info.checked = TitanGetVar(TITAN_BRONZE_ID, "ShowCoinNone");
	info.func = function()
		ShowProperLabels("ShowCoinNone")
	end
	TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());

	local info = {};
	info.text = L["TITAN_BRONZE_COIN_LABELS"];
	info.checked = TitanGetVar(TITAN_BRONZE_ID, "ShowCoinLabels");
	info.func = function()
		ShowProperLabels("ShowCoinLabels")
	end
	TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());

	local info = {};
	info.text = L["TITAN_BRONZE_COIN_ICONS"];
	info.checked = TitanGetVar(TITAN_BRONZE_ID, "ShowCoinIcons");
	info.func = function()
		ShowProperLabels("ShowCoinIcons")
	end
	TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());

	TitanPanelRightClickMenu_AddSeparator(TitanPanelRightClickMenu_GetDropdownLevel());

	-- Show gold only option - no silver, no copper
	info = {};
	info.text = L["TITAN_BRONZE_ONLY"];
	info.checked = TitanGetVar(TITAN_BRONZE_ID, "ShowBronzeOnly");
	info.func = function()
		TitanToggleVar(TITAN_BRONZE_ID, "ShowBronzeOnly");
		TitanPanelButton_UpdateButton(TITAN_BRONZE_ID);
	end
	TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());

	TitanPanelRightClickMenu_AddSeparator(TitanPanelRightClickMenu_GetDropdownLevel());

	-- Use comma or period as separater on gold
	local info = {};
	info.text = L["TITAN_PANEL_USE_COMMA"];
	info.checked = TitanGetVar(TITAN_BRONZE_ID, "UseSeperatorComma");
	info.func = function()
		Seperator("UseSeperatorComma")
	end
	TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());

	local info = {};
	info.text = L["TITAN_PANEL_USE_PERIOD"];
	info.checked = TitanGetVar(TITAN_BRONZE_ID, "UseSeperatorPeriod");
	info.func = function()
		Seperator("UseSeperatorPeriod")
	end
	TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());

	TitanPanelRightClickMenu_AddSeparator(TitanPanelRightClickMenu_GetDropdownLevel());

	-- Show session info
	info = {};
	info.text = L["TITAN_BRONZE_SHOW_STATS_TITLE"];
	info.checked = TitanGetVar(TITAN_BRONZE_ID, "ShowSessionInfo");
	info.func = function()
		TitanToggleVar(TITAN_BRONZE_ID, "ShowSessionInfo");
	end
	TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());

	TitanPanelRightClickMenu_AddSeparator(TitanPanelRightClickMenu_GetDropdownLevel());

	-- Function to toggle gold per hour sort
	info = {};
	info.text = L["TITAN_BRONZE_TOGGLE_GPH_SHOW"]
	info.checked = TitanGetVar(TITAN_BRONZE_ID, "DisplayBronzePerHour");
	info.func = function()
		TitanPanelBronzeGPH_Toggle()
	end
	TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());

end

local function ToonAdd(show, amount, total)
	local new_total = 0
	
	if show then
		new_total = total + amount
	else
		new_total = total
	end
	
	return new_total
end

--[[
-- *******************************************************************************************
-- NAME: TotalBronze()
-- DESC: Calculates total gold for display per user selections
-- *******************************************************************************************
--]]
local function TotalBronze()
	local ttlgold = 0;
	local cnt = 0;
	local countelements = 0;
	local faction = UnitFactionGroup("Player");
	local coin_str = ""
	local character, charserver = "", ""
	local char_faction = ""
	local ignore_faction = TitanGetVar(TITAN_BRONZE_ID, "IgnoreFaction")
	
	for _ in pairs (realmNames) do 
		countelements = countelements + 1 
	end

	if TitanGetVar(TITAN_BRONZE_ID, "SeparateServers") then
		-- Parse the database and display all characters on this server
		BronzeSave[BRONZE_INDEX].gold = GetMoney()

		for index, money in pairs(BronzeSave) do
			character, charserver, char_faction = GetIndexInfo(index)
			if (character) and (charserver == realmName) then
				if ignore_faction or (char_faction == faction) then
					ttlgold = ToonAdd(BronzeSave[index].show, BronzeSave[index].gold, ttlgold)
				else
					-- Do not show per flags
				end
			else
				-- Toon is not on connected / merged server
			end
		end
	elseif TitanGetVar(TITAN_BRONZE_ID, "MergeServers") then
		-- Parse the database and display characters on merged / connected servers
		for ms = 1, countelements do
			BronzeSave[BRONZE_INDEX].gold = GetMoney()

			for index, money in pairs(BronzeSave) do
				character, charserver, char_faction = GetIndexInfo(index)
				-- GetAutoCompleteRealms removes spaces, idk why... 
				if (charserver) then
					charserver = string.gsub(charserver, "%s", "");
				end

				if (character) and (charserver == realmNames[ms]) then
					if ignore_faction or (char_faction == faction) then
						ttlgold = ToonAdd(BronzeSave[index].show, BronzeSave[index].gold, ttlgold)
					else
						-- Do not show per flags
					end
				else
					-- Toon is not on connected / merged server
				end
			end
		end
	elseif TitanGetVar(TITAN_BRONZE_ID, "AllServers") then
		-- Parse the database and display characters on all servers
		BronzeSave[BRONZE_INDEX].gold = GetMoney()

		for index, money in pairs(BronzeSave) do
			character, charserver, char_faction = GetIndexInfo(index)
			if (character) then
				if ignore_faction or (char_faction == faction) then
					ttlgold = ToonAdd(BronzeSave[index].show, BronzeSave[index].gold, ttlgold)
				else
					-- Do not show per flags
				end
			else
				-- Toon is invalid??
			end
		end
	end

	return ttlgold;
end

-- ====== Tool tip routines
local function GetToonInfo(info)
	return info.name, info.realm, info.faction
end

--[[
-- *******************************************************************************************
-- NAME: GetTooltipText()
-- DESC: Gets the tool-tip text, what appears when we hover over Bronze on the Titan bar.
-- *******************************************************************************************
--]]
local function GetTooltipText()
	local BronzeSaveSorted = {};
	local currentMoneyRichText = "";
	local countelements = 0;
	local faction, faction_locale = UnitFactionGroup("Player") -- get localized faction
	local ignore_faction = TitanGetVar(TITAN_BRONZE_ID, "IgnoreFaction")
	
	for _ in pairs (realmNames) do 
		countelements = countelements + 1 
	end

--	if countelements == 0 or TitanGetVar(TITAN_BRONZE_ID, "SeparateServers") then
	-- The check for no connected realms was confusing so use the 'merge' format
	-- if requested.
	-- insert all keys from hash into the BronzeSaveSorted array
	
	if TitanGetVar(TITAN_BRONZE_ID, "SeparateServers") then
		-- Parse the database and display characters from this server
		BronzeSave[BRONZE_INDEX].gold = GetMoney()
		local char_faction = ""
		local character, charserver = "", ""

		for index, money in pairs(BronzeSave) do
			character, charserver, char_faction = GetIndexInfo(index)
			if (character) then
				if (charserver == realmName) then
					if ignore_faction or (char_faction == faction) then
						if BronzeSave[index].show then
							table.insert(BronzeSaveSorted, index);
						end
					end
				end
			end
		end
	elseif TitanGetVar(TITAN_BRONZE_ID, "MergeServers") then
		-- Parse the database and display characters from merged / connected servers
		for ms = 1, countelements do
			local server = realmNames[ms]
			BronzeSave[BRONZE_INDEX].gold = GetMoney()
			local character, charserver = "", ""
			local char_faction = ""

			for index, money in pairs(BronzeSave) do
				character, charserver, char_faction = GetIndexInfo(index)
				-- GetAutoCompleteRealms removes spaces, idk why... 
				if (charserver) then
					charserver = string.gsub(charserver, "%s", "");
				end

				if (character) then
					if (charserver == server) then
						if ignore_faction or (char_faction == faction) then
							if BronzeSave[index].show then
								table.insert(BronzeSaveSorted, index);
							end
						end
					end
				end
			end
		end
	elseif TitanGetVar(TITAN_BRONZE_ID, "AllServers") then
		-- Parse the database and display characters from all servers
		BronzeSave[BRONZE_INDEX].gold = GetMoney()
		local character, charserver = "", ""
		local char_faction = ""

		for index, money in pairs(BronzeSave) do
			character, charserver, char_faction = GetToonInfo(BronzeSave[index])
			if (character) then
				if ignore_faction or (char_faction == faction) then
					if BronzeSave[index].show then
						table.insert(BronzeSaveSorted, index);
					end
				end
			end
		end
	end

	local by_realm = TitanGetVar(TITAN_BRONZE_ID, "GroupByRealm")
	-- This section will sort the array based on user preference
	-- * by name or by gold amount descending
	-- * grouping by realm if selected
	if TitanGetVar(TITAN_BRONZE_ID, "SortByName") then
		table.sort(BronzeSaveSorted, function (key1, key2) 
			if by_realm then
				if BronzeSave[key1].realm ~= BronzeSave[key2].realm then
					return BronzeSave[key1].realm < BronzeSave[key2].realm
				end
			end

			return BronzeSave[key1].name < BronzeSave[key2].name 
			end)
	else
		table.sort(BronzeSaveSorted, function (key1, key2) 
			if by_realm then
				if BronzeSave[key1].realm ~= BronzeSave[key2].realm then
					return BronzeSave[key1].realm < BronzeSave[key2].realm
				end
			end

			return BronzeSave[key1].gold > BronzeSave[key2].gold 
			end)
	end

	-- Array holds all characters to display, nicely sorted.
	currentMoneyRichText = ""
	local coin_str = ""
	local faction_text = ""
	local curr_realm = ""
	local show_dash = false
	local show_realm = true
	local character, charserver, char_faction
	for i = 1, getn(BronzeSaveSorted) do
		character, charserver, char_faction = GetIndexInfo(BronzeSaveSorted[i]) --GetToonInfo(BronzeSave[BronzeSaveSorted[i]])
		coin_str = NiceCash(BronzeSave[BronzeSaveSorted[i]].gold, false, false)
		show_dash = false
		show_realm = true

		if (TitanGetVar(TITAN_BRONZE_ID, "SeparateServers")) then
--			charserver = ""  -- do not repeat the server on each line
			show_realm = false
		elseif (TitanGetVar(TITAN_BRONZE_ID, "MergeServers")) then
			show_dash = true
--			charserver = "-"..charserver
		elseif (TitanGetVar(TITAN_BRONZE_ID, "AllServers")) then
			show_dash = true
		end

		if by_realm then
			-- Set a realm header
			if charserver ~= curr_realm then
				currentMoneyRichText = currentMoneyRichText.."\n"
					.."-- "..charserver
				curr_realm = charserver
			end
			show_dash = false
--			charserver = ""  -- do not repeat the server on each line
			show_realm = false
		end

		if ignore_faction then
			if char_faction == TITAN_ALLIANCE then
				faction_text = "-".."|cff5b92e5"
							..BronzeSave[BronzeSaveSorted[i]].faction
							.._G["FONT_COLOR_CODE_CLOSE"]
			elseif char_faction == TITAN_HORDE then
				faction_text = "-"..TitanUtils_GetHexText(BronzeSave[BronzeSaveSorted[i]].faction, "d42447")
			end
		end
		
		currentMoneyRichText = currentMoneyRichText.."\n"
			..character
			..(show_dash and "-" or "")
			..(show_realm and charserver or "")
			..faction_text
			.."\t"..coin_str
	end

--[[
print("TG"
.." "..tostring(counter)
.." "..tostring(x0)
.." "..tostring(x1)
.." "..tostring(getn(BronzeSaveSorted))
.." "..tostring(TitanGetVar(TITAN_BRONZE_ID, "SeparateServers"))
.." "..tostring(TitanGetVar(TITAN_BRONZE_ID, "MergeServers"))
.." "..tostring(TitanGetVar(TITAN_BRONZE_ID, "AllServers"))
.." "..tostring(TITANPANEL_TOOLTIP)
--.." "..tostring(TITANPANEL_TOOLTIP_X)
)
--]]

	coin_str = ""
	-- Display total gold
	coin_str = NiceCash(TotalBronze(), false, false)
	currentMoneyRichText = currentMoneyRichText.."\n"
		..TITAN_BRONZE_SPACERBAR.."\n"
		..L["TITAN_BRONZE_TTL_BRONZE"].."\t"..coin_str

	-- find session earnings and earning per hour
	local sesstotal = GetMoney() - BRONZE_STARTINGBRONZE;
	local negative = false;
	if (sesstotal < 0) then
		sesstotal = math.abs(sesstotal);
		negative = true;
	end

	local sesslength = GetTime() - BRONZE_SESSIONSTART;
	local perhour = math.floor(sesstotal / sesslength * 3600);

	coin_str = NiceCash(BRONZE_STARTINGBRONZE, false, false)
	
	local sessionMoneyRichText = ""
	if TitanGetVar(TITAN_BRONZE_ID, "ShowSessionInfo") then
		sessionMoneyRichText = "\n\n"..TitanUtils_GetHighlightText(L["TITAN_BRONZE_STATS_TITLE"])
			.."\n"..L["TITAN_BRONZE_START_BRONZE"].."\t"..coin_str.."\n"

		if (negative) then
			BRONZE_COLOR = TITAN_BRONZE_RED;
			BRONZE_SESS_STATUS = L["TITAN_BRONZE_SESS_LOST"];
			BRONZE_PERHOUR_STATUS = L["TITAN_BRONZE_PERHOUR_LOST"];
		else
			BRONZE_COLOR = TITAN_BRONZE_GREEN;
			BRONZE_SESS_STATUS = L["TITAN_BRONZE_SESS_EARNED"];
			BRONZE_PERHOUR_STATUS = L["TITAN_BRONZE_PERHOUR_EARNED"];
		end

		coin_str = NiceCash(sesstotal, true, true)
	--		..TitanUtils_GetColoredText(BRONZE_SESS_STATUS,BRONZE_COLOR)
		sessionMoneyRichText = sessionMoneyRichText
			..TitanUtils_GetColoredText(BRONZE_SESS_STATUS,BRONZE_COLOR)
			.."\t"..coin_str.."\n";

		if TitanGetVar(TITAN_BRONZE_ID, "DisplayBronzePerHour") then
			coin_str = NiceCash(perhour, true, true)
			sessionMoneyRichText = sessionMoneyRichText
				..TitanUtils_GetColoredText(BRONZE_PERHOUR_STATUS,BRONZE_COLOR)
				.."\t"..coin_str.."\n";
		end
	else
		-- Do not display session info
	end

	local final_tooltip = TitanUtils_GetBronzeText(L["TITAN_BRONZE_TOOLTIPTEXT"].." : ")

	local final_server = ""
	if realmNames == nil or TitanGetVar(TITAN_BRONZE_ID, "SeparateServers") then
		final_server = realmName
	elseif TitanGetVar(TITAN_BRONZE_ID, "MergeServers") then
		final_server = L["TITAN_BRONZE_MERGED"]
	elseif TitanGetVar(TITAN_BRONZE_ID, "AllServers") then
		final_server = ALL
	end
	final_server = TitanUtils_GetBronzeText(final_server.." : ")
	
	local final_faction = ""
	if ignore_faction then
		final_faction = TitanUtils_GetBronzeText(ALL)
	elseif faction == TITAN_ALLIANCE then
		final_faction = "|cff5b92e5"..FACTION_ALLIANCE.._G["FONT_COLOR_CODE_CLOSE"]
--		final_faction = TitanUtils_GetGreenText(FACTION_ALLIANCE)
		-- "|cff0000ff"..text.._G["FONT_COLOR_CODE_CLOSE"]
	elseif faction == TITAN_HORDE then
		final_faction = TitanUtils_GetRedText(FACTION_HORDE)
	end
	
	return ""
		..currentMoneyRichText.."\n"
		..TITAN_BRONZE_SPACERBAR.."\n"
		..final_tooltip..final_server..final_faction.."\n"
		..sessionMoneyRichText
end
-- ====== 

-- ====== Right click menu routines
--[[
-- *******************************************************************************************
-- NAME: ViewAll_Toggle()
-- DESC: This toggles whether or not the player wants to view total gold on the button, or player gold.
-- *******************************************************************************************
--]]
local function ViewAll_Toggle()
	TitanToggleVar(TITAN_BRONZE_ID, "ViewAll")
	TitanPanelButton_UpdateButton(TITAN_BRONZE_ID)
end

--[[
-- *******************************************************************************************
-- NAME: Sort_Toggle()
-- DESC: This toggles how the player wants the display to be sorted - by name or gold amount
-- *******************************************************************************************
--]]
local function Sort_Toggle()
	TitanToggleVar(TITAN_BRONZE_ID, "SortByName")
end

--[[
-- *******************************************************************************************
-- NAME: ResetSession()
-- DESC: Resets the current session
-- *******************************************************************************************
--]]
local function ResetSession()
	BRONZE_STARTINGBRONZE = GetMoney();
	BRONZE_SESSIONSTART = GetTime();
	DEFAULT_CHAT_FRAME:AddMessage(TitanUtils_GetGreenText(L["TITAN_BRONZE_SESSION_RESET"]));
end

--[[
-- **************************************************************************
-- NAME : Initialize_Array()
-- DESC : Build the gold array for the server/faction
-- **************************************************************************
--]]
local function Initialize_Array(self)
	if (BRONZE_INITIALIZED) then return; end

	self:UnregisterEvent("VARIABLES_LOADED");

	-- See if this is a new to toon to Bronze
	if (BronzeSave[BRONZE_INDEX] == nil) then
		BronzeSave[BRONZE_INDEX] = {}
		BronzeSave[BRONZE_INDEX] = {gold = GetMoney(), name = UnitName("player")}
	end
	
	-- Ensure the saved vars are usable
	for index, money in pairs(BronzeSave) do
		local character, charserver, char_faction = GetIndexInfo(index) --string.match(index, '(.*)_(.*)::(.*)')
		
		-- Could be a new toon to Bronze or an updated Bronze
		local show_toon = BronzeSave[index].show
		if show_toon == nil then
			show_toon = true
		end
		BronzeSave[index].show = show_toon
		BronzeSave[index].realm = charserver  -- added July 2022
		
		-- added Aug 2022 for #1332. 
		-- Faction in index was not set for display in tool tip.
		-- Created localized faction as a field; set every time in case user changes languages
		if char_faction == TITAN_ALLIANCE then
			BronzeSave[index].faction = FACTION_ALLIANCE
		elseif char_faction == TITAN_HORDE then
			BronzeSave[index].faction = FACTION_HORDE
		else
			BronzeSave[index].faction = FACTION_OTHER
		end
--[[
		if character == UnitName("player") and charserver == realmName then
			local rementry = character.."_"..charserver.."::"..UnitFactionGroup("Player");
			local showCharacter = BronzeSave[rementry].show
			if showCharacter == nil then showCharacter = true end
			BronzeSave[BRONZE_INDEX] = {gold = GetMoney("player"), show = showCharacter, name = UnitName("player")}
		end
--]]
	end
	BRONZE_STARTINGBRONZE = GetMoney();
	BRONZE_SESSIONSTART = GetTime();
	BRONZE_INITIALIZED = true;

	-- AFTER we say init is done or we'll never show the gold!
	TitanPanelButton_UpdateButton(TITAN_BRONZE_ID)
end

--[[
-- **************************************************************************
-- NAME : ClearData()
-- DESC : This will allow the user to clear all the data and rebuild the array
-- **************************************************************************
--]]
local function ClearData(self)
	BRONZE_INITIALIZED = false;

	BronzeSave = {};
	Initialize_Array(self);

	DEFAULT_CHAT_FRAME:AddMessage(TitanUtils_GetGreenText(L["TITAN_BRONZE_DB_CLEARED"]));
end

local function TitanBronze_ClearDB()
	StaticPopupDialogs["TITANBRONZE_CLEAR_DATABASE"] = {
		text = TitanUtils_GetNormalText(L["TITAN_PANEL_MENU_TITLE"].." "
			..L["TITAN_BRONZE_MENU_TEXT"]).."\n\n"..L["TITAN_BRONZE_CLEAR_DATA_WARNING"],
		button1 = ACCEPT,
		button2 = CANCEL,
		OnAccept = function(self)
			local frame = _G["TitanPanelBronzeButton"]
			ClearData(frame)
		end,
		showAlert = 1,
		timeout = 0,
		whileDead = 1,
		hideOnEscape = 1
	};
	StaticPopup_Show("TITANBRONZE_CLEAR_DATABASE");
end

--[[
-- *******************************************************************************************
-- NAME: CreateMenu
-- DESC: Builds the right click config menu
-- *******************************************************************************************
--]]
local function CreateMenu()
	if TitanPanelRightClickMenu_GetDropdownLevel() == 1 then
		-- Menu title
		TitanPanelRightClickMenu_AddTitle(L["TITAN_BRONZE_ITEMNAME"]);

		-- Function to toggle button gold view
		local info = {};
		info.text = L["TITAN_BRONZE_TOGGLE_ALL_TEXT"]
		info.checked = TitanGetVar(TITAN_BRONZE_ID, "ViewAll");
		info.func = function()
			ViewAll_Toggle()
		end
		TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());

		info = {};
		info.text = L["TITAN_BRONZE_TOGGLE_PLAYER_TEXT"]
		info.checked = not TitanGetVar(TITAN_BRONZE_ID, "ViewAll");
		info.func = function()
			ViewAll_Toggle()
		end
		TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());
		TitanPanelRightClickMenu_AddSeparator();

		-- Display options
		info = {};
		info.notCheckable = true
		info.text = L["TITAN_BRONZE_TOOLTIP_DISPLAY_OPTIONS"];
		info.value = "Display_Options";
		info.hasArrow = 1;
		TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());

		TitanPanelRightClickMenu_AddSeparator();

		-- Show / delete toons
		info = {};
		info.notCheckable = true
		info.text = L["TITAN_BRONZE_SHOW_PLAYER"];
		info.value = "ToonShow";
		info.hasArrow = 1;
		TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());

		info = {};
		info.notCheckable = true
		info.text = L["TITAN_BRONZE_DELETE_PLAYER"];
		info.value = "ToonDelete";
		info.hasArrow = 1;
		TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());

		TitanPanelRightClickMenu_AddSeparator();

		-- Option to clear the enter database
		info = {};
		info.notCheckable = true
		info.text = L["TITAN_BRONZE_CLEAR_DATA_TEXT"];
		info.func = TitanBronze_ClearDB;
		TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());

		TitanPanelRightClickMenu_AddCommand(L["TITAN_BRONZE_RESET_SESS_TEXT"], TITAN_BRONZE_ID, ResetSession);

		TitanPanelRightClickMenu_AddControlVars(TITAN_BRONZE_ID)
	end

	-- Second (2nd) level for show / delete | sort by
	if TitanPanelRightClickMenu_GetDropdownLevel() == 2 
		and TitanPanelRightClickMenu_GetDropdMenuValue() == "ToonDelete" then
		local info = {};
		info.notCheckable = true
		info.text = L["TITAN_BRONZE_FACTION_PLAYER_ALLY"];
		info.value = "DeleteAlliance";
		info.hasArrow = 1;
		TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());

		info.text = L["TITAN_BRONZE_FACTION_PLAYER_HORDE"];
		info.value = "DeleteHorde";
		info.hasArrow = 1;
		TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());
	elseif TitanPanelRightClickMenu_GetDropdownLevel() == 2 
		and TitanPanelRightClickMenu_GetDropdMenuValue() == "ToonShow" then
		local info = {};
		info.notCheckable = true
		info.text = L["TITAN_BRONZE_FACTION_PLAYER_ALLY"];
		info.value = "ShowAlliance";
		info.hasArrow = 1;
		TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());

		info.text = L["TITAN_BRONZE_FACTION_PLAYER_HORDE"];
		info.value = "ShowHorde";
		info.hasArrow = 1;
		TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());
	elseif TitanPanelRightClickMenu_GetDropdownLevel() == 3
		and TitanPanelRightClickMenu_GetDropdMenuValue() == "Sorting" then
		-- Show gold only option - no silver, no copper
		local info = {};
		info.text = L["TITAN_BRONZE_TOGGLE_SORT_BRONZE"]
		info.checked = not TitanGetVar(TITAN_BRONZE_ID, "SortByName");
		info.func = function()
			Sort_Toggle()
		end
		TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());

		local info = {};
		info.text = L["TITAN_BRONZE_TOGGLE_SORT_NAME"]
		info.checked = TitanGetVar(TITAN_BRONZE_ID, "SortByName");
		info.func = function()
			Sort_Toggle()
		end
		TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());

		TitanPanelRightClickMenu_AddSeparator(TitanPanelRightClickMenu_GetDropdownLevel());

		local info = {};
		info.text = L["TITAN_BRONZE_GROUP_BY_REALM"];
		info.checked = TitanGetVar(TITAN_BRONZE_ID, "GroupByRealm")
		info.func = function()
			TitanToggleVar(TITAN_BRONZE_ID, "GroupByRealm")
		end
		TitanPanelRightClickMenu_AddButton(info, TitanPanelRightClickMenu_GetDropdownLevel());
	elseif TitanPanelRightClickMenu_GetDropdownLevel() == 2 
		and TitanPanelRightClickMenu_GetDropdMenuValue() == "Display_Options" then
		DisplayOptions()
	end

	-- Third (3rd) level for the list of characters / toons
	if TitanPanelRightClickMenu_GetDropdownLevel() == 3 and TitanPanelRightClickMenu_GetDropdMenuValue() == "DeleteAlliance" then
		DeleteMenuButtons(TITAN_ALLIANCE)
	elseif TitanPanelRightClickMenu_GetDropdownLevel() == 3 and TitanPanelRightClickMenu_GetDropdMenuValue() == "DeleteHorde" then
		DeleteMenuButtons(TITAN_HORDE)
	elseif TitanPanelRightClickMenu_GetDropdownLevel() == 3 and TitanPanelRightClickMenu_GetDropdMenuValue() == "ShowAlliance" then
		ShowMenuButtons(TITAN_ALLIANCE)
	elseif TitanPanelRightClickMenu_GetDropdownLevel() == 3 and TitanPanelRightClickMenu_GetDropdMenuValue() == "ShowHorde" then
		ShowMenuButtons(TITAN_HORDE)
	end
end

--[[
-- *******************************************************************************************
-- NAME: FindBronze()
-- DESC: This routines determines which gold total the ui wants (server or player) then calls it and returns it
-- *******************************************************************************************
--]]
local function FindBronze()
	if (not BRONZE_INITIALIZED) then
		-- in case there is no db entry for this toon, return blank.
		-- When Bronze is ready it will init
		return ""
	end

	local ret_str = ""
	local ttlgold = 0;

	BronzeSave[BRONZE_INDEX].gold = GetMoney()

	if TitanGetVar(TITAN_BRONZE_ID, "ViewAll") then
		ttlgold = TotalBronze()
	else
		ttlgold = GetMoney();
	end

	ret_str = NiceCash(ttlgold, true, false)

	return L["TITAN_BRONZE_MENU_TEXT"]..": "..FONT_COLOR_CODE_CLOSE, ret_str
end

--[[
-- **************************************************************************
-- NAME : OnLoad()
-- DESC : Registers the add on upon it loading
-- **************************************************************************
--]]
local function OnLoad(self)
	local notes = ""
		.."Keeps track of all gold held by a player's toons.\n"
		.."- Can show by server / merged servers / all servers.\n"
		.."- Can show by faction.\n"
	self.registry = {
		id = TITAN_BRONZE_ID,
		category = "Built-ins",
		version = TITAN_BRONZE_VERSION,
		menuText = L["TITAN_BRONZE_MENU_TEXT"],
		menuTextFunction = CreateMenu,
		tooltipTitle = L["TITAN_BRONZE_TOOLTIP"],
		tooltipTextFunction = GetTooltipText,
		buttonTextFunction = FindBronze,
		icon = "Interface\\AddOns\\TitanBronze\\Artwork\\TitanBronze",
		iconWidth = 16,
		notes = notes,
		controlVariables = {
			ShowIcon = true,
			ShowLabelText = true,
			ShowRegularText = false,
			ShowColoredText = false,
			DisplayOnRightSide = true,
		},
		savedVariables = {
			Initialized = true,
			DisplayBronzePerHour = true,
			ShowCoinNone = false,
			ShowCoinLabels = true,
			ShowCoinIcons = false,
			ShowBronzeOnly = false,
			SortByName = true,
			ViewAll = true,
			ShowIcon = true,
			ShowLabelText = false,
			ShowColoredText = true,
			DisplayOnRightSide = false,
			UseSeperatorComma = true,
			UseSeperatorPeriod = false,
			MergeServers = false,
			SeparateServers = true,
			AllServers = false,
			IgnoreFaction = false,
			GroupByRealm = false,
			gold = { total = "112233", neg = false },
			ShowSessionInfo = true
		}
	};

	self:RegisterEvent("PLAYER_ENTERING_WORLD");

	if (not BronzeSave) then
		BronzeSave={};
	end
	
	-- Faction is English to use as index NOT display
	BRONZE_INDEX = UnitName("player").."_"..realmName.."::"..UnitFactionGroup("Player");
end

--[[
-- **************************************************************************
-- NAME : OnShow()
-- DESC : Create repeating timer when plugin is visible
-- **************************************************************************
--]]
local function OnShow(self)
	self:RegisterEvent("PLAYER_MONEY");
	if BronzeSave and TitanGetVar(TITAN_BRONZE_ID, "DisplayBronzePerHour") then
		if BronzeTimerRunning then
			-- Do not start a new one
		else
			BronzeTimer = AceTimer:ScheduleRepeatingTimer(TitanPanelPluginHandle_OnUpdate, 1, updateTable)
			BronzeTimerRunning = true
		end
	else
		-- timer running or user does not want gold per hour
	end
end

--[[
-- **************************************************************************
-- NAME : OnHide()
-- DESC : Destroy repeating timer when plugin is hidden
-- **************************************************************************
--]]
local function OnHide(self)
	self:UnregisterEvent("PLAYER_MONEY");
	AceTimer:CancelTimer(BronzeTimer)
	BronzeTimerRunning = false
end

--[[
-- **************************************************************************
-- NAME : OnEvent()
-- DESC : This section will grab the events registered to the add on and act on them
-- **************************************************************************
--]]
local function OnEvent(self, event, ...)
--[[
print("_OnEvent"
.." "..tostring(event)..""
)
--]]
	if (event == "PLAYER_MONEY") then
		if (BRONZE_INITIALIZED) then
			BronzeSave[BRONZE_INDEX].gold = GetMoney()
			TitanPanelButton_UpdateButton(TITAN_BRONZE_ID)
		end
		return;
	end

	if (event == "PLAYER_ENTERING_WORLD") then
		if (not BRONZE_INITIALIZED) then
			Initialize_Array(self);
		end
		TitanPanelButton_UpdateButton(TITAN_BRONZE_ID)
		return;
	end
end

local function Create_Frames()
	if _G[TITAN_BUTTON] then
		return -- if already created
	end
	
	-- general container frame
	local f = CreateFrame("Frame", nil, UIParent)
--	f:Hide()

	-- Titan plugin button
	local window = CreateFrame("Button", TITAN_BUTTON, f, "TitanPanelComboTemplate")
	window:SetFrameStrata("FULLSCREEN")
	-- Using SetScript("OnLoad",   does not work
	OnLoad(window);
--	TitanPanelButton_OnLoad(window); -- Titan XML template calls this...
	
	window:SetScript("OnShow", function(self)
		OnShow(self);
		TitanPanelButton_OnShow(self);
	end)
	window:SetScript("OnHide", function(self)
		OnHide(self);
	end)
	window:SetScript("OnEvent", function(self, event, ...)
		OnEvent(self, event, ...) 
	end)
end


Create_Frames() -- do the work
