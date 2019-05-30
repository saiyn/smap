#include "util.h"

Ops o;

Ops::Ops():scripts(0),verbose(0)
{
	memset(device, 0, sizeof(device));

	strcpy(device, "wlp4s0");
}

Ops::~Ops()
{


}


void Ops::setScripts(char *arg)
{
	char *p, *next;

	while((p = strrchr(arg, ',')) != NULL){
		next = p + 1;
		
		scripts.push_back(std::string(next));
		
		std::cout << "saiyn : set script " << std::string(next) << std::endl; 

		*p = 0;
	}

	scripts.push_back(std::string(arg));


	std::cout << "saiyn : set script " << std::string(arg) << std::endl; 
}

const char *inet_socktop(const struct sockaddr_storage *ss)
{
	static char buf[INET6_ADDRSTRLEN + 1];
	void *addr;
	
	if(ss->ss_family == AF_INET)
		addr = (void *)&((struct sockaddr_in *)ss)->sin_addr;
	else if(ss->ss_family == AF_INET6)
		addr = (void *)&((struct sockaddr_in6 *)ss)->sin6_addr;
	else
		addr = NULL;

	if(inet_ntop(ss->ss_family, addr, buf, sizeof(buf)) == NULL)
	{
		std::cout << "inet_ntop fail: " << __LINE__ << std::endl;
	}

	return buf;
}


struct addrinfo *resolve_all(const char *hostname, int pf)
{
	struct addrinfo hints = {0};
	struct addrinfo *result;
	int rc;

	hints.ai_family = pf;
	hints.ai_socktype = SOCK_DGRAM;
	rc = getaddrinfo(hostname, NULL, &hints, &result);
	if(rc != 0)
	{
		std::cout << "resolving " << hostname << " fail " << __LINE__ << std::endl;
		return NULL;
	}
	
	return result;
}







