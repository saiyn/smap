#include "Target.h"
#include "util.h"
#include "nse_utility.h"
#include "nse_main.h"


static void parse_targets(std::vector<Target *> &T, char *ip_str)
{

	//for now just assuem we get a single ip 


	Target *t = new Target();
	struct in_addr id;
	int s;

	s = inet_pton(AF_INET, ip_str, &id);
	if(s <= 0){
		fprintf(stderr, "inet_pton error\n");
		exit(EXIT_FAILURE);
	}



	struct sockaddr_in si = {0};

	si.sin_family = AF_INET;
	si.sin_port = 0;
	si.sin_addr.s_addr = id.s_addr;


	t->setTargetSockAddr((struct sockaddr_storage *)&si, sizeof(si));


	T.push_back(t);
}

int main(int argc, char *argv[])
{

	int opt;
	const char *optstring = "s:v";

	while((opt = getopt(argc, argv, optstring)) != -1){
		switch(opt){
		case 's':
			printf("scripts: %s\n", optarg);

			o.setScripts(optarg);	
		break;

		case 'v':
			printf("set verbose\n");
			o.verbose = 1;

		default:
			fprintf(stderr, "Uaage: %s [-s scripts]\n", argv[0]);
			exit(EXIT_FAILURE);
		}
	}

	std::vector<Target *> Targets;

	if(optind < argc){
		parse_targets(Targets, argv[optind++]);
	}

	open_nse();

	
	script_scan(Targets);

	return 0;
}

