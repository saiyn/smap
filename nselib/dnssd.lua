local dns = require "dns"
local stdnse = require "stdnse"

_ENV = stdnse.module("dnssd", stdnse.seeall)


Comm = {
	
	queryAllServices = function(host, port)
		local sendCnt, timeout = 2, 5000
		return dns.query("_services._dns-sd._udp.local", {port = port, host = host, dtype="PTR", retAll=true, multiple=true, sendCount=sendCnt,
			timeout=timeout } )

	end

}



Helper = {

	new = function(self, host, port)
		local o = {}
		setmetatable(o, self)
		self.__index = self
		o.host = host
		o.port = port
		o.mcast = true
		return o
	end,

	queryServices = function(self, service)
		local result = {}
		local status, response
		local port = self.port or 5353
		local host = self.host or "224.0.0.251"
		
		if(not(service)) then
			status, response = Comm.queryAllServices(host, port)
			if(not(status)) then
				print("query service fail")
				return status, response
			end

		else
			print("specific service not supported now")

		end


		

	
	end

}


return _ENV


