return {
    LrSdkVersion = 6.0,
    LrSdkMinimumVersion = 6.0,

    LrToolkitIdentifier = "com.axiom.lightroom.mcp.custom",
    LrPluginName = "Lightroom MCP Custom",

    LrInitPlugin = "PluginInit.lua",
    LrForceInitPlugin = true,
    LrShutdownPlugin = "PluginShutdown.lua",

    LrExportMenuItems = {
        {
            title = "Lightroom MCP: Start Bridge",
            file = "MenuStart.lua",
        },
        {
            title = "Lightroom MCP: Stop Bridge",
            file = "MenuStop.lua",
        },
        {
            title = "Lightroom MCP: Show Status",
            file = "MenuStatus.lua",
        },
        {
            title = "Lightroom MCP: Restart Bridge",
            file = "MenuRestart.lua",
        },
    },

    VERSION = { major = 0, minor = 4, revision = 0, build = 0 },
}
