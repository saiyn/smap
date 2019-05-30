local stdnse = require "stdnse"

_ENV = stdnse.module("comm", stdnse.seeall)


local setup_connect = function(host, port, opts)
	local sock = nsock.new()

	sock:set_timeout(opts.timeout)

	local status, err = sock:connect(host, port, opts.proto)

	if not status then
		sock:close()
		return status, err
	end

	sock:set_timeout(opts.timeout)

	return true, sock

end


function opencon(host, port, data, opts)
	opts = opts or {}
	local status, sd = setup_connect(host, port, opts)
	if not status then
		return nil, sd, nil
	end

	local response

	if data and #data > 0 then
		sd:send(data)
		status, response = sd:receive()
	end

	if not status then
		sd:close()
		return nil, rseponse, nil
	end

	return sd,response,nil
end
	
function strsplit(pattern, text)
	local result = {}
	local pos = 1

	while true do
		head,tail = string.find(text, pattern, pos)
		if head then
			result[#result + 1] = string.sub(text, pos, head - 1)
			pos = tail + 1
		else
			result[#result + 1] = string.sub(text, pos)
			break
		end
	end

	return result

end

return _ENV
