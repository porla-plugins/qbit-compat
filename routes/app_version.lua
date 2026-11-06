local M = {}

function M.handler()
    ---@param res PoHttpServerResponse
    return function(_, res)
        res:write_status("200 OK")
        res:write_header("Content-Type", "text/plain")
        res:finish("v4.6.5")
    end
end

return M
