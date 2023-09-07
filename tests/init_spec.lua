local async = require("nio").tests
local Tree = require("neotest.types").Tree
local plugin = require("neotest-foundry")({})

describe("adapter enabled", function()
  async.it("enable adapter", function()
    assert.Not.Nil(plugin.root("./spec"))
  end)

  async.it("disable adapter", function()
    assert.Nil(plugin.root("./spec-nofoundry"))
  end)
end)

describe("is_test_file", function()
  it("matches foundry test files", function()
    assert.True(plugin.is_test_file("./spec/test/Counter.t.sol"))
  end)

  it("does not match plain solidity files", function()
    assert.False(plugin.is_test_file("./spec/test/Counter.sol"))
  end)

  it("does not match file name ending with test", function()
    assert.False(plugin.is_test_file("./setup_test.ts"))
  end)
end)

describe("discover_positions", function()
  async.it("provides meaningful names from a basic spec", function()
    local positions = plugin.discover_positions("./spec/test/Counter.t.sol"):to_list()

    local expected_output = {
      {
        name = "Counter.t.sol",
        type = "file",
      },
      {
        {
          name = "CounterTest",
          type = "namespace",
        },
        {
          {
            name = "testIncrement",
            type = "test",
          },
          {
            name = "testSetNumber",
            type = "test",
          },
        },
      },
    }

    assert.equals(expected_output[1].type, positions[1].type)
    assert.equals(expected_output[2][1].name, positions[2][1].name)
    assert.equals(expected_output[2][1].type, positions[2][1].type)

    assert.equals(3, #positions[2])
    for i, value in ipairs(expected_output[2][2]) do
      assert.is.truthy(value)
      local position = positions[2][i + 1][1]
      assert.is.truthy(position)
      assert.equals(value.name, position.name)
      assert.equals(value.type, position.type)
    end
  end)
end)
