local codec = require("porla_codec")
local crypto = require("porla_crypto")
local sessions = require("porla_sessions")

local M = {}

---@class QbitContext
---@field config table
---@field session PoSessionHandle

---@type table<string, { expires: integer, username: string }>
local session_state = {}

---@param username string
function M.create_session(username)
    local now = os.time()

    for token, s in pairs(session_state) do
        if s.expires <= now then
            session_state[token] = nil
        end
    end

    local token = codec.hex.encode(crypto.randombytes(32))

    session_state[token] = {
        expires = now + 3600,
        username = username
    }

    return token
end

---@param config { session?: string }
---@param user { session?: string }
---@return PoSessionHandle?
---@return string # the session's name, for messages
function M.session_for(config, user)
    local name = user.session or config.session

    if name then
        return sessions.get(name), name
    end

    return sessions.default(), "default"
end

---@param res PoHttpServerResponse
local function forbidden(res)
    res:write_status("403 Forbidden")
    res:write_header("Content-Type", "text/plain")
    res:finish("Forbidden")
end

function M.authed_route(config, handler)
    ---@param req PoHttpServerRequest
    ---@param res PoHttpServerResponse
    return function(req, res)
        local cookie_header = req.headers["cookie"]

        if not cookie_header then
            return forbidden(res)
        end

        local sid = cookie_header:match("%f[%w]SID=([%x]+)")

        if not sid then
            return forbidden(res)
        end

        local s = session_state[sid]
        local now = os.time()

        if not s or s.expires <= now then
            session_state[sid] = nil
            return forbidden(res)
        end

        local user = config.users[s.username]

        if not user then
            session_state[sid] = nil
            return forbidden(res)
        end

        local session, session_name = M.session_for(config, user)

        if not session then
            print("Session not loaded:", session_name)
            res:write_status("503 Service Unavailable")
            res:write_header("Content-Type", "text/plain")
            return res:finish("Session not available")
        end

        s.expires = now + 3600

        local ctx = {
            config = config,
            session = session
        }

        return handler(req, res, ctx)
    end
end

return M
