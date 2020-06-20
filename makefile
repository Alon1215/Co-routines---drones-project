
all: ass3

ass3: drone.o ass3.o scheduler.o target.o printer.o
	gcc -m32 -g -Wall -o ass3 drone.o ass3.o scheduler.o target.o printer.o	

ass3.o:	ass3.s
	nasm -g -f elf32 -o ass3.o ass3.s

target.o:	target.s
	nasm -g -f elf32 -o target.o target.s

printer.o: printer.s
	nasm -g -f elf32 -o printer.o printer.s

scheduler.o: scheduler.s
	nasm -g -f elf32 -o scheduler.o scheduler.s

drone.o: drone.s
	nasm -g -f elf32 -o drone.o drone.s

.PHONY: clean

clean: 
	rm -f *.o ass3

	