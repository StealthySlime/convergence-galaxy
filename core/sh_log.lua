Convergence.Log = Convergence.Log or {}

local Log = Convergence.Log
local Levels = Convergence.Constants.LOG_LEVELS

Log.MinimumLevel = Levels.INFO

local function serializeFields(fields)
    if not istable(fields) or table.IsEmpty(fields) then
        return ""
    end

    local fragments = {}

    for key, value in SortedPairs(fields) do
        fragments[#fragments + 1] = string.format("%s=%s", tostring(key), tostring(value))
    end

    return " | " .. table.concat(fragments, " ")
end

local function write(levelName, area, message, fields)
    local level = Levels[levelName] or Levels.INFO

    if level < Log.MinimumLevel then
        return
    end

    local line = string.format(
        "[Convergence][%s][%s] %s%s",
        levelName,
        tostring(area or "General"),
        tostring(message or ""),
        serializeFields(fields)
    )

    if levelName == "ERROR" then
        ErrorNoHalt(line .. "\n")
        return
    end

    print(line)
end

function Log.SetMinimumLevel(levelName)
    local value = Levels[string.upper(tostring(levelName or ""))]

    if not value then
        return false, Convergence.Constants.ERROR.INVALID_ARGUMENT,
            "Unknown log level."
    end

    Log.MinimumLevel = value
    return true
end

function Log.Debug(area, message, fields)
    write("DEBUG", area, message, fields)
end

function Log.Info(area, message, fields)
    write("INFO", area, message, fields)
end

function Log.Warn(area, message, fields)
    write("WARN", area, message, fields)
end

function Log.Error(area, message, fields)
    write("ERROR", area, message, fields)
end

function Log.Audit(action, context, fields)
    context = context or {}
    fields = table.Copy(fields or {})

    fields.actor = context.actorName or context.actorID or "SYSTEM"
    fields.source = context.source or "system"
    fields.reason = context.reason or "No reason supplied."

    write("AUDIT", action, "Persistent action recorded.", fields)
end
