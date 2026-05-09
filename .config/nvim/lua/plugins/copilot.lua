return {
  "github/copilot.vim",
  lazy = false,
  init = function()
    -- Force copilot.vim to use the language-server that ships with the
    -- plugin (currently 1.408.0) instead of npx-installing the newest
    -- one. The latest 1.485.0 + Node 24+ combo trips a JsonParseError
    -- ("Response content-type is missing") inside Device Flow stage 1
    -- — the bundled version doesn't.
    local bundled = vim.fn.stdpath("data")
      .. "/lazy/copilot.vim/copilot-language-server/dist/language-server.js"
    if vim.fn.filereadable(bundled) == 1 then
      vim.g.copilot_command = { "node", bundled, "--stdio" }
    end
  end,
}
