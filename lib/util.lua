local http = require("http")
local strings = require("vfox.strings")
local unixRubyVersions = {
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
    "24.0.1",
    "24.0.0",
    "23.1.2",
    "23.1.1",
    "23.1.0",
    "23.0.1",
    "23.0.0",
    "22.3.1",
    "22.3.0",
    "22.2.0",
    "22.1.0",
    "22.0.0.2",
    "21.3.0",
    "21.2.0.1",
    "21.2.0",
    "21.1.0",
    "21.0.0.2",
    "21.0.0",
    "20.3.0",
    "20.2.0",
    "20.1.0",
    "20.0.0",
}

-- available.lua
function fetchAvailable(noCache)
    local result = {}
    if noCache then
        clearCache()
    end
    if RUNTIME.osType == "windows" then
        result = fetchForWindows()
    else
        result = fetchForUnix()
    end

    return result
end

function clearCache()
    os.remove(RUNTIME.pluginDirPath .. "/available.cache")
end

function fetchForWindows()
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

    for i, v in ipairs(compareVersionArray) do
        if tonumber(currentVersionArray[i]) > tonumber(v) then
            return 1
        elseif tonumber(currentVersionArray[i]) < tonumber(v) then
            return -1
        end
    end

    return 0
end

function fetchForUnix()
    local result = {}
    for i, v in ipairs(unixRubyVersions) do
        if i == 1 then
            table.insert(result, {
                version = v,
                note = "latest",
            })
        elseif compareVersion(v, "20.0.0") >= 0 then
            table.insert(result, {
                version = v,
                note = "truffleruby",
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
        version = unixRubyVersions[1]
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
    elseif osType ~= "darwin" and osType ~= "linux" then
        print("Unsupported OS: " .. osType)
        os.exit(1)
    elseif not hasValue(unixRubyVersions, version) then
        print("Unsupported version: " .. version)
        os.exit(1)
    elseif compareVersion(version, "20.0.0") >= 0 then
        file = generateTruffleRuby(version, osType, archType)
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

function generateTruffleRuby(version, osType, archType)
    local file
    local githubURL = os.getenv("GITHUB_URL") or "https://github.com/"
    local tag = compareVersion(version, "23.0.0") >= 0 and "graal-" .. version or "vm-" .. version

    if compareVersion(version, "22.2.0") < 0 and archType == "arm64" then
        print("Unsupported version " .. version .. " for " .. archType)
        os.exit(1)
    end
    if archType == "arm64" then
        archType = "aarch64"
    end
    if osType == "darwin" then
        osType = "macos"
    end
    file = githubURL:gsub("/$", "") .. "/oracle/truffleruby/releases/download/%s/truffleruby-%s-%s-%s.tar.gz"
    file = file:format(tag, version, osType, archType)

    return file
end

-- post_install.lua
function unixInstall(path, version)
    if compareVersion(version, "20.0.0") >= 0 then
        patchTruffleRuby(path)
    else
        mambaInstall(path, version)
    end
end

function patchTruffleRuby(path)
    local command1 = path .. "/lib/truffle/post_install_hook.sh > /dev/null"
    local command2 = "mkdir -p " .. path .. "/share/gems/bin"
    local command3 = "rm -rf " .. path .. "/src"

    for _, command in ipairs({ command1, command2, command3 }) do
        local status = os.execute(command)
        if status ~= 0 then
            print("Failed to execute command: " .. command)
            os.exit(1)
        end
    end
end

function mambaInstall(path, version)
    local macromamba = path .. "/macromamba"
    local condaForge = os.getenv("Conda_Forge") or "conda-forge"
    local command1 = "chmod +x " .. macromamba
    local command2 = macromamba
        .. " create -yqp "
        .. path
        .. "/temp -r "
        .. path
        .. " ruby="
        .. version
        .. " -c "
        .. condaForge
    local command3 = "mv " .. path .. "/temp/* " .. path
    local command4 = "mkdir -p " .. path .. "/share/gems/bin"
    local command5 = "rm -rf " .. path .. "/temp " .. path .. "/pkgs " .. path .. "/etc " .. path .. "/conda-meta"

    downloadMacroMamba(macromamba)
    for _, command in ipairs({ command1, command2, command3, command4, command5 }) do
        local status = os.execute(command)
        if status ~= 0 then
            print("Failed to execute command: " .. command)
            os.exit(1)
        end
    end
    os.remove(macromamba)
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

function makeGemsPath(path)
    local gemsPath = path .. "\\share\\gems\\bin"
    local command = "mkdir " .. gemsPath
    local status = os.execute(command)
    if status ~= 0 then
        print("Failed to execute command: " .. command)
        os.exit(1)
    end
end
