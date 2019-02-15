#include "nse_utility.h"


void nseU_setbfield(lua_State *L, int idx, const char *field, int b)
{
	idx = lua_absindex(L, idx);
	lua_pushboolean(L, b);
	lua_setfield(L, idx, field);
}


void nseU_setsfield(lua_State *L, int idx, const char *field, const char *what)
{
	idx = lua_absindex(L, idx);
	lua_pushstring(L, what);
	lua_setfield(L, idx, field);
}

void nseU_appendfstr(lua_State *L, int idx, const char *fmt, ...)
{
	va_list va;
	idx = lua_absindex(L, idx);
	va_start(va, fmt);
	lua_pushvfstring(L, fmt, va);
	va_end(va);
	lua_rawseti(L, idx, lua_rawlen(L, idx)+1);
}
