local json = require "cjson"
local http = require "socket.http"
local ltn12 = require "ltn12"
local logger = require "src.logger"

local M = {}

M.FLARESOLVERR_URL = "http://localhost:8191/v1"
M.TIMEOUT = 120000

function M.request_get(url, cookies)
    local payload = {
        cmd = "request.get",
        url = url,
        maxTimeout = M.TIMEOUT,
    }
    if cookies then
        payload.cookies = cookies
    end

    local body = json.encode(payload)

    logger.separator()
    logger.info("FlareSolverr: POST " .. M.FLARESOLVERR_URL)
    logger.info("  target: " .. url)

    local resp_body = {}
    local _, status = http.request {
        url = M.FLARESOLVERR_URL,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#body),
        },
        source = ltn12.source.string(body),
        sink = ltn12.sink.table(resp_body),
    }

    local raw = table.concat(resp_body)
    logger.info("FlareSolverr: HTTP " .. tostring(status) .. ", response " .. #raw .. " bytes")

    if status ~= 200 then
        logger.error("FlareSolverr returned status " .. tostring(status))
        return nil, status, raw
    end

    local ok, data = pcall(json.decode, raw)
    if not ok then
        logger.error("FlareSolverr JSON decode error: " .. tostring(data))
        return nil, nil, raw
    end

    return data
end

function M.fetch(url)
    logger.info("FlareSolverr: solving challenge for " .. url .. " ...")

    local data = M.request_get(url)
    if not data then
        return nil, nil, nil
    end

    if data.status ~= "ok" then
        logger.error("FlareSolverr error: " .. tostring(data.message or data.error))
        logger.preview(tostring(data), 2000)
        return nil, nil, nil
    end

    local solution = data.solution
    local status = solution.status
    local body = solution.response

    -- Extract cookies from solution
    local cookies = {}
    if solution.cookies then
        for _, c in ipairs(solution.cookies) do
            cookies[c.name] = c.value
            logger.info("  cookie: " .. c.name .. "=" .. c.value:sub(1, 30) .. "...")
        end
    end

    logger.info("FlareSolverr: solved, status=" .. tostring(status) .. ", body=" .. #body .. " bytes")

    return body, status, cookies, solution.headers
end

return M
