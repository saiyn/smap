#include "util.h"
#include "Target.h"



Target::Target()
{
	targetname = "saiyn-lenovo";
}


void Target::setTargetName(const char *name)
{
	if(targetname){
		free(targetname);
		targetname = NULL;
	}

	if(name){
		targetname = strdup(name);
	}
}


void Target::GenerateTargetIPString(void)
{
	struct sockaddr_in *sin = (struct sockaddr_in *)&targetsock;

	inet_ntop(sin->sin_family, (char *)&sin->sin_addr, targetipstring, sizeof(targetipstring));
}

void Target::setTargetSockAddr(const struct sockaddr_storage *ss, size_t ss_len)
{
	assert(ss_len > 0 && ss_len <= sizeof(*ss));

	memcpy(&targetsock, ss, ss_len);

	GenerateTargetIPString();
}


