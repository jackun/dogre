compiler=dmd.exe
linker=dmd.exe

target=bin\Debug\Sample1.exe
objects = obj\Debug\main.obj


all: $(target)

$(target): $(objects)
	@echo Linking...
	$(linker)  -debug -gc "-of$@" $(objects) "../../OgreD/ogre/general/windows/OgreWin32.res" "..\..\Deps\DerelictUtil\bin\Debug\libDerelictUtil.lib" "..\..\Deps\DerelictSDL2\bin\Debug\libDerelictSDL2.lib" "..\..\Deps\DerelictGL3\bin\Debug\libDerelictGL3.lib" "..\..\RenderSystems\GL\bin\Debug\libRenderSystemGL.lib" "..\..\Deps\DerelictFI\bin\Debug\libDerelictFI.lib" "..\..\OgreD\bin\Debug\libOgreD.lib" -L/PAGESIZE:1024

obj\Debug\main.obj : main.d
	$(compiler) -c $? "-of$@" "-I..\..\OgreD" "-I..\..\Deps\DerelictFI" "-I..\..\RenderSystems\GL" "-I..\..\Deps\DerelictGL3" "-I..\..\Deps\DerelictUtil" "-I..\..\Deps\DerelictSDL2" -gc 

clean:
	del /Q "$(target)" $(objects)
