local dns = require "dns"
local stdnse = require "stdnse"
local LOG_INFO = stdnse.log_info
local LOG_WARN = stdnse.log_warn

_ENV = stdnse.module("dnssd", stdnse.seeall)


Comm = {


	queryService = function(host, port, service)
		local sendCnt, timeout = 1, 5000

		LOG_INFO("try to query serive: " .. service)

		return dns.query(service, {port = port, host = host, dtype="PTR",retPkt=true,multiple=true,sendCount=sendCnt, timeout=timeout})
	end,
	
	queryAllServices = function(host, port)
		local sendCnt, timeout = 1, 5000
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
				LOG_WARN("query service fail")
				return status, response
			end

		else
			LOG_INFO("specific service not supported now")

		end

		
		for _, v in ipairs(response) do
			for _,service in ipairs(v.output) do

				status, res = Comm.queryService(host, port, service)
				
				table.insert(result, res)

			end
		end


		return true, result
		
	end

}


return _ENV


