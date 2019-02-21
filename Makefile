
CC= g++
LIBLUA_PATH= ./liblua

CPPFLAGS = -I$(LIBLUA_PATH) -O0 -g

LDFLAGS = -lm

LUA= $(LIBLUA_PATH)/liblua.a

LIBS= $(LUA)

TARGET= saiyn


OBJS= main.o		\
     nse_main.o		\
     nse_utility.o	\
     Target.o		\
     util.o		\
     nse_nsock_tmp.o



%.o:%.cc
	$(CC) -c $(CPPFLAGS) $^ -o $@   


all: $(LUA) $(TARGET)



$(TARGET): $(OBJS) $(LIBS)
	$(CC) $(CPPFLAGS)  $^ -o $@ $(LDFLAGS)


$(LUA):
	make -C $(LIBLUA_PATH) generic


echo:
	@echo $(LUA)

clean:
	rm -rf $(LIBLUA_PATH)/*.o $(LIBLUA_PATH)/*.a *.o $(TARGET)



