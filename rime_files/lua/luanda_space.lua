-- 按鍵處理（避免自幹 highlight/menu:prepare，焦點切換時易讓 rime.dll 崩）
-- 1) 中文組字時空白 → '_'（一聲）
-- 2) Enter → 記錄慣用詞並確認候選
-- 3) BackSpace → 刪除一整個音節
-- 翻頁改由 schema key_binder 送 Page_Up/Page_Down，不用 Lua 改 selected_index

local kAccepted = 1
local kNoop = 2
local userdict = require("luanda_userdict")

local TONES = {
    ["3"] = true,
    ["4"] = true,
    ["6"] = true,
    ["7"] = true,
    ["_"] = true,
}

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
        local prev = 0
        for i = last_tone - 1, 1, -1 do
            if TONES[string.sub(input, i, i)] then
                prev = i
                break
            end
        end
        return string.sub(input, 1, prev)
    elseif last_tone then
        return string.sub(input, 1, last_tone)
    end

    return ""
end

local function record_current_selection(ctx)
    local input = ctx.input
    if not input or input == "" then
        return
    end
    local ok, cand = pcall(function()
        return ctx:get_selected_candidate()
    end)
    if ok and cand and cand.text and cand.text ~= "" and cand.text ~= "[模型載入中]" then
        userdict.record(input, cand.text)
    end
end

local function processor(key, env)
    local ctx = env.engine.context
    local repr = key:repr()

    if repr == "Return" or repr == "KP_Enter" then
        if ctx:is_composing() then
            local ok, cand = pcall(function()
                return ctx:get_selected_candidate()
            end)
            if ok and cand and cand.text == "[模型載入中]" then
                return kAccepted
            end
            record_current_selection(ctx)
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

    if repr == "BackSpace" then
        local input = ctx.input
        local trimmed = trim_last_syllable(input)
        if trimmed == input then
            return kNoop
        end
        -- 用 pop/push 比 clear+push 更不易在焦點切換時踩 rime 內部狀態
        local n = #input - #trimmed
        if n > 0 and ctx.pop_input then
            ctx:pop_input(n)
        else
            ctx:clear()
            if #trimmed > 0 then
                ctx:push_input(trimmed)
            end
        end
        return kAccepted
    end

    if repr == "space" then
        ctx:push_input("_")
        return kAccepted
    end

    return kNoop
end

return processor
