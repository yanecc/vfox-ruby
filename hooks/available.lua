require("util")

function PLUGIN:Available(ctx)
    local buildArg = hasValue(ctx.args, "--ruby-build")
    local cacheArg = hasValue(ctx.args, "--no-cache")
    if cacheArg then
        clearCache()
    end
    return fetchAvailable(buildArg)
end