#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>

#include "nsock.h"


#include "nse_utility.h"
#include "nse_main.h"
#include "util.h"


#define THREAD_I  1
#define BUFFER_I  2

#define FROM "<"
#define TO   ">"


enum{
	NSOCK_POOL = lua_upvalueindex(1),
	NSOCK_SOCKET = lua_upvalueindex(2)
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



static nsock_pool get_pool(lua_State *L)
{
	nsock_pool *nspp;

	nspp = (nsock_pool *)lua_touserdata(L, NSOCK_POOL);

	assert(nspp != NULL);

	assert(*nspp != NULL);

	return *nspp;
}

static void status(lua_State *L, enum nse_status status)
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

	int tt = luaL_checkinteger(L, 1);

	if(nsock_loop(nsp, tt) == NSOCK_LOOP_ERROR)
		return luaL_error(L, "a fatal error occurred in nsock_loop");
	
	printf("looping...\n");

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

	nseU_checktarget(L, 2, &addr, &targetname);

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


static int connect(lua_State *L, int status, lua_KContext ctx)
{
	enum type {TCP, UDP, SSL};
	static const char * const op[] = {"tcp", "udp", "ssl", NULL};

	nsock_pool nsp = get_pool(L);

	nse_nsock_udata *nu = check_nsock_udata(L, 1, false);

	const char *addr, *targetname;

	nseU_checktarget(L, 2, &addr, &targetname);
	
	const char *default_proto = NULL;

	unsigned short port = nseU_checkport(L, 3, &default_proto);

	if(default_proto == NULL){
		switch(nu->proto){
			case IPPROTO_TCP:
				default_proto = "tcp";
			break;

			case IPPROTO_UDP:
				default_proto = "udp";
			break;

			default:
				default_proto = "tcp";
			break;

		}
	}
	
	int what = luaL_checkoption(L, 4, default_proto, op);

	struct addrinfo *dest;
	int error_id;

	struct addrinfo hints = {0};

	hints.ai_flags = AI_NUMERICHOST;
	error_id = getaddrinfo(addr, NULL, &hints, &dest);

	if(error_id == EAI_NONAME){
		hints.ai_flags = 0;
		hints.ai_family = AF_INET;
		error_id = getaddrinfo(addr, NULL, &hints, &dest);
	}

	if(error_id)
		return nseU_safeerror(L, gai_strerror(error_id));

	if(!dest)
		return nseU_safeerror(L, "getaddrinfo returned s b n a");


	nu->nsiod = nsock_iod_new(nsp, NULL);

	if(nu->source_addr.ss_family != AF_UNSPEC){
		nsock_iod_set_localaddr(nu->nsiod, &nu->source_addr, nu->source_addrlen);
	}

	if(targetname != NULL){
		if(nsock_iod_set_hostname(nu->nsiod, targetname) == -1)
			printf("nsock_iod_set_hostname fail");
	}

	nu->af = dest->ai_addr->sa_family;
	nu->thread = L;
	nu->action = "PRECONNECT";
	nu->direction = TO;

	switch(what)
	{
		case TCP:
			nu->proto = IPPROTO_TCP;
			nsock_connect_tcp(nsp, nu->nsiod, callback, nu->timeout, nu, dest->ai_addr, dest->ai_addrlen, port);
		break;

		case UDP:
			nu->proto = IPPROTO_UDP;
			nsock_connect_udp(nsp, nu->nsiod, callback, nu, dest->ai_addr, dest->ai_addrlen,port);
		break;

		case SSL:
			printf("no support for ssl now\n");
		break;

	}

	if(dest != NULL)
		freeaddrinfo(dest);

	if(!strncmp(nu->action, "ERROR", 5)){
		return nseU_safeerror(L, "nsock connect failed immediately");
		
	}

	return yield(L, nu, "CONNECT", TO);
}



static int l_connect(lua_State *L)
{
	return connect(L, LUA_OK, 0);
}


static const char* default_af_string(int af)
{
	if(af == AF_INET)
		return "inet";
	else
		return "inet6";
}


static void initialize(lua_State *L, int idx, nse_nsock_udata *nu, int proto, int af)
{
	lua_createtable(L, 2, 0);

	lua_pushliteral(L, "");

	lua_rawseti(L, -2, BUFFER_I);

	lua_setuservalue(L, idx);

	nu->nsiod = NULL;
	nu->proto = proto;
	nu->af = af;
	nu->source_addr.ss_family = AF_UNSPEC;
	nu->source_addrlen = sizeof(nu->source_addr);
	nu->timeout = 3000;
	nu->thread = NULL;
	nu->direction = nu->action = NULL;
}

static int l_new(lua_State *L)
{
	static const char *proto_strings[] = {"tcp", "udp", NULL};
	int proto_map[] = {IPPROTO_TCP, IPPROTO_UDP};
	static const char *af_strings[] = {"inet", "inet6", NULL};
	int af_map[] = {AF_INET, AF_INET6};
	int proto, af;
	nse_nsock_udata *nu;

	proto = proto_map[luaL_checkoption(L, 1,"tcp", proto_strings)];
	af = af_map[luaL_checkoption(L, 2, "inet", af_strings)];

	lua_settop(L, 0);

	nu = (nse_nsock_udata *)lua_newuserdata(L, sizeof(nse_nsock_udata));

	lua_pushvalue(L, NSOCK_SOCKET);

	lua_setmetatable(L, -2);
	initialize(L, 1, nu, proto, af);

	return 1;
}

static int l_set_timeout(lua_State *L)
{
	nse_nsock_udata *nu = check_nsock_udata(L, 1, false);
	int timeout = nseU_checkinteger(L, 2);

	if(timeout < -1)
		return luaL_error(L, "negative timeout: %f", timeout);

	nu->timeout = timeout;

	return nseU_success(L);
}


static int l_close(lua_State *L)
{
	nse_nsock_udata *nu = check_nsock_udata(L, 1, false);

	if(nu->nsiod == NULL)
		return nseU_safeerror(L, "socket alread closed");


	initialize(L, 1, nu, nu->proto, nu->af);

	return nseU_success(L);
}


static int nsock_gc(lua_State *L)
{
	nse_nsock_udata *nu = check_nsock_udata(L, 1, false);

	if(nu->nsiod)
		return l_close(L);

	return 0;
}


LUALIB_API int luaopen_nsock(lua_State *L)
{

	static const luaL_Reg metatable_index[] = {
		{"connect", l_connect},
		{"send", l_send},
		{"sendto", l_sendto},
		{"receive", l_receive},
		{"set_timeout", l_set_timeout},
		{NULL, NULL}
	};


	static const luaL_Reg l_nsock[] = {
		{"new", l_new},
		{"loop", l_loop},
		{NULL, NULL}
	};


	int i;
	int top = lua_gettop(L);


	/* library upvalues */
	nsock_pool nsp = new_pool(L); /* NSOCK_POOL */
	lua_newtable(L); /* NSOCK_SOCKET*/

	int nupvals = lua_gettop(L) - top;

	/* create the nsock metatable for sockets */
	lua_pushvalue(L, top + 2);
	luaL_newlibtable(L, metatable_index);
	
	for(i = top + 1; i <= top + nupvals; i++)
		lua_pushvalue(L, i);

	luaL_setfuncs(L, metatable_index, nupvals);

	lua_setfield(L, -2, "__index");

	for(i = top + 1; i <= top + nupvals; i++)
		lua_pushvalue(L, i);

	lua_pushcclosure(L, nsock_gc, nupvals);
	lua_setfield(L, -2, "__gc");
	lua_newtable(L);
	lua_setfield(L, -2, "__metatable");
	lua_pop(L, 1);


	luaL_newlibtable(L, l_nsock);
	for(i = top+1; i <=  top + nupvals; i++)
		lua_pushvalue(L, i);

	luaL_setfuncs(L, l_nsock,nupvals);
	

	return 1;
}

