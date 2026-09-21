-- tests/store_spec.lua
describe("clickaholic.store", function()
  local store
  local path

  before_each(function()
    package.loaded["clickaholic.store"] = nil
    store = require("clickaholic.store")
    path = vim.fn.tempname() .. ".json"
  end)

  after_each(function()
    vim.fn.delete(path)
  end)

  describe("load", function()
    it("returns an empty list when the file doesn't exist", function()
      assert.are.same({}, store.load(path))
    end)

    it("warns once and returns an empty list for corrupt JSON", function()
      vim.fn.writefile({ "not json" }, path)
      local warned
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        warned = { msg = msg, level = level }
      end
      local result = store.load(path)
      vim.notify = original_notify
      assert.are.same({}, result)
      assert.is_not_nil(warned)
      assert.are.equal(vim.log.levels.WARN, warned.level)
    end)
  end)

  describe("save/load round-trip", function()
    it("persists and reloads buttons with source tagged", function()
      store.save(path, {
        { label = "Test", icon = "🧪", action_type = "shell", action = "npm test" },
      })
      local loaded = store.load(path)
      assert.are.equal(1, #loaded)
      assert.are.equal("Test", loaded[1].label)
      assert.are.equal("stored", loaded[1].source)
    end)
  end)

  describe("add", function()
    it("appends a button and persists it", function()
      store.add(path, { label = "One", icon = "1", action_type = "cmd", action = ":echo 1" })
      local result = store.add(path, { label = "Two", icon = "2", action_type = "cmd", action = ":echo 2" })
      assert.are.equal(2, #result)
      assert.are.equal("Two", result[2].label)
      assert.are.equal(2, #store.load(path))
    end)
  end)

  describe("update", function()
    it("replaces the entry at the given index", function()
      store.add(path, { label = "Old", icon = "1", action_type = "cmd", action = ":echo 1" })
      local result = store.update(path, 1, { label = "New", icon = "1", action_type = "cmd", action = ":echo 1" })
      assert.are.equal("New", result[1].label)
      assert.are.equal("New", store.load(path)[1].label)
    end)
  end)

  describe("remove", function()
    it("removes the entry at the given index", function()
      store.add(path, { label = "One", icon = "1", action_type = "cmd", action = ":echo 1" })
      store.add(path, { label = "Two", icon = "2", action_type = "cmd", action = ":echo 2" })
      local result = store.remove(path, 1)
      assert.are.equal(1, #result)
      assert.are.equal("Two", result[1].label)
    end)
  end)

  describe("move", function()
    it("swaps with the next entry when moving down", function()
      store.add(path, { label = "One", icon = "1", action_type = "cmd", action = ":echo 1" })
      store.add(path, { label = "Two", icon = "2", action_type = "cmd", action = ":echo 2" })
      local result = store.move(path, 1, "down")
      assert.are.equal("Two", result[1].label)
      assert.are.equal("One", result[2].label)
    end)

    it("is a no-op moving the first entry up", function()
      store.add(path, { label = "One", icon = "1", action_type = "cmd", action = ":echo 1" })
      local result = store.move(path, 1, "up")
      assert.are.equal("One", result[1].label)
    end)

    it("is a no-op moving the last entry down", function()
      store.add(path, { label = "One", icon = "1", action_type = "cmd", action = ":echo 1" })
      local result = store.move(path, 1, "down")
      assert.are.equal("One", result[1].label)
    end)
  end)
end)
