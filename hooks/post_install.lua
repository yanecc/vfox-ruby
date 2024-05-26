require("util")

function PLUGIN:PostInstall(ctx)
    local sdkInfo = ctx.sdkInfo["ruby"]
    if RUNTIME.osType == "windows" then
        makeGemsPath(sdkInfo.path)
        return
    end
    mambaInstall(sdkInfo.path, sdkInfo.version)
end