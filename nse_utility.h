#ifndef _NSE_UTILITY_H_
#define _NSE_UTILITY_H_

extern "C"{


#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

}

void nseU_appendfstr(lua_State *L, int idx, const char *fmt, ...);


void nseU_setbfield(lua_State *L, int idx, const char *field, int b);


void nseU_setsfield(lua_State *L, int idx, const char *field, const char *what);


void *nseU_checkudata(lua_State *L, int idx, int upvalue, const char *name);


void nseU_checktarget(lua_State *L, int idx, const char **address, const char **targetname);


int nseU_success(lua_State *L);


unsigned short nseU_checkport(lua_State *L, int idx, const char **protocol);

int nseU_safeerror(lua_State *L, const char *fmt, ...);


#endif
