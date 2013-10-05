compiler=dmd
linker=dmd

target=bin/Debug/libDerelictGLFW3.a
objects = obj/Debug/derelict.glfw3.functions.o obj/Debug/derelict.glfw3.glfw3.o obj/Debug/derelict.glfw3.types.o


all: $(target)

$(target): $(objects)
	@echo Linking...
	$(linker) -debug -lib "-of$@" $(objects)

obj/Debug/derelict.glfw3.functions.o : derelict/glfw3/functions.d
	$(compiler) -c $? "-of$@" "-I../DerelictUtil" -gc 

obj/Debug/derelict.glfw3.glfw3.o : derelict/glfw3/glfw3.d
	$(compiler) -c $? "-of$@" "-I../DerelictUtil" -gc 

obj/Debug/derelict.glfw3.types.o : derelict/glfw3/types.d
	$(compiler) -c $? "-of$@" "-I../DerelictUtil" -gc 

clean:
	$(RM) "$(target)" $(objects)
