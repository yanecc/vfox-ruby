require("util")

function PLUGIN:PostInstall(ctx)
    if RUNTIME.osType == "windows" then
        return
    end
    
    local sdkInfo = ctx.sdkInfo["ruby"]
    mambaInstall(sdkInfo.path, sdkInfo.version)
end