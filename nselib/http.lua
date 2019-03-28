
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
				function(u) parsed.useinfo = u; return "" end)

		authority = string.gsub(authority, ":(%d+)$", 
				function(p) parsed.port = tonumber(p); return "" end)

		if authority ~= "" then parsed.host = authority end
			
		return parsed

	end,

}






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





