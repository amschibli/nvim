-- Debug-Oberfläche (dap-ui) erst öffnen, wenn das Programm an einem Haltepunkt
-- anhält, nicht schon bei jedem Start. Java-Tests (Leertaste t t / t r) laufen
-- immer über den Debugger: Mit dem LazyVim-Standard ging die Oberfläche bei
-- jedem Testlauf auf und wieder zu, das Layout sprang hin und her.
-- `config` ersetzt die von LazyVim (extras.dap.core), deshalb setup hier selbst.
-- Seitenleiste rechts statt links: Links neben dem Explorer erbte dieser beim
-- Schliessen ihren Platz und wurde bei jedem Lauf breiter (40 → 81 Spalten).
return {
  {
    "rcarriga/nvim-dap-ui",
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
      dap.listeners.after.event_stopped["dapui_config"] = function()
        dapui.open({})
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close({})
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close({})
      end
    end,
  },
}
