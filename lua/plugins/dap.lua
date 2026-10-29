-- Debug-Oberfläche (dap-ui) erst öffnen, wenn das Programm an einem Haltepunkt
-- anhält, nicht schon bei jedem Start (Ausnahme: Konsole bei main, siehe unten).
-- Java-Tests (Leertaste t t / t r) laufen immer über den Debugger: Mit dem
-- LazyVim-Standard ging die Oberfläche bei jedem Testlauf auf und wieder zu,
-- das Layout sprang hin und her.
-- `config` ersetzt die von LazyVim (extras.dap.core), deshalb setup hier selbst.
-- Seitenleiste rechts statt links: Links neben dem Explorer erbte dieser beim
-- Schliessen ihren Platz und wurde bei jedem Lauf breiter (40 → 81 Spalten).
return {
  {
    "rcarriga/nvim-dap-ui",
    -- dapui.toggle() schaltet jeden Teil einzeln um: War nur die Konsole offen,
    -- ging sie zu und die Seitenleiste auf. Hier: etwas offen → alles zu.
    keys = {
      {
        "<leader>du",
        function()
          local dapui = require("dapui")
          for _, layout in ipairs(require("dapui.windows").layouts) do
            if layout:is_open() then
              return dapui.close({})
            end
          end
          dapui.open({})
        end,
        desc = "Dap UI",
      },
    },
    opts = {
      layouts = {
        {
          elements = {
            { id = "scopes", size = 0.25 },
            { id = "breakpoints", size = 0.25 },
            { id = "stacks", size = 0.25 },
            { id = "watches", size = 0.25 },
          },
          size = 40,
          position = "right",
        },
        {
          elements = {
            { id = "repl", size = 0.5 },
            { id = "console", size = 0.5 },
          },
          size = 10,
          position = "bottom",
        },
      },
    },
    config = function(_, opts)
      local dap = require("dap")
      local dapui = require("dapui")
      dapui.setup(opts)
      -- main-Methode (Leertaste d c): jdtls startet sie mit console =
      -- "integratedTerminal", die Ausgabe landet in der Konsole von dap-ui.
      -- Die gleich unten öffnen und nach Programmende offen lassen, sonst ist die
      -- Ausgabe weg, bevor man sie lesen kann. Tests haben kein console-Feld.
      local function ist_programm(session)
        return session and session.config and session.config.console == "integratedTerminal"
      end
      dap.listeners.after.event_initialized["dapui_config"] = function(session)
        if ist_programm(session) then
          dapui.open({ layout = 2 })
        end
      end
      dap.listeners.after.event_stopped["dapui_config"] = function()
        dapui.open({})
      end
      -- Nach Programmende stand das Konsolenfenster nach unten gescrollt (leere
      -- Zeilen des Terminals), die Ausgabe oben war nicht zu sehen. Deshalb so
      -- scrollen, dass die letzte Zeile mit Text unten im Fenster steht.
      local function konsole_zeigen()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].filetype == "dapui_console" then
            local zeilen = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            local letzte = #zeilen
            while letzte > 1 and zeilen[letzte]:match("^%s*$") do
              letzte = letzte - 1
            end
            local hoehe = vim.api.nvim_win_get_height(win)
            vim.api.nvim_win_call(win, function()
              vim.fn.winrestview({ topline = math.max(1, letzte - hoehe + 1), lnum = letzte })
            end)
          end
        end
      end
      local function schliessen(session)
        if ist_programm(session) then
          dapui.close({ layout = 1 })
          vim.defer_fn(konsole_zeigen, 300)
        else
          dapui.close({})
        end
      end
      dap.listeners.before.event_terminated["dapui_config"] = schliessen
      dap.listeners.before.event_exited["dapui_config"] = schliessen

      -- Leertaste d t beendet nur die Debug-Verbindung, das Programm im
      -- Konsolen-Terminal lief weiter (Spring: Port blieb belegt, der nächste
      -- Start brach ab mit "jobstart … requires unmodified buffer"). Der
      -- Java-Debugger kennt kein "terminate", nvim-dap trennt nur (disconnect),
      -- ein terminated-Ereignis kommt dann nicht. Deshalb nach disconnect und
      -- am Ende jeder Sitzung das Programm in der Konsole stoppen. War es schon
      -- fertig, passiert nichts.
      local function konsole_stoppen()
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          local job = vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "dapui_console" and vim.b[buf].terminal_job_id
          if job and vim.fn.jobwait({ job }, 0)[1] == -1 then
            vim.fn.jobstop(job)
          end
        end
      end
      dap.listeners.after.disconnect["konsole_stoppen"] = konsole_stoppen
      dap.listeners.after.event_terminated["konsole_stoppen"] = konsole_stoppen
    end,
  },
}
