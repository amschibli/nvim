-- Frontend (React/Vite mit CSS und CSS Modules), ergänzt das Extra
-- lang.typescript. Mason installiert die Server beim ersten Start selbst.
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "css", "scss" } },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- CSS: Vervollständigung von Eigenschaften/Werten, Fehler
        cssls = {},
        -- index.html
        html = {},
        -- CSS Modules: in TSX bei styles.container mit g d zur Klasse in
        -- *.module.css springen, Vorschläge für Klassennamen
        cssmodules_ls = {},
      },
    },
  },
}
