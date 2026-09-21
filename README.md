# clickaholic.nvim

A highly configurable button bar for Neovim. Define buttons — icon,
label, and an action (a Vim command, a shell command, or a Lua function)
— and click them from a persistent bar at the top of every window.

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

Run `:Clickaholic` to open the button manager: `a` to add, `e`/`<CR>` to
edit, `d` to delete, `K`/`J` to reorder. Buttons added this way are saved
to `stdpath('data')/clickaholic.json` and survive restarts.

Buttons defined in `setup()` with `action_type = "lua"` can run any Lua
function, but can only be changed by editing your config — a function
can't be saved to disk, so the manager only offers `cmd`/`shell` types.

## Commands

| Command | Action |
|---|---|
| `:Clickaholic` | Open the button manager |
| `:ClickaholicOutput` | Show the last shell button's full output |

## License

MIT
