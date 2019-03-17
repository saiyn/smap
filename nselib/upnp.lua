local stdnse = require "stdnse"

_ENV = stdnse.module("upnp", stdnse.seeall)

Comm = {

	new = function(self, host, port)
		local o = {}
		setmetatable(o, self)
		self.__index = self
		o.host = host
		o.port = port
		o.mcast = ture

		return o

	end,
	

	connect = function(self)
		if(self.mcast) then
			self.socket = nsock.new("udp")
			self.socket:set_timeout(5000)
		else
			self.socket = nsock.new()
			self.socket:set_timeout(5000)
			local status, err = self.socket:connect(self.host, self.port, "udp")
			if(not(status)) then return false, err end
		end

		return true
	end,

	sendRequest = function(self)

		local payload = 'M-SEARCH * HTTP/1.1\r\n\z
		Host:239.255.255.250:1900\r\n\z
		ST:upnp:rootdevice\r\n\z
		Man:"ssdp:discover"\r\n\z
		MX:3\r\n\r\n'

		local status, err
		
		if(self.mcast) then
			status, err = self.socket:sendto(self.host, self.port, payload)
		else
			status, err = self.socket:send(payload)
		end

		--if(not(status)) then return false, err end

		return true

	end,

	receiveResponse = function(self)
		local status, response
		local result = {}
		local host_response = {}

		repeat
			status, response = self.socket:receive()
			--if(not(status) and #response == 0) then
			--	return false, response
			--elseif(not(status)) then
			--	break
			--end

			local status,_,_,ip,_ = self.socket:get_info()
			if(not(status)) then
				return false, "failed to retrieve socket information"
			end

			print("upnp receive from:" .. ip .. "response" .. response)

		until (not(self.mcast))

	end,

	close = function(self) self.socket:close() end

}	


Helper = {
	
	new = function(self, host, port)
		local o = {}

		setmetatable(o, self)
		self.__index = self

		if host == nil then host = '239.255.255.250' end
		if port == nil then port = '1900' end


		o.comm = Comm:new(host,port)

		return o
	end,

	queryServices = function(self)
		local status, err = self.comm:connect()
		local response

		if(not(status)) then return false, err end

		status, err = self.comm:sendRequest()
		--if(not(status)) then return false, err end

		status, response = self.comm:receiveResponse()
		--self.comm:close()

		return status, response
		
	end,
}


return _ENV





