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

#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>


#define LOG_STDOUT 1024
#define LOG_STDERR 2048
#define LOG_MAX LOG_STDERR


class Ops{
	public:
		Ops();
		~Ops();
	
		void setScripts(char *arg);


		std::vector<std::string> scripts;

		char device[64];
		
		int verbose;
};


extern Ops o;


struct addrinfo *resolve_all(const char *hostname, int pf);

const char *inet_socktop(const struct sockaddr_storage *ss);



void log_write(int logt, const char *fmt, ...);

#endif
