require("util")

function PLUGIN:PreInstall(ctx)
    local file, version, sha256 = getDownloadInfo(ctx.version)
    return {
        url = file,
        version = version,
        sha256 = sha256
    }
end