local crypto = require("porla_crypto")

local auth = require("lib.auth")

local M = {}

-- Verifying unknown usernames too keeps login timing from revealing which usernames exist.
local DUMMY_HASH = "$argon2id$v=19$m=65536,t=2,p=1$OZa5HxjQ10Un85XjbpIk6w$JoD4jT3L+7olyABCCXCN5DioW4qHMdcOS5oEZhfwP9k"

---@param users table<string, { password_hash: string }>
function M.handler(users)
    ---@param req PoHttpServerRequest
    ---@param res PoHttpServerResponse
    return function(req, res)
        local form = req.form and req.form.fields or {}

        local given_username, given_password = form.username or "", form.password or ""

        local user = users[given_username] or nil
        local password_hash = user and user.password_hash or DUMMY_HASH

        crypto.pwhash_verify(password_hash, given_password, function(err, valid)
            if err or not valid or not user then
                res:write_status("200 OK")
                return res:finish("Fails.")
            end

            print("Login for", given_username)

            local token = auth.create_session(given_username)
            local cookie = string.format("SID=%s; HttpOnly; SameSite=Strict; path=/", token)

            res:write_status("200 OK")
            res:write_header("Set-Cookie", cookie)
            res:finish("Ok.")
        end)
    end
end

return M
