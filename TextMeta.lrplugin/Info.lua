--[[
        Info.lua
--]]

return {
    appName = "TextMeta",
    author = "Rob Cole",
    authorsWebsite = "www.robcole.com",
    donateUrl = "http://www.robcole.com/Rob/Donate",
    platforms = { 'Windows', 'Mac' },
    pluginId = "com.robcole.lightroom.TextMeta",
    xmlRpcUrl = "http://www.robcole.com/Rob/_common/cfpages/XmlRpc.cfm",
    LrPluginName = "rc TextMeta",
    LrSdkMinimumVersion = 3.0,
    LrSdkVersion = 4.0,
    LrPluginInfoUrl = "http://www.robcole.com/Rob/ProductsAndServices/TextMetaLrPlugin",
    LrPluginInfoProvider = "ExtendedManager.lua",
    LrToolkitIdentifier = "com.robcole.lightroom.TextMeta",
    LrInitPlugin = "Init.lua",
    LrShutdownPlugin = "Shutdown.lua",
    LrMetadataProvider = "Metadata.lua",
    LrLibraryMenuItems = {
        {
            title = "&Update Metadata",
            file = "mUpdateMetadata.lua",
        },
    },
    LrHelpMenuItems = {
        {
            title = "General &Help",
            file = "mHelp.lua",
        },
    },
    VERSION = { display = "1.4    Build: 2012-11-20 01:24:40" },
}
