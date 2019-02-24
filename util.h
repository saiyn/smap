#ifndef _UTIL_H_
#define _UTIL_H_


#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <vector>
#include <iostream>
#include <string>
#include <assert.h>
#include <string.h>

class Ops{
	public:
		Ops();
		~Ops();
	
		void setScripts(char *arg);


		std::vector<std::string> scripts;

		char device[64];

};


extern Ops o;


#endif
