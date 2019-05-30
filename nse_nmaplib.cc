#include "nse_utility.h"


static int l_resolve(lua_State *L)
{
	static const char *fam_op[] = {"inet", "inet6", "upspec", NULL};
	static const int fams[] = {AF_INET, AF_INET6, AF_UNSPEC};
	struct sockaddr_storage ss;
	struct addrinfo *addr, *addrs;
	const char *host = luaL_checkstring(L, 1);
	int af = fams[luaL_checkoption(L, 2, "unspec", fam_op)];

	addrs = reslove_all(host, af);

	if(!addrs)
		return nseU_safeerror(L, "Failed to resolve");

	lua_pushboolean(L, true);

	lua_newtable(L);
	for(addr = addrs; addr != NULL; addr = addr->ai_next)
	{
		if(af != AF_UNSPEC && addr->ai_family != af)
			continue;
		if(addr->ai_addrlen > sizeof(ss))
			continue;

		memcpy(&ss, addr->ai_addr, addr->ai_addrlen);
		nseU_appendfstr(L, -1, "%s", inet_socktop(&ss));
	}

	if(addrs != NULL)
		freeaddrinfo(addrs);
	
	return 2;
}


int luaopen_nmap(lua_State *L)
{
	static const luaL_Reg nmaplib[] = {
		{"resolve", l_reslove},
		{NULL, NULL}
	};


	luaL_newlib(L, nmaplib);

	return 1;
}
