#include <unistd.h>
#include <stdio.h>
#include <sys/time.h>
#include <time.h>
#include <stdarg.h>


#include "log.h"



slog& slog::GetInstance()
{
	static slog instance(LOG_LEVEL_DEFAULT, STDOUT_FILENO);

	return instance;
}


static void get_time_str(char *s)
{
	struct timeval now;

	struct tm *cur;

	gettimeofday(&now, NULL);
	
	cur = localtime(&now.tv_sec);

	if(s)
	{
		sprintf(s, "%d-%d-%d-%d:%d:%d:%d", cur->tm_year + 1900, cur->tm_mon + 1, cur->tm_mday, 
				cur->tm_hour, cur->tm_min, cur->tm_sec, (int)(now.tv_usec / 1000));	
	}
}


void slog::output(int l, const char *file, const char *fn,const int line, const char *format, ...)
{
	if(m_level >= l )
	{
		va_list ap;
		char buf[128] = {0};

		va_start(ap, format);

		get_time_str(buf);

		fprintf(stdout, "[%s][%s][%d][%s]", file, fn,line, buf);

		vfprintf(stdout, format, ap);

		fflush(stdout);

		va_end(ap);
	}
}
