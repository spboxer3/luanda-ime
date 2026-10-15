-- Tab 觸發後才向本機 AI 要糾錯候選；平時不 yield（洋蔥負責選字）

local CACHE_DIR = (os.getenv("APPDATA") or ".") .. "\\Rime\\luanda\\ipc"
local CACHE_FILE = CACHE_DIR .. "\\candidates.txt"
local KEYS_FILE = CACHE_DIR .. "\\response_keys.txt"
local REQ_FILE = CACHE_DIR .. "\\request.txt"
local STATUS_FILE = CACHE_DIR .. "\\status.txt"
local LOADING_TEXT = "[AI糾錯中]"

local PROP_AI = "luanda_ai"
local PROP_KEYS = "luanda_ai_keys"

local last_results = {}
local last_result_keys = nil
local hooks_installed = false

local function clear_ai_props(ctx)
    ctx:set_property(PROP_AI, "0")
    ctx:set_property(PROP_KEYS, "")
end

local function install_hooks(env)
    if hooks_installed then
        return
    end
    hooks_installed = true
    local ctx = env.engine.context
    local function reset(c)
        last_results = {}
        last_result_keys = nil
        clear_ai_props(c)
    end
    if ctx.commit_notifier then
        ctx.commit_notifier:connect(reset)
    end
    if ctx.clear_notifier then
        ctx.clear_notifier:connect(reset)
    end
    if ctx.update_notifier then
        ctx.update_notifier:connect(function(c)
            if c:get_property(PROP_AI) ~= "1" then
                return
            end
            local want = c:get_property(PROP_KEYS) or ""
            if want ~= "" and c.input ~= want then
                -- 繼續打字 → 退出 AI 模式，回到洋蔥
                reset(c)
            end
        end)
    end
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
        if line and #line > 0 and line ~= "..." and line ~= LOADING_TEXT and line ~= "[模型載入中]" then
            table.insert(results, line)
        end
    end
    if #results == 0 then
        return nil
    end
    return results
end

-- 洋蔥：空白＝一聲、\\＝音節分隔；模型訓練用 '_' 一聲、無分隔符
local function to_ai_keys(input)
    local s = string.gsub(input or "", "\\", "")
    s = string.gsub(s, " ", "_")
    return s
end

local function write_request(keys)
    local f = io.open(REQ_FILE, "w")
    if not f then
        return false
    end
    f:write(keys)
    f:close()
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

local function translator(input, seg, env)
    install_hooks(env)

    local ctx = env.engine.context
    if ctx:get_property(PROP_AI) ~= "1" then
        return
    end
    if (ctx:get_property(PROP_KEYS) or "") ~= input then
        return
    end
    if seg:has_tag("punct") then
        return
    end
    if ctx:get_option("ascii_mode") then
        return
    end

    local ai_keys = to_ai_keys(input)
    if #ai_keys < 2 then
        return
    end

    if last_result_keys ~= ai_keys then
        write_request(ai_keys)
        -- 使用者主動按 Tab，允許稍長等待；仍不啟動行程
        local ok = wait_for_response(ai_keys, 600)
        if not ok and read_text(STATUS_FILE) == "loading" then
            local cand = Candidate("luanda_ai", seg.start, seg._end, LOADING_TEXT, "AI")
            cand.quality = 9000
            yield(cand)
            return
        end
    else
        refresh_from_disk(ai_keys)
    end

    if last_result_keys == ai_keys and last_results then
        for i, text in ipairs(last_results) do
            local cand = Candidate("luanda_ai", seg.start, seg._end, text, "AI")
            cand.quality = 8000 - i
            yield(cand)
        end
    end
end

return translator
