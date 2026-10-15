-- 有選字框時按 Tab → 觸發 AI 糾錯（只設旗標並刷新，不在此啟動行程）

local kAccepted = 1
local kNoop = 2

local PROP_AI = "luanda_ai"
local PROP_KEYS = "luanda_ai_keys"

local function processor(key, env)
    local ctx = env.engine.context
    local repr = key:repr()

    if repr ~= "Tab" then
        return kNoop
    end

    if not ctx:is_composing() then
        return kNoop
    end
    if not ctx:has_menu() then
        return kNoop
    end
    if ctx:get_option("ascii_mode") then
        return kNoop
    end

    local input = ctx.input or ""
    if input == "" then
        return kNoop
    end

    -- 再按一次 Tab：取消 AI，回到純洋蔥
    if ctx:get_property(PROP_AI) == "1" and ctx:get_property(PROP_KEYS) == input then
        ctx:set_property(PROP_AI, "0")
        ctx:set_property(PROP_KEYS, "")
        ctx:refresh_non_confirmed_composition()
        return kAccepted
    end

    ctx:set_property(PROP_AI, "1")
    ctx:set_property(PROP_KEYS, input)
    ctx:refresh_non_confirmed_composition()
    return kAccepted
end

return processor
