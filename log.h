#ifndef _LOG_H_
#define _LOG_H_



#define LEVEL_OF_ERROR (0)

#define LEVEL_OF_WARN  (1)

#define LEVEL_OF_INFO  (2)

#define LEVEL_OF_DEBUG (4)

#define LOG_LEVEL_DEFAULT LEVEL_OF_DEBUG

class slog
{
	public:
		static slog& GetInstance();
		
		void output(int, const char *, const char *,const int, const char *, ...);

		int setLogLevel(int level)
		{
			m_level = level;
		}
	
		int setLogfd(int fd);


	private:
		slog(int level, int fd):m_level(level), m_fd(fd){}

		int m_fd;
		
		int m_level;
};



#define LOG_RAW(level,format ,...) slog::GetInstance().output(level, __FILE__, __FUNCTION__, __LINE__, format, ##__VA_ARGS__) 

#define LOG_INFO(format, ...) LOG_RAW(LEVEL_OF_INFO, format, ##__VA_ARGS__)

#define LOG_WARN(format, ...) LOG_RAW(LEVEL_OF_WARN, format, ##__VA_ARGS__)

#define LOG_ERROR(format, ...) LOG_RAW(LEVEL_OF_ERROR, format, ##__VA_ARGS__)

#define LOG_DEBUG(format, ...) LOG_RAW(LEVEL_OF_DEBUG, format, ##__VA_ARGS__)


#endif
