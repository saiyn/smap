#include "nsock.h"


#include "nse_utility.h"
#include "nse_main.h"
#include "util.h"


enum{
	NSOCK_POOL = lua_upvalueindex(1)	
};


typedef struct nse_nsock_udata
{
	nsock_iod nsiod;
	int timeout;

	lua_State *thread;

	int proto;
	int af;


	const char *direction;
	const char *action;

	struct sockaddr_storage source_addr;
	size_t source_addrlen;



}nse_nsock_udata;




static int gc_pool(lua_State *L)
{
	nsock_pool *nsp = (nsock_pool *)lua_touserdata(L, 1);

	assert(*nsp != NULL);

	nsock_pool_delete(*nsp);
	
	*nsp = NULL;

	return 0;
}



static nsock_pool new_pool(lua_State *L)
{
	nsock_pool nsp = nsock_pool_new(NULL);
	nsock_pool *nspp;

	nsock_pool_set_device(nsp, o.device);

	nsock_pool_set_broadcast(nsp, true);


	nspp = (nsock_pool *)lua_newuserdata(L, sizeof(nsock_pool));

	*nspp = nsp;

	lua_newtable(L);
	lua_pushcfunction(L, gc_pool);
	lua_setfield(L, -2, "__gc");
	lua_setmetatable(L, -2);

	return nsp; 
}



static nsock_poop get_pool(lua_State *L)
{
	nsock_pool *nspp;

	nspp = (nsock_pool *)lua_touserdata(L, NSOCK_POOL);

	assert(nspp != NULL);

	assert(*nspp != NULL);

	return *nspp;
}

static void status(lua_State *l, enum nse_status status)
{
	switch(status)
	{
		case NSE_STATUS_SUCCESS:
			lua_pushboolean(L, true);
			nse_restore(L, 1);
			break;

		case NSE_STATUS_KILL:
		case NSE_STATUS_CANCELLED:
			return;

		case NSE_STATUS_EOF:
		case NSE_STATUS_ERROR:
		case NSE_STATUS_TIMEOUT:
			lua_pushnil(L);
			lua_pushstring(L, nse_status2str(status));
			nse_restore(L, 2);
			break;

		default:
			assert(0);
			break;
	}
}


static void callback(nsock_pool nsp, nsock_event nse, void *ud)
{
	nse_nsock_udata *nu = (nse_nsock_udata *)ud;
	lua_State *L = nu->thread;

	assert(lua_status(L) == LUA_YIELD);

	status(L, nse_status(nse));
}


static int yield(lua_State *L, nse_nsock_udata *nu, const char *action, const char *dir)
{
	lua_getuservalue(L, 1);
	lua_pushthread(L);
	lua_rawseti(L, -2, THREAD_I);
	lua_pop(L, 1);
	nu->thread = L;
	nu->action = action;
	nu->direction = dir;
	return nse_yield(L);

}


static nse_nsock_udata *check_nsock_udata(lua_State *L, int idx, bool open)
{
	nse_nsock_udata *nu = (nse_nsock_udata *)nseU_checkudata(L, idx, NSOCK_SOCKET, "nsock");

	if(open && nu->nsiod == NULL){
		
		if(nu->proto == IPPROTO_UDP){
			nsock_pool nsp;


			nsp = get_pool(L);

			nu->nsiod = nsock_iod_new(nsp, NULL);

			if(nu->source_addr.ss_family != AF_UNSPEC){
				nsock_iod_set_localaddr(nu->nsiod, &nu->source_addr, nu->source_addrlen);

			}


			if(nsock_setup_udp(nsp, nu->nsiod, nu->af) == -1){
				luaL_error(L, "error in setup of iod");
			}

		}

	}
	
	return nu;
}


#define NSOCK_UDATA_ENSURE_OPEN(L, nu)	\
do {	\
    if(nu->nsiod == NULL)	\
	return nseU_safeerror(L, "socket must be connectd");	\
}while(0)


static int l_loop(lua_State *L)
{
	nsock_pool nsp = get_pool(L);

	int tt = luaL_checkinterger(L, 1);

	if(nsock_loop(nsp, tt) == NSOCK_LOOP_ERROR)
		return luaL_error(L, "a fatal error occurred in nsock_loop");
	
	return 0;
}




static int l_send(lua_State *L)
{
	nsock_pool nsp = get_pool(L);

	nse_nsock_udata *nu = check_nsock_udata(L, 1, true);

	NSOCK_UDATA_ENSURE_OPEN(L, nu);

	size_t size;

	const char *string = luaL_checklstring(L, 2, &size);

	nsock_write(nsp, nu->nsiod, callback, nu->timeout, nu, string, size);

	return yield(L, nu, "SEND", TO);
}


static int l_sendto(lua_State *L)
{
	nsock_pool nsp = get_pool(L);
	nse_nsock_udata *nu = check_nsock_udata(L, 1, true);
	NSOCK_UDATA_ENSURE_OPEN(L, nu);

	size_t size;
	const char *addr, *targetname;

	nseU_checktarget(L, 2, &addr, &targtname);

	const char *default_proto = NULL;
	unsigned short port = nseU_checkport(L, 3, &default_proto);
	const char *string = luaL_checklstring(L, 4, &size);
	int error_id;
	struct addrinfo *dest;

	error_id = getaddrinfo(addr, NULL, NULL, &dest);
	if(error_id)
		return nseU_safeerror(L, "getaddrinfo error");

	if(dest == NULL)
		return nseU_safeerror(L, "getaddrinfo return success, but no result");


	nsock_sendto(nsp, nu->nsiod, callback, nu->timeout, nu, dest->ai_addr, dest->ai_addrlen, port, string, size);

	freeaddrinfo(dest);

	return yield(L, nu, "SEND", TO);
}


static void receive_callback(nsock_pool nsp, nsock_event nse, void *udata)
{
	nse_nsock_udata *nu = (nse_nsock_udata *)udata;
	lua_State *L = nu->thread;

	assert(lua_status(L) == LUA_YIELD);

	if(nse_status(nse) == NSE_STATUS_SUCCESS)
	{
		int len;
		const char *str = nse_readbuf(nse, &len);
		lua_pushboolean(L, true);
		lua_pushlstring(L, str, len);
		nse_restore(L, 2);
	}
	else
		status(L, nse_status(nse));	
}


static int l_receive(lua_State *L)
{
	nsock_pool nsp = get_pool(L);

	nse_nsock_udata *nu = check_nsock_udata(L, 1, true);

	NSOCK_UDATA_ENSURE_OPEN(L, nu);

	nsock_read(nsp, nu->nsiod, receive_callback, nu->timeout, nu);

	return yield(L, nu, "RECEIVE", FROM);
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

