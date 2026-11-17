local _, ns = ...
local UI = ns.UI

local STONE = "Interface\\Icons\\INV_Stone_SharpeningStone_05"
local FOOD = "Interface\\Icons\\INV_Misc_Food_15"
local FLASK = "Interface\\Icons\\INV_Potion_62"

local LISTS = {
	WARRIOR = {
		{ key = "shout", label = "Battle Shout", name = 6673, ids = { 6673 } },
	},
	DRUID = {
		{ key = "motw", label = "Mark of the Wild", name = 1126, ids = { 1126, 21849 } },
		{ key = "thorns", label = "Thorns", name = 467, ids = { 467 }, off = true },
	},
	MAGE = {
		{ key = "intellect", label = "Arcane Intellect", name = 1459, ids = { 1459, 23028 } },
		{ key = "armor", label = "Mage armor", ids = { 168, 7302, 6117 } },
	},
	PRIEST = {
		{ key = "fortitude", label = "Power Word: Fortitude", name = 1243, ids = { 1243, 21562 } },
		{ key = "innerfire", label = "Inner Fire", name = 588, ids = { 588 } },
	},
	WARLOCK = {
		{ key = "armor", label = "Demon Armor", name = 706, ids = { 687, 706 } },
	},
	PALADIN = {
		{ key = "blessing", label = "Blessing", ids = { 19740, 19742, 20217, 1038, 20911, 19977, 25782, 25894, 25898, 25895, 25899, 25890 } },
		{ key = "aura", label = "Aura", ids = { 465, 7294, 19746, 19891, 19888, 19876, 20218 } },
	},
	HUNTER = {
		{ key = "aspect", label = "Aspect", ids = { 13165, 13163, 5118, 13159, 20043, 13161 } },
	},
	SHAMAN = {
		{ key = "shield", label = "Lightning Shield", name = 324, ids = { 324 } },
		{ key = "weapon", label = "Weapon enchant", weapon = true },
	},
	ROGUE = {
		{ key = "weapon", label = "Poison", weapon = true },
	},
}

local GROUP = {
	{ key = "gfort", label = "Power Word: Fortitude", name = 1243, ids = { 1243, 21562 }, from = "PRIEST" },
	{ key = "gmotw", label = "Mark of the Wild", name = 1126, ids = { 1126, 21849 }, from = "DRUID" },
	{ key = "gint", label = "Arcane Intellect", name = 1459, ids = { 1459, 23028 }, from = "MAGE", mana = true },
}

local COMMON = {
	{ key = "food", label = "Food buff", ids = { 19705 }, instance = true, always = true, icon = FOOD },
	{ key = "flask", label = "Flask", ids = { 17626, 17627, 17628, 17629 }, raid = true, always = true, icon = FLASK, off = true },
	{ key = "stone", label = "Weapon stone or oil", weapon = true, instance = true, icon = STONE },
}

local function spellName(id)
	local name
	if C_Spell and C_Spell.GetSpellName then
		name = C_Spell.GetSpellName(id)
	elseif GetSpellInfo then
		name = GetSpellInfo(id)
	end
	if type(name) == "string" and not ns.IsSecret(name) and name ~= "" then return name end
end

local function spellIcon(id)
	if C_Spell and C_Spell.GetSpellTexture then return (C_Spell.GetSpellTexture(id)) end
	if GetSpellTexture then return (GetSpellTexture(id)) end
end

local function known(id)
	if C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook then
		local ok, v = pcall(C_SpellBook.IsSpellKnownOrInSpellBook, id)
		if ok then return v and true or false end
	end
	if IsPlayerSpell then return IsPlayerSpell(id) and true or false end
	if IsSpellKnown then return IsSpellKnown(id) and true or false end
	return true
end

local function label(e)
	return e.name and spellName(e.name) or e.label
end
ns.ReminderLabel = label

