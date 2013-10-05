compiler=dmd
linker=dmd

DFLAGS=-gc
target=bin/Debug/libDerelictFI.a
objects = obj/Debug/derelict.freeimage.freeimage.o obj/Debug/derelict.freeimage.functions.o obj/Debug/derelict.freeimage.types.o


all: $(target)

$(target): $(objects)
	@echo Linking...
	$(linker)  -debug -lib "-of$@" $(objects) -L-lfreeimage

obj/Debug/derelict.freeimage.freeimage.o : derelict/freeimage/freeimage.d
	$(compiler) -c $? "-of$@" "-I../DerelictUtil" $(DFLAGS)

obj/Debug/derelict.freeimage.functions.o : derelict/freeimage/functions.d
	$(compiler) -c $? "-of$@" "-I../DerelictUtil" $(DFLAGS)

obj/Debug/derelict.freeimage.types.o : derelict/freeimage/types.d
	$(compiler) -c $? "-of$@" "-I../DerelictUtil" $(DFLAGS)

clean:
	$(RM) "$(target)" $(objects)
