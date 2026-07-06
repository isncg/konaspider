local http = require "src.http"
local logger = require "src.logger"
local flaresolverr = require "src.flaresolverr"
local cookie = require "src.cookie"
local json = require "cjson"
local io = require "io"
local lfs = require "lfs"

local TARGET_URL = "https://konachan.net/post.json"
local DATA_DIR = ".data"

http.load_headers()

function ensure_dir(dir)
    if not lfs.attributes(dir) then
        lfs.mkdir(dir)
    end
end

function parse_and_save_json(body)
    -- Try to decode JSON (response might be a single JSON object or HTML)
    local ok, data = pcall(json.decode, body)
    if not ok or not data then
        logger.warn("response is not valid JSON, checking if it's still a challenge page...")
        if body:find("challenges.cloudflare.com") or body:find("cf_chl") then
            logger.error("still got challenge page - FlareSolverr did not solve it")
        end
        return false
    end

    logger.info("JSON parsed successfully")
    if type(data) == "table" then
        if #data > 0 then
            logger.info("  array length: " .. #data)
            logger.info("  first entry keys: " .. table.concat(keys_of(data[1]), ", "))
        end
    end

    ensure_dir(DATA_DIR)
    local path = DATA_DIR .. "/post.json"
    local f = io.open(path, "w")
    if f then
        f:write(body)
        f:close()
        logger.info("saved response to: " .. path)
    end

    return true
end

function keys_of(t)
    local keys = {}
    for k, _ in pairs(t) do
        keys[#keys + 1] = tostring(k)
    end
    return keys
end

function save_cookies_to_headers(cookies)
    -- Save cf_clearance and other cookies to header file for direct use
    -- This allows subsequent runs without FlareSolverr if cookie is still valid
    local cookie_str = ""
    for name, value in pairs(cookies) do
        cookie.set(name, value)
        cookie_str = cookie_str .. name .. "=" .. value .. "; "
    end
    logger.info("cookies saved to jar")
end

-- Main flow
print("=== KonaSpider ===")
print("Attempting FlareSolverr at " .. flaresolverr.FLARESOLVERR_URL .. " ...")
print()

local body, status, cookies = flaresolverr.fetch(TARGET_URL)

if body and status == 200 then
    save_cookies_to_headers(cookies or {})
    local ok = parse_and_save_json(body)

    print("FlareSolverr: SUCCESS")
    print("Body: " .. #body .. " bytes")
    if ok then
        print("Output: " .. DATA_DIR .. "/post.json")
    end
else
    print("FlareSolverr: FAILED (status=" .. tostring(status) .. ")")
    print()
    print("Trying direct request for diagnosis...")
    local cf = require "src.cf_challenge"
    local diag_body, diag_type = cf.run_diagnostic()
    print("Diagnostic: " .. tostring(diag_type))
end

print()
print("Full log: " .. logger.log_path)
