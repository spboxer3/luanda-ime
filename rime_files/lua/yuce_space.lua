-- 按鍵處理：
-- 1) 中文組字時空白 → '_'（一聲），英文模式不轉換
-- 2) Enter → 確認目前候選（不再誤送成空白／底線）

local kAccepted = 1
local kNoop = 2

local function processor(key, env)
    local ctx = env.engine.context
    local repr = key:repr()

    -- Enter：選中／上屏目前高亮候選
    if repr == "Return" or repr == "KP_Enter" then
        if ctx:is_composing() then
            ctx:confirm_current_selection()
            return kAccepted
        end
        return kNoop
    end

    if not ctx:is_composing() then
        return kNoop
    end
    if ctx:get_option("ascii_mode") then
        return kNoop
    end

    -- 中文模式空白 = 一聲
    if repr == "space" then
        ctx:push_input("_")
        return kAccepted
    end

    return kNoop
end

return processor
