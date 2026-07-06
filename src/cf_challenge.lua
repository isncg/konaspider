local http = require "src.http"
local logger = require "src.logger"
local cookie = require "src.cookie"
local lfs = require "lfs"
local io = require "io"
local os = require "os"

local M = {}

local TARGET_URL = "https://konachan.net/post.json"
local SAMPLES_DIR = "samples"

function M.ensure_samples_dir()
    local ok = lfs.attributes(SAMPLES_DIR)
    if not ok then
        lfs.mkdir(SAMPLES_DIR)
    end
end

function M.fetch_challenge_page()
    M.ensure_samples_dir()
    cookie.reset()

    local timestamp = os.date("%Y%m%d_%H%M%S")
    local save_path = SAMPLES_DIR .. "/challenge_" .. timestamp .. ".html"

    logger.info("fetching challenge page, no cf_clearance...")
    local body, status, headers = http.get(TARGET_URL)

    if not body then
        logger.error("no response body received")
        return nil, status, headers, save_path
    end

    local file = io.open(save_path, "w")
    if file then
        file:write(body)
        file:close()
        logger.info("challenge page saved to: " .. save_path)
    end

    return body, status, headers, save_path
end

function M.identify(html)
    if not html then
        return "NO_BODY"
    end
    if html:find("chk_jschl") then
        return "IUAM"
    end
    if html:find("turnstile") or html:find("cf%-turnstile") then
        return "TURNSTILE"
    end
    if html:find("cType:%s*'managed'") or html:find('cType:%s*"managed"') then
        return "MANAGED_CHALLENGE"
    end
    if html:find("Access denied") then
        return "ACCESS_DENIED"
    end
    if html:find('"posts":') or html:find('"id":') then
        return "JSON_RESPONSE"
    end
    return "UNKNOWN"
end

function M.extract_iuam_params(html)
    local params = {}

    params.action = html:match('action="([^"]*)"')
    params.jschl_vc = html:match('name="jschl_vc" value="([^"]*)"')
    params.pass = html:match('name="pass" value="([^"]*)"')
    params.r = html:match('name="r" value="([^"]*)"')

    local a = html:find(' a.')
    if a then
        local s_val = html:match(' a. value = "([^"]+)"')
        params.initial_a_value = s_val
    end

    local jschl_pattern = html:match("(jschl%-answer[^;]+)")
    params.jschl_answer_fragment = jschl_pattern

    return params
end

function M.extract_js_blocks(html)
    local blocks = {}
    for script_content in html:gmatch('<script[^>]*>(.-)</script>') do
        if #script_content > 100 then
            blocks[#blocks + 1] = script_content
        end
    end
    return blocks
end

function M.run_diagnostic()
    logger.separator()
    logger.info("=== CLOUDFLARE CHALLENGE DIAGNOSTIC ===")

    local body, status, headers, save_path = M.fetch_challenge_page()

    if not body then
        logger.error("no body received, status=" .. tostring(status))
        return
    end

    logger.info("HTTP status: " .. tostring(status))
    logger.info("Body length: " .. #body .. " bytes")
    logger.info("Saved to: " .. save_path)

    local challenge_type = M.identify(body)
    logger.info("Challenge type: " .. challenge_type)

    if challenge_type == "IUAM" then
        local params = M.extract_iuam_params(body)
        logger.info("IUAM params:")
        for k, v in pairs(params) do
            logger.info("  " .. k .. " = " .. tostring(v or "nil"))
        end
    elseif challenge_type == "TURNSTILE" or challenge_type == "MANAGED_CHALLENGE" then
        logger.warn(challenge_type .. " detected! Pure Lua cannot solve this.")
        logger.warn("This challenge requires JS execution + browser fingerprinting.")
        logger.warn("Alternatives:")
        logger.warn("  1. Manually copy cf_clearance cookie from browser into headers.txt")
        logger.warn("  2. Use FlareSolverr proxy service")
        logger.warn("  3. Use a headless browser (puppeteer/playwright) to harvest cookies")
    elseif challenge_type == "JSON_RESPONSE" then
        logger.info("Already got JSON response! Challenge not required.")
    elseif challenge_type == "ACCESS_DENIED" then
        logger.error("Access denied. IP may be blocked or more headers needed.")
    else
        logger.warn("Unknown challenge type. Manual analysis required.")
    end

    logger.preview(body, 3000)
    local js_blocks = M.extract_js_blocks(body)
    logger.info("JS blocks found: " .. #js_blocks)
    for i, js in ipairs(js_blocks) do
        local js_path = SAMPLES_DIR .. "/challenge_js_" .. i .. ".js"
        local f = io.open(js_path, "w")
        if f then
            f:write(js)
            f:close()
            logger.info("  saved JS block " .. i .. " to: " .. js_path)
        end
    end

    logger.info("=== DIAGNOSTIC COMPLETE ===")
    logger.separator()

    return body, challenge_type
end

return M
