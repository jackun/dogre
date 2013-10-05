compiler=dmd
linker=dmd

DFLAGS=-gc "-I../DerelictUtil"
target=bin/Debug/libDerelictSDL2.a
objects = obj/Debug/derelict.sdl2.functions.o obj/Debug/derelict.sdl2.image.o obj/Debug/derelict.sdl2.mixer.o obj/Debug/derelict.sdl2.sdl.o obj/Debug/derelict.sdl2.ttf.o obj/Debug/derelict.sdl2.types.o


all: $(target)

$(target): $(objects)
	@echo Linking...
	$(linker) $(DFLAGS) -debug -lib "-of$@" $(objects)

obj/Debug/derelict.sdl2.functions.o : derelict/sdl2/functions.d
	$(compiler) -c $? "-of$@" $(DFLAGS)

obj/Debug/derelict.sdl2.image.o : derelict/sdl2/image.d
	$(compiler) -c $? "-of$@" $(DFLAGS)

obj/Debug/derelict.sdl2.mixer.o : derelict/sdl2/mixer.d
	$(compiler) -c $? "-of$@" $(DFLAGS)

obj/Debug/derelict.sdl2.sdl.o : derelict/sdl2/sdl.d
	$(compiler) -c $? "-of$@" $(DFLAGS)

obj/Debug/derelict.sdl2.ttf.o : derelict/sdl2/ttf.d
	$(compiler) -c $? "-of$@" $(DFLAGS)

obj/Debug/derelict.sdl2.types.o : derelict/sdl2/types.d
	$(compiler) -c $? "-of$@" $(DFLAGS)

clean:
	$(RM) "$(target)" $(objects)
