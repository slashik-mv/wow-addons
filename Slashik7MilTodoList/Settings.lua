local _, addon = ...

addon.defaults = { showOnLogin = false, lockWindow = false }
addon.tasks = {
  { id = "abundance", label = "Abundance\n20,000 points" },
  { id = "haranir", label = "Legends of\nthe Haranir" },
  { id = "liadrin", label = "Lady Liadrin\nWeekly task" },
  { id = "assignment1", label = "Special\nAssignment #1" },
  { id = "assignment2", label = "Special\nAssignment #2" },
}

function addon:InitializeDatabase()
  if type(Slashik7MilTodoListDB) ~= "table" then Slashik7MilTodoListDB = {} end
  self.db = Slashik7MilTodoListDB
  local db = self.db
  db.settings = db.settings or {}
  db.characters = db.characters or {}
  db.order = db.order or {}
  db.version = 1
  for key, value in pairs(self.defaults) do
    if db.settings[key] == nil then db.settings[key] = value end
  end
end
