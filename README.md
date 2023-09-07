# neotest-foundry

This plugin provides a [Foundry](https://github.com/foundry-rs/foundry) adapter for the [Neotest](https://github.com/rcarriga/neotest) framework.

Credits to [neotest-vitest](https://github.com/marilari88/neotest-vitest) and [vscode-foundry-test-runner](https://github.com/PraneshASP/vscode-foundry-test-runner).

https://github.com/llllvvuu/neotest-foundry/assets/5601392/f8d70d05-f0fb-4aef-b2a6-8c71ec8ae7c4

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
  'nvim-neotest/neotest',
  dependencies = {
    ...,
    'llllvvuu/neotest-foundry',
  }
  config = {
    ...,
    adapters = {
      require('neotest-foundry')
    }
  }
}
```

## Configuration
Defaults:
```lua
...
adapters = {
  require('neotest-foundry')({
    foundryCommand = "forge test", -- string | function
    foundryConfig = nil, -- string | function
    env = {}, -- table | function
    cwd = function () return lib.files.match_root_pattern("foundry.toml") end, -- string | function
    filterDir = function(name)
      return (
        name ~= "node_modules"
        and name ~= "cache"
        and name ~= "out"
        and name ~= "artifacts"
        and name ~= "docs"
        and name ~= "doc"
        -- and name ~= "lib"
      )
    end,
  })
}
```

## Testing

```sh
./scripts/test
```
