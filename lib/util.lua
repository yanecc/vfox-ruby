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

function clearCache()
    os.remove(RUNTIME.pluginDirPath .. "/available.cache")
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

function sortVersions(versions)
    table.sort(versions, function(a, b)
        return compareVersion(a, b) == 1
    end)
end

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

function generateURL(version, osType, archType)
    local file
    local githubURL = os.getenv("GITHUB_URL") or "https://github.com/"
    if osType == "windows" then
        local bit = archType == "amd64" and "64" or "86"
        file = githubURL:gsub("/$", "")
            .. "/oneclick/rubyinstaller2/releases/download/RubyInstaller-%s-1/rubyinstaller-%s-1-x%s.7z"
        file = file:format(version, version, bit)
    elseif not hasValue(condaVersions, version) then
        print("Unsupported version: " .. version)
        os.exit(1)
    end

    return file
end

function hasValue(table, value)
    for _, v in ipairs(table) do
        if v == value then
            return true
        end
    end

    return false
end

-- post_install.lua
function mambaInstall(path, version)
    local macromamba = path .. "/macromamba"
    downloadMacroMamba(macromamba)
    local command1 = "chmod +x " .. macromamba
    local status = os.execute(command1)
    if status ~= 0 then
        print("Failed to execute command: " .. command1)
        os.exit(1)
    end
    local condaForge = os.getenv("Conda_Forge") or "conda-forge"
    local command2 = macromamba
        .. " create -yqp "
        .. path
        .. "/temp -r "
        .. path
        .. " ruby="
        .. version
        .. " -c "
        .. condaForge
    local status = os.execute(command2)
    if status ~= 0 then
        print("Failed to execute command: " .. command2)
        os.exit(1)
    end
    local command3 = "mv " .. path .. "/temp/* " .. path
    local status = os.execute(command3)
    if status ~= 0 then
        print("Failed to execute command: " .. command3)
        os.exit(1)
    end
    local command4 = "mkdir -p " .. path .. "/share/gems/bin"
    local status = os.execute(command4)
    if status ~= 0 then
        print("Failed to execute command: " .. command4)
        os.exit(1)
    end
    os.remove(macromamba)
    local command5 = "rm -rf " .. path .. "/temp " .. path .. "/pkgs " .. path .. "/etc " .. path .. "/conda-meta"
    local status = os.execute(command5)
    if status ~= 0 then
        print("Failed to execute command: " .. command5)
        os.exit(1)
    end
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
    elseif archType == "ppc64le" and osType == "linux" then
    else
        print("Unsupported environment: " .. osType .. "-" .. archType)
        os.exit(1)
    end
    file = githubURL:gsub("/$", "") .. "/mamba-org/micromamba-releases/releases/latest/download/micromamba-%s-%s"
    file = file:format(osType, archType)

    return file
end
