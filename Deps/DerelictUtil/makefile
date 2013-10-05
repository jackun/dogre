compiler=dmd
linker=dmd

DFLAGS=-gc
target=bin/Debug/libDerelictUtil.a
objects = obj/Debug/derelict.util.exception.o obj/Debug/derelict.util.loader.o obj/Debug/derelict.util.sharedlib.o obj/Debug/derelict.util.system.o obj/Debug/derelict.util.wintypes.o obj/Debug/derelict.util.xtypes.o


all: $(target)

$(target): $(objects)
	@echo Linking...
	$(linker) $(DFLAGS) -debug -lib "-of$@" $(objects) -L-ldl

obj/Debug/derelict.util.exception.o : derelict/util/exception.d
	$(compiler) -c $? "-of$@"  $(DFLAGS)

obj/Debug/derelict.util.loader.o : derelict/util/loader.d
	$(compiler) -c $? "-of$@"  $(DFLAGS)

obj/Debug/derelict.util.sharedlib.o : derelict/util/sharedlib.d
	$(compiler) -c $? "-of$@"  $(DFLAGS)

obj/Debug/derelict.util.system.o : derelict/util/system.d
	$(compiler) -c $? "-of$@"  $(DFLAGS)

obj/Debug/derelict.util.wintypes.o : derelict/util/wintypes.d
	$(compiler) -c $? "-of$@"  $(DFLAGS)

obj/Debug/derelict.util.xtypes.o : derelict/util/xtypes.d
	$(compiler) -c $? "-of$@"  $(DFLAGS)

clean:
	$(RM) "$(target)" $(objects)
