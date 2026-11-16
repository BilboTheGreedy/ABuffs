local _, ns = ...
local UI = ns.UI
local C = UI.colors

local DISPEL = {
	Magic = { 0.2, 0.6, 1 },
	Curse = { 0.6, 0, 1 },
	Disease = { 0.6, 0.4, 0 },
	Poison = { 0, 0.6, 0 },
}
local HARM = { 0.8, 0.1, 0.1 }
local ENCHANT = { 0.6, 0.3, 0.9 }
local GAP = 4
local TEXT = 12

local groups = {}
ns.groups = groups

local function plain(v)
	if v == nil or ns.IsSecret(v) then return nil end
	return v
end

function ns.Read(filter)
	local out = {}
	for i = 1, 40 do
		local data
		if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
			local ok, d = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, filter)
			if ok and type(d) == "table" then data = d end
		elseif UnitAura then
			local name, icon, count, dispel, duration, expires, _, _, _, spellId = UnitAura("player", i, filter)
			if name then
				data = { name = name, icon = icon, applications = count, dispelName = dispel, duration = duration, expirationTime = expires, spellId = spellId }
			end
		end
		if not data then break end
		local duration, expires = plain(data.duration), plain(data.expirationTime)
		local secret = ns.IsSecret(data.duration) or ns.IsSecret(data.expirationTime)
		local a = {
			index = i, filter = filter, icon = data.icon, name = plain(data.name), id = plain(data.spellId),
			instance = data.auraInstanceID, dispel = plain(data.dispelName), secret = secret and true or false,
			duration = type(duration) == "number" and duration or 0,
			expires = type(expires) == "number" and expires or 0,
		}
		local count = data.applications
		if ns.IsSecret(count) then
			a.countSecret = true
		elseif type(count) == "number" and count > 1 then
			a.count = count
		end
		out[#out + 1] = a
	end
	return out
end

function ns.ReadEnchants()
	local out = {}
	if not GetWeaponEnchantInfo then return out end
	local ok, hasMain, mainLeft, mainCharges, _, hasOff, offLeft, offCharges = pcall(GetWeaponEnchantInfo)
	if not ok then return out end
	local now = GetTime()
	local function add(has, left, charges, slot)
		if not has or ns.IsSecret(has) then return end
		local a = { enchant = slot, duration = 0, expires = 0, secret = false }
		if type(left) == "number" and not ns.IsSecret(left) then
			a.expires = now + left / 1000
			a.duration = left / 1000
		end
		if type(charges) == "number" and not ns.IsSecret(charges) and charges > 1 then a.count = charges end
		if GetInventoryItemTexture then a.icon = GetInventoryItemTexture("player", slot) end
		a.name = slot == 16 and "Main hand enchant" or "Off hand enchant"
		out[#out + 1] = a
	end
	add(hasMain, mainLeft, mainCharges, 16)
	add(hasOff, offLeft, offCharges, 17)
	return out
end

local function sortAuras(list)
	for _, a in ipairs(list) do
		if a.secret then return end
	end
	table.sort(list, function(x, y)
		local px, py = x.expires == 0, y.expires == 0
		if px ~= py then return px end
		if x.expires ~= y.expires then return x.expires > y.expires end
		return (x.index or 0) < (y.index or 0)
	end)
end

local function showTooltip(self)
	local a = self.aura
	if not a then return end
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
	local done = false
	if a.enchant then
		if GameTooltip.SetInventoryItem then done = pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", a.enchant) end
	elseif GameTooltip.SetUnitAura then
		done = pcall(GameTooltip.SetUnitAura, GameTooltip, "player", a.index, a.filter)
	elseif a.filter == "HELPFUL" and GameTooltip.SetUnitBuff then
		done = pcall(GameTooltip.SetUnitBuff, GameTooltip, "player", a.index)
	elseif GameTooltip.SetUnitDebuff then
		done = pcall(GameTooltip.SetUnitDebuff, GameTooltip, "player", a.index)
	end
	if not done and a.name then GameTooltip:AddLine(a.name, 1, 1, 1) end
	GameTooltip:Show()
end

local function cancel(self, button)
	local a = self.aura
	if button ~= "RightButton" or not a or ns.InCombat() then return end
	if a.enchant then
		if CancelItemTempEnchantment then pcall(CancelItemTempEnchantment, a.enchant == 16 and 1 or 2) end
	elseif a.filter == "HELPFUL" and CancelUnitBuff then
		pcall(CancelUnitBuff, "player", a.index, a.filter)
	end
end

local function createIcon(group)
	local f = CreateFrame("Button", nil, group.frame)
	f.tex = f:CreateTexture(nil, "ARTWORK")
	f.tex:SetAllPoints(f)
	f.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	f.edges = UI.Border(f, { 0, 0, 0, 1 })
	f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
	f.cd:SetAllPoints(f)
	f.cd:SetReverse(true)
	f.cd:Hide()
	f.count = UI.Text(f, "NumberFontNormalSmall", "RIGHT", { 1, 1, 1 })
	f.count:SetPoint("BOTTOMRIGHT", -1, 1)
	f.time = UI.Text(f, "GameFontHighlightSmall", "CENTER", C.text)
	f.time:SetPoint("TOP", f, "BOTTOM", 0, -1)
	f:RegisterForClicks("RightButtonUp")
	f:SetScript("OnClick", cancel)
	f:SetScript("OnEnter", showTooltip)
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return f
end

local function edgeColor(f, c)
	for _, e in ipairs(f.edges) do e:SetColorTexture(c[1], c[2], c[3], 1) end
end

local function setIcon(f, a, group)
	f.aura = a
	f.tex:SetTexture(a.icon)
	if group.key == "debuffs" then
		edgeColor(f, a.dispel and DISPEL[a.dispel] or HARM)
	elseif group.key == "enchants" then
		edgeColor(f, ENCHANT)
	else
		edgeColor(f, { 0, 0, 0 })
	end
	f.count:SetText("")
	if a.count then
		f.count:SetText(a.count)
	elseif a.countSecret and a.instance and C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount then
		local ok, text = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, "player", a.instance, 2, 99)
		if ok and text ~= nil then f.count:SetText(text) end
	end
	f.cd:Hide()
	f.time:SetText("")
	f:SetAlpha(1)
	if a.secret then
		if a.instance and C_UnitAuras and C_UnitAuras.GetAuraDuration and f.cd.SetCooldownFromDurationObject then
			local ok, obj = pcall(C_UnitAuras.GetAuraDuration, "player", a.instance)
			if ok and obj then
				if pcall(f.cd.SetCooldownFromDurationObject, f.cd, obj) then f.cd:Show() end
			end
		end
	end
end

local function tick(group, now)
	local db = ns.db
	for i = 1, group.shown do
		local f = group.icons[i]
		local a = f.aura
		if a and not a.secret and a.expires > 0 then
			local left = a.expires - now
			if left < 0 then left = 0 end
			f.time:SetText(db.timers and ns.TimeText(left) or "")
			if db.flash > 0 and left < db.flash then
				f:SetAlpha(0.45 + 0.55 * math.abs(math.sin(now * 3)))
			else
				f:SetAlpha(1)
			end
		end
	end
end

local function layout(group, list)
	local db = ns.db
	local size = db.size
	if group.key == "debuffs" then size = math.floor(size * 1.15 + 0.5) end
	local step = size + GAP
	local per = db.perRow
	group.frame:SetSize(per * step - GAP, size)
	for i, a in ipairs(list) do
		local f = group.icons[i]
		if not f then
			f = createIcon(group)
			group.icons[i] = f
		end
		local col, row = (i - 1) % per, math.floor((i - 1) / per)
		f:SetSize(size, size)
		f:ClearAllPoints()
		if db.growLeft then
			f:SetPoint("TOPRIGHT", group.frame, "TOPRIGHT", -col * step, -row * (step + TEXT))
		else
			f:SetPoint("TOPLEFT", group.frame, "TOPLEFT", col * step, -row * (step + TEXT))
		end
		setIcon(f, a, group)
		f:Show()
	end
	for i = #list + 1, #group.icons do
		group.icons[i]:Hide()
		group.icons[i].aura = nil
	end
	group.shown = #list
	tick(group, GetTime())
end

local LABEL = { buffs = "Buffs", debuffs = "Debuffs", enchants = "Weapon enchants", reminders = "Reminders" }

function ns.Group(key)
	local g = groups[key]
	if g then return g end
	g = { key = key, icons = {}, shown = 0 }
	local frame = CreateFrame("Frame", "ABuffs_" .. key, UIParent)
	frame:SetSize(200, 32)
	g.frame = frame
	local db = ns.db.groups[key]
	db.locked = ns.db.locked
	UI.Movable(frame, db)
	local handle = CreateFrame("Button", nil, frame)
	handle:SetAllPoints(frame)
	handle:SetFrameLevel((frame:GetFrameLevel() or 1) + 20)
	UI.Fill(handle, { 1, 0.82, 0, 0.25 })
	UI.Border(handle, C.accent)
	handle.label = UI.Text(handle, "GameFontNormalSmall", "CENTER", C.accent)
	handle.label:SetPoint("CENTER")
	handle.label:SetText(LABEL[key] .. " (drag)")
	handle:RegisterForDrag("LeftButton")
	handle:RegisterForClicks("RightButtonUp")
	handle:SetScript("OnDragStart", function() frame:StartDrag() end)
	handle:SetScript("OnDragStop", function() frame:StopDrag() end)
	handle:SetScript("OnClick", function(self) UI.Menu(self, ns.Options()) end)
	handle:SetShown(not ns.db.locked)
	g.handle = handle
	groups[key] = g
	if not ns.anchor then ns.anchor = frame end
	return g
end

function ns.Refresh()
	if not ns.db then return end
	local buffs = ns.Read("HELPFUL")
	local debuffs = ns.Read("HARMFUL")
	if ns.db.sort then
		sortAuras(buffs)
		sortAuras(debuffs)
	end
	ns.buffs = buffs
	layout(ns.Group("buffs"), buffs)
	layout(ns.Group("debuffs"), debuffs)
	layout(ns.Group("enchants"), ns.ReadEnchants())
	ns:Fire("AURAS")
end

local hidden
local pendingHide
local function hideBlizzard()
	if not ns.db.hideBlizzard then return end
	if ns.InCombat() then
		pendingHide = true
		return
	end
	pendingHide = false
	if not hidden then
		hidden = CreateFrame("Frame")
		hidden:Hide()
	end
	for _, name in ipairs({ "BuffFrame", "DebuffFrame", "TemporaryEnchantFrame" }) do
		local f = _G[name]
		if f and f.SetParent then pcall(f.SetParent, f, hidden) end
	end
end
ns.HideBlizzard = hideBlizzard

local function applyOptions()
	for key, g in pairs(groups) do
		local db = ns.db.groups[key]
		db.locked = ns.db.locked
		g.handle:SetShown(not ns.db.locked)
	end
	hideBlizzard()
	ns.Refresh()
end

ns:Listen("OPTIONS", applyOptions)
ns:Listen("LAYOUT_RESET", function()
	for _, g in pairs(groups) do g.frame:Restore() end
end)

ns:Listen("LOGIN", function()
	hideBlizzard()
	ns.Refresh()
	local ticker = CreateFrame("Frame")
	local elapsed, slow = 0, 0
	ticker:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + (dt or 0)
		if elapsed < 0.1 then return end
		slow = slow + elapsed
		elapsed = 0
		local now = GetTime()
		for _, g in pairs(groups) do
			if g.key ~= "reminders" then tick(g, now) end
		end
		if slow >= 1 then
			slow = 0
			local n = #ns.ReadEnchants()
			if n ~= groups.enchants.shown then ns.Refresh() end
		end
	end)
end)

ns:On("UNIT_AURA", function(unit)
	if unit == "player" then ns.Debounce("auras", 0.05, ns.Refresh) end
end)
ns:On("PLAYER_ENTERING_WORLD", function() ns.Debounce("auras", 0.05, ns.Refresh) end)
ns:On("UNIT_INVENTORY_CHANGED", function(unit)
	if unit == "player" then ns.Debounce("auras", 0.05, ns.Refresh) end
end)
ns:On("PLAYER_REGEN_ENABLED", function()
	if pendingHide then hideBlizzard() end
	ns.Debounce("auras", 0.05, ns.Refresh)
end)
ns:On("PLAYER_REGEN_DISABLED", function() ns.Debounce("auras", 0.05, ns.Refresh) end)
