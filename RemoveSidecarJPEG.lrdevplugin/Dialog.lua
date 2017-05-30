local LrFunctionContext = import 'LrFunctionContext'
local LrBinding = import 'LrBinding'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrTasks = import 'LrTasks'
local LrLogger = import 'LrLogger'
local LrProgressScope = import 'LrProgressScope'
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

		LrTasks.startAsyncTask(function () 
			LrFunctionContext.callWithContext("calclate sidecar jpegs", function (context)
				local progressScope = LrDialogs.showModalProgressDialog {
					title = "Finding Sidecar Files",
					caption = "",
					cannotCancel = false,
					functionContext = context,
				}

				local totalSize = 0
				for i, photo in ipairs(photos) do
					logger:trace(i, #photos, photo)
					progressScope:setPortionComplete(i, #photos)
					progressScope:setCaption(string.format("%d/%d total: %d MB: ", i, #photos, totalSize / 1024 / 1024))

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

					if progressScope:isCanceled() then
						logger:trace("Canceled")
						return
					end
				end
				props.isReady = true
				progressScope:done()
				logger:trace( string.format("Ready %s", targets) )
			end)
			LrTasks.yield()

			if #targets > 0 then
				local confirm = LrDialogs.confirm(
					"Sure to move sidecar JPEGs to trash?", 
					string.format("%d files (%d MB)", #targets, props.totalSize / 1024 / 1024), 
					"Move to Trash", 
					"Cancel"
				)
				logger:trace( string.format("confirm: %s", confirm) )

				if confirm == "ok" then
					LrFunctionContext.callWithContext("remove sidecar jpegs", function (context)
						local progressScope = LrProgressScope {
							title = "Removing sidecar JPEG",
							functionContext = context,
						}
						for i, target in ipairs(targets) do
							progressScope:setPortionComplete(i, #targets)
							progressScope:setCaption(string.format("%s", target))
							logger:trace(i, #targets, target)
							LrFileUtils.moveToTrash(target)
						end
					end)
				end
			else
				LrDialogs.message("No sidecar JPEGs found.", nil, "info" )
			end
		end, "Calculating Total Size")
	end)
end

showDialog();
