#!/usr/bin/bash

echo 
DIR=$(readlink -f $1)
CURDIR=$(pwd)
TARGET=$DIR
#TARGET=$(dirname $TARGET)
TARGET=$(basename $TARGET) # get parent dir as target name
MODE=Unittest
CMODE=-unittest

echo compiler=dmd
echo linker=dmd

echo LIBS=-L-lX11 -L-ldl -L-lXaw -L-lXt  \
		../DerelictFI/bin/Unittest/libDerelictFI.a \
		../DerelictUtil/bin/Unittest/libDerelictUtil.a

echo DFLAGS=-debug -version=OGRE_THREAD_SUPPORT_STD -version=OGRE_NO_ZIP_ARCHIVE -version=OGRE_NO_VIEWPORT_ORIENTATIONMODE \
	-I../DerelictFI -I../DerelictUtil


echo target=bin/$MODE/$TARGET
echo -n "objects = "

find $DIR -type f -iname \*.d | \
    (while read LINE; do
        LINE=${LINE##$CURDIR/}
        OBJ=${LINE//\//.} # greedy slashes to dots
        OBJ=${OBJ%%.d}.o
        echo -n "obj/$MODE/$OBJ "
    done);

echo


echo 'all: $(target)'
echo '$(target): $(objects)'
echo -e \\t'@echo Linking...'
echo -e \\t'$(linker) ' $CMODE ' $(LIBS)  "-of$@" $(objects)'
        
        
find $DIR -type f -iname \*.d | \
    (while read LINE; do
        LINE=${LINE##$CURDIR/}
        OBJ=${LINE//\//.} # greedy slashes to dots
        OBJ=${OBJ%%.d}.o
        echo "obj/$MODE/$OBJ : $LINE"
        echo -e \\t'$(compiler) -gc ' $CMODE ' $(DFLAGS) -c $? "-of$@" '
        echo
    done);

echo clean:
echo -e \\t'$(RM) "$(target)" $(objects)'
