-- ~/.config/nvim/lua/plugins/extras.lua

return {

  -- VSCode integration
  { import = "lazyvim.plugins.extras.vscode" },

  -- Utilitários
  { import = "lazyvim.plugins.extras.util.dot" },
  { import = "lazyvim.plugins.extras.util.mini-hipatterns" },

  -- Linguagens
  { import = "lazyvim.plugins.extras.lang.java" },
  { import = "lazyvim.plugins.extras.lang.python" },
  { import = "lazyvim.plugins.extras.lang.sql" },
  { import = "lazyvim.plugins.extras.lang.json" },
}
