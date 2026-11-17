local ADDON, ns = ...

local defaults = {
	hideBlizzard = true,
	timers = true,
	clock = false,
	sort = true,
	flash = 10,
	reminders = true,
	locked = true,
	size = 32,
	debuffScale = 1.15,
	perRow = 10,
	growLeft = true,
	off = {},
	hidden = {},
	groups = {
		buffs = { scale = 1, default = { "TOPRIGHT", "TOPRIGHT", -230, -16 } },
		debuffs = { scale = 1, default = { "TOPRIGHT", "TOPRIGHT", -230, -150 } },
		enchants = { scale = 1, default = { "TOPRIGHT", "TOPRIGHT", -230, -215 } },
		reminders = { scale = 1, default = { "CENTER", "CENTER", 0, -170 } },
	},
}

ACore.New(ADDON, ns, { db = "ABuffsDB", defaults = defaults, profile = true })

function ns.InCombat()
	return InCombatLockdown and InCombatLockdown() and true or false
end

function ns.TimeText(left)
	if left >= 3600 then return math.floor(left / 3600 + 0.5) .. "h" end
	if ns.db and ns.db.clock and left >= 60 then
		local s = math.floor(left + 0.5)
		return string.format("%d:%02d", math.floor(s / 60), s % 60)
	end
	if left >= 60 then return math.floor(left / 60 + 0.5) .. "m" end
	return tostring(math.floor(left + 0.5))
end

function ns.Options()
	local db = ns.db
	local UI = ns.UI
	local function changed() ns:Fire("OPTIONS") end
	local function pick(key, value, text)
		return {
			text = text, checked = db[key] == value,
			func = function()
				db[key] = value
				changed()
			end,
		}
	end
	local entries = {
		{ text = "ABuffs", title = true },
		UI.Check(db, "locked", "Lock position", changed),
		UI.Check(db, "hideBlizzard", "Hide the default buff frame", changed),
		UI.Check(db, "timers", "Show time left", changed),
		UI.Check(db, "clock", "Time left as minutes:seconds", changed),
		UI.Check(db, "sort", "Sort by time left", changed),
		UI.Check(db, "growLeft", "Grow to the left", changed),
		UI.Check(db, "reminders", "Missing buff reminders", changed),
		{ text = "Icon size", title = true },
	}
	for _, s in ipairs({ 24, 28, 32, 38, 44 }) do entries[#entries + 1] = pick("size", s, tostring(s)) end
	entries[#entries + 1] = { text = "Debuff size", title = true }
	for _, s in ipairs({ { 1, "Same as buffs" }, { 1.15, "Larger" }, { 1.4, "Much larger" }, { 1.75, "Huge" } }) do
		entries[#entries + 1] = pick("debuffScale", s[1], s[2])
	end
	entries[#entries + 1] = { text = "Icons per row", title = true }
	for _, n in ipairs({ 6, 8, 10, 12, 16 }) do entries[#entries + 1] = pick("perRow", n, tostring(n)) end
	entries[#entries + 1] = { text = "Flash when under", title = true }
	for _, n in ipairs({ 0, 5, 10, 30 }) do
		entries[#entries + 1] = pick("flash", n, n == 0 and "Never" or (n .. " seconds"))
	end
	for _, e in ipairs(ns.ReminderEntries and ns.ReminderEntries() or {}) do entries[#entries + 1] = e end
	local hidden = {}
	for name in pairs(db.hidden) do hidden[#hidden + 1] = name end
	table.sort(hidden)
	if #hidden > 0 then
		entries[#entries + 1] = { text = "Hidden buffs (click to show again)", title = true }
		for _, name in ipairs(hidden) do
			entries[#entries + 1] = {
				text = name,
				func = function()
					db.hidden[name] = nil
					changed()
				end,
			}
		end
	end
	return entries
end

ACore.Register({
	name = "ABuffs",
	options = function() return ns.Options() end,
	title = "ABuffs",
	slash = "/abuffs",
	desc = "buffs, debuffs and reminders",
	toggle = function() ns.UI.Menu(ACoreMinimapButton or UIParent, ns.Options()) end,
})

SLASH_ABUFFS1 = "/abuffs"
SlashCmdList["ABUFFS"] = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "unlock" then
		ns.db.locked = false
		ns:Fire("OPTIONS")
	elseif msg == "lock" then
		ns.db.locked = true
		ns:Fire("OPTIONS")
	elseif msg == "reset" then
		for _, g in pairs(ns.db.groups) do
			g.pos = nil
			g.scale = 1
		end
		ns:Fire("LAYOUT_RESET")
	else
		ns.UI.Menu(ns.anchor or UIParent, ns.Options())
	end
end
