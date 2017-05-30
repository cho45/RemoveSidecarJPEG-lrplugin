local LrFunctionContext = import 'LrFunctionContext'
local LrBinding = import 'LrBinding'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrTasks = import 'LrTasks'
local LrLogger = import 'LrLogger'
local LrFileUtils = import 'LrFileUtils'
local LrApplication = import 'LrApplication'
local logger = LrLogger( 'libraryLogger' )
logger:enable("print")

local function showDialog()
	LrFunctionContext.callWithContext( "showDialog", function (context)
		local f = LrView.osFactory()

		local props = LrBinding.makePropertyTable( context )
		props.totalSize = "calclating..."
		props.isReady = false

		local catalog = LrApplication.activeCatalog()
		local photos = catalog:getMultipleSelectedOrAllPhotos()
		local targets = {}
		local cancel = false

		LrTasks.startAsyncTask(function ()
			local totalSize = 0
			for i, photo in ipairs(photos) do
				logger:trace(i, #photos, photo)
				local isVirtualCopy = photo:getRawMetadata("isVirtualCopy")
				local format = photo:getRawMetadata("fileFormat")

				if not isVirtualCopy and (format == 'RAW' or format == 'DNG') then
					local path = photo:getRawMetadata("path")
					local base = path:gsub("%.[^.]+$", "")

					logger:trace( string.format("Found RAW File %s (base: %s)", path, base) )

					local jpegs = {
						string.format("%s.JPG", base),
						string.format("%s.jpg", base),
					}

					for _, jpeg in ipairs(jpegs) do
						logger:trace( string.format("Check %s", jpeg) )
						if LrFileUtils.isDeletable(jpeg) then
							local attr = LrFileUtils.fileAttributes(jpeg)
							logger:trace( string.format("Get attr %s %s", jpeg, attr.fileSize) )
							if attr.fileSize then
								totalSize = totalSize + attr.fileSize
								logger:trace( string.format("Found Sidecar JPEG File %s (size: %d)", jpeg, attr.fileSize) )
								table.insert(targets, jpeg)
							end
							break
						end
					end

					props.totalSize = totalSize
				end

				if cancel then
					logger:trace("Canceled")
					return
				end
			end
			props.isReady = true
			logger:trace( string.format("Ready %s", targets) )
		end, "Calculating Total Size")

		local c = f:row {
			bind_to_object = props,

			f:static_text {
				title = "Total Size: ",
			},

			f:static_text {
				title = LrView.bind {
					key = "totalSize",
					width_in_chars = 30,
					transform = function (value, fromTable)
						return string.format("%d MB", value / 1024 / 1024)
					end
				}
			},

			f:push_button {
				title = "Remove",
				enabled = LrView.bind("isReady"),

				action = function()
					logger:trace( "Remove button clicked." )
					props.isReady = false
					for i, target in ipairs(targets) do
						logger:trace(i, #targets, target)
					end
					-- memo
					-- LrFileUtils.moveToTrash()
				end,
			},
		}

		local ret = LrDialogs.presentModalDialog {
			title = "Remove Sidecar JPEGs",
			contents = c
		}

		if ret == "cancel" then
			cancel = true
		end

	end)
end

showDialog();
