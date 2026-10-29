-- Java (jdtls): statische Imports für Test-Bibliotheken.
-- jdtls schlägt statische Methoden (mock, when, assertEquals, …) nur vor,
-- wenn ihre Klasse hier als Favorit steht. Dann gehen Autovervollständigung
-- und <leader>ca "Add static import".
-- Nur `opts` setzen: LazyVim führt die Tabellen zusammen, `config`/`init` würden ersetzt.
return {
  -- LazyVim legt "Debug (Attach) - Remote" als erste Debug-Konfiguration an
  -- (an ein laufendes Programm mit Port 5005 anhängen, hier nie gebraucht).
  -- Stand bei Leertaste d c zuoberst und wurde aus Versehen gewählt. Leeren,
  -- jdtls ergänzt danach die "Launch …"-Einträge für alle main-Klassen.
  {
    "mfussenegger/nvim-dap",
    opts = function()
      require("dap").configurations.java = {}
    end,
  },
  {
    "mfussenegger/nvim-jdtls",
    opts = {
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
        },
      },
    },
  },
}
