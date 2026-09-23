-- tests/cwd_match_spec.lua
describe("clickaholic.cwd_match", function()
  local cwd_match

  before_each(function()
    package.loaded["clickaholic.cwd_match"] = nil
    cwd_match = require("clickaholic.cwd_match")
  end)

  it("matches when button_cwd is nil (global button)", function()
    assert.is_true(cwd_match.matches(nil, "/home/user/proj"))
  end)

  it("matches when button_cwd is an empty string (global button)", function()
    assert.is_true(cwd_match.matches("", "/home/user/proj"))
  end)

  it("matches when cwd equals button_cwd exactly", function()
    assert.is_true(cwd_match.matches("/home/user/proj", "/home/user/proj"))
  end)

  it("matches when cwd is a subdirectory of button_cwd", function()
    assert.is_true(cwd_match.matches("/home/user/proj", "/home/user/proj/apps/console"))
  end)

  it("does not match a sibling directory with a similar name", function()
    -- A plain string-prefix check would wrongly match "/home/user/proj-old"
    -- against a button scoped to "/home/user/proj".
    assert.is_false(cwd_match.matches("/home/user/proj", "/home/user/proj-old"))
  end)

  it("does not match an unrelated directory", function()
    assert.is_false(cwd_match.matches("/home/user/proj", "/home/user/other"))
  end)

  it("does not match a parent directory of button_cwd", function()
    assert.is_false(cwd_match.matches("/home/user/proj/apps/console", "/home/user/proj"))
  end)
end)
