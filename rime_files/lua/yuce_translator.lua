-- 零行程「預測」翻譯器（字根補齊版）。
-- ≥2 鍵即送推論；完整音節多等一會兒，字根階段用較短等待。

local CACHE_DIR = (os.getenv("TEMP") or ".") .. "\\rime_yuce_cache"
local CACHE_FILE = CACHE_DIR .. "\\candidates.txt"
local KEYS_FILE = CACHE_DIR .. "\\response_keys.txt"
local REQ_FILE = CACHE_DIR .. "\\request.txt"

local last_results = {}
local last_result_keys = nil
local last_req_written = nil
local hooks_installed = false

local function clear_memory_cache()
    last_results = {}
    last_result_keys = nil
    last_req_written = nil
end

-- 上一句上屏後，若新輸入與舊結果鍵碼無關，立刻丟棄舊候選
local function drop_stale_cache(input)
    if last_result_keys and #last_result_keys > 0 then
        local continues = (input == last_result_keys)
            or (string.sub(input, 1, #last_result_keys) == last_result_keys)
        if not continues then
            clear_memory_cache()
        end
    end
    if last_req_written and #last_req_written > 0 then
        local continues_req = (input == last_req_written)
            or (string.sub(input, 1, #last_req_written) == last_req_written)
        if not continues_req then
            last_req_written = nil
        end
    end
end

local function cache_fits_input(input)
    if not last_result_keys or #last_results == 0 then
        return false
    end
    return input == last_result_keys
        or string.sub(input, 1, #last_result_keys) == last_result_keys
end

local function install_clear_hooks(env)
    if hooks_installed then
        return
    end
    hooks_installed = true
    local ctx = env.engine.context
    -- 選字上屏或清除組字時，清空記憶體快取，避免下一句先看到舊候選
    ctx.commit_notifier:connect(function()
        clear_memory_cache()
    end)
    ctx.clear_notifier:connect(function()
        clear_memory_cache()
    end)
end

local function is_syllable_end(input)
    local last = string.sub(input, -1)
    return last == "3" or last == "4" or last == "6" or last == "7" or last == "_"
end

local function read_text(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local data = f:read("*a")
    f:close()
    if not data then
        return nil
    end
    data = string.gsub(data, "\r", "")
    data = string.gsub(data, "^%s+", "")
    data = string.gsub(data, "%s+$", "")
    if data == "" then
        return nil
    end
    return data
end

local function read_candidates()
    local data = read_text(CACHE_FILE)
    if not data then
        return nil
    end
    local results = {}
    for line in string.gmatch(data .. "\n", "(.-)\n") do
        if line and #line > 0 and line ~= "..." then
            table.insert(results, line)
        end
    end
    if #results == 0 then
        return nil
    end
    return results
end

local function read_response_keys()
    return read_text(KEYS_FILE)
end

local function write_request(keys)
    local f = io.open(REQ_FILE, "w")
    if not f then
        return false
    end
    f:write(keys)
    f:close()
    last_req_written = keys
    return true
end

local function busy_wait_ms(ms)
    -- librime-lua 無 sleep；用 os.clock 做極短等待
    local t0 = os.clock()
    local target = ms / 1000
    while (os.clock() - t0) < target do
    end
end

local function refresh_from_disk(wanted_keys)
    local rk = read_response_keys()
    if not rk then
        return false
    end
    -- 只要回應鍵碼是目前輸入的「前綴」或完全相等，就採用
    if rk ~= wanted_keys and string.sub(wanted_keys, 1, #rk) ~= rk then
        return false
    end
    local results = read_candidates()
    if not results then
        return false
    end
    last_results = results
    last_result_keys = rk
    return true
end

local function wait_for_response(wanted_keys, max_ms)
    local slices = math.floor(max_ms / 5)
    for _ = 1, slices do
        if refresh_from_disk(wanted_keys) and last_result_keys == wanted_keys then
            return true
        end
        busy_wait_ms(5)
    end
    -- 超時仍盡量用最新前綴結果
    refresh_from_disk(wanted_keys)
    return last_result_keys == wanted_keys
end

-- 大千鍵盤 → 注音符號（與官方 bopomofo preedit_format 相同；'_'／空白 = 一聲 ˉ）
local ZHUYIN_MAP = {
    ["1"] = "ㄅ", ["q"] = "ㄆ", ["a"] = "ㄇ", ["z"] = "ㄈ",
    ["2"] = "ㄉ", ["w"] = "ㄊ", ["s"] = "ㄋ", ["x"] = "ㄌ",
    ["e"] = "ㄍ", ["d"] = "ㄎ", ["c"] = "ㄏ",
    ["r"] = "ㄐ", ["f"] = "ㄑ", ["v"] = "ㄒ",
    ["5"] = "ㄓ", ["t"] = "ㄔ", ["g"] = "ㄕ", ["b"] = "ㄖ",
    ["y"] = "ㄗ", ["h"] = "ㄘ", ["n"] = "ㄙ",
    ["u"] = "ㄧ", ["j"] = "ㄨ", ["m"] = "ㄩ",
    ["8"] = "ㄚ", ["i"] = "ㄛ", ["k"] = "ㄜ", [","] = "ㄝ",
    ["9"] = "ㄞ", ["o"] = "ㄟ", ["l"] = "ㄠ", ["."] = "ㄡ",
    ["0"] = "ㄢ", ["p"] = "ㄣ", [";"] = "ㄤ", ["/"] = "ㄥ",
    ["-"] = "ㄦ",
    ["_"] = "ˉ", [" "] = "ˉ",
    ["6"] = "ˊ", ["3"] = "ˇ", ["4"] = "ˋ", ["7"] = "˙",
}

local function to_zhuyin_preedit(input)
    local parts = {}
    for i = 1, #input do
        local ch = string.sub(input, i, i)
        parts[#parts + 1] = ZHUYIN_MAP[ch] or ch
    end
    return table.concat(parts)
end

local function yield_list(seg, results, preedit)
    for i, text in ipairs(results) do
        local cand = Candidate("yuce_ai", seg.start, seg._end, text, "")
        cand.preedit = preedit
        cand.quality = 1000 - i
        yield(cand)
    end
end

local function yield_english(input, seg)
    -- 英文模式：組字區／候選都顯示英數，不轉注音
    local spaced = string.gsub(input, "_", " ")
    local raw = input
    local cand1 = Candidate("yuce_en", seg.start, seg._end, spaced, "")
    cand1.preedit = spaced
    cand1.quality = 1000
    yield(cand1)
    if raw ~= spaced then
        local cand2 = Candidate("yuce_en", seg.start, seg._end, raw, "")
        cand2.preedit = spaced
        cand2.quality = 999
        yield(cand2)
    end
end

local function translator(input, seg, env)
    install_clear_hooks(env)

    if string.len(input) < 1 then
        return
    end

    -- 新開一句／不相干輸入：先清掉上一句候選
    drop_stale_cache(input)

    -- Shift（inline_ascii）開啟 ascii_mode 時：改顯示英文候選
    if env.engine.context:get_option("ascii_mode") then
        yield_english(input, seg)
        return
    end

    local preedit = to_zhuyin_preedit(input)

    -- 少於 2 鍵：尚不足以補齊
    if string.len(input) < 2 then
        local cand = Candidate("yuce_ai", seg.start, seg._end, "...", "")
        cand.preedit = preedit
        cand.quality = 1
        yield(cand)
        return
    end

    -- 字根補齊：每多一鍵都投稿；完整音節等久一點，字根階段短等
    if last_req_written ~= input then
        write_request(input)
    end
    if last_result_keys ~= input then
        local wait_ms = is_syllable_end(input) and 280 or 150
        wait_for_response(input, wait_ms)
    else
        refresh_from_disk(input)
    end

    if cache_fits_input(input) then
        yield_list(seg, last_results, preedit)
    else
        local cand = Candidate("yuce_ai", seg.start, seg._end, "...", "")
        cand.preedit = preedit
        cand.quality = 1
        yield(cand)
    end
end

return translator
