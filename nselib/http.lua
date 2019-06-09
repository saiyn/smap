local string = require "string"
local stdnse = require "stdnse"
local table = require "table"
local comm = require "comm"


_ENV = stdnse.module("http", stdnse.seeall)

local function LOG_INFO(...) return stdnse.log_info("HTTP.LUA", ...) end


local url = {
	parse = function(url, default)
		local parsed = {}

		url = string.gsub(url, "%%(%x%x)", function(hex)
			local char = string.char(tonumber(hex, 16))
			if string.match(char, "[a-zA-Z0-9._~-]") then
				return char
			end

			return nil
		end)

		-- get fragment
		url = string.gsub(url, "#(.*)$", function(f)
			parsed.fragment = f
			return ""
		end)

		-- get scheme
		url = string.gsub(url, "^(%w[%w.+-]*):",
		function(s) parsed.scheme = string.lower(s); return "" end)

		-- get authority
		url = string.gsub(url, "^//([^/]*)", function(n)
			parsed.authority = n
			return ""
		end)

		-- get query string
		url = string.gsub(url, "%?(.*)", function(q)
			parsed.query = q
			return ""
		end)
		
		-- get params
		url = string.gsub(url, "%;(.*)", function(p)
			parsed.params = p
			return ""
		end)

		--path is whatever was left
		parsed.path = url

		if parsed.path:sub(-1) == "/" then
			parsed.is_folder = true
		else
			parsed.is_folder = false
			parsed.extension = parsed.path:match("%.([^/.;]+)%f[;\0][^/]*$")
		end

		local authority = parsed.authority
		if not authority then return parsed end

		authority = string.gsub(authority, "([^@]*)@", 
				function(u) parsed.userinfo = u; return "" end)

		authority = string.gsub(authority, ":(%d+)$", 
				function(p) parsed.port = tonumber(p); return "" end)

		if authority ~= "" then parsed.host = authority end

		local userinfo = parsed.userinfo
		if not userinfo then return parsed end

		userinfo = string.gsub(userinfo, ":([^:]*)$", 
				function(p) parsed.password = p; return "" end)


		parsed.user = userinfo
			

			
		return parsed

	end,

}


