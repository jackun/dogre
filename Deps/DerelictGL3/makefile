compiler=dmd
linker=dmd

DFLAGS=-gc
target=bin/Debug/libDerelictGL3.a
objects = obj/Debug/derelict.opengl3.arb.o obj/Debug/derelict.opengl3.cgl.o obj/Debug/derelict.opengl3.constants.o obj/Debug/derelict.opengl3.deprecatedConstants.o obj/Debug/derelict.opengl3.deprecatedFunctions.o obj/Debug/derelict.opengl3.ext.o obj/Debug/derelict.opengl3.functions.o obj/Debug/derelict.opengl3.gl.o obj/Debug/derelict.opengl3.gl3.o obj/Debug/derelict.opengl3.glx.o obj/Debug/derelict.opengl3.internal.o obj/Debug/derelict.opengl3.types.o obj/Debug/derelict.opengl3.wgl.o obj/Debug/derelict.opengl3.nv.o


all: $(target)

$(target): $(objects)
	@echo Linking...
	$(linker) $(DFLAGS) -debug -lib "-of$@" $(objects)

obj/Debug/derelict.opengl3.arb.o : derelict/opengl3/arb.d
	$(compiler) -c $? "-of$@" "-I../DerelictUtil" $(DFLAGS)

obj/Debug/derelict.opengl3.cgl.o : derelict/opengl3/cgl.d
	$(compiler) -c $? "-of$@" "-I../DerelictUtil" $(DFLAGS)

obj/Debug/derelict.opengl3.constants.o : derelict/opengl3/constants.d
	$(compiler) -c $? "-of$@" "-I../DerelictUtil" $(DFLAGS)

obj/Debug/derelict.opengl3.deprecatedConstants.o : derelict/opengl3/deprecatedConstants.d
	$(compiler) -c $? "-of$@" "-I../DerelictUtil" $(DFLAGS)

obj/Debug/derelict.opengl3.deprecatedFunctions.o : derelict/opengl3/deprecatedFunctions.d
	$(compiler) -c $? "-of$@" "-I../DerelictUtil" $(DFLAGS)

obj/Debug/derelict.opengl3.ext.o : derelict/opengl3/ext.d
	$(compiler) -c $? "-of$@" "-I../DerelictUtil" $(DFLAGS)

obj/Debug/derelict.opengl3.functions.o : derelict/opengl3/functions.d
	$(compiler) -c $? "-of$@" "-I../DerelictUtil" $(DFLAGS)

obj/Debug/derelict.opengl3.gl.o : derelict/opengl3/gl.d
	$(compiler) -c $? "-of$@" "-I../DerelictUtil" $(DFLAGS)

obj/Debug/derelict.opengl3.gl3.o : derelict/opengl3/gl3.d
	$(compiler) -c $? "-of$@" "-I../DerelictUtil" $(DFLAGS)

obj/Debug/derelict.opengl3.glx.o : derelict/opengl3/glx.d
	$(compiler) -c $? "-of$@" "-I../DerelictUtil" $(DFLAGS)

obj/Debug/derelict.opengl3.internal.o : derelict/opengl3/internal.d
	$(compiler) -c $? "-of$@" "-I../DerelictUtil" $(DFLAGS)

obj/Debug/derelict.opengl3.types.o : derelict/opengl3/types.d
	$(compiler) -c $? "-of$@" "-I../DerelictUtil" $(DFLAGS)

obj/Debug/derelict.opengl3.wgl.o : derelict/opengl3/wgl.d
	$(compiler) -c $? "-of$@" "-I../DerelictUtil" $(DFLAGS)

obj/Debug/derelict.opengl3.nv.o : derelict/opengl3/nv.d
	$(compiler) -c $? "-of$@" "-I../DerelictUtil" $(DFLAGS)

clean:
	$(RM) "$(target)" $(objects)
