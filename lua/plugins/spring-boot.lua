-- Spring Boot (spring-boot.nvim): der Spring Boot Language Server aus VS Code.
-- - application.properties / application.yml: Vervollständigung, Doku beim
--   Hovern, Sprung zur @ConfigurationProperties-Klasse, Fehler bei falschen Keys
-- - Java: Code Actions und Hinweise zu Spring-Annotationen
-- - :SpringBoot → Beans, Endpoints (@GetMapping …), Annotationen suchen
-- Läuft nur in Projekten mit Spring Boot im pom.xml / build.gradle, in
-- normalen Java-Übungen startet nichts.
return {
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "vscode-spring-boot-tools" } },
  },
  {
    "JavaHello/spring-boot.nvim",
    ft = { "java", "yaml", "jproperties" },
    dependencies = { "mfussenegger/nvim-jdtls" },
    opts = {
      project_filter = function(root_dir)
        return require("spring_boot.util").has_spring_boot_dependency(root_dir)
      end,
      -- Inlay Hints (graue Parameternamen wie "body:") nur von jdtls. Liefern
      -- zwei Server welche, behält Neovim 0.12 die Hints des langsameren aus
      -- einer älteren Fassung der Datei. Nach Zeilen zusammenfügen o. ä.
      -- stehen die dann hinter dem Zeilenende: "Decoration provider win …
      -- inlay_hint.lua:362: Invalid 'col': out of range" bei jedem Neuzeichnen.
      -- Spring Boot zeigt Hints nur bei @Scheduled-Cron-Ausdrücken.
      server = {
        handlers = { ["textDocument/inlayHint"] = function() end },
      },
    },
  },
  -- Die Java-Seite läuft als Erweiterung in jdtls: dessen Jars kommen zu den
  -- Bundles (Debugger, Tests) dazu, die LazyVim schon übergibt. jdtls nimmt
  -- Bundles nur beim Start an, deshalb hier und nicht später.
  -- opts.jdtls aus java.lua (Tabelle) bleibt erhalten, darum herum gewickelt.
  {
    "mfussenegger/nvim-jdtls",
    opts = function(_, opts)
      local vorher = opts.jdtls
      opts.jdtls = function(config)
        if type(vorher) == "function" then
          config = vorher(config) or config
        elseif type(vorher) == "table" then
          config = vim.tbl_deep_extend("force", config, vorher)
        end
        local ok, spring_boot = pcall(require, "spring_boot")
        if ok then
          config.init_options = config.init_options or {}
          config.init_options.bundles = config.init_options.bundles or {}
          vim.list_extend(config.init_options.bundles, spring_boot.java_extensions())
        end
        return config
      end
    end,
  },
}