local function build_request(host, port, method, path, options)
	options = options or {}

	local mod_options = {
		header = {
			Connection = "close",
			Host = host,
			["User-Agent"] = USER_AGENT
		}
	}

	local request_line = method.." "..path.." HTTP/1.1"
	local header = {}
	for name, value in pairs(mod_options.header) do
		header[#header + 1] = name..": "..value
	end

	return request_line .. "\r\n" .. table.concat(header, "\r\n") .. "\r\n\r\n" .. ""
end

local function do_connect(host, port, data, options)
	if options.scheme == "https" or options.scheme == "http" then
		return comm.opencon(host, port, data, {
			timeout = 30000,
			any_af = options.any_af,
			proto = (options.scheme == "https" and "ssl" or "tcp"),
		})
	end
end


local function recv_line(s, partial)
	local _, e
	local status, data
	local pos

	partial = partial or ""

	pos = 1
	while true do
		_, e = string.find(partial, "\n", pos, true)
		if e then
			break
		end

		status, data = s:receive()
		if not status then
			return status, data
		end

		pos = #partial
		partial = partial .. data
	end

	return string.sub(partial, 1, e), string.sub(partial, e+1)
end


local function parse_status_line(status_line, response)
	response["status-line"] = status_line

	local version, status, reason_phrase = string.match(status_line, 
		"^HTTP/(%d+%.%d+) +(%d+)%f[ \r\n] *(.-)\r?\n$")

	if not version then
		return nil, string.format("Error parsing status-line %q.", status_line)
	end

	response.version = version
	response.status = tonumber(status)
	if not response.status then
		return nil, string.format("Status code is not numeric: %s", status)
	end

	return true

end


local function recv_header(s, partial)
	local lines = {}

	partial = partial or ""

	while true do
		local line
		line, partial = recv_line(s, partial)
		if not lien then
			return line, partial
		end

		if line == "\r\n" or line == "\n" then
			break
		end
		
		lines[#lines + 1] = line
	end

	return table.concat(lines), partial
		
end


local function get_token(s, offset)
	local _, i, token = s:find("^([^()<>@,;:\\\"/%[%]?={} \0\001-\031\127]+)", offset)
	if i then
		return i + 1, token
	else
		return nil
	end
end

local function skip_lws(s, pos)
	local _,e

	while true do
		while string.match(s, "^[ \t]", pos) do
			pos = pos+ 1
		end

		_, e = string.find(s, "^\r?\n[ \t]", pos)
		if not e then
			return pos
		end
		pos = e + 1
	end
end


local function skip_space(s, offset)
	local _, i, space = s:find("^([ \t]*)", offset)
	return i + 1, space
end


parse_set_cookie = function(s)
	local name, value
	local _, pos

	local cookie = {}
	s = s:gsub(";", "; ")

	_,pos,cookie.name,cookie.value = s:find("^[ \t]*(.-)[ \t]*=[ \t]*(.-)[ \t]*%f[;\0]")
	if not (cookie.name or ""):find("^[^;]+$") then
		return nil, "can't get cookie name"
	end
	pos = pos + 1

	while s:sub(pos, pos) == ";" do
		_,pos,name = s:find("[ \t]*(.-)[ \t]*%f[=;\0]", pos + 1)
		pos = pos + 1
		if s:sub(pos, pos) == "=" then
			_,pos,value = s:find("[ \t]*(.-)[ \t]*%f[;\0]", pos + 1)
			pos = pos + 1
		else
			value = ""
		end

		name = name:lower()
		if not (name == "" or name == "name" or name == "value") then
			cookie[name] = value
		end
	end
		
	return cookie
end
	
	
local function parse_header(header, response)
	local pos
	local name,words
	local s,e

	response.header = {}
	response.rawheader = comm.strsplit("\r?\n", header)
	pos = 1
	while pos <= #header do
		e, name = get_token(header, pos)

		if e then
			if header:sub(e, e) ~= ":" then
				name = nil
			end

			pos = e + 1
		end

		pos = skip_lws(header, pos)

		words = {}
		
		while pos <= #header and not string.match(header, "^\r?\n", pos) do
			s = pos
			while not string.match(header, "^[ \t]", pos) and
				not string.match(header, "^\r?\n", pos) do
				pos = pos + 1
			end
			words[#words + 1] = string.sub(header, s, pos -1)
			pos = skip_lws(header, pos)
		end

		if name then
			name = string.lower(name)
			local value = table.concat(words, " ")
			if response.header[name] then
				response.header[name] = response.header[name] .. ", " .. value
			else
				response.header[name] = value
			end

			if name == "set-cookie" then
				local cookie, err = parse_set_cookie(value)
				if cookie then
					response.cookies[#response.cookies + 1] = cookie
				else
				end
			end
		end

		s, e = string.find(header, "^\r?\n", pos)
		if not e then
			return nil, string.format("Header field named %q didn't end with CRLF", name)
		end
		pos = e + 1
	end

	return true
end

local function recv_length(s, length, partial)
	local parts, last

	partial = partial or ""

	parts = {}
	last = partial
	length = length - #last

	while length > 0 do
		local status

		parts[#parts + 1] = last
		status, last = s:receive()
		if not status then
			return nil, last, table.concat(parts)
		end
		length = length - #last
	end

	if length == 0 then
		return table.concat(parts) .. last, ""
	else
		return table.concat(parts) .. string.sub(last, 1, length - 1), string.sub(last, length)
	end

end	




local function recv_all(s, partial)
	local parts

	partial = partial or ""

	parts = {partial}
	while true do
		local status, part = s:receive()
		if not status then
			break
		else
			parts[#parts + 1] = part
		end
	end

	return table.concat(parts), ""

end


local function recv_chunked(s, partial)
	local chunks, chunk, fragment
	local chunk_size
	local pos

	chunks = {}
	
	repeat
		local line, hex, _, i

		line, partial = recv_line(s, partial)
		if not line then
			return nil, "Chunk size not received; " .. partial, table.concat(chunks)
		end

		pos = 1
		pos = skip_space(line, pos)


		_, i, hex = string.find(line, "^([%x]+)", pos)
		if not i then
			return nil, ("chunked encoding didn't find hex; got %q"):format(line:sub(pos, pos+10)),
			table.concat(chunks)
		end

		pos = i + 1

		chunk_size = tonumber(hex, 16)

		chunk, partial, fragment = recv_length(s, chunk_size, partial)	
		if not chunk then
			return nil,
				"Incomplete chunk: " .. partial,
				table.concat(chunks) .. fragment
		end

		chunks[#chunks + 1] = chunk

		line, partial = recv_line(s, partial)
		if not lien then
			print("Didn't find DRLF after chunk-data")
		elseif not string.match(line, "^\r?\n") then
			return nil,
				("didn't find CRLF after chunk-data;got %q"):format(line),
				table.concat(chunks)

		end


	until chunk_size == 0

	return table.concat(chunks), partial
end
	



local function recv_body(s, response, method, partial)
	local connection_close, connection_keepalive
	local transfer_encoding
	local content_length
	local err

	partial = partial or ""

	connection_close = false
	connection_keepalive = false

	if response.header.connection then
		local offset,token
		offset = 0
		while true do
			offset, token = get_token(response.header.connection, offset + 1)
			if not offset then
				break
			end

			if stting.lower(token) == "close" then
				connection_close = true
			elseif string.lower(token) == "keep-alive" then
				connection_keepalive = true
			end
		end
	end

	if string.upper(method) == "HEAD"
		or (response.status >= 100 and response.status <= 199)
		or response.status == 204 or response.status == 304 then
		if connection_close or (response.version == "1.0" and not connection_keepalive) then
			return recv_all(s, partial)
		else
			return "", partial
		end
	end

	if response.header["transfer-encoding"]
		and response.header["transfer-encoding"] ~= "identity" then
		return recv_chunked(s, partial)
	end

	-- if a message is received with both aa Transfer-Encoding header field
	-- and a Content-Length header field, the latter must be ignored
	--
	
	if response.header["content-length"] and not response.header["transfer-encoding"] then
		content_length = tonumber(response.header["content-length"])
		if not content_length then
			return nil, string.format("Content-Length %q is non-numeric", response.header["content-length"])
		end
		return recv_length(s, content_length, partial)
	end

	return recv_all(s,partial)

end
	



local function next_response(s, method, partial)
	local response
	local status_line, header, body, fragment
	local status, err

	partial = partial or ""

	response = {
		status = nil,
		["status-line"] = nil,
		header = {},
		rawheader = {},
		cookies = {},
		body=""
	}

	status_line, partial = recv_line(s, partial)
	if not status_line then
		return nil, partial

	end

	status, err = parse_status_line(status_line, response)
	if not status then
		return nil, err
	end

	header, partial = recv_header(s, partial)
	if not header then
		return nil, partial
	end

	status, err = parse_header(header, response)
	if not status then
		return nil, err
	end

	body, partial, fragment = recv_body(s, response, method, partial)
	if not body then
		return nil, partial, fragment
	end

	response.body = body

	return response, partial
end

local function http_error(status_line, fragment)
	return {
		status = nil,
		["status-line"] = status_line,
		header = {},
		rawheader = {},
		body = nil,
		fragment = fragment
	}
end


local function request(host, port, data, options)
	local method
	local header
	local response

	method = string.match(data, "^(%S+)")

	--print("request for " .. data)
	LOG_INFO("request for:%s\n", data);

	local socket, partial, opts = do_connect(host, port, data, options)

	if not socket then
		print("http.request socket error: " .. partial)
		return nil
	end
	
	repeat
		local fragment
		response, partial, fragment = next_response(socket, method, partial)
		if not response then
			return http_error("error in next_response function " .. partial, fragment)
		end

	until not(response.status >= 100 and response.status <= 199)

	socket:close()

	return response
end


function generic_request(host, port, method, path, options)
	return request(host, port, build_request(host, port, method, path, options), options)

end	

function get(host, port, path, options)
	options = options or {}
	local response = generic_request(host, port, "GET", path, options)

	return response
end
	


function get_url(u, options)
	local parsed = url.parse(u)
	local port = {}

	port.service = parsed.scheme
	port.number = parsed.port or 80
	options.scheme = options.scheme or parsed.scheme

	local path = parsed.path or "/"
	if parsed.query then 
		path = path .. "?" .. parsed.query
	end

	return get(parsed.host, port, path, options)
end


return _ENV


