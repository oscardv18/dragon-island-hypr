-- Consent and bounded restoration before loading the user's unchanged plugin specs.
local M = {}

local function warn(message)
  vim.notify("dragon-island Neovim: " .. message, vim.log.levels.WARN)
end

local function lock()
  local path = vim.fn.stdpath("config") .. "/lazy-lock.json"
  local text = table.concat(vim.fn.readfile(path), "\n")
  return vim.json.decode(text), vim.fn.sha256(text)
end

function M.ready(force)
  if vim.fn.has("nvim-0.12") == 0 or type(jit) ~= "table" then
    warn("Esta configuración requiere Neovim >= 0.12 con LuaJIT. Se abre sin plugins.")
    return false
  end
  if vim.env.DRAGON_NVIM_RESTORE == "1" then
    return true -- only the already-confirmed, time-limited child process
  end
  local ok, versions, digest = pcall(lock)
  if not ok then
    warn("No se puede leer lazy-lock.json; se abre sin plugins.")
    return false
  end
  local marker = vim.fn.stdpath("state") .. "/dragon-plugins-restored"
  local complete = true
  for name in pairs(versions) do
    if not vim.uv.fs_stat(vim.fn.stdpath("data") .. "/lazy/" .. name) then
      complete = false
      break
    end
  end
  if not force and complete and vim.fn.filereadable(marker) == 1 and vim.fn.readfile(marker)[1] == digest then
    return true
  end
  local approved = vim.env.DRAGON_NVIM_SYNC == "1"
  if not approved and #vim.api.nvim_list_uis() > 0 then
    approved = vim.fn.confirm("¿Restaurar los plugins del lockfile? Requiere red (máximo 180 s).", "&Sí\n&No", 2) == 1
  end
  if not approved then
    warn("Plugins pendientes; se abre sin plugins. Usa :DragonNvimRestore para confirmar y reintentar.")
    return false
  end
  if vim.fn.executable("git") == 0 or vim.fn.executable("timeout") == 0 then
    warn("Faltan git o timeout (coreutils). Instala las dependencias del módulo editor.")
    return false
  end
  local probe_ok, probe = pcall(function()
    return vim.system({ "timeout", "--kill-after=2s", "8s", "git", "ls-remote", "https://github.com/folke/lazy.nvim.git", "HEAD" }, { text = true }):wait()
  end)
  if not probe_ok or probe.code ~= 0 then
    warn("Sin acceso a GitHub: no se descargó nada. Reintenta con :DragonNvimRestore cuando tengas red.")
    return false
  end
  local restored, result = pcall(function()
    return vim.system({
      "timeout", "--kill-after=5s", "180s", vim.v.progpath, "--headless", "-u",
      vim.fn.stdpath("config") .. "/init.lua", "+Lazy! restore", "+qa",
    }, { text = true, env = { DRAGON_NVIM_RESTORE = "1" } }):wait()
  end)
  if not restored or result.code ~= 0 then
    warn("Restauración pendiente (fallo o tiempo agotado). Se abre sin plugins; :DragonNvimRestore reintenta.")
    return false
  end
  -- Do not claim success if a failed clone left a partial installation.
  for name in pairs(versions) do
    if not vim.uv.fs_stat(vim.fn.stdpath("data") .. "/lazy/" .. name) then
      warn("Faltan plugins tras restore. Se abre sin plugins; usa :DragonNvimRestore para reintentar.")
      return false
    end
  end
  vim.fn.mkdir(vim.fn.stdpath("state"), "p")
  vim.fn.writefile({ digest }, marker)
  return true
end

return M
