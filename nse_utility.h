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


#endif
