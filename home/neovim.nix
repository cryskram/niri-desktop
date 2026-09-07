# Neovim — LazyVim (DEV_ENVIRONMENT §2, RICE §31)
# Starter from https://github.com/LazyVim/starter — bootstraps lazy.nvim.
# Keeps machine reproducible, project plugins stay in lazy/lazy-lock.
{ pkgs, lib, ... }:
{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    withNodeJs = true;
    withPython3 = true;
    withRuby = false;
    # Deps LazyVim expects globally (telescope, etc. will use these)
    extraPackages = with pkgs; [
      gcc # treesitter
      gnumake
      ripgrep
      fd
      fzf
      lazygit
      git
      curl
      wget
      unzip
      nodejs # for copilot/mason
      tree-sitter
    ];
    # Keep plugins minimal — LazyVim manages via lazy.nvim (lazy-lock.json per user)
    # We provide lazy.nvim as nix store path to avoid bootstrap curl in init.
    plugins = with pkgs.vimPlugins; [
      lazy-nvim
    ];
  };

  # LazyVim config — bootstrap + Storm touches
  xdg.configFile."nvim/init.lua".text = ''
    -- Managed by ~/niri-desktop/home/neovim.nix — LazyVim starter
    -- Bootstrap lazy.nvim from nix (fallback to git if not found)
    local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
    if not vim.loop.fs_stat(lazypath) then
      local nix_lazy = "${pkgs.vimPlugins.lazy-nvim}"
      if vim.loop.fs_stat(nix_lazy) then
        vim.opt.rtp:prepend(nix_lazy)
      else
        vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
        vim.opt.rtp:prepend(lazypath)
      end
    else
      vim.opt.rtp:prepend(lazypath)
    end

    vim.g.mapleader = " "
    vim.g.maplocalleader = "\\"

    require("lazy").setup({
      spec = {
        { "LazyVim/LazyVim", import = "lazyvim.plugins" },
        { import = "plugins" },
      },
      defaults = { lazy = false, version = false },
      install = { colorscheme = { "tokyonight", "habamax" } },
      checker = { enabled = false },
      performance = { rtp = { disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" } } },
    })
  '';

  # Minimal LazyVim overrides — keep Storm, ensure lazyvim.plugins loads
  xdg.configFile."nvim/lua/config/lazy.lua".text = ''
    return {
      defaults = { lazy = true },
      install = { colorscheme = { "tokyonight" } },
      checker = { enabled = false },
    }
  '';

  xdg.configFile."nvim/lua/plugins/tokyonight.lua".text = ''
    return {
      {
        "folke/tokyonight.nvim",
        opts = { style = "storm", transparent = false },
      },
    }
  '';

  # Ensure lua/plugins dir exists (user will get lazy-lock.json after first run)
  home.activation.ensureNvimPluginsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p $HOME/.config/nvim/lua/plugins
  '';
}
