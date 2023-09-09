---@diagnostic disable: undefined-field
local lib = require("neotest.lib")
local logger = require("neotest.logging")

---@class neotest.FoundryOptions
---@field filterDir?: fun(string): boolean
---@field foundryCommand? string|fun(): string
---@field foundryConfigFile? string|fun(): string
---@field env? table<string, string>|fun(): table<string, string>
---@field cwd? string|fun(): string

---@type neotest.Adapter
local adapter = { name = "neotest-foundry" }

adapter.root = function(path)
  return lib.files.match_root_pattern("foundry.toml")(path)
end

function adapter.filter_dir(name)
  return (
    name ~= "node_modules"
    and name ~= "cache"
    and name ~= "out"
    and name ~= "artifacts"
    and name ~= "docs"
    and name ~= "doc"
  )
end

---@param file_path? string
---@return boolean
function adapter.is_test_file(file_path)
  if file_path == nil then
    return false
  end

  return string.match(file_path, "%.t%.sol$") ~= nil
end

---@async
---@return neotest.Tree | nil
function adapter.discover_positions(path)
  local query = [[
    (contract_declaration
      name: (_) @namespace.name
      (inheritance_specifier) @inherits (#match? @inherits "Test$")
    ) @namespace.definition

    (function_definition
        name: (_) @test.name (#match? @test.name "^test")
    ) @test.definition
  ]]

  return lib.treesitter.parse_positions(path, query, { require_namespaces = true })
end

local function getFoundryCommand()
  return "forge test"
end

---@param path string
---@return string|nil
local function getFoundryConfig(path)
  return nil
end

local function escapeTestPattern(s)
  return (
    s:gsub("%(", "%\\(")
      :gsub("%)", "%\\)")
      :gsub("%]", "%\\]")
      :gsub("%[", "%\\[")
      :gsub("%*", "%\\*")
      :gsub("%+", "%\\+")
      :gsub("%-", "%\\-")
      :gsub("%?", "%\\?")
      :gsub("%$", "%\\$")
      :gsub("%^", "%\\^")
      :gsub("%/", "%\\/")
  )
end

local function get_strategy_config(strategy, command)
  local config = {
    dap = function()
      return {
        name = "Debug Foundry Tests",
        type = "TODO", --TODO: see https://github.com/foundry-rs/foundry/issues/5784
        request = "launch",
        args = { unpack(command, 2) },
        runtimeExecutable = command[1],
        console = "integratedTerminal",
        internalConsoleOptions = "neverOpen",
      }
    end,
  }
  if config[strategy] then
    return config[strategy]()
  end
end

local function getEnv(specEnv)
  return specEnv
end

---@param path string
---@return string|nil
local function getCwd(path)
  return adapter.root(path)
end

---@param args neotest.RunArgs
---@return neotest.RunSpec | nil
function adapter.build_spec(args)
  local tree = args.tree

  if not tree then
    return
  end

  local node = args.tree:data()
  local cwd = getCwd(node.path)
  local config = getFoundryConfig(node.path)
  local command = vim.split(getFoundryCommand(), "%s+")

  local filename = node.path:match("([^/]+)$")
  local glob = "**/" .. filename .. "/**"
  if filename:match("%.t%.sol$") ~= nil then
    glob = "**/" .. filename
  end
  vim.list_extend(command, { "--match-path", glob })

  if node.type == "test" then
    vim.list_extend(command, { "--match-test", "^" .. escapeTestPattern(node.name) })
  end

  if node.type == "namespace" then
    vim.list_extend(command, { "--match-contract", "^" .. escapeTestPattern(node.name) .. "$" })
  end

  if config ~= nil then
    vim.list_extend(command, { "--config-path", config })
  end

  vim.list_extend(command, { "--json", "--silent" })

  return {
    command = command,
    cwd = cwd,
    context = {
      file = node.path,
    },
    -- strategy = get_strategy_config(args.strategy, command),
    env = getEnv(args[2] and args[2].env or {}),
  }
end

local function cleanAnsi(s)
  return s:gsub("\x1b%[%d+;%d+;%d+;%d+;%d+m", "")
    :gsub("\x1b%[%d+;%d+;%d+;%d+m", "")
    :gsub("\x1b%[%d+;%d+;%d+m", "")
    :gsub("\x1b%[%d+;%d+m", "")
    :gsub("\x1b%[%d+m", "")
end

local function tableIsEmpty(t)
  for _ in pairs(t) do
    return false
  end
  return true
end

local function parsed_json_to_results(data, spec)
  local tests = {}

  for testContract, contractTestResults in pairs(data) do
    for testFn, testResult in pairs(contractTestResults.test_results) do
      local status = testResult.status

      if status == "Success" then
        status = "passed"
      elseif status == "Failure" then
        status = "failed"
      else
        status = "skipped"
      end

      local i = 1
      local errorMsg = ""
      local errors = {}
      for _, decodedLog in pairs(testResult.decoded_logs) do
        if string.match(errorMsg, "^Error:") ~= nil then
          if errorMsg ~= "" then
            errors[i] = { message = errorMsg }
            i = i + 1
          end
          errorMsg = cleanAnsi(decodedLog)
        else
          errorMsg = errorMsg .. "\n" .. cleanAnsi(decodedLog)
        end
      end
      if errorMsg ~= "" then
        errors[i] = { message = errorMsg }
        i = i + 1
      end

      local keyid = spec.cwd .. "/" .. testContract:gsub(":", "::") .. "::" .. testFn:match("[^(]+")
      tests[keyid] = { status = status, short = testResult.reason }
      if not tableIsEmpty(errors) then
        tests[keyid].errors = errors
      end
    end
  end

  return tests
end

---@async
---@param spec neotest.RunSpec
---@return neotest.Result[]
function adapter.results(spec, result, tree)
  local success, data = pcall(lib.files.read, result.output)

  if not success then
    logger.error("Could not read from foundry stdout")
    return {}
  end

  local ok, parsed = pcall(vim.json.decode, data, { luanil = { object = true } })

  if not ok then
    logger.error("Failed to parse test output json")
    return {}
  end

  return parsed_json_to_results(parsed, spec)
end

local is_callable = function(obj)
  return type(obj) == "function" or (type(obj) == "table" and obj.__call)
end

setmetatable(adapter, {
  ---@param opts neotest.FoundryOptions
  __call = function(_, opts)
    if is_callable(opts.foundryCommand) then
      getFoundryCommand = opts.foundryCommand
    elseif opts.foundryCommand then
      getFoundryCommand = function()
        return opts.foundryCommand
      end
    end
    if is_callable(opts.foundryConfigFile) then
      getFoundryConfig = opts.foundryConfigFile
    elseif opts.foundryConfigFile then
      getFoundryConfig = function()
        return opts.foundryConfigFile
      end
    end
    if is_callable(opts.env) then
      getEnv = opts.env
    elseif opts.env then
      getEnv = function(specEnv)
        return vim.tbl_extend("force", opts.env, specEnv)
      end
    end
    if is_callable(opts.cwd) then
      getCwd = opts.cwd
    elseif opts.cwd then
      getCwd = function()
        return opts.cwd
      end
    end
    if is_callable(opts.filterDir) then
      adapter.filter_dir = opts.filterDir
    end
    return adapter
  end,
})

return adapter
