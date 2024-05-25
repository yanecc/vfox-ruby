local http = require("http")
local strings = require("vfox.strings")
local condaVersions = {
    "3.2.2",
    "3.1.2",
    "3.1.1",
    "3.1.0",
    "2.7.2",
    "2.6.6",
    "2.6.5",
    "2.6.3",
    "2.5.7",
    "2.5.5",
    "2.4.5",
    "2.4.4",
    "2.4.3",
    "2.4.2",
    "2.4.1",
    "2.3.3",
}

function compareVersion(currentVersion, targetVersion)
    local currentVersionArray = strings.split(currentVersion, ".")
    local compareVersionArray = strings.split(targetVersion, ".")

    for i, v in ipairs(currentVersionArray) do
        if tonumber(v) > tonumber(compareVersionArray[i]) then
            return 1
        elseif tonumber(v) < tonumber(compareVersionArray[i]) then
            return -1
        end
    end
    return 0
end

function sortVersions(versions)
    table.sort(versions, function(a, b)
        return compareVersion(a, b) == 1
    end)
end

-- pre_install.lua
function getDownloadInfo(version)
    local file
    if version == "latest" then
        version = getLatestVersion()
    end
    file = generateURL(version, RUNTIME.osType, RUNTIME.archType)

    return file, version
end

function getLatestVersion()
    local version
    if RUNTIME.osType == "windows" then
        version = getLatestVersionFromRubyInstaller()
    else
        version = condaVersions[1]
    end

    return version
end

function getLatestVersionFromRubyInstaller()
    local resp, err = http.get({
        url = "https://rubyinstaller.org/downloads/",
    })
    if err ~= nil then
        error("Failed to request: " .. err)
    end
    if resp.status_code ~= 200 then
        error("Failed to get latest version: " .. err .. "\nstatus_code => " .. resp.status_code)
    end
    local version = resp.body:match("Ruby (%d.%d.%d+)-1 %(x64%)")

    return version
end

-- available.lua
function fetchAvailable(noCache)
    local result = {}
    if noCache then
        clearCache()
    end
    if RUNTIME.osType == "windows" then
        result = fetchFromRubyInstaller()
    else
        result = fetchFromCondaForge()
    end

    return result
end

function fetchFromRubyInstaller()
    local result = {}
    local versions = {}
    local resp, err = http.get({
        url = "https://rubyinstaller.org/downloads/archives/",
    })
    if err ~= nil then
        error("Failed to request: " .. err)
    end
    if resp.status_code ~= 200 then
        error("Failed to get information: " .. err .. "\nstatus_code => " .. resp.status_code)
    end

    local firstLoop = true
    for version in resp.body:gmatch('7z">Ruby (%d.%d.%d+)-1 %(x64%)') do
        table.insert(versions, version)
    end
    sortVersions(versions)
    for i, v in ipairs(versions) do
        if i == 1 then
            table.insert(result, {
                version = v,
                note = "latest",
            })
        else
            table.insert(result, {
                version = v,
            })
        end
    end

    return result
end

function fetchFromCondaForge()
    local result = {}
    for i, v in ipairs(condaVersions) do
        if i == 1 then
            table.insert(result, {
                version = v,
                note = "latest",
            })
        else
            table.insert(result, {
                version = v,
            })
        end
    end

    return result
end

function clearCache()
    os.remove(RUNTIME.pluginDirPath .. "/available.cache")
end

function generateURL(version, osType, archType)
    local file
    local githubURL = os.getenv("GITHUB_URL") or "https://github.com/"
    if osType == "windows" then
        local bit = archType == "amd64" and "64" or "86"
        file = githubURL:gsub("/$", "")
            .. "/oneclick/rubyinstaller2/releases/download/RubyInstaller-%s-1/rubyinstaller-%s-1-x%s.7z"
        file = file:format(version, version, bit)
    end

    return file
end

function generateMacroMamba(osType, archType)
    local file
    local githubURL = os.getenv("GITHUB_URL") or "https://github.com/"
    if osType == "darwin" then
        osType = "osx"
    end
    if archType == "amd64" then
        archType = "64"
    elseif archType == "arm64" then
        if osType == "linux" then
            archType = "aarch64"
        end
    else
        error("Unsupported architecture: " .. archType)
    end
    file = githubURL:gsub("/$", "") .. "/mamba-org/micromamba-releases/releases/latest/download/micromamba-%s-%s"
    file = file:format(osType, archType)

    return file
end

function downloadMacroMamba(path)
    local file = generateMacroMamba(RUNTIME.osType, RUNTIME.archType)
    local err = http.download_file({
        url = file,
    }, path)
    if err ~= nil then
        error("Failed to download micromamba: " .. err)
    end
end
