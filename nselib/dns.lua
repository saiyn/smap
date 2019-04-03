local stdnse = require "stdnse"
local string = require "string"

local serialize = stdnse.serialize

_ENV = stdnse.module("dns", stdnse.seeall)



---
-- Table of DNS resource types
--
types = {
	A = 1,
	NS = 2,
	SOA = 6,
	CNAME = 5,
	PTR = 12,
	HINFO = 13,
	MX = 15,
	TXT = 16,
	AAAA = 28,
	SRV = 33,
	OPT = 41,
	SSHFP = 44,
	NSEC = 47,
	NSEC3 = 50,
	AXFR = 252,
	ANY = 255
}

CLASS = {
	IN = 1,
	CH = 3,
	ANY = 255
}

function newPacket()
	local pkt = {}
	pkt.id = 1
	pkt.flags = {}
	pkt.flags.RD = true
	pkt.questions = {}
	pkt.zones = {}
	pkt.updates = {}
	pkt.answers = {}
	pkt.auth = {}
	pkt.additional = {}
	return pkt
end


function addQuestion(pkt, dname, dtype, class)
	local class = class or CLASS.IN
	local q = {}
	q.dname = dname
	q.dtype = dtype
	q.class = class
	table.insert(pkt.questions, q)
	return pkt
end

local function encodeFlags(flags)
	local fb = 0

	if flags.QR then fb = fb|0x8000 end
	if flags.OC1 then fb = fb|0x4000 end
	if flags.OC2 then fb = fb|0x2000 end
	if flags.OC3 then fb = fb|0x1000 end
	if flags.OC4 then fb = fb|0x0800 end
	if flags.AA then fb = fb|0x0400 end
	if flags.TC then fb = fb|0x0200 end
	if flags.RD then fb = fb|0x0100 end
	if flags.RA then fb = fb|0x0080 end
	if flags.RC1 then fb = fb|0x0008 end
	if flags.RC2 then fb = fb|0x0004 end
	if flags.RC3 then fb = fb|0x0002 end
	if flags.RC4 then fb = fb|0x0001 end
	
	return fb

end


