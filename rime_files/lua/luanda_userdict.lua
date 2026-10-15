-- 亂打輸入法使用者慣用詞（選過的「鍵碼 → 詞」會加權）
-- 檔案：%APPDATA%\Rime\luanda_user_dict.txt  （每行：keys<TAB>詞）

local M = {}

local function dict_path()
    local appdata = os.getenv("APPDATA")
    if appdata and #appdata > 0 then
        return appdata .. "\\Rime\\luanda_user_dict.txt"
    end
    return (os.getenv("TEMP") or ".") .. "\\luanda_user_dict.txt"
end

local cache_keys = nil
local cache_list = nil

local function utf8_len(s)
    local n = 0
    for _ in string.gmatch(s, "[%z\1-\127\194-\244][\128-\191]*") do
        n = n + 1
    end
    return n
end

local function has_non_ascii(text)
    for i = 1, #text do
        if string.byte(text, i) >= 128 then
            return true
        end
    end
    return false
end

function M.record(keys, text)
    if not keys or keys == "" or not text or text == "" then
        return
    end
    if text == "..." or text == "[模型載入中]" then
        return
    end
    -- 略過純英文／純 ASCII 候選
    if not has_non_ascii(text) then
        return
    end

    local path = dict_path()
    local f = io.open(path, "a")
    if not f then
        return
    end
    f:write(keys .. "\t" .. text .. "\n")
    f:close()
    cache_keys = nil
    cache_list = nil
end

function M.lookup(keys)
    if not keys or keys == "" then
        return {}
    end
    if cache_keys == keys and cache_list then
        return cache_list
    end

    local path = dict_path()
    local f = io.open(path, "r")
    if not f then
        cache_keys = keys
        cache_list = {}
        return cache_list
    end

    local counts = {}
    for line in f:lines() do
        line = string.gsub(line, "\r", "")
        local k, t = string.match(line, "^(.-)\t(.+)$")
        if k == keys and t and t ~= "" then
            counts[t] = (counts[t] or 0) + 1
        end
    end
    f:close()

    local arr = {}
    for t, c in pairs(counts) do
        arr[#arr + 1] = { text = t, count = c, len = utf8_len(t) }
    end
    table.sort(arr, function(a, b)
        if a.count ~= b.count then
            return a.count > b.count
        end
        return a.len > b.len
    end)

    local out = {}
    for i = 1, math.min(45, #arr) do
        out[#out + 1] = arr[i].text
    end
    cache_keys = keys
    cache_list = out
    return out
end

return M
