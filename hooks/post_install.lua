require("util")

function PLUGIN:PostInstall(ctx)
    if RUNTIME.osType == "windows" then
        return
    end
    --- ctx.rootPath SDK installation directory
    local rootPath = ctx.rootPath -- .version-fox/cache/ruby/v-3.3.1
    local sdkInfo = ctx.sdkInfo["ruby"]
    local path = sdkInfo.path -- .version-fox/cache/ruby/v-2.4.9/ruby-2.4.9
    local macromamba = path .. "/macromamba"
    downloadMacroMamba(macromamba)
    local command1 = "chmod +x " .. macromamba
    local status = os.execute(command1)
    if status ~= 0 then
        error("Failed to execute command: " .. command1)
    end
    local condaForge = os.getenv("Conda_Forge") or "conda-forge"
    -- ./micromamba create -yqp /root/pixi/env -r /root/pixi ruby=3.1.1 --channel conda-forge
    local command2 = macromamba
        .. " create -yqp "
        .. path
        .. "/temp -r "
        .. path
        .. " ruby="
        .. sdkInfo.version
        .. " -c "
        .. condaForge
    local status = os.execute(command2)
    if status ~= 0 then
        error("Failed to execute command: " .. command2)
    end
    local command3 = "mv " .. path .. "/temp/* " .. path
    local status = os.execute(command3)
    if status ~= 0 then
        error("Failed to execute command: " .. command3)
    end
    os.remove(macromamba)
    local command4 = "rm -rf " .. path .. "/temp " .. path .. "/pkgs"
    local status = os.execute(command4)
    if status ~= 0 then
        error("Failed to execute command: " .. command4)
    end
end
