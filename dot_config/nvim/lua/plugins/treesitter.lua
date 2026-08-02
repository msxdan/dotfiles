-- nvim-treesitter rewrote its API on `main` and archived `master`: there is no
-- configs module or setup() anymore. Parsers are installed explicitly and
-- highlight/indent are enabled per buffer through core Neovim.
-- Needs nvim 0.11+ and the tree-sitter CLI (pacman: tree-sitter-cli).
return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter").install({
      "lua", "javascript", "yaml", "bash", "terraform", "python",
      "markdown", "markdown_inline",
    })
    vim.api.nvim_create_autocmd("FileType", {
      pattern = {
        "lua", "javascript", "yaml", "sh", "bash", "terraform", "python",
        "markdown",
      },
      callback = function(ev)
        -- pcall: the parser may not be compiled yet on a fresh machine while
        -- install() is still running in the background.
        if pcall(vim.treesitter.start, ev.buf) then
          vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end,
}
