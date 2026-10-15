-- 舊版空白→'_' 處理已停用：亂打改以洋蔥為底（空白＝一聲由洋蔥處理）。
-- 保留此檔以免舊 schema 引用報錯；一律 noop。

local kNoop = 2

local function processor(_key, _env)
    return kNoop
end

return processor
