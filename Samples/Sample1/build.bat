@echo off
set compiler=dmd
set linker=link
set target=bin\Debug\Sample1.exe
set objects=obj\Debug\main.obj

%compiler% -debug -g -c main.d -of%objects% -I..\..\OgreD -I..\..\Deps\DerelictFI ^
	-I..\..\Deps\DerelictGL3 -I..\..\Deps\DerelictSDL2 -I..\..\Deps\DerelictUtil ^
	-I..\..\RenderSystems\GL

%linker% /PAGESIZE:1024 /CO  %objects%/DEBUG ^
	"..\..\OgreD\bin\Debug\libOgreD.lib" ^
	"..\..\Deps\DerelictUtil\bin\Debug\libDerelictUtil.lib" "..\..\Deps\DerelictSDL2\bin\Debug\libDerelictSDL2.lib" ^
	"..\..\Deps\DerelictGL3\bin\Debug\libDerelictGL3.lib" "..\..\RenderSystems\GL\bin\Debug\libRenderSystemGL.lib" ^
	"..\..\Deps\DerelictFI\bin\Debug\libDerelictFI.lib" user32.lib gdi32.lib, ^
	%target%,map,,,"..\..\OgreD\ogre\general\windows\OgreWin32.res"


echo DONE
