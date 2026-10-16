
local setmetatable = setmetatable
local wipe = wipe
local unpack = unpack
local select = select

BuildModule('NetEaseMemorize-1.0')

-- Weak keys never release strings in Lua 5.1, and CheckContent is keyed by every
-- listing title and comment seen this session: unbounded, it kept them all. The
-- functions are pure, so a full cache is simply dropped and refilled.
local NORMAL_LIMIT = 2048

function normal(fn)
    local count = 0
    local db = setmetatable({}, {
        __mode = 'k',
        __index = function(t, k)
            local v = fn(k)
            if v ~= nil then
                if count >= NORMAL_LIMIT then
                    wipe(t)
                    count = 0
                end
                count = count + 1
                t[k] = v
            end
            return v
        end
    })

    local function check(k)
        if k == nil then
            return fn(k)
        end
        return db[k]
    end

    local function clear()
        wipe(db)
        count = 0
    end

    local function size()
        return count
    end
    return check, clear, size
end

local function rets(...)
    return {count = select('#', ...), ...}
end

function multirets(fn)
    local db = setmetatable({}, {__mode = 'kv',})

    local function check(k)
        if k == nil then
            return fn(k)
        end
        local v = db[k]
        if not v then
            v = rets(fn(k))
            db[k] = v
        end
        return unpack(v, 1, v.count)
    end

    local function clear()
        wipe(db)
    end
    return check, clear
end
