local M = {}

---@param req PoHttpServerRequest
---@return table<string, string>
function M.fields(req)
    return req.form and req.form.fields or {}
end

---@param value? string
function M.is_true(value)
    return value ~= nil and value:lower() == "true"
end

---@param value? string
---@return string[]?
function M.parse_tags(value)
    local tags = {}

    for tag in (value or ""):gmatch("[^,]+") do
        tag = tag:match("^%s*(.-)%s*$")

        if tag ~= "" then
            tags[#tags + 1] = tag
        end
    end

    return #tags > 0 and tags or nil
end

return M
