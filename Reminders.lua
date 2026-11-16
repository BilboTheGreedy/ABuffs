local _, ns = ...
local UI = ns.UI

local STONE = "Interface\\Icons\\INV_Stone_SharpeningStone_05"
local FOOD = "Interface\\Icons\\INV_Misc_Food_15"

local LISTS = {
	WARRIOR = {
		{ key = "shout", label = "Battle Shout", ids = { 6673 } },
	},
	DRUID = {
		{ key = "motw", label = "Mark of the Wild", ids = { 1126, 21849 } },
		{ key = "thorns", label = "Thorns", ids = { 467 }, off = true },
	},
	MAGE = {
		{ key = "intellect", label = "Arcane Intellect", ids = { 1459, 23028 } },
		{ key = "armor", label = "Mage armor", ids = { 168, 7302, 6117 } },
	},
	PRIEST = {
		{ key = "fortitude", label = "Power Word: Fortitude", ids = { 1243, 21562 } },
		{ key = "innerfire", label = "Inner Fire", ids = { 588 } },
	},
	WARLOCK = {
		{ key = "armor", label = "Demon Armor", ids = { 687, 706 } },
	},
	PALADIN = {
		{ key = "blessing", label = "Blessing", ids = { 19740, 19742, 20217, 1038, 20911, 19977, 25782, 25894, 25898, 25895, 25899, 25890 } },
		{ key = "aura", label = "Aura", ids = { 465, 7294, 19746, 19891, 19888, 19876, 20218 } },
	},
	HUNTER = {
		{ key = "aspect", label = "Aspect", ids = { 13165, 13163, 5118, 13159, 20043, 13161 } },
	},
	SHAMAN = {
		{ key = "shield", label = "Lightning Shield", ids = { 324 } },
		{ key = "weapon", label = "Weapon enchant", weapon = true },
	},
	ROGUE = {
		{ key = "weapon", label = "Poison", weapon = true },
	},
}

local COMMON = {
	{ key = "food", label = "Food buff", ids = { 19705 }, instance = true, always = true, icon = FOOD },
	{ key = "stone", label = "Weapon stone or oil", weapon = true, instance = true, icon = STONE },
}

local function spellName(id)
	if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
	if GetSpellInfo then return (GetSpellInfo(id)) end
end

local function spellIcon(id)
	if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
	if GetSpellTexture then return GetSpellTexture(id) end
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

function ns.ReminderList()
	local out = {}
	for _, e in ipairs(LISTS[ns.playerClass] or {}) do out[#out + 1] = e end
	local hasWeapon = false
	for _, e in ipairs(out) do
		if e.weapon then hasWeapon = true end
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
		entries[#entries + 1] = {
			text = e.label, checked = enabled(e),
			func = function()
				ns.db.off[e.key] = enabled(e)
				ns:Fire("OPTIONS")
			end,
		}
	end
	return entries
end

function ns.Missing()
	local out = {}
	if not ns.db.reminders or ns.InCombat() then return out end
	if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return out end
	local names = {}
	for _, a in ipairs(ns.buffs or {}) do
		if a.secret and not a.name then return out end
		if a.name then names[a.name] = true end
	end
	local inside = IsInInstance and IsInInstance() and true or false
	local enchants = ns.ReadEnchants()
	local main = false
	for _, a in ipairs(enchants) do
		if a.enchant == 16 then main = true end
	end
	for _, e in ipairs(ns.ReminderList()) do
		if enabled(e) and (not e.instance or inside) then
			if e.weapon then
				local armed = GetInventoryItemID and GetInventoryItemID("player", 16)
				if armed and not main then
					out[#out + 1] = { entry = e, icon = e.icon or STONE, label = e.label }
				end
			else
				local have, can, icon = false, e.always or false, e.icon
				for _, id in ipairs(e.ids) do
					local name = spellName(id)
					if name and names[name] then have = true break end
					if not e.always and known(id) then
						can = true
						icon = icon or spellIcon(id)
					end
				end
				if can and not have then
					out[#out + 1] = { entry = e, icon = icon or spellIcon(e.ids[1]), label = e.label }
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

ns:Listen("AURAS", ns.RefreshReminders)
ns:On("PLAYER_EQUIPMENT_CHANGED", function() ns.Debounce("remind", 0.3, ns.RefreshReminders) end)
ns:On("ZONE_CHANGED_NEW_AREA", function() ns.Debounce("remind", 0.3, ns.RefreshReminders) end)
ns:On("SPELLS_CHANGED", function() ns.Debounce("remind", 0.3, ns.RefreshReminders) end)
