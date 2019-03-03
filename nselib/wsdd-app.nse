local wsdd = require "wsdd"

action = function()

	local helper = wsdd.Helper:new("239.255.255.250", 3702)

	helper:setTimeout(5000)

	local status, result = helper['discoverDevices'](helper)
	

	print(result)
end





