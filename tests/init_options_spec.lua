local async = require("nio").tests
local Tree = require("neotest.types").Tree

describe("build_spec with override", function()
  async.it("builds command", function()
    local plugin = require("neotest-foundry")({})

    local positions = plugin.discover_positions("./spec/test/Counter.t.sol"):to_list()
    local tree = Tree.from_list(positions, function(pos)
      return pos.id
    end)
    local spec =
      plugin.build_spec({ nil, { env = { spec_override = true } }, tree = tree._children[1] })
    local command = spec.command

    assert.is.same(command, {
      "forge",
      "test",
      "--match-path",
      "**/Counter.t.sol",
      "--match-contract",
      "^CounterTest$",
      "--json",
      "--silent",
    })

    plugin = require("neotest-foundry")({
      foundryCommand = "mybinary override",
      foundryConfigFile = "myconfig",
      env = { override = "override", adapter_override = true },
    })
    spec = plugin.build_spec({
      nil,
      { env = { spec_override = true } },
      tree = tree._children[1]._children[2],
    })
    command = spec.command

    assert.is.same(command, {
      "mybinary",
      "override",
      "--match-path",
      "**/Counter.t.sol",
      "--match-test",
      "^testSetNumber",
      "--config-path",
      "myconfig",
      "--json",
      "--silent",
    })
    assert.is.same(
      spec.env,
      { override = "override", adapter_override = true, spec_override = true }
    )
  end)
end)
