-- Java (jdtls): statische Imports für Test-Bibliotheken.
-- jdtls schlägt statische Methoden (mock, when, assertEquals, …) nur vor,
-- wenn ihre Klasse hier als Favorit steht. Dann gehen Autovervollständigung
-- und <leader>ca "Add static import".
-- Nur `opts` setzen: LazyVim führt die Tabellen zusammen, `config`/`init` würden ersetzt.
return {
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
