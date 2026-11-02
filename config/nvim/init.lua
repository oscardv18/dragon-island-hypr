-- The user's plugin configuration is loaded only after a confirmed first-use restore.
local first_use = require("config.dragon_first_use")
vim.api.nvim_create_user_command("DragonNvimRestore", function()
  if first_use.ready(true) then
    require("config.lazy")
  end
end, { desc = "Confirmar y restaurar los plugins fijados (máximo 180 s)", force = true })
if first_use.ready() then
  require("config.lazy")
end
