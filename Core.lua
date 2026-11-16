local ADDON, ns = ...

local defaults = {
	hideBlizzard = true,
	timers = true,
	sort = true,
	flash = 10,
	reminders = true,
	locked = true,
	size = 32,
	perRow = 10,
	growLeft = true,
	off = {},
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
	if left >= 60 then return math.floor(left / 60 + 0.5) .. "m" end
	return tostring(math.floor(left + 0.5))
end

function ns.Options()
	local db = ns.db
	local UI = ns.UI
	local function changed() ns:Fire("OPTIONS") end
	local entries = {
		{ text = "ABuffs", title = true },
		UI.Check(db, "locked", "Lock position", changed),
		UI.Check(db, "hideBlizzard", "Hide the default buff frame", changed),
		UI.Check(db, "timers", "Show time left", changed),
		UI.Check(db, "sort", "Sort by time left", changed),
		UI.Check(db, "growLeft", "Grow to the left", changed),
		UI.Check(db, "reminders", "Missing buff reminders", changed),
		{ text = "Icon size", title = true },
	}
	for _, s in ipairs({ 24, 28, 32, 38, 44 }) do
		entries[#entries + 1] = {
			text = tostring(s), checked = db.size == s,
			func = function()
				db.size = s
				changed()
			end,
		}
	end
	entries[#entries + 1] = { text = "Icons per row", title = true }
	for _, n in ipairs({ 6, 8, 10, 12, 16 }) do
		entries[#entries + 1] = {
			text = tostring(n), checked = db.perRow == n,
			func = function()
				db.perRow = n
				changed()
			end,
		}
	end
	entries[#entries + 1] = { text = "Flash when under", title = true }
	for _, n in ipairs({ 0, 5, 10, 30 }) do
		entries[#entries + 1] = {
			text = n == 0 and "Never" or (n .. " seconds"), checked = db.flash == n,
			func = function()
				db.flash = n
				changed()
			end,
		}
	end
	for _, e in ipairs(ns.ReminderEntries and ns.ReminderEntries() or {}) do entries[#entries + 1] = e end
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
