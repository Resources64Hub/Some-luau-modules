local SHFC = {}
local HttpService = game:GetService("HttpService")
local Analytics = game:GetService("RbxAnalyticsService")

local FOLDER = "SHFC_Cache"
local SHARED = FOLDER .. "/Shared_Cache"
local PRIVATE = FOLDER .. "/Private_Cache"
local CONFIG = FOLDER .. "/config.json"
local SALT = "Open_Cache"
local STATS_PATH = FOLDER .. "/stats.json"

local function updateStats(fileSize)
    local stats = {TotalSavedBytes = 0, CacheHits = 0}
    if isfile(STATS_PATH) then
        local s, c = pcall(readfile, STATS_PATH)
        if s then stats = HttpService:JSONDecode(c) end
    end
    
    stats.TotalSavedBytes = (stats.TotalSavedBytes or 0) + (fileSize or 0)
    stats.CacheHits = (stats.CacheHits or 0) + 1
    
    writefile(STATS_PATH, HttpService:JSONEncode(stats))
end

local function getHWID()
    return Analytics:GetClientId()
end

local function getHash(str)
    local hash = 2166136261
    for i = 1, #str do
        hash = bit32.bxor(hash, string.byte(str, i))
        hash = (hash * 16777619) % 4294967296
    end
    return string.format("%08x", hash)
end

local function compress(str)
    return str -- A regular stub since any compression leads to errors
end

local function NeedsUpdate()
    if not isfile(CONFIG) then return true end
    local s, c = pcall(readfile, CONFIG)
    if not s then return true end
    local cfg = HttpService:JSONDecode(c)
    local yy, mm, dd = cfg.LastUpdate:match("(%d%d)%.(%d%d)%.(%d%d)")
    local lastT = os.time({year=2000+tonumber(yy), month=tonumber(mm), day=tonumber(dd), hour=0, min=0, sec=0})
    local now = os.date("*t")
    local curT = os.time({year=now.year, month=now.month, day=now.day, hour=0, min=0, sec=0})
    return math.floor((curT-lastT)/86400) >= (tonumber(cfg.UpdateCacheTimeInDays) or 7)
end

local function CleanFolder(path)
    if isfolder(path) then
        for _, f in ipairs(listfiles(path)) do
            if isfolder(f) then CleanFolder(f) pcall(delfolder, f) else pcall(delfile, f) end
        end
    end
end

function SHFC.Init()
    if not isfolder(FOLDER) then makefolder(FOLDER) end
    if not isfolder(SHARED) then makefolder(SHARED) end
    if not isfolder(PRIVATE) then makefolder(PRIVATE) end
    if not isfile(CONFIG) then
        writefile(CONFIG, HttpService:JSONEncode({UpdateCacheTimeInDays=7, LastUpdate=os.date("%y.%m.%d")}))
    end
    if NeedsUpdate() then
        CleanFolder(SHARED)
        local s, c = pcall(readfile, CONFIG)
        if s then
            local cfg = HttpService:JSONDecode(c)
            cfg.LastUpdate = os.date("%y.%m.%d")
            writefile(CONFIG, HttpService:JSONEncode(cfg))
        end
    end
end

function SHFC.Save(key, content, folderPath)
    SHFC.Init()
    local data = compress(content)
    local signature = getHash(data .. SALT .. getHWID())
    local fn = string.format("%s_%s_cached_mod_%s.shfcc", os.date("%y.%m.%d"), key, getHash(data))
    for _, p in ipairs(listfiles(folderPath)) do
        if p:find("_"..key.."_cached_mod_") then pcall(delfile, p) end
    end
    writefile(folderPath .. "/" .. fn, signature .. "\n" .. data)
end

function SHFC.Load(key, folderPath)
    SHFC.Init()
    local startTime = os.clock()
    local pat = "_" .. key .. "_cached_mod_"
    for _, p in ipairs(listfiles(folderPath)) do
        if p:find(pat) then
            local raw = readfile(p)
            local sig, data = raw:match("^([%w]+)\n(.+)$")
            if sig and data and sig == getHash(data .. SALT .. getHWID()) then
                updateStats(#data) 
                
                local timeTaken = string.format("%.4f", os.clock() - startTime)
                print(string.format("[SHFC] Loaded from %s in %s sec", p, timeTaken))
                return data
            else
                pcall(delfile, p)
            end
        end
    end
    return nil
end

function SHFC.PrintStats()
    if isfile(STATS_PATH) then
        local stats = HttpService:JSONDecode(readfile(STATS_PATH))
        local mb = string.format("%.2f", stats.TotalSavedBytes / (1024 * 1024))
        print("--- [SHFC STATISTICS] ---")
        print("🚀 Traffic Saved: " .. mb .. " MB")
        print("🎯 Cache Saved: " .. stats.CacheHits)
        print("-------------------------")
    end
end

function SHFC.HttpGetOrLoad(url, shared)
    local p = (shared == false) and PRIVATE or SHARED
    local uk = getHash(url)
    local c = SHFC.Load(uk, p)
    if c and not NeedsUpdate() then return c end
    local s, r = pcall(function() return game:HttpGet(url) end)
    if s and r then SHFC.Save(uk, r, p) return r end
    return c
end

function SHFC.Wrap(func, shared)
    if type(func) ~= "function" then return func end
    local isShared = (shared ~= false)
    return setfenv(func, setmetatable({}, {
        __index = function(_, k)
            if k == "game" or k == "Game" then
                return setmetatable({}, {
                    __index = function(_, gk)
                        local r = game[gk]
                        if gk == "HttpGet" or gk == "httpget" then
                            return function(s, url) return SHFC.HttpGetOrLoad(url, isShared) end
                        end
                        return type(r) == "function" and function(s, ...) return r(s==_ and game or s, ...) end or r
                    end
                })
            end
            if k == "HttpGet" then return function(s, url) return SHFC.HttpGetOrLoad(url, isShared) end end
            return getfenv(0)[k]
        end
    }))
end

return SHFC
