local http = require("http")
local json = require("json")
local strings = require("vfox.strings")

function fetchManifest()
    local manifest
    local githubURL = os.getenv("GITHUB_URL") or "https://github.com/"
    local resp, err = http.get({
        url = githubURL:gsub("/$", "") .. "/yanecc/vfox-ruby/releases/manifest",
    })
    if err ~= nil then
        error("Failed to request: " .. err)
    end
    if resp.status_code ~= 200 then
        error("Failed to get versions: " .. err .. "\nstatus_code => " .. resp.status_code)
    end
    manifest = resp.body:match("<code>(.-)</code>")
    manifest = json.decode(manifest)

    return manifest
end

local Manifest = fetchManifest()

-- available.lua
function fetchAvailable(buildArg)
    local result = {}

    if RUNTIME.osType == "windows" then
        result = fetchForWindows()
    elseif buildArg then
        for _, v in ipairs(Manifest["ruby-build"]) do
            table.insert(result, {
                version = v,
            })
        end
        return result
    else
        result = fetchForUnix()
    end
    for _, v in ipairs(Manifest.jruby) do
        table.insert(result, {
            version = v,
            note = "jruby",
        })
    end

    return result
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
        error("Failed to get Ruby versions: " .. err .. "\nstatus_code => " .. resp.status_code)
    end

    for version in resp.body:gmatch('7z">Ruby (%d.%d.%d+)%-1 %(x64%)') do
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

    for i, v in ipairs(Manifest.ruby) do
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

function clearCache()
    os.remove(RUNTIME.pluginDirPath .. "/available.cache")
    os.exit()
end

-- pre_install.lua
function getDownloadInfo(version)
    local file, sha256

    if version == "latest" then
        version = getLatestVersion()
    end
    file, sha256 = generateURL(version, RUNTIME.osType, RUNTIME.archType)

    return file, version, sha256
end

function getLatestVersion()
    local version

    if RUNTIME.osType == "windows" then
        local resp, err = http.get({
            url = "https://rubyinstaller.org/downloads/",
        })
        if err ~= nil then
            error("Failed to request: " .. err)
        end
        if resp.status_code ~= 200 then
            error("Failed to get latest version: " .. err .. "\nstatus_code => " .. resp.status_code)
        end
        version = resp.body:match("Ruby (%d.%d.%d+)%-1 %(x64%)")
    else
        version = Manifest.ruby[1]
    end

    return version
end

function generateURL(version, osType, archType)
    local file, sha256

    if hasValue(Manifest.jruby, version) then
        file, sha256 = generateJRuby(version)
    elseif osType == "windows" then
        file, sha256 = generateWindowsRuby(version, archType)
    elseif hasValue(Manifest["ruby-build"], version) then
        file = generateRubyBuild()
    elseif osType ~= "darwin" and osType ~= "linux" then
        print("Unsupported OS: " .. osType)
        os.exit(1)
    elseif not hasValue(Manifest.ruby, version) then
        print("Unsupported version: " .. version)
        os.exit(1)
    elseif hasValue(Manifest.homebrew, version) then
        file = generateHomebrewRuby(version, osType, archType)
    elseif compareVersion(version, "20.0.0") >= 0 then
        file = generateTruffleRuby(version, osType, archType)
    end

    return file, sha256
end

function generateJRuby(version)
    local file, sha256

    if os.getenv("GITHUB_URL") then
        file = os.getenv("GITHUB_URL"):gsub("/$", "") .. "/jruby/jruby/releases/download/%s/jruby-bin-%s.tar.gz"
    else
        file = "https://repo1.maven.org/maven2/org/jruby/jruby-dist/%s/jruby-dist-%s-bin.tar.gz"
    end
    file = file:format(version, version)
    sha256 = "https://repo1.maven.org/maven2/org/jruby/jruby-dist/%s/jruby-dist-%s-bin.tar.gz.sha256"
    local resp, err = http.get({
        url = sha256:format(version, version),
    })
    if err ~= nil then
        error("Failed to request: " .. err)
    end
    if resp.status_code ~= 200 then
        error("Failed to get sha256: " .. err .. "\nstatus_code => " .. resp.status_code)
    end
    sha256 = resp.body

    return file, sha256
end

function generateWindowsRuby(version, archType)
    local file, sha256
    local bit = archType == "amd64" and "64" or "86"
    local githubURL = os.getenv("GITHUB_URL") or "https://github.com/"
    file = githubURL:gsub("/$", "")
        .. "/oneclick/rubyinstaller2/releases/download/RubyInstaller-%s-1/rubyinstaller-%s-1-x%s.7z"
    file = file:format(version, version, bit)

    local resp, err = http.get({
        url = "https://rubyinstaller.org/downloads/archives/",
    })
    if err ~= nil then
        error("Failed to request: " .. err)
    end
    if resp.status_code ~= 200 then
        error("Failed to get sha256: " .. err .. "\nstatus_code => " .. resp.status_code)
    end
    sha256 = resp.body:match(version .. "%-1%-x" .. bit .. '.7z[%s%S]-value="([0-9a-z]+)')

    return file, sha256
end

function generateRubyBuild()
    local githubURL = os.getenv("GITHUB_URL") or "https://github.com/"
    local file = githubURL:gsub("/$", "") .. "/rbenv/ruby-build/tags"
    local resp, err = http.get({
        url = file,
    })
    if err ~= nil then
        error("Failed to request: " .. err)
    end
    if resp.status_code ~= 200 then
        error("Failed to get latest ruby-build: " .. err .. "\nstatus_code => " .. resp.status_code)
    end
    file = resp.body:match("(v%d+)</a>") .. ".tar.gz"
    file = githubURL:gsub("/$", "") .. "/rbenv/ruby-build/archive/refs/tags/" .. file

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

