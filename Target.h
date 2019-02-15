#ifndef _TARGET_HPP_
#define _TARGET_HPP_

#include <string.h>
#include <netinet/in.h>

class Target {

public:
	Target();
	~Target(){};

	const char *targetipstr() const {return targetipstring;}

	const char *TargetName() const {return targetname;}

	void setTargetName(const char *name);

	void setTargetSockAddr(const struct sockaddr_storage *ss, size_t ss_len);


private:
	void GenerateTargetIPString();


private:
	

	char *targetname;

	char targetipstring[INET6_ADDRSTRLEN];

	struct sockaddr_storage targetsock;
};

#endif
