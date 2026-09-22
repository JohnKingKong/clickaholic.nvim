# clickaholic.nvim

A highly configurable button bar for Neovim. Define buttons — an icon,
a label, or both, plus an action (a Vim command, a shell command, or a
Lua function) — and click them from a persistent bar at the top of
every window.

## Installation (lazy.nvim)

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

## Adding buttons interactively

Run `:Clickaholic` to open the button manager:

| Key | Action |
|---|---|
| `a` | Add a button |
| `e` / `<CR>` | Edit the selected button |
| `d` | Delete the selected button |
| `K` / `J` | Move the selected button up / down |
| `<C-e>` | Pick an icon (while editing the Icon field) |
| `<CR>` | Submit the form |
| `<Esc>` / `q` | Cancel the form, or close the window from the list |
| `?` | Toggle the full keybind legend |

Buttons added this way are saved to `stdpath('data')/clickaholic.json`
and survive restarts.

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
