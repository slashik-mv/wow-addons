local addon, handler, pending = {}, nil, {}
local shown, created = false, 0
CreateFrame = function() return {
  RegisterEvent = function() end,
  SetScript = function(_, _, callback) handler = callback end,
} end
C_Timer = { NewTicker = function() return {} end, After = function(_, callback) table.insert(pending, callback) end }
SlashCmdList = {}
addon.InitializeDatabase = function(self) self.db = { settings = { showOnLogin = true } } end
addon.RegisterSettingsUI = function() end
addon.CheckWeeklyReset = function() end
addon.RegisterCharacter = function() end
addon.RefreshWindow = function() end
assert(loadfile('TrackerFrame.lua'))('Slashik7MilTodoList', addon)
addon.RefreshWindow = function() end
addon.CreateWindow = function(self)
  created = created + 1
  self.window = { Show = function() shown = true end, IsShown = function() return shown end }
end
assert(loadfile('Slashik7MilTodoList.lua'))('Slashik7MilTodoList', addon)
local function emit(event, a, b) handler(nil, event, a, b) end
local function flush() for _, callback in ipairs(pending) do callback() end; pending = {} end
emit('ADDON_LOADED', 'Slashik7MilTodoList')
emit('PLAYER_LOGIN')
assert(not shown and #pending == 0, 'do not open during early login')
emit('PLAYER_ENTERING_WORLD', true, false)
assert(not shown and #pending == 1)
flush()
assert(shown and created == 1, 'open after initial world entry')
shown = false
emit('PLAYER_ENTERING_WORLD', false, false)
flush()
assert(not shown, 'zone transitions must not reopen window')
emit('PLAYER_ENTERING_WORLD', false, true)
flush()
assert(shown, 'UI reload opens window')
emit('PLAYER_ENTERING_WORLD', true, false)
flush()
assert(shown and created == 1, 'show is idempotent')
shown = false
addon.db.settings.showOnLogin = false
emit('PLAYER_ENTERING_WORLD', true, false)
flush()
assert(not shown, 'disabled setting is respected')
print('PASS: initial login, reload, deferred opening, zone transitions, repeated show, disabled setting')
