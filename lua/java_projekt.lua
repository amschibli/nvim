-- Java: was zum Projekt gehört, nicht zur einzelnen Datei (Maven-Tests,
-- Spotless-Erkennung mit Zwischenspeicher pro Projekt). Aufgerufen aus
-- after/ftplugin/java.lua.

local M = {}

-- Java-Tests mit Maven statt mit dem Test-Runner von jdtls: Leertaste t m die
-- ganze Testklasse, Leertaste t M die Methode unter dem Cursor. Der Runner von
-- jdtls fand in AssertJ (assertj-core hat eine module-info.java) keine Tests
-- ("0 succeeded"), Maven schon. Baut nur das Modul der Datei und was es braucht
-- (-pl … -am), unten im Terminal. spotless.check.skip: Formatierung erst vor dem
-- PR prüfen, sonst bricht der Build bei jeder kleinen Änderung schon davor ab.
function M.maven_test(nur_methode)
  local datei = vim.api.nvim_buf_get_name(0)
  local root = vim.fs.root(datei, { "mvnw" })
  local modul = vim.fs.root(datei, { "pom.xml" })
  if not root or not modul then
    return vim.notify("Kein Maven-Projekt mit ./mvnw gefunden", vim.log.levels.WARN)
  end
  local test = vim.fn.expand("%:t:r")
  if nur_methode then
    local node = vim.treesitter.get_node()
    while node and node:type() ~= "method_declaration" do
      node = node:parent()
    end
    local name = node and node:field("name")[1]
    if not name then
      return vim.notify("Cursor steht in keiner Methode", vim.log.levels.WARN)
    end
    test = test .. "#" .. vim.treesitter.get_node_text(name, 0)
  end
  local cmd = "./mvnw -q test -Dtest=" .. test .. " -Dsurefire.failIfNoSpecifiedTests=false -Dspotless.check.skip=true"
  if modul ~= root then
    cmd = cmd .. " -pl " .. vim.fs.relpath(root, modul) .. " -am"
  end
  -- -q zeigt bei grünen Tests nichts an, darum am Schluss selbst melden
  cmd = cmd .. ' && echo "✓ grün: ' .. test .. '" || echo "✗ rot oder Fehler: ' .. test .. '"'
  vim.cmd("silent! wall")
  Snacks.terminal.open(cmd, { cwd = root, interactive = false, win = { position = "bottom", height = 0.35 } })
end

-- Projekte mit Spotless (z. B. AssertJ): nvim formatiert dort Java-Dateien
-- beim Speichern nicht. jdtls formatierte sonst nach eigenen Regeln halbe
-- Dateien um (25 Zeilen Diff für ein geändertes Wort), Leertaste u f half nur
-- bis zum Neustart. Formatiert wird dort mit ./mvnw spotless:apply; Leertaste
-- u F schaltet es für eine Datei trotzdem ein. Nur Java: Markdown, TS usw.
-- formatiert nvim weiter. Erkannt am Plugin (Maven: groupId/artifactId,
-- Gradle: Plugin-ID), nicht am Wort «spotless», das auch in Kommentaren steht.
local spotless_projekt = {}
function M.hat_spotless(root)
  if spotless_projekt[root] == nil then
    spotless_projekt[root] = false
    for _, name in ipairs({ "pom.xml", "build.gradle", "build.gradle.kts" }) do
      local datei = root .. "/" .. name
      if vim.fn.filereadable(datei) == 1 then
        local inhalt = table.concat(vim.fn.readfile(datei), "\n")
        if inhalt:find("com.diffplug.spotless", 1, true) or inhalt:find("spotless-maven-plugin", 1, true) then
          spotless_projekt[root] = true
        end
      end
    end
  end
  return spotless_projekt[root]
end

-- Eclipse-Formatter-Datei im Projekt (z. B. aus IntelliJ exportiert:
-- Settings → Editor → Code Style → Java → Zahnrad → Export → Eclipse XML
-- Profile). Liegt sie im Projektordner, formatiert jdtls genau danach,
-- sonst nach den Eclipse-Standardregeln. Gibt { pfad, tab, breite } oder nil:
-- tab = true (Tabs) / false (Leerzeichen), breite = Einrückung in Zeichen.
local formatter_namen = { "eclipse-formatter.xml", ".eclipse-formatter.xml" }
function M.formatter(root)
  if not root then
    return nil
  end
  for _, name in ipairs(formatter_namen) do
    local pfad = root .. "/" .. name
    if vim.fn.filereadable(pfad) == 1 then
      local inhalt = table.concat(vim.fn.readfile(pfad), "\n")
      local function wert(schluessel)
        return inhalt:match('id="org%.eclipse%.jdt%.core%.formatter%.' .. schluessel .. '"%s+value="([^"]*)"')
          or inhalt:match('value="([^"]*)"%s+id="org%.eclipse%.jdt%.core%.formatter%.' .. schluessel .. '"')
      end
      local zeichen = wert("tabulation%.char")
      local breite = tonumber(wert("indentation%.size") or "") or tonumber(wert("tabulation%.size") or "")
      return { pfad = pfad, tab = zeichen == "tab", breite = breite }
    end
  end
  return nil
end

return M
