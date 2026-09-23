# clickaholic.nvim

A highly configurable button bar for Neovim. Define buttons — an icon,
a label, or both, plus an action (a Vim command, a shell command, or a
Lua function) — and click them.

## Installation (lazy.nvim)

Zero config required — by default clickaholic renders into
`vim.o.winbar`, so it works out of the box with no other plugins:

```lua
return {
  "johnkingkong/clickaholic.nvim",
  event = "VeryLazy",
  opts = {
    buttons = {
      { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope find_files" },
      { label = "Test", icon = "🧪", action_type = "shell", action = "npm test" },
    },
  },
}
```

## Renderers

`opts.renderer` picks where the buttons are drawn:

| `renderer` | Surface | Requires | Notes |
|---|---|---|---|
| `"winbar"` (default) | `vim.o.winbar` | nothing | Per-window, top of the editor. Duplicates once per split — the simplest option and the zero-config default. |
| `"tabline"` | `vim.o.tabline` | [bufferline.nvim](https://github.com/akinsho/bufferline.nvim) | Genuinely single instance across the whole editor, top of the editor. Plugs into bufferline's `custom_areas` extension point. |
| `"lualine"` | `vim.o.statusline` | [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim) | Genuinely single instance, bottom of the editor. Adds one lualine component per button. |
| `"none"` | — | — | Disables rendering; call `require("clickaholic").apply_renderer()` yourself if you're building a custom integration. |

### `"tabline"` (bufferline.nvim)

```lua
return {
  "johnkingkong/clickaholic.nvim",
  event = "VeryLazy",
  opts = {
    renderer = "tabline",
    buttons = { --[[ ... ]] },
  },
}
```

Then wire clickaholic into your own bufferline config's
`options.custom_areas`:

```lua
return {
  "akinsho/bufferline.nvim",
  opts = {
    options = {
      custom_areas = {
        right = function()
          return require("clickaholic.tabline").custom_area()
        end,
      },
    },
  },
}
```

### `"lualine"` (lualine.nvim)

```lua
return {
  "johnkingkong/clickaholic.nvim",
  event = "VeryLazy",
  opts = {
    renderer = "lualine",
    buttons = { --[[ ... ]] },
  },
}
```

lualine.nvim doesn't have an extension point that auto-refreshes, so your
own lualine config needs to merge clickaholic's components in and
re-`setup()` whenever they change:

```lua
return {
  "nvim-lualine/lualine.nvim",
  config = function(_, opts)
    local base_x = vim.deepcopy(opts.sections.lualine_x or {})
    local function refresh()
      opts.sections.lualine_x = vim.list_extend(vim.deepcopy(base_x), require("clickaholic.lualine").components())
      require("lualine").setup(opts)
    end
    require("lualine").setup(opts)
    vim.schedule(refresh)
    vim.api.nvim_create_autocmd("User", { pattern = "ClickaholicButtonsChanged", callback = refresh })
  end,
}
```

## Scoping a button to a directory

Add `cwd` to a button to only show it when the current directory is that
path or a subdirectory of it — buttons with no `cwd` are global and
always show:

```lua
buttons = {
  { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope find_files" }, -- global
  {
    label = "Console",
    icon = "🚀",
    action_type = "cmd",
    action = "botright split | terminal cd ~/proj/apps/console && pnpm run start",
    cwd = vim.fn.expand("~/proj"), -- only shows inside ~/proj (or a subdirectory)
  },
}
```

## Adding buttons interactively

Run `:Clickaholic` to open the button manager:

| Key | Action |
|---|---|
| `a` | Add a button |
| `e` / `<CR>` | Edit the selected button |
| `d` | Delete the selected button |
| `K` / `J` | Move the selected button up / down |
| `<C-e>` | Pick an icon (while editing the Icon field) |
| `<C-l>` | Link the Cwd field to the current directory |
| `<CR>` | Submit the form |
| `<Esc>` / `q` | Cancel the form, or close the window from the list |
| `?` | Toggle the full keybind legend |

Buttons added this way are saved to `stdpath('data')/clickaholic.json`
and survive restarts. The form's Cwd field works the same as `opts.buttons`'
`cwd` (see [Scoping a button to a directory](#scoping-a-button-to-a-directory)
above) — leave it blank for a global button, or press `<C-l>` to fill it
in with wherever you currently are.

Buttons defined in `setup()` with `action_type = "lua"` can run any Lua
function, but can only be changed by editing your config — a function
can't be saved to disk, so the manager only offers `cmd`/`shell` types.

Icon and label are each optional — leave either field blank for an
icon-only or text-only button — but at least one of the two is
required.

### Picking an icon

While editing a button's Icon field, press `<C-e>` to browse a curated
set of common emoji in a small popup. Use Neovim's own `/` search to
filter (e.g. `/rocket<CR>`), `j`/`k` to move, `<CR>` to pick, `<Esc>`/`q`
to cancel.

## Commands

| Command | Action |
|---|---|
| `:Clickaholic` | Open the button manager |
| `:ClickaholicOutput` | Show the last shell button's full output |

## License

MIT
