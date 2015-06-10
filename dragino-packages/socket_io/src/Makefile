# socket_io Makefile
socket_io: socket_io.o
	$(CC) $(LDFLAGS) socket_io.o -o socket_io
socket_io.o: socket_io.c
	$(CC) $(CFLAGS) -c socket_io.c

# remove object files and executable when user executes "make clean"
clean:
	rm *.o socket_io
