--[[
  AsmonFinder.TypeGuards

  Runtime type checks. Lua has no TypeScript typeof narrowing, so these
  named guards wrap type() and pcall. Secret client strings can still
  type as "string" but throw when compared; IsPublicString accounts for that.
]]

---@type AsmonFinderNamespace
AsmonFinder = AsmonFinder or {}
AsmonFinder.TypeGuards = AsmonFinder.TypeGuards or {}

---@type table
local TypeGuards = AsmonFinder.TypeGuards

---Read type(value) without throwing.
---@param value unknown Value to inspect.
---@return string? valueType Lua type name, or nil when type() failed.
function TypeGuards.SafeType(value)
  ---@type boolean, string
  local ok, valueType = pcall(type, value)
  if not ok then
    return nil
  end

  return valueType
end

---Whether value is a Lua string (may still be a secret client string).
---@param value unknown Value to inspect.
---@return boolean isString
function TypeGuards.IsString(value)
  return TypeGuards.SafeType(value) == "string"
end

---Whether value is a Lua number.
---@param value unknown Value to inspect.
---@return boolean isNumber
function TypeGuards.IsNumber(value)
  return TypeGuards.SafeType(value) == "number"
end

---Whether value is a Lua boolean.
---@param value unknown Value to inspect.
---@return boolean isBoolean
function TypeGuards.IsBoolean(value)
  return TypeGuards.SafeType(value) == "boolean"
end

---Whether value is a Lua function.
---@param value unknown Value to inspect.
---@return boolean isFunction
function TypeGuards.IsFunction(value)
  return TypeGuards.SafeType(value) == "function"
end

---Whether value is a Lua table (record / array / map).
---@param value unknown Value to inspect.
---@return boolean isRecord
function TypeGuards.IsRecord(value)
  return TypeGuards.SafeType(value) == "table"
end

---Whether the client marked this value as a secret string.
---@param value unknown Value to inspect.
---@return boolean isSecret
function TypeGuards.IsSecretValue(value)
  if not issecretvalue then
    return false
  end

  ---@type boolean, boolean
  local ok, isSecret = pcall(issecretvalue, value)
  if not ok then
    return false
  end

  return isSecret == true
end

---Compare a string against empty. Callers must pcall this for secret strings.
---@param value string Candidate string.
---@return boolean notEmpty
function TypeGuards.StringIsNotEmpty(value)
  return value ~= ""
end

---Whether value is a normal non-empty Lua string that addon code may compare.
---@param value unknown Value to inspect.
---@return boolean isPublic
function TypeGuards.IsPublicString(value)
  if TypeGuards.IsSecretValue(value) then
    return false
  end

  if not TypeGuards.IsString(value) then
    return false
  end

  ---@type boolean, boolean
  local ok, notEmpty = pcall(TypeGuards.StringIsNotEmpty, value)
  if not ok then
    return false
  end

  return notEmpty == true
end

---Return value when it is a public non-empty string, otherwise nil.
---@param value unknown Raw API return.
---@return string? text
function TypeGuards.AsPublicString(value)
  if not TypeGuards.IsPublicString(value) then
    return nil
  end

  return value
end

---Whether value is a finite number (not nan).
---@param value unknown Value to inspect.
---@return boolean isFinite
function TypeGuards.IsFiniteNumber(value)
  if not TypeGuards.IsNumber(value) then
    return false
  end

  if value ~= value then
    return false
  end

  return true
end

---@type (fun(message: string))?
local printer

---@type table<string, boolean>
local loggedFailureKeys = {}

---Highest number of table fields included in a shape log.
---@type number
local MAX_RECORD_FIELDS = 12

---Install the chat/printer used for type-guard rejections.
---@param nextPrinter? fun(message: string) Message sink.
function TypeGuards.SetPrinter(nextPrinter)
  if nextPrinter == nil then
    printer = nil
    return
  end

  if TypeGuards.IsFunction(nextPrinter) then
    printer = nextPrinter
  end
end

---Clear the once-per-shape rejection log. Used by tests.
function TypeGuards.ResetLoggedFailures()
  loggedFailureKeys = {}
end

---Build a public key label without concatenating secret values.
---@param key unknown Table key.
---@return string label Safe key label.
function TypeGuards.DescribeKey(key)
  if TypeGuards.IsPublicString(key) then
    return key
  end

  if TypeGuards.IsFiniteNumber(key) then
    return tostring(key)
  end

  return TypeGuards.SafeType(key) or "unknown"
end

