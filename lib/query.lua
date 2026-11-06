local function url_decode(s)
    s = s:gsub("+", " ")
    s = s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
    return s
end

local M = {}

---@param qs string|nil
---@return table<string, string|string[]>
function M.parse_query(qs)
    local params = {}
    if not qs or qs == "" then return params end

    qs = qs:gsub("^%?", "")

    for pair in qs:gmatch("[^&]+") do
        local k, v = pair:match("^([^=]*)=?(.*)$")
        k = url_decode(k)
        v = url_decode(v)

        if k ~= "" then
            local existing = params[k]
            if existing == nil then
                params[k] = v
            elseif type(existing) == "table" then
                existing[#existing + 1] = v
            else
                params[k] = { existing, v }
            end
        end
    end

    return params
end

return M
