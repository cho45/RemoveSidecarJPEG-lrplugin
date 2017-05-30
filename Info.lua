return {

	LrSdkVersion = 3.0,

	LrToolkitIdentifier = 'net.lowreal.RemoveSidecarJPEG',
	LrPluginName = "RemoveSidecarJPEG",

	LrLibraryMenuItems = {
		{
			title = LOC "Remove Sidecar JPEG...",
			file = "Dialog.lua",
			enabledWhen = "anythingSelected",
		},
	},

	VERSION = { major=3, minor=0, revision=0, build=200000, },
}