---Describe a table by public field names and value types.
---@param value table Record to inspect.
---@return string shape Safe table shape.
function TypeGuards.DescribeRecord(value)
  ---@type string[]
  local fields = {}

  local function CollectFields()
    for key, field in pairs(value) do
      fields[#fields + 1] = TypeGuards.DescribeKey(key)
        .. ":"
        .. (TypeGuards.SafeType(field) or "unknown")
    end
  end

  local ok = pcall(CollectFields)
  if not ok then
    return "table pairs-failed"
  end

  table.sort(fields)

  if #fields == 0 then
    return "table {}"
  end

  if #fields > MAX_RECORD_FIELDS then
    ---@type string[]
    local shown = {}
    local index = 1
    while index <= MAX_RECORD_FIELDS do
      shown[index] = fields[index]
      index = index + 1
    end

    return "table {"
      .. table.concat(shown, ", ")
      .. ", +"
      .. tostring(#fields - MAX_RECORD_FIELDS)
      .. "}"
  end

  return "table {" .. table.concat(fields, ", ") .. "}"
end

---Describe a value's shape without printing secret string contents.
---@param value unknown Value to inspect.
---@return string shape Safe shape text.
function TypeGuards.DescribeValue(value)
  if value == nil then
    return "nil"
  end

  if TypeGuards.IsSecretValue(value) then
    return "secret type=" .. (TypeGuards.SafeType(value) or "unknown")
  end

  local valueType = TypeGuards.SafeType(value)
  if not valueType then
    return "type() failed"
  end

  if valueType == "string" then
    ---@type boolean, boolean
    local ok, notEmpty = pcall(TypeGuards.StringIsNotEmpty, value)
    if not ok then
      return "string compare-failed"
    end

    if notEmpty ~= true then
      return "string empty"
    end

    ---@type boolean, number
    local lengthOk, length = pcall(string.len, value)
    if lengthOk and TypeGuards.IsFiniteNumber(length) then
      return "string len=" .. tostring(length)
    end

    return "string"
  end

  if valueType == "number" then
    if value ~= value then
      return "number nan"
    end

    return "number value=" .. tostring(value)
  end

  if valueType == "boolean" then
    return "boolean value=" .. tostring(value)
  end

  if valueType == "table" then
    return TypeGuards.DescribeRecord(value)
  end

  return valueType
end

---Whether a rejected value is worth logging (skip normal nil/empty).
---@param value unknown Rejected value.
---@return boolean shouldLog
function TypeGuards.ShouldLogRejection(value)
  if value == nil then
    return false
  end

  if TypeGuards.IsSecretValue(value) then
    return true
  end

  if TypeGuards.IsString(value) then
    ---@type boolean, boolean
    local ok, notEmpty = pcall(TypeGuards.StringIsNotEmpty, value)
    if not ok then
      return true
    end

    if notEmpty ~= true then
      return false
    end
  end

  return true
end

---Log one unique type-guard rejection with the incoming data shape.
---@param context string Call site label.
---@param expected string Expected shape name.
---@param value unknown Rejected value.
function TypeGuards.LogGuardFailure(context, expected, value)
  if not TypeGuards.ShouldLogRejection(value) then
    return
  end

  local contextText = TypeGuards.AsPublicString(context)
  if not contextText then
    contextText = "unknown"
  end

  local expectedText = TypeGuards.AsPublicString(expected)
  if not expectedText then
    expectedText = "unknown"
  end

  local shape = TypeGuards.DescribeValue(value)
  local key = contextText .. "|" .. expectedText .. "|" .. shape
  if loggedFailureKeys[key] then
    return
  end

  loggedFailureKeys[key] = true

  if not printer then
    return
  end

  printer(
    "[Asmon Finder Types] rejected "
      .. contextText
      .. " expected="
      .. expectedText
      .. " got="
      .. shape
  )
end

---Return a public non-empty string, logging unexpected shapes.
---@param context string Call site label.
---@param value unknown Raw API return.
---@return string? text
function TypeGuards.ExpectPublicString(context, value)
  if TypeGuards.IsPublicString(value) then
    return value
  end

  TypeGuards.LogGuardFailure(context, "public-string", value)
  return nil
end

---Return a table, logging unexpected shapes.
---@param context string Call site label.
---@param value unknown Raw API return.
---@return table? record
function TypeGuards.ExpectRecord(context, value)
  if TypeGuards.IsRecord(value) then
    return value
  end

  TypeGuards.LogGuardFailure(context, "record", value)
  return nil
end

---Return a finite number, logging unexpected shapes.
---@param context string Call site label.
---@param value unknown Raw API return.
---@return number? amount
function TypeGuards.ExpectFiniteNumber(context, value)
  if TypeGuards.IsFiniteNumber(value) then
    return value
  end

  TypeGuards.LogGuardFailure(context, "finite-number", value)
  return nil
end

---Return a function, logging unexpected shapes.
---@param context string Call site label.
---@param value unknown Raw API return.
---@return function? callback
function TypeGuards.ExpectFunction(context, value)
  if TypeGuards.IsFunction(value) then
    return value
  end

  TypeGuards.LogGuardFailure(context, "function", value)
  return nil
end