local function encodeAdditional(additional)
	if type(additional) ~= "table" then return nil end
	
	local encA = {}
	for _,v in ipairs(additional) do
		encA[#encA + 1] = string.pack(">xI2I2I4s2", v.type, v.class, v.ttl,v.rdata)
	end

	return table.concat(encA)
end

local function encodeFQDN(fqdn)
	if(not(fqdn) or #fqdn == 0) then return "\0" end

	local encQ = {}
	for part in string.gmatch(fqdn, "[^%.]+") do
		encQ[#encQ+1] = string.pack("s1", part)
	end
	encQ[#encQ+1] = "\0"

	return table.concat(encQ)
end



local function encodeQuestions(questions)
	local encQ = {}

	for _, v in ipairs(questions) do
		encQ[#encQ + 1] = encodeFQDN(v.dname)
		encQ[#encQ + 1] = string.pack(">I2I2", v.dtype, v.class)
	end

	return table.concat(encQ)
end



function encode(pkt)
	local encFlags = encodeFlags(pkt.flags)
	local additional = encodeAdditional(pkt.additional)
	local aorplen = #pkt.answers
	local data, qorzlen, aorulen

	if(#pkt.questions > 0) then
		data = encodeQuestions(pkt.questions)
		qorzlen = #pkt.questions
		aorulen = 0

	else
		print("is an update?")
	end

	local encStr

	encStr = string.pack(">I2I2I2I2I2I2", pkt.id, encFlags, qorzlen, aorplen, aorulen, #pkt.additional) .. data .. additional

	return encStr

end


local function sendPackets(data, host, port, timeout, cnt, multiple, proto)
	local socket = nsock.new("udp")
	local responses = {}

	socket:set_timeout(timeout)

	for i = 1,cnt do
		local status, err

		status, err = socket:sendto(host, port, data)

		--if(not(status)) then
		--	print("dns sendto fail:" .. err)
			
		--	return false, err
		--end
	end

	local response

	while(true) do
		status, response = socket:receive()
		if(not(status)) then
			print("dns receive rsp fail")
			break
	
		end

		local status, _, _, ip, _ = socket:get_info()
		
		print("receive from:" .. ip .. response)


		table.insert(responses, {data = response, peer = ip})
	end

	if(#responses > 0) then
		socket:close()
		return true, responses
	end
			
	socket:close()
	return false
end

function decStr(data, pos)
	local function dec(data, pos, limit)
		local partlen
		local parts = {}
		local part

		limit = limit or 10
		if limit < 0 then
			return pos, nil
		end

		partlen, pos = string.unpack(">B", data, pos)
		while(partlen ~= 0) do
			if(partlen < 64) then
				if(#data - pos + 1) < partlen then
					return pos
				end
				part, pos = string.unpack("c" .. partlen, data, pos)
				table.insert(parts,part)
				partlen, pos = string.unpack(">B", data, pos)
			else
				partlen, pos = string.unpack(">I2", data, pos - 1)
				local _, part = dec(data, partlen - 0xC000 + 1, limit - 1)
				if part == nil then
					return pos
				end
				table.insert(parts, part)
				partlen = 0
			end
		end

			return pos, table.concat(parts, ".")
		end

	return dec(data, pos)
end	



local decoder = {}

decoder[types.A] = function(entry)

	print("decode ip: " .. entry.data:sub(1,4))
end


local function decDomain(entry, data, pos)
	local np = pos - #entry.data
	local _
	_,entry.domain = decStr(data, np)
end

decoder[types.CNAME] = decDomain


decoder[types.PTR] = decDomain


decoder[types.TXT] =
function (entry, data, pos)

	local len = entry.data:len()
	local np = pos - #entry.data
	local txt_len
	local txt

	if len > 0 then
		entry.TXT = {}
		entry.TXT.text = {}
	end

	while np < len do
		txt, np = string.unpack("s1", data, np)
		table.insert(entry.TXT.text, txt)
	end

	print("%%%%%%%%%%%%%%%%%%%%%%")
	print("decode a TXT Record")
	print(serialize(entry))
	print("%%%%%%%%%%%%%%%%%%%")
end


decoder[types.SRV] = 
function(entry, data, pos)
	local np = pos - #entry.data
	local _
	entry.SRV = {}
	entry.SRV.prio, entry.SRV.weight, entry.SRV.port, np = string.unpack(">I2I2I2", data, np)
	np, entry.SRV.target = decStr(data, np)

	print("+++++++++++++++++++")
	print("decode a SRV Record")
	print(serialize(entry))
	print("++++++++++++++++++")


end


local function decodeFlags(flags)
	local tflags = {}
	if (flags & 0x8000) ~= 0 then tflags.QR = true end
	if (flags & 0x4000) ~= 0 then tflags.OC1 = true end
	if (flags & 0x2000) ~= 0 then tflags.OC2 = true end
	if (flags & 0x1000) ~= 0 then tflags.OC3 = true end
	if (flags & 0x0800) ~= 0 then tflags.OC4 = true end
	if (flags & 0x0400) ~= 0 then tflags.AA = true end
	if (flags & 0x0200) ~= 0 then tflags.TC = true end
        if (flags & 0x0100) ~= 0 then tflags.RD = true end
        if (flags & 0x0080) ~= 0 then tflags.RA = true end
        if (flags & 0x0008) ~= 0 then tflags.RC1 = true end
 	if (flags & 0x0004) ~= 0 then tflags.RC2 = true end
 	if (flags & 0x0002) ~= 0 then tflags.RC3 = true end
 	if (flags & 0x0001) ~= 0 then tflags.RC4 = true end

	return tflags

end

local function decodeQuestions(data, count, pos)
	local q = {}
	for i = 1, count do
		local currQ = {}
		pos, currQ.dname = decStr(data, pos)
		currQ.dtype, currQ.class,pos = string.unpack(">I2I2", data, pos)
		table.insert(q,currQ)
	end
	return pos, q
end

local function decodeRR(data, count, pos)
	local ans = {}
	for i = 1, count do
		local currRR = {}
		pos, currRR.dname = decStr(data, pos)
		currRR.dtype, currRR.class, currRR.ttl, pos = string.unpack(">I2I2I4", data, pos)
		currRR.data, pos = string.unpack(">s2",data, pos)

		if decoder[currRR.dtype] then
			decoder[currRR.dtype](currRR, data, pos)
		end

		table.insert(ans, currRR)
	end
	
	return pos, ans
end


function decode(data)
	local pos
	local pkt = {}
	local cnt = {}
	local encFlags

	pkt.id,encFlags,cnt.q,cnt.a,cnt.auth,cnt.add,pos = string.unpack(">I2I2I2I2I2I2", data)


	pkt.flags = decodeFlags(encFlags)


	print("=============================")
	print("id: " .. pkt.id)
	print("answer cnt: " .. cnt.a)
	print("add cnt: " .. cnt.add)

	if(encFlags & 0xF000) == 0xA000 then
		return pkt
	else
		pos,pkt.questions = decodeQuestions(data, cnt.q, pos)
		pos,pkt.answers = decodeRR(data, cnt.a, pos)
		pos,pkt.auth = decodeRR(data, cnt.auth,pos)
		pos,pkt.add = decodeRR(data, cnt.add, pos)

		print(serialize(pkt.answers))
		print(serialize(pkt.add))
		print("===========================")
	end


	return pkt
end


local function gotAnswer(rPkt)
	if #rPkt.answers > 0 then

		-- are those answers not just cnames?
		if rPkt.questions[1].dtype == types.A then
			for _,v in ipairs(rPkt.answers) do
				if v.dtype == types.A then
					return true
				end
			end
		
			return false
		else
			return true
		end

	elseif rPkt.flags.RC3 and rPkt.flags.RC4 then
		return true
	else 

		return false
	end
end 
	

local answerFetcher = {}

answerFetcher[types.TXT] = function(dec, retAll)
	local answers = {}
	
	for _,v in ipairs(dec.answers) do
		if v.TXT and v.TXT.text then
			for _, v in ipairs(v.TXT.text) do
				table.insert(answers, v)
			end
		end
	end

	if #answers == 0 then
		return false, "No answers"
	end

	return true, answers
end


answerFetcher[types.A] = function(dec, retAll)
	local answers = {}
	
	for _, ans in ipairs(dec.answers) do
		if ans.dtype == types.A then
			table.insert(answers, ans.ip)
		end
	end

	if #answers == 0 then
		return false, "no answers"
	end

	return true, answers
end


answerFetcher[types.CNAME] = function(dec, retAll)
	local answers = {}

	print(dec.answers)

	for _, v in ipairs(dec.answers) do
		if v.domain then table.insert(answers, v.domain) end
	end

	if #answers == 0 then
		return false, "no answers"

	end

	return true, answers

end


answerFetcher[types.SRV] = function(dec, retAll)
	local srv,ip,answers = {},{},{}

	for _, ans in ipairs(dec.answers) do
		if ans.dtypes == types.sRV then
			table.insert(answers, ("%s:%s:%s:%s"):format(ans.SRV.prio,ans.SRV.weight, ans.SRV.port, ans.SRV.target))
		end
	end

	if #answers == 0 then
		return false, "no answer"
	end

	return true, answers
end


answerFetcher[types.PTR] = answerFetcher[types.CNAME]




function findNiceAnswer(dtype, dec, retAll)
	if (#dec.answers > 0) then
		if answerFetcher[dtype] then
			return answerFetcher[dtype](dec, retAll)
		else
			return false, "unable to handle response"
		end
	elseif (dec.flags.RC3 and dec.flags.RC4) then
		return false, "No such Name"
	else
		return false, "No answers"
	end
end
	

local function processResponse(response, dname, dtype, options)
	local rpkt = decode(response)


	if gotAnswer(rpkt) then
		if(options.retPkt) then
			return true, rpkt
		else
			return findNiceAnswer(dtype, rpkt, options.retAll)
		end
	elseif (not(options.noauth)) then
		
		--local next_server = getAuthDns(rPkt)
		

		--if type(next_server) == 'table' and next_server.cname then
		--	options.tries = options.tries - 1
		--	return query(next-server.cname, options)
		--end
	
		--if next_server and next_server ~= options.host and options.tries > 1 then
		--	options.host = next_server
		--	options.tries = options.tries - 1
		--	return query(dname, options)
		--end

	elseif (options.retPkt) then
		return true, rPkt
	end	

	

	return false, "No answers"

end


function query(dname, options)
	if not options then options = {} end


	local dtype, host, port, proto = options.dtype, options.host, options.port, options.proto

	if proto == nil then proto = 'udp' end
	if port == nil then port = '53' end


	if not options.tries then options.tries = 10 end

	if not options.sendCount then options.sendCount = 2 end


	if type(dtype) == "string" then
		dtype = types[dtype]
	end

	if not dtype then dtype = types.A end


	local pkt = newPacket()

	addQuestion(pkt, dname, dtype, class)
	
	local data = encode(pkt)

	local status, response = sendPackets(data, host, port, options.timeout,options.sendCount,options.multiple,proto)


	if status then
	
		print("dns query success")

		local multirsp = {}

		for _, r in ipairs(response) do
			local status, presponse = processResponse(r.data, dname, dtype, options)
			if(status) then

				
				print("receive mdns from " .. r.peer)

				print("*********************************")
				for _, v in ipairs(presponse) do
					print("domain " .. serialize(v))
				end

				print("***********************************")



				table.insert(multirsp, {['output']=presponse, ['peer']=r.peer})
			end

		end

		return true, multirsp
	else
		print("dns query fail")

		return false, "No answers"
	end

end



return _ENV
