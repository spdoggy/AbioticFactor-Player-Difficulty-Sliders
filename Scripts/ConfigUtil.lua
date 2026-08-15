local ConfigUtil = {}

-- ============================================================
-- GENERIC VALIDATORS
-- ============================================================

function ConfigUtil.ValidateBoolean(value, default, logFunc, fieldName)
    if type(value) ~= "boolean" then
        if value ~= nil and logFunc and fieldName then
            logFunc("Invalid " .. fieldName .. " (must be boolean), using " .. tostring(default), "warning")
        end
        return default
    end
    return value
end

-- ============================================================
-- SECURITY OFFICE KEYPAD CONFIG VALIDATOR
-- ============================================================

local DEFAULTS = {
    Debug = false,
}

function ConfigUtil.ValidateConfig(userConfig, logFunc)
    local config = userConfig or {}

    config.Debug = ConfigUtil.ValidateBoolean(config.Debug, DEFAULTS.Debug, logFunc, "Debug")

    return config
end

return ConfigUtil
