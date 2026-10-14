-- 按鍵處理：
-- 1) 中文組字時空白 → '_'（一聲）
-- 2) Enter → 確認目前候選
-- 3) BackSpace → 刪除「一整個字」（一個音節），而非單一注音鍵

local kAccepted = 1
local kNoop = 2

local TONES = {
    ["3"] = true,
    ["4"] = true,
    ["6"] = true,
    ["7"] = true,
    ["_"] = true,
}

-- 從末尾刪掉一個音節（完整：含聲調；未完：刪到上一聲調之後）
local function trim_last_syllable(input)
    if not input or #input == 0 then
        return ""
    end

    local last_tone = nil
    for i = #input, 1, -1 do
        if TONES[string.sub(input, i, i)] then
            last_tone = i
            break
        end
    end

    if last_tone == #input then
        -- 結尾是完整音節：刪到上一個聲調為止
        local prev = 0
        for i = last_tone - 1, 1, -1 do
            if TONES[string.sub(input, i, i)] then
                prev = i
                break
            end
        end
        return string.sub(input, 1, prev)
    elseif last_tone then
        -- 未完成音節：只刪掉最後聲調之後的字根
        return string.sub(input, 1, last_tone)
    end

    -- 整段都還沒聲調：一次清掉（視為同一個未完成字）
    return ""
end

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

    -- BackSpace：刪一整個字（音節）
    if repr == "BackSpace" then
        local input = ctx.input
        local trimmed = trim_last_syllable(input)
        if trimmed == input then
            return kNoop
        end
        ctx:clear()
        if #trimmed > 0 then
            ctx:push_input(trimmed)
        end
        return kAccepted
    end

    -- 中文模式空白 = 一聲
    if repr == "space" then
        ctx:push_input("_")
        return kAccepted
    end

    return kNoop
end

return processor
