-- Wird von install.sh aufgerufen:
--   nvim --headless "+luafile scripts/headless-setup.lua"
-- Installiert die Mason-Pakete aus mason.txt und die Treesitter-Parser
-- von LazyVim, damit der erste normale Start nicht mehr warten muss.
-- Beendet Neovim selbst (Exit-Code 1, wenn etwas fehlt).

local function say(s)
  io.stdout:write(s .. "\n")
end

local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local fehler = {}

-- 1. Mason --------------------------------------------------------------
local liste = {}
for zeile in io.lines(repo .. "/mason.txt") do
  zeile = vim.trim((zeile:gsub("#.*", "")))
  if zeile ~= "" then
    liste[#liste + 1] = zeile
  end
end
-- Treesitter braucht die tree-sitter-CLI. Fehlt sie im System (Debian),
-- kommt sie aus Mason, wie es LazyVim beim normalen Start auch täte.
if vim.fn.executable("tree-sitter") == 0 then
  liste[#liste + 1] = "tree-sitter-cli"
end

-- Lädt auch die LazyVim-Konfiguration von mason.nvim, die ihrerseits
-- schon Pakete installiert. Deshalb unten nie ein zweites install()
-- auf ein Paket, das gerade installiert wird.
require("lazy").load({ plugins = { "mason.nvim" } })
local mr = require("mason-registry")

local bereit = false
mr.refresh(function()
  bereit = true
end)
if not vim.wait(300000, function() return bereit end, 200) then
  say("FEHLER: Mason-Registry nicht geladen (Internet?)")
  vim.cmd("cquit 1")
end

local gescheitert = {}
mr:on("package:install:failed", function(pkg)
  gescheitert[pkg.name] = true
end)

local pakete = {}
for _, name in ipairs(liste) do
  local ok, pkg = pcall(mr.get_package, name)
  if not ok then
    fehler[#fehler + 1] = "Mason kennt " .. name .. " nicht"
  else
    pakete[#pakete + 1] = pkg
    if not pkg:is_installed() and not pkg:is_installing() then
      pkg:install()
    end
  end
end

-- Den Paketordner gibt es schon vor dem Ende der Installation (danach
-- folgen noch Links und Receipt). Erst fertig, wenn nicht mehr installing,
-- sonst bricht das Beenden von Neovim die Installation ab und Mason
-- löscht das Paket wieder.
local gemeldet = {}
local function mason_fertig()
  local alle = true
  for _, pkg in ipairs(pakete) do
    if pkg:is_installing() then
      alle = false
    elseif pkg:is_installed() then
      if not gemeldet[pkg.name] then
        gemeldet[pkg.name] = true
        say("  Mason: " .. pkg.name)
      end
    elseif not gescheitert[pkg.name] then
      alle = false
    end
  end
  return alle
end
say("Mason: " .. #pakete .. " Pakete …")
vim.wait(1800000, mason_fertig, 500)
for _, pkg in ipairs(pakete) do
  if not pkg:is_installed() then
    fehler[#fehler + 1] = "Mason-Paket " .. pkg.name .. " nicht installiert"
  end
end

-- 2. Treesitter ---------------------------------------------------------
-- Laden startet die Installation von LazyVim; TS.install wartet auf
-- Parser, die gerade schon gebaut werden, statt sie doppelt zu bauen.
require("lazy").load({ plugins = { "nvim-treesitter" } })
if vim.fn.executable("tree-sitter") == 0 then
  fehler[#fehler + 1] = "tree-sitter-CLI fehlt, keine Parser gebaut"
else
  local TS = require("nvim-treesitter")
  local verfuegbar = {}
  for _, l in ipairs(TS.get_available()) do
    verfuegbar[l] = true
  end
  local soll = vim.tbl_filter(function(l)
    return verfuegbar[l]
  end, LazyVim.opts("nvim-treesitter").ensure_installed or {})
  say("Treesitter: " .. #soll .. " Parser …")
  local ok, erfolg = pcall(function()
    return TS.install(soll):wait(900000)
  end)
  local da = {}
  for _, l in ipairs(TS.get_installed()) do
    da[l] = true
  end
  for _, l in ipairs(soll) do
    if not da[l] then
      fehler[#fehler + 1] = "Treesitter-Parser " .. l .. " fehlt"
    end
  end
  if not ok or not erfolg then
    say("  Treesitter meldete Fehler: " .. tostring(erfolg))
  end
end

-- Ergebnis --------------------------------------------------------------
if #fehler > 0 then
  say("")
  for _, f in ipairs(fehler) do
    say("FEHLER: " .. f)
  end
  vim.cmd("cquit 1")
end
-- Auch Installationen abwarten, die Plugins selbst gestartet haben
local function keine_installation()
  for _, pkg in ipairs(mr.get_all_packages()) do
    if pkg:is_installing() then
      return false
    end
  end
  return true
end
vim.wait(600000, keine_installation, 500)

say("Mason und Treesitter vollständig.")
vim.cmd("qall!")
