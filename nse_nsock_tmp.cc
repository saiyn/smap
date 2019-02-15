#include "nse_utility.h"
#include "nse_main.h"

static int cnt;


static int l_send(lua_State *L)
{
	size_t size;

	const char *string = luaL_checklstring(L, 1, &size);

	cnt = 3;

	return nse_yield(L);
}



static int l_loop(lua_State *L)
{
	if(cnt){
		while(cnt--){
			sleep(1);
		}
		
		printf("will call nse_restore\n");

		nse_restore(L);
	}

}


LUALIB_API int luaopen_nsock(lua_State *L)
{
	static const luaL_Reg l_nsock[] = {
		{"send", l_send},
		{"loop", l_loop},
		{"NULL", "NULL"}
	};


	luaL_newlib(L, l_nsock);

	return 1;
}

