
CC= g++
LIBLUA_PATH= ./liblua

LIBNBASE_PATH = ./nbase

LIBNSOCK_PATH = ./nsock

CPPFLAGS = -I$(LIBLUA_PATH) -I$(LIBNBASE_PATH) -I$(LIBNSOCK_PATH)/include -O0 -g

LDFLAGS = -lm -lpcap

LUA= $(LIBLUA_PATH)/liblua.a

NSOCK= $(LIBNSOCK_PATH)/src/libnsock.a

LIBS= $(LUA) $(NSOCK)  $(LIBNBASE_PATH)/libnbase.a

TARGET= saiyn


OBJS= main.o		\
     nse_main.o		\
     nse_utility.o	\
     Target.o		\
     util.o		\
     nse_nsock_tmp.o	\
     network.o



%.o:%.cc
	$(CC) -c $(CPPFLAGS) $^ -o $@   


all: $(LUA) $(TARGET)



$(TARGET): $(OBJS) $(LIBS)
	$(CC) $(CPPFLAGS)  $^ -o $@ $(LDFLAGS)


$(LUA):
	make -C $(LIBLUA_PATH) generic

$(NSOCK):
	make -C $(LIBNSOCK_PATH)/src
	

echo:
	@echo $(LUA)

clean:
	rm -rf $(LIBLUA_PATH)/*.o $(LIBLUA_PATH)/*.a *.o $(TARGET)
	make -C $(LIBNSOCK_PATH)/src clean
	make -C $(LIBNBASE_PATH) clean


