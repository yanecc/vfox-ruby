function PLUGIN:EnvKeys(ctx)
    local mainPath = ctx.path

    return {
        {
            key = "PATH",
            value = mainPath .. "/bin"
        },
        {
            key = "PATH",
            value = mainPath .. "/share/gems/bin"
        },
        {
            key = "GEM_HOME",
            value = mainPath .. "/share/gems"
        }
    }
end