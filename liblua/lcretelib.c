/**zl3 adding crete lua lib**/

#define lcretelib_c
#define LUA_LIB


#include "lauxlib.h"
#include "lualib.h"

#include "lua.h"

#include <stddef.h>
#include <crete/custom_instr.h>

#include <errno.h>

#include <stdio.h>
#include <stdlib.h>

static int mconcolic (lua_State *L) {
  lua_Integer len;  /* concolic string length */
  len = luaL_checkinteger(L, 2);
  char *str = luaL_checkstring(L, 1);
  printf("api make concolic enter\n");
  str[len+1]='\0';
  crete_make_concolic(str, len, "lua_api_string");
  printf("api make concolic finished\n");
  //printf("lua api calling, integer is %d, str is %s\n", len, str);
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

static int replaytest(lua_State *L){
	printf("enter replay test\n");
	char *str = luaL_checkstring(L,1);
	printf("test case path is %s\n", str);

	FILE *fp = fopen(str, "r");
	if (fp == NULL){
		printf("Could not open test case file\n");
		lua_pushnil(L);
		lua_pushstring(L, strerror(errno));
		return 2;
	}

	char *line = NULL;
	size_t len = 0;
	int i = 0;
	lua_newtable(L);

	while( getline(&line,&len,fp) != -1 ){
		if(strlen(line) == 1)
			continue;
		//printf("test case output is %s\n", line);
		lua_pushnumber(L, i++);
		lua_pushstring(L, line);
		lua_settable(L, -3);
	}
	fclose(fp);
	free(line);


	//output a directory
    /**
    struct dirent *de;
	int i;
	DIR *dr = opendir(str);

	if(dr == NULL){
		printf("Could not open test case directory" );
		lua_pushnil(L);
		lua_pushstring(L, strerror(errno));
		return 2;
	}

	lua_newtable(L);
	i =1;
	while((de = readdir(dr)) != NULL){
		lua_pushnmuber(L, i++);
		lua_pushstring(L, de->d_name);
		lua_settable(L, -3);
	}
	closedir(dr);
	**/
	return 1;

}

static const luaL_Reg crete_funcs[] = {
  {"mconcolic", mconcolic},
  {"voidpid", voidpid},
  {"sendpid",sendpid},
  {"mexit", mexit},
  {"replaytest", replaytest},
  {NULL, NULL}
};


LUAMOD_API int luaopen_crete (lua_State *L) {
  luaL_newlib(L, crete_funcs);
  return 1;
}
