local upnp = require "upnp"

action = function()
	local helper = upnp.Helper:new()

	local status, result = helper:queryServices()

	print(result)

end


