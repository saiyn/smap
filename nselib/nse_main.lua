local coroutine = require "coroutine"
local yield = coroutine.yield
local wrap = coroutine.wrap
local create = coroutine.create
local resume = coroutine.resume
local status = coroutine.status

local package = require "package"
local string = require "string"
local gsub = string.gsub
local tabel = require "table"
local insert = table.insert
local pack = table.pack
local unpack = table.unpack


print("saiyn:in nse_main.lua\n")



local socket = require "nsock"
local loop = socket.loop


do 
	local function loader(lib)
		lib = lib:gsub("%.", "/")
		local name = "nselib/"..lib..".lua"

		return assert(loadfile(name))
	end

	insert(package.searchers, 1, loader)
end


local rules = ...;

local YIELD = "NSE_YIELD"
local BASE = "NSE_BASE"
local WAITING_TO_RUNNING = "NSE_WAITING_TO_RUNNING"

local debug = require "debug"
local _R = debug.getregistry()

local Script = {}

local Thread = {}

local ACTION_STARTING = {}



function Thread:resume()
	
	local ok,r1,r2 = resume(self.co, unpack(self.args, 1, self.args.n))


	local status = status(self.co)


	if ok and r1 == ACTION_STARTING then
		print("r1 == action_starting\n")

		self.action_started = true
		return self:resume()
	elseif not ok then
		print("saiyn:something wrong\n")
		return false
	elseif status == "suspended" then
		if r1 == NSE_YIELD_VALUE then
			return true
		else
			print("saiyn:suspend happen wrong\n")
			return false
		end
	elseif status == "dead" then

		if self.action_started then
			print(ok,r1,r2)

		end
		print("saiyn: thread dead\n")
	end
end

function Thread:__index(key)
	return Thread[key] or self.script[key]
end


function Script:new_thread(...)
	local function main()
		yield(ACTION_STARTING)

		local status,err = pcall(self.nse)
		print(err)

		status,err = pcall(action)

		print(err)

		return status
	end


	print("in script.new_thread\n")

	local co = create(main)

	local thread = {
		co = co,
		identifier = tostring(co),
		script = self,
		parent = nil,
		args  = pack(...)	
	}

	thread.parent = thread
	setmetatable(thread,Thread)
	return thread

end



function Script.new(nse)
	local script = {
		nse = nse,
		threads = {},
	}

	return setmetatable(script, Script)
end


Script.__index = Script



local function get_chose_scripts(rules)
	local chosen_scripts = {}

	print("in get chose scripts\n")

	--local nse = assert(loadfile("nselib/upnp-app.nse"), "load upnp-app.nse\n")

	--chosen_scripts[#chosen_scripts + 1] = Script.new(nse)

	nse = assert(loadfile("nselib/dnssd-app.nse"), "load dnssd-app.nse")

	chosen_scripts[#chosen_scripts + 1] = Script.new(nse)


	print(#chosen_scripts)

	return chosen_scripts

end

--load all chosen scripts
local chosen_scripts = get_chose_scripts(rules)



local function run(threads_iter, hosts)

	local running,waiting,pending = {},{},{}
	local all = setmetatable({}, {__mode = "kv"})
	local current


	local yielded_base = setmetatable({}, {__mode = "kv"})

	_R[YIELD] = function(co)
		yielded_base[co] = current
		return NSE_YIELD_VALUE
	end

	_R[WAITING_TO_RUNNING] = function(co, ...)
		local base = yielded_base[co] or all[co]
		if base then
			co = base.co
			if waiting[co] then
				pending[co],waiting[co] = waiting[co], nil
				pending[co].args = pack(...)
				print("WAITING TO RUNNING...")
			end
		end
	end



	while next(running) or next(waiting) or threads_iter do
		while threads_iter do
			local thread = threads_iter()
			if not thread then
				print("thread is nil\n")
				threads_iter = nil
				break
			end
			all[thread.co], running[thread.co] = thread, thread
		end

		for co, thread in pairs(running) do
			current, running[co] = thread, nil


			if thread:resume() then
				waiting[co] = thread

			else
				all[co] = nil
			end
		end

		loop(50)
		
		for co,thread in pairs(pending) do
			pending[co],running[co] = nil,thread
		end
	end
end
		


local function main(hosts)

	local function threads_iter()
		for _,script in ipairs(chosen_scripts) do
			local thread =  script:new_thread("dummy-args")
			if thread then
				yield(thread)
			end
		end
	end


	run(wrap(threads_iter), hosts)

end


return main


