require("util")

function PLUGIN:PostInstall(ctx)
    local sdkInfo = ctx.sdkInfo["ruby"]
    if RUNTIME.osType == "windows" then
        makeGemsPath(sdkInfo.path)
        return
    end
    unixInstall(ctx.rootPath, sdkInfo.path, sdkInfo.version)
end