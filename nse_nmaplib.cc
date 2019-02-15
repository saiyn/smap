#include "nse_utility.h"


int luaopen_nmap(lua_State *L)
{
	static const luaL_Reg nmaplib[] = {
		{"new_socket", nseU_placeholder},
		{NULL, NULL}
	};


	luaL_newlib(L, nmaplib);
	int nmap_idx = lua_gettop(L);

	
	/**
	 * Pull out some functions from the nmap.socket and nmap.dnet libraries.
	 */
	luaL_requiref(L, "nmap.socket", luaopen_nsock, 0);
	/* nmap.socket.new ->nmap.new_socket. */
	lua_getfield(L, -1, "new");
	lua_setfield(L, nmap_idx, "new_socket");
	/* store nmap.socket; used by nse_main.lua. */
	lua_setfield(L, nmap_idx, "socket");

	lua_settop(L, nmap_idx);

	return 1;
}
