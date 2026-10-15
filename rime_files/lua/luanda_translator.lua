-- luanda translator (exact-match + userdict)
-- Only show results whose response_keys exactly equal current input.

local CACHE_DIR = (os.getenv("TEMP") or ".") .. "\\rime_luanda_cache"
local CACHE_FILE = CACHE_DIR .. "\\candidates.txt"
local KEYS_FILE = CACHE_DIR .. "\\response_keys.txt"
local REQ_FILE = CACHE_DIR .. "\\request.txt"

local userdict = require("luanda_userdict")

local last_results = {}
local last_result_keys = nil
local last_req_written = nil
local last_compose_keys = ""
local hooks_installed = false

local function clear_memory_cache()
    last_results = {}
    last_result_keys = nil
    last_req_written = nil
end

local function drop_stale_cache(input)
    if last_result_keys and last_result_keys ~= input then
        last_results = {}
        last_result_keys = nil
    end
    if last_req_written and last_req_written ~= input then
        last_req_written = nil
    end
end

local function cache_fits_input(input)
    return last_result_keys == input and last_results and #last_results > 0
end

local function install_clear_hooks(env)
    if hooks_installed then
        return
    end
    hooks_installed = true
    local ctx = env.engine.context
    ctx.commit_notifier:connect(function()
        clear_memory_cache()
    end)
    ctx.clear_notifier:connect(function()
        clear_memory_cache()
        last_compose_keys = ""
    end)
    if ctx.select_notifier then
        ctx.select_notifier:connect(function(c)
            local cand = c:get_selected_candidate()
            if cand and last_compose_keys ~= "" and cand.text then
                userdict.record(last_compose_keys, cand.text)
            end
        end)
    end
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
    local t0 = os.clock()
    local target = ms / 1000
    while (os.clock() - t0) < target do
    end
end

local function refresh_from_disk(wanted_keys)
    local rk = read_text(KEYS_FILE)
    if not rk or rk ~= wanted_keys then
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
        if refresh_from_disk(wanted_keys) then
            return true
        end
        busy_wait_ms(5)
    end
    return refresh_from_disk(wanted_keys)
end

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

local function yield_english(input, seg)
    local spaced = string.gsub(input, "_", " ")
    local raw = input
    local cand1 = Candidate("luanda_en", seg.start, seg._end, spaced, "")
    cand1.preedit = spaced
    cand1.quality = 1000
    yield(cand1)
    if raw ~= spaced then
        local cand2 = Candidate("luanda_en", seg.start, seg._end, raw, "")
        cand2.preedit = spaced
        cand2.quality = 999
        yield(cand2)
    end
end

local function looks_like_bopomofo_keys(input)
    return string.match(input, "^[1qaz2wsxedcrfv5tgbyhnujm8ik,9ol%.0p;/%-6347_ ]+$") ~= nil
end

local function merge_unique(prefer, rest)
    local seen = {}
    local out = {}
    local function add(list)
        for _, t in ipairs(list) do
            if t and t ~= "" and t ~= "..." and not seen[t] then
                seen[t] = true
                out[#out + 1] = t
            end
        end
    end
    add(prefer)
    add(rest)
    return out
end

local function yield_merged(seg, texts, preedit)
    for i, text in ipairs(texts) do
        if i > 9 then
            break
        end
        local cand = Candidate("luanda_ai", seg.start, seg._end, text, "")
        cand.preedit = preedit
        cand.quality = 2000 - i
        yield(cand)
    end
end

local function translator(input, seg, env)
    install_clear_hooks(env)

    if seg:has_tag("punct") then
        return
    end
    if string.len(input) < 1 or not looks_like_bopomofo_keys(input) then
        return
    end

    last_compose_keys = input
    drop_stale_cache(input)

    if env.engine.context:get_option("ascii_mode") then
        yield_english(input, seg)
        return
    end

    local preedit = to_zhuyin_preedit(input)
    local habit = userdict.lookup(input)

    if string.len(input) < 2 then
        if #habit > 0 then
            yield_merged(seg, habit, preedit)
        end
        return
    end

    if last_req_written ~= input then
        write_request(input)
    end
    if last_result_keys ~= input then
        local wait_ms = is_syllable_end(input) and 320 or 180
        wait_for_response(input, wait_ms)
    else
        refresh_from_disk(input)
    end

    local ai = {}
    if cache_fits_input(input) then
        ai = last_results
    end

    local merged = merge_unique(habit, ai)
    if #merged > 0 then
        yield_merged(seg, merged, preedit)
    end
end

return translator
