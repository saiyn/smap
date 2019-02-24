#ifndef _NSE_MIAN_HPP_
#define _NSE_MAIN_HPP_

#include <vector>



class Target;


int nse_yield(lua_State *);

void nse_restore(lua_State *, int);




void open_nse(void);



void script_scan(std::vector<Target *> &targets);


#endif
