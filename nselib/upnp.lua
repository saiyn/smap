local stdnse = require "stdnse"
local http = require "http"

local LOG_INFO = stdnse.log_info

_ENV = stdnse.module("upnp", stdnse.seeall)

Comm = {

	new = function(self, host, port)
		local o = {}
		setmetatable(o, self)
		self.__index = self
		o.host = host
		o.port = port
		o.mcast = true

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

		if(not(status)) then return false, err end

		return true

	end,

	receiveResponse = function(self)
		local status, response
		local result = {}
		local host_responses = {}

		repeat
			status, response = self.socket:receive()
			if(not(status) and #response == 0) then
				return false, response
			elseif(not(status)) then
				break
			end

			local status,_,_,ip,_ = self.socket:get_info()
			if(not(status)) then
				return false, "failed to retrieve socket information"
			end

			LOG_INFO("UPNP.LUA", "upnp receive from:%s\n", ip)
			--print("upnp receive from:" .. ip .. "response" .. response)

			if(not(host_responses[ip])) then
				local status, output = self:decodeResponse(response)
				if(not(status)) then
					return false, "failed to decode upnp response"
				end

				output = {output}

				output.name = ip

				table.insert(result, output)

				host_responses[ip] = true
			else

				LOG_INFO("UPNP.LUA", "ignore response:%s\n", response);
				--print("ignore response: " .. response)
			end


		until (not(self.mcast))

		return true, result

	end,

	decodeResponse = function(self, response)
		local output = {}

		if response == nil then
			return false, "nil response"
		end

		local server, location
		server = string.match(response, "[Ss][Ee][Rr][Vv][Ee][Rr]:%s*(.-)\r?\n")
		if server ~= nil then table.insert(output, "Server: " .. server) end

		location = string.match(response, "[Ll][Oo][Cc][Aa][Tt][Ii][Oo][Nn]:%s*(.-)\r?\n")
		if location ~= nil then 
			table.insert(output, "Location: " .. location)
			
			local status,result = self:retrieveXML(location)
			if status then
				table.insert(output, result)
			end
		end

		if #output > 0 then
			return true, output
		else
			return false, "could not decode response"
		end
		

		return true, output
	end,

	retrieveXML = function(self, location)
		local response 
		local options = {}
		options['header'] = {}
		options['header']['Accept'] = "text/xml, application/xml, text/html"

		response = http.get_url(location, options)

		--print(response['body'])

		--stdnse.serialize(response)

		if response ~= nil then
			local output = {}

			for device in string.gmatch(response['body'], "<deviceType>(.-)</UDN>") do
				local fn, mnf, mdl, nm, ver

				
				LOG_INFO("UPNP.LUA", "device description:%s\n", device)
				--print("-----------deive: " .. device)

				fn = string.match(device, "<friendlyName[ ]*>(.-)</friendlyName>")
				mnf = string.match(device, "<manufacturer[ ]*>(.-)</manufacturer>")
				mdl = string.match(device, "<modelDescription[ ]*>(.-)</modelDescription>")
				nm = string.match(device, "<modelName[ ]*>(.-)</modelName>")
				ver = string.match(device, "<modelNumber[ ]*>(.-)</modelNumber>")

				if fn ~= nil then table.insert(output, "Name: " .. fn) end
				if mnf ~= nil then table.insert(output, "Manufacturer: " .. mnf) end
				if mdl ~= nil then table.insert(output, "Model Descr: " .. mdl) end
				if nm ~= nil then table.insert(output, "Model Name: " .. nm) end
				if ver ~= nil then table.insert(output, "Model Version: " .. ver) end


				LOG_INFO("UPNP.LUA", "retrieve result,fn:%s, mnf:%s\n", fn, mnf);

				--print("retrieve result fn: " .. fn .. "mnf: " .. mnf .. "mdl: " .. mdl .. "nm: " .. nm)
			end

			return true, output
		else
			return false, "Could not retrieve xml file"
		end

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





