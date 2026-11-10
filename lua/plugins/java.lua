-- Java (jdtls): statische Imports für Test-Bibliotheken.
-- jdtls schlägt statische Methoden (mock, when, assertEquals, …) nur vor,
-- wenn ihre Klasse hier als Favorit steht. Dann gehen Autovervollständigung
-- und <leader>ca "Add static import".
-- Nur `opts` setzen: LazyVim führt die Tabellen zusammen, `config`/`init` würden ersetzt.

-- Java-Tests (Leertaste t t / t r): danach unten die Fehlerliste (Trouble) mit
-- den roten Tests öffnen, sind alle grün, wieder schliessen. Der Fokus bleibt
-- im Code. Gleiche Tasten wie LazyVim (extras.lang.java), nur mit after_test.
local function java_test_liste(items)
  local trouble = require("trouble")
  if items and #items > 0 then
    trouble.open({ mode = "qflist", focus = false })
    trouble.refresh({ mode = "qflist" })
  else
    trouble.close({ mode = "qflist" })
  end
end

-- Leertaste d c: main-Methode der aktuellen Datei direkt starten, ohne
-- Auswahlliste. Die main-Klassen vorher neu suchen: LazyVim tut das nur
-- beim Start von jdtls, neue Klassen fehlten sonst bis :JdtWipeDataAndRestart.
-- Läuft schon ein Debug-Lauf: weiter wie gewohnt. Keine main in der Datei:
-- Auswahlliste (z. B. Spring-App starten, Haltepunkt im Controller).
local function main_starten(client, buf)
  local jdap = require("jdtls.dap")
  local dap = require("dap")
  if dap.session() then
    return dap.continue()
  end
  local paket
  for _, zeile in ipairs(vim.api.nvim_buf_get_lines(0, 0, 50, false)) do
    paket = zeile:match("^%s*package%s+([%w_%.]+)%s*;")
    if paket then
      break
    end
  end
  local klasse = vim.fn.expand("%:t:r")
  klasse = paket and (paket .. "." .. klasse) or klasse
  local function starten()
    jdap.setup_dap_main_class_configs({
      on_ready = vim.schedule_wrap(function()
        for _, config in ipairs(dap.configurations.java or {}) do
          if config.mainClass == klasse then
            return dap.run(config)
          end
        end
        dap.continue()
      end),
    })
  end
  -- Vorher kompilieren: Eine eben gespeicherte neue Klasse gab sonst
  -- "Hauptklasse … konnte nicht gefunden werden". Fehler in anderen
  -- Dateien stören nicht, gestartet wird trotzdem.
  -- Altes Programm in der Konsole (z. B. eben mit Leertaste d t beendet)
  -- erst ganz fertig werden lassen, sonst bricht der Start ab mit
  -- "jobstart … requires unmodified buffer".
  for _, konsole in ipairs(vim.api.nvim_list_bufs()) do
    local job = vim.bo[konsole].filetype == "dapui_console" and vim.b[konsole].terminal_job_id
    if job and vim.fn.jobwait({ job }, 0)[1] == -1 then
      vim.fn.jobstop(job)
      vim.fn.jobwait({ job }, 10000)
    end
  end
  vim.notify("Kompiliere und suche main-Klassen …")
  client:request("java/buildWorkspace", false, function()
    vim.schedule(starten)
  end, buf)
end

-- Eigene Tasten für Java-Puffer. LazyVim ruft opts.on_attach am Ende seines
-- LspAttach auf, nach seinen eigenen Tasten (which-key setzt sie sofort):
-- gleiche Tasten werden hier also sicher überschrieben.
local function on_attach(args)
  local client = vim.lsp.get_client_by_id(args.data.client_id)
  local buf = args.buf
  local jdap = require("jdtls.dap")
  vim.keymap.set("n", "<leader>tt", function()
    jdap.test_class({ after_test = java_test_liste })
  end, { buffer = buf, desc = "Run All Test" })
  vim.keymap.set("n", "<leader>tr", function()
    jdap.test_nearest_method({ after_test = java_test_liste })
  end, { buffer = buf, desc = "Run Nearest Test" })
  vim.keymap.set("n", "<leader>dc", function()
    main_starten(client, buf)
  end, { buffer = buf, desc = "Run/Continue (main der Datei)" })
end

return {
  -- LazyVim legt "Debug (Attach) - Remote" als erste Debug-Konfiguration an
  -- (an ein laufendes Programm mit Port 5005 anhängen, hier nie gebraucht).
  -- Stand bei Leertaste d c zuoberst und wurde aus Versehen gewählt. Leeren,
  -- jdtls ergänzt danach die "Launch …"-Einträge für alle main-Klassen.
  -- Absichtlich in opts, nicht in config: LazyVim legt den Eintrag selbst in
  -- einer opts-Funktion an (diese läuft danach). Ein eigenes config würde das
  -- config von dap.core ersetzen (Haltepunkt-Symbole, launch.json).
  {
    "mfussenegger/nvim-dap",
    opts = function()
      require("dap").configurations.java = {}
    end,
  },
  {
    "mfussenegger/nvim-jdtls",
    opts = {
      -- main-Klassen nicht schon beim Start suchen: jdtls hat das Projekt dann
      -- noch nicht fertig eingelesen ("Could not resolve java executable /
      -- classpath"). Leertaste d c sucht selbst (main_starten oben).
      dap_main = false,
      on_attach = on_attach,
      -- Als Funktion, damit die Config pro Projekt (root_dir) angepasst werden
      -- kann. tbl_deep_extend legt neue Tabellen an: opts.settings gilt für alle
      -- Projekte und darf nicht verändert werden.
      jdtls = function(config)
        -- Datei umbenennen im Explorer (r): jdtls soll die Klasse mit umbenennen.
        -- Ohne diese Angabe fragt snacks jdtls gar nicht erst.
        config = vim.tbl_deep_extend("force", config, {
          capabilities = {
            workspace = { fileOperations = { willRename = true, didRename = true } },
          },
        })
        -- Eigene Formatter-Datei im Projekt (eclipse-formatter.xml, z. B. aus
        -- IntelliJ exportiert): jdtls formatiert dann genau danach, gleich wie
        -- IntelliJ/Eclipse im Team. Siehe lua/java_projekt.lua.
        local formatter = require("java_projekt").formatter(config.root_dir)
        if formatter then
          config.settings = vim.tbl_deep_extend("force", config.settings or {}, {
            java = { format = { settings = { url = formatter.pfad } } },
          })
        end
        return config
      end,
      settings = {
        java = {
          completion = {
            favoriteStaticMembers = {
              "org.junit.jupiter.api.Assertions.*",
              "org.mockito.Mockito.*",
              "org.mockito.ArgumentMatchers.*",
              "org.hamcrest.Matchers.*",
              "org.assertj.core.api.Assertions.*",
            },
          },
          -- Generate toString(): Klammern wie IntelliJ (Person{a=1, b=2}) statt
          -- Eclipse (Person [a=1, b=2]). Die '…' nur um Strings kann die
          -- Eclipse-Vorlage nicht, die von Hand ergänzen.
          codeGeneration = {
            toString = {
              template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
            },
          },
        },
      },
    },
  },
}