function generateHomebrewRuby(version, osType, archType)
    local file
    local githubURL = os.getenv("GITHUB_URL") or "https://github.com/"
    local releaseURL = githubURL:gsub("/$", "") .. "/Homebrew/homebrew-portable-ruby/releases/"

    if osType == "linux" and archType == "amd64" then
        file = releaseURL .. "download/%s/portable-ruby-%s.x86_64_linux.bottle.tar.gz"
    elseif osType == "darwin" and archType == "amd64" then
        file = releaseURL .. "download/%s/portable-ruby-%s.el_capitan.bottle.tar.gz"
    elseif osType == "darwin" and archType == "arm64" then
        file = releaseURL .. "download/%s/portable-ruby-%s.arm64_big_sur.bottle.tar.gz"
    else
        print("Unsupported environment: " .. osType .. "-" .. archType)
        os.exit(1)
    end
    file = file:format(version, version)

    return file
end

function generateTruffleRuby(version, osType, archType)
    local tag, file
    local githubURL = os.getenv("GITHUB_URL") or "https://github.com/"
    local releaseURL = githubURL:gsub("/$", "") .. "/oracle/truffleruby/releases/"

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
    if version:sub(-4) == ".jvm" and compareVersion(version, "23.1.0") >= 0 then
        version = version:gsub("%.jvm$", "")
        file = releaseURL .. "download/%s/truffleruby-jvm-%s-%s-%s.tar.gz"
    else
        file = releaseURL .. "download/%s/truffleruby-%s-%s-%s.tar.gz"
    end
    tag = compareVersion(version, "23.0.0") >= 0 and "graal-" .. version or "vm-" .. version
    file = file:format(tag, version, osType, archType)

    return file
end

-- post_install.lua
function unixInstall(rootPath, path, version)
    if hasValue(Manifest.homebrew, version) then
        patchHomebrewRuby(path, version)
    elseif hasValue(Manifest.jruby, version) then
        patchJRuby(path)
    elseif hasValue(Manifest["ruby-build"], version) then
        patchRubyBuild(path, version)
    elseif compareVersion(version, "20.0.0") >= 0 then
        patchTruffleRuby(path)
    else
        mambaInstall(rootPath, path, version)
    end
end

function patchHomebrewRuby(path, version)
    local command1 = "mv " .. path .. "/" .. version .. "/* " .. path
    local command2 = "mkdir -p " .. path .. "/share/gems/bin"
    local command3 = "rm -rf " .. path .. "/.brew " .. path .. "/" .. version

    for _, command in ipairs({ command1, command2, command3 }) do
        local status = os.execute(command)
        if status ~= 0 then
            print("Failed to execute command: " .. command)
            os.exit(1)
        end
    end
end

function patchRubyBuild(path, version)
    version = version:gsub("%.mrb$", "")
    version = version:sub(-3) == ".rb" and version:sub(1, -4) or "mruby-" .. version
    local builder = path .. "/../ruby-build"
    local command1 = "mkdir -p " .. builder
    local command2 = "mv " .. path .. "/* " .. path .. "/.git* " .. builder
    local command3 = builder .. "/bin/ruby-build " .. version .. " " .. path .. " > /dev/null"
    local command4 = "mkdir -p " .. path .. "/share/gems/bin"
    local command5 = "rm -rf " .. builder

    for _, command in ipairs({ command1, command2, command3, command4, command5 }) do
        local status = os.execute(command)
        if status ~= 0 then
            print("Failed to execute command: " .. command)
            os.exit(1)
        end
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

function patchJRuby(path)
    local command1 = "mkdir -p " .. path .. "/share/gems/bin"
    local command2 = "rm -f " .. path .. "/bin/*.{exe,bat,dll}"

    for _, command in ipairs({ command1, command2 }) do
        local status = os.execute(command)
        if status ~= 0 then
            print("Failed to execute command: " .. command)
            os.exit(1)
        end
    end
end

function mambaInstall(rootPath, path, version)
    local conda = rootPath .. "/conda"
    local mamba = rootPath .. "/conda/micromamba"
    local condaForge = os.getenv("Conda_Forge") or "conda-forge"
    local command1 = "mv " .. path .. " " .. conda
    local command2 = "chmod +x " .. mamba
    local command3 = mamba .. " create -yqp " .. path .. " -r " .. conda .. " ruby=" .. version .. " -c " .. condaForge
    local command4 = "mkdir -p " .. path .. "/share/gems/bin"
    local command5 = "rm -rf " .. path .. "/etc " .. path .. "/conda-meta " .. conda

    downloadMicroMamba(path .. "/micromamba")
    for _, command in ipairs({ command1, command2, command3, command4, command5 }) do
        local status = os.execute(command)
        if status ~= 0 then
            print("Failed to execute command: " .. command)
            os.exit(1)
        end
    end
end

function downloadMicroMamba(path)
    local file = generateMicroMamba(RUNTIME.osType, RUNTIME.archType)
    local err = http.download_file({
        url = file,
    }, path)
    if err ~= nil then
        error("Failed to download micromamba: " .. err)
    end
end

function generateMicroMamba(osType, archType)
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
