local dnssd = require "dnssd"

action = function()
	local helper = dnssd.Helper:new()

	local status, result = helper:queryServices()
	
	print("dnssd done")
	print(result)
end
