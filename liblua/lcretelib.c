/**zl3 adding crete lua lib**/

#define lcretelib_c
#define LUA_LIB


#include "lauxlib.h"
#include "lualib.h"
#include "lobject.h"

#include "lua.h"

#include <stdbool.h>
#include <stddef.h>
#include <crete/custom_instr.h>

static int mconcolic (lua_State *L) {

  /* second arg: concolic string length, it is always an integer */
  lua_Integer len;
  len = luaL_checkinteger(L, 2);

  //check type of the first arg
  int arg_type = lua_type(L, 1);
  printf("arg_type is %d\n", arg_type);

  switch(arg_type)
  {
    case 4:;
    	char *str = luaL_checkstring(L, 1);
    	printf("api make concolic enter, it is a string \n");
    	str[len+1]='\0';
    	crete_make_concolic(str, len, "lua_api_string");
    	printf("api make concolic finished, it is a string\n");
    	//printf("lua api calling, string length is %d, str is %s\n", len, str);
    	break;
    case 3:;
    	//lua_number is a double but convert it to integer
    	lua_Integer integer = lua_tointeger(L, 1);
    	printf("api make concolic enter, it is a number\n");
    	crete_make_concolic(&integer, 8, "lua_api_number");
    	printf("api make concolic finished, it is a number\n");
    	//printf("lua api calling, number is %f\n", number);
    	break;
    /**
    case 1:;
    	bool bo = lua_toboolean(L, 1);
    	printf("api make concolic enter, it is a boolean\n");
    	crete_make_concolic(&bo, 1, "lua_api_boolean");
    	printf("api make concolic finished, it is a boolean\n");
    	break;
    **/
    default:
    	return 0;
  }
  return 0;
}

static int voidpid(lua_State *L){
	printf("api voidpid enter\n");
	crete_void_target_pid();
	printf("api voidpid finished\n");
	return 0;
}

static int sendpid(lua_State *L){
	printf("api sendpid enter\n");
	crete_send_target_pid();
	printf("api sendpid finished\n");
	return 0;
}

static int mexit(lua_State *L){
	printf("api mexit enter\n");
	int status;
	  if (lua_isboolean(L, 1))
	    status = (lua_toboolean(L, 1) ? EXIT_SUCCESS : EXIT_FAILURE);
	  else
	    status = (int)luaL_optinteger(L, 1, EXIT_SUCCESS);
	  if (lua_toboolean(L, 2))
	    lua_close(L);
	  if (L) exit(status);  /* 'if' to avoid warnings for unreachable 'return' */
	  return 0;
	printf("api mexit finished\n");
	return 0;
}

static const luaL_Reg crete_funcs[] = {
  {"mconcolic", mconcolic},
  {"voidpid", voidpid},
  {"sendpid",sendpid},
  {"mexit", mexit},
  {NULL, NULL}
};


LUAMOD_API int luaopen_crete (lua_State *L) {
  luaL_newlib(L, crete_funcs);
  return 1;
}
