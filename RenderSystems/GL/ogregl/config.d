module ogregl.config;
import ogre.config;

debug=OGRE_GL_DBG;
debug(OGRE_GL_DBG)
    enum OGRE_GL_DBG = true;
else
    enum OGRE_GL_DBG = false;

static if (OGRE_THREAD_SUPPORT == 1)
  enum GLEW_MX = true;
else
  enum GLEW_MX = false;

//If not defined, < 1.3 functions get used (?). But probably converting to 2.0+ anyway
version=GL_VERSION_1_3;
version(GL_VERSION_1_3)
    enum GL_VERSION_1_3 = true;
else
    enum GL_VERSION_1_3 = false;

/// Use SDL2 for context creation etc.
//Note that currently there is no WindowEventUtilities class for SDL
//version=USE_SDL;
version(USE_SDL)
    enum USE_SDL = true;
else
    enum USE_SDL = false;

/// Use plain X11 for context creation etc.
version(Posix)
    version=USE_GLX;
version(USE_GLX)
    enum USE_GLX = true && !USE_SDL; //Can't use both
else
    enum USE_GLX = false;

/// Use plain Win32 for context creation etc.
version(Windows)
    version=USE_WIN32;
version(USE_WIN32)
    enum USE_WIN32 = true && !USE_SDL; //Can't use both
else
    enum USE_WIN32 = false;

/// Use Cocoa/Carbon for context creation etc.
//version=USE_OSX;
version(USE_OSX)
    enum USE_OSX = true && !USE_SDL; //Can't use both
else
    enum USE_OSX = false;