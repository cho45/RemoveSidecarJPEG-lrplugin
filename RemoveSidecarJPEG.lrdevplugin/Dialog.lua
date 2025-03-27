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
logger:enable("logfile")

local function showDialog()
	LrFunctionContext.callWithContext( "showDialog", function (context)
		local props = LrBinding.makePropertyTable( context )
		props.totalSize = "calclating..."
		props.isReady = false

		local catalog = LrApplication.activeCatalog()
		local photos = catalog:getMultipleSelectedOrAllPhotos()
		local targets = {}

		LrTasks.startAsyncTask(function () 
			local continue = LrFunctionContext.callWithContext("calclate sidecar jpegs", function (context)
				local progressScope = LrDialogs.showModalProgressDialog {
					title = "Finding Sidecar Files",
					caption = "",
					cannotCancel = false,
					functionContext = context,
					width = 800
				}

				local totalSize = 0
				for i, photo in ipairs(photos) do
					local path = photo:getRawMetadata("path")

					logger:trace(i, #photos, photo)

					progressScope:setPortionComplete(i, #photos)
					progressScope:setCaption(string.format(
						"%d/%d Total Found: %d MB %s",
						i,
						#photos,
						totalSize / 1024 / 1024,
						path
					))

					local isVirtualCopy = photo:getRawMetadata("isVirtualCopy")
					local format = photo:getRawMetadata("fileFormat")

					if not isVirtualCopy and (format == 'RAW' or format == 'DNG') then
						local base = path:gsub("%.[^.]+$", "")

						logger:trace( string.format("Found RAW File %s (base: %s)", path, base) )

						local jpegs = {
							string.format("%s.JPG", base),
							string.format("%s.jpg", base),
						}

						-- treat PXL_20250325_023559643.RAW-02.ORIGINAL.dng -> PXL_20250325_023559643.RAW-01.COVER.jpg pairs
						-- but PXL_20250325_023626919.RAW-01.MP.COVER.jpg (motion photo) is not target
						if path:match("%-02.ORIGINAL%.dng$") then
							local cover = path:gsub("%-02.ORIGINAL%.dng$", "-01.COVER.jpg")
							table.insert(jpegs, cover)
						end

						for _, jpeg in ipairs(jpegs) do
							local photo = catalog:findPhotoByPath(jpeg)
							logger:trace( string.format("Check %s %s", jpeg, photo) )
							if photo then
								local attr = LrFileUtils.fileAttributes(jpeg)
								logger:trace( string.format("Get attr %s %s", jpeg, attr.fileSize) )
								if attr.fileSize then
									totalSize = totalSize + attr.fileSize
									logger:trace( string.format("Found Sidecar JPEG File %s (size: %d)", jpeg, attr.fileSize) )
								end
								table.insert(targets, photo)
								break
							end
						end

						props.totalSize = totalSize
					end

					if progressScope:isCanceled() then
						logger:trace("Canceled")
						return false
					end
				end
				props.isReady = true
				progressScope:done()
				logger:trace( string.format("Ready %s", targets) )
				return true
			end)

			logger:trace( string.format("continue? %s", continue) )
			if not continue then
				return
			end

			LrTasks.yield()

			if #targets > 0 then
				local confirm = LrDialogs.confirm(
					"Sure to select sidecar JPEGs to trash?", 
					string.format("%d files (%d MB)", #targets, props.totalSize / 1024 / 1024), 
					"Select sidecar JPEGs", 
					"Cancel"
				)
				logger:trace( string.format("confirm: %s", confirm) )

				if confirm == "ok" then
					catalog:setSelectedPhotos(targets[1], targets)
				end
			else
				LrDialogs.message("No sidecar JPEGs found.", nil, "info" )
			end
		end, "Calculating Total Size")
	end)
end

showDialog();