function ns.ReminderList()
	local out = {}
	for _, e in ipairs(LISTS[ns.playerClass] or {}) do out[#out + 1] = e end
	local hasWeapon = false
	for _, e in ipairs(out) do
		if e.weapon then hasWeapon = true end
	end
	for _, e in ipairs(GROUP) do
		if e.from ~= ns.playerClass then out[#out + 1] = e end
	end
	for _, e in ipairs(COMMON) do
		if not (e.weapon and hasWeapon) then out[#out + 1] = e end
	end
	return out
end

local function enabled(e)
	local v = ns.db.off[e.key]
	if v == nil then return not e.off end
	return not v
end

function ns.ReminderEntries()
	local entries = { { text = "Remind me about", title = true } }
	for _, e in ipairs(ns.ReminderList()) do
		local text = label(e)
		if e.from then
			text = text .. "  (from a group member)"
		elseif e.raid then
			text = text .. "  (in raids)"
		elseif e.instance then
			text = text .. "  (in instances)"
		end
		entries[#entries + 1] = {
			text = text, checked = enabled(e),
			func = function()
				ns.db.off[e.key] = enabled(e)
				ns:Fire("OPTIONS")
			end,
		}
	end
	return entries
end

local function groupClasses()
	local out = {}
	local n = GetNumGroupMembers and GetNumGroupMembers() or 0
	if ns.IsSecret(n) or type(n) ~= "number" or n < 1 or not UnitExists then return out end
	local raid = IsInRaid and IsInRaid() and true or false
	for i = 1, n do
		local unit = (raid and "raid" or "party") .. i
		if UnitExists(unit) then
			local _, class = UnitClass(unit)
			if not ns.IsSecret(class) and type(class) == "string" then out[class] = true end
		end
	end
	return out
end

local function usesMana()
	if not UnitPowerMax then return true end
	local ok, max = pcall(UnitPowerMax, "player", 0)
	if not ok or ns.IsSecret(max) or type(max) ~= "number" then return true end
	return max > 0
end

function ns.Missing()
	local out = {}
	if not ns.db.reminders or ns.InCombat() then return out end
	if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return out end
	local names = {}
	for _, a in ipairs(ns.buffs or {}) do
		if not a.name then return out end
		names[a.name] = true
	end
	local inside = IsInInstance and IsInInstance() and true or false
	local raid = IsInRaid and IsInRaid() and true or false
	local classes
	local main = false
	for _, a in ipairs(ns.ReadEnchants()) do
		if a.enchant == 16 then main = true end
	end
	for _, e in ipairs(ns.ReminderList()) do
		if enabled(e) and (not e.instance or inside) and (not e.raid or raid) then
			if e.weapon then
				local armed = GetInventoryItemID and GetInventoryItemID("player", 16)
				if armed and not main and ns.EnchantsKnown() then
					out[#out + 1] = { entry = e, icon = e.icon or STONE, label = label(e) }
				end
			else
				local have, can, icon = false, e.always or false, e.icon
				if e.from then
					classes = classes or groupClasses()
					can = classes[e.from] and (not e.mana or usesMana()) or false
				end
				for _, id in ipairs(e.ids) do
					local name = spellName(id)
					if name and names[name] then have = true break end
					if not e.always and not e.from and known(id) then
						can = true
						icon = icon or spellIcon(id)
					end
				end
				if can and not have then
					out[#out + 1] = { entry = e, icon = icon or spellIcon(e.ids[1]), label = label(e) }
				end
			end
		end
	end
	return out
end

local function createIcon(group)
	local f = CreateFrame("Button", nil, group.frame)
	f.tex = f:CreateTexture(nil, "ARTWORK")
	f.tex:SetAllPoints(f)
	f.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	f.tex:SetDesaturated(true)
	f.edges = UI.Border(f, { 0.8, 0.2, 0.2, 1 })
	f:SetAlpha(0.6)
	f:RegisterForClicks("RightButtonUp")
	f:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Missing: " .. (self.label or ""), 1, 0.3, 0.3)
		GameTooltip:AddLine("Right-click to stop this reminder", 0.58, 0.6, 0.65)
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f:SetScript("OnClick", function(self)
		if self.entry then
			ns.db.off[self.entry.key] = true
			ns:Fire("OPTIONS")
		end
	end)
	return f
end

function ns.RefreshReminders()
	if not ns.db then return end
	local group = ns.Group("reminders")
	local list = ns.Missing()
	local size = math.floor(ns.db.size * 0.85 + 0.5)
	local step = size + 4
	group.frame:SetSize(math.max(1, #list, 3) * step - 4, size)
	local offset = (#list * step - 4) / 2
	for i, m in ipairs(list) do
		local f = group.icons[i]
		if not f then
			f = createIcon(group)
			group.icons[i] = f
		end
		f.entry, f.label = m.entry, m.label
		f.tex:SetTexture(m.icon)
		f:SetSize(size, size)
		f:ClearAllPoints()
		f:SetPoint("LEFT", group.frame, "CENTER", (i - 1) * step - offset, 0)
		f:Show()
	end
	for i = #list + 1, #group.icons do group.icons[i]:Hide() end
	group.shown = #list
end

local function later() ns.Debounce("remind", 0.3, ns.RefreshReminders) end

ns:Listen("AURAS", ns.RefreshReminders)
ns:On("PLAYER_EQUIPMENT_CHANGED", later)
ns:On("ZONE_CHANGED_NEW_AREA", later)
ns:On("SPELLS_CHANGED", later)
ns:On("GROUP_ROSTER_UPDATE", later)
