#include "nse_utility.h"
#include <math.h>

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

int nseU_safeerror(lua_State *L, const char *fmt, ...)
{
	va_list va;

	lua_pushboolean(L, false);
	va_start(va,fmt);
	lua_pushvfstring(L, fmt, va);
	va_end(va);
	return 2;
}

void nseU_typeerror(lua_State *L, int idx, const char *type)
{
	const char *msg = lua_pushfstring(L, "%s expected, got %s", type, luaL_typename(L, idx));
	luaL_argerror(L, idx, msg);
}

void *nseU_checkudata(lua_State *L, int idx, int upvalue, const char *name)
{
	idx = lua_absindex(L, idx);

	lua_getmetatable(L, idx);

	if(!(lua_isuserdata(L, idx) && lua_rawequal(L, -1, upvalue)))
		nseU_typeerror(L, idx, name);

	lua_pop(L, 1);

	return lua_touserdata(L, idx);
}

unsigned short nseU_checkport(lua_State *L, int idx, const char **protocol)
{
	unsigned short port;

	idx = lua_absindex(L, idx);

	if(lua_istable(L, idx)){
		lua_getfield(L, idx, "number");
		if(!lua_isinteger(L, -1))
			luaL_argerror(L, idx, "port table lacks integer 'number' field");
		
		port = (unsigned short)lua_tointeger(L, -1);

		lua_getfield(L, idx, "protocol");

		if(lua_isstring(L, -1))
			*protocol = lua_tostring(L, -1);
		lua_pop(L, 2);
	}else{
		port = (unsigned short)luaL_checkinteger(L, idx);
	}

	return port;
}

void nseU_checktarget(lua_State *L, int idx, const char **address, const char **targetname)
{
	idx = lua_absindex(L, idx);

	if(lua_istable(L, idx)){
		lua_getfield(L, idx, "ip");
		*address = lua_tostring(L, -1);
		lua_getfield(L, idx, "targetname");
		*targetname = lua_tostring(L, -1);
		
		if(*address == NULL && *targetname == NULL)
			luaL_argerror(L, idx, "host table lacks 'ip' or 'targetname' fields");

		*address = *address ? *address : *targetname;

		lua_pop(L, 2);
	}else{
		*address = *targetname = luaL_checkstring(L, idx);
	}

}

int nseU_success(lua_State *L)
{
	lua_pushboolean(L, true);
	return 1;
}


int nseU_checkinteger(lua_State *L, int arg)
{
	lua_Number n = luaL_checknumber(L, arg);
	int i;
	
	if(!lua_numbertointeger(floor(n), &i)){
		return luaL_error(L, "number cannot be converted to an integer");
	}

	return i;
}


