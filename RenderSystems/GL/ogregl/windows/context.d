module ogregl.windows.context;

version(Windows):
import derelict.opengl3.gl;
import derelict.opengl3.wgl;
import derelict.util.wintypes;

import ogre.bindings.mini_win32;
import ogre.exception;
import ogre.general.root;

import ogregl.context;
import ogregl.rendersystem;
import ogregl.windows.support;

class Win32Context: GLContext
{
public:
    this(HDC     hDC,
         HGLRC   Glrc)
    {
        mHDC = hDC;
        mGlrc = Glrc;
    }
    
    ~this()
    {
        // NB have to do this is subclass to ensure any methods called back
        // are on this subclass and not half-destructed superclass
        GLRenderSystem rs = cast(GLRenderSystem)(Root.getSingleton().getRenderSystem());
        rs._unregisterContext(this);
    }
    
    /** See GLContext */
    override void setCurrent()
    {
        wglMakeCurrent(mHDC, mGlrc);      
    }
    
    /** See GLContext */
    override void endCurrent()
    {
        wglMakeCurrent(null, null);
    }
    
    /// @copydoc GLContext::clone
    override GLContext clone() //const
    {
        // Create new context based on own HDC
        HGLRC newCtx = wglCreateContext(mHDC);
        
        if (!newCtx)
        {
            throw new InternalError(
                "Error calling wglCreateContext", "Win32Context.clone");
        }
        
        HGLRC oldrc = wglGetCurrentContext();
        HDC oldhdc = wglGetCurrentDC();
        wglMakeCurrent(null, null);
        // Share lists with old context
        if (!wglShareLists(mGlrc, newCtx))
        {
            string errorMsg = translateWGLError();
            wglDeleteContext(newCtx);
            throw new RenderingApiError("wglShareLists() failed: " ~ errorMsg, "Win32Context::clone");
        }
        // restore old context
        wglMakeCurrent(oldhdc, oldrc);
        
        
        return new Win32Context(mHDC, newCtx);
    }
    
    override void releaseContext()
    {
        if (mGlrc !is null)
        {
            wglDeleteContext(mGlrc);
            mGlrc = null;
            mHDC  = null;
        }       
    }
    
protected:
    HDC     mHDC;
    HGLRC   mGlrc;
}


/*static if (OGRE_THREAD_SUPPORT == 1)
{
    // declared in OgreGLPrerequisites.h 
    WGLEWContext * wglewGetContext()
    {
        //static OGRE_THREAD_POINTER_VAR(WGLEWContext, WGLEWContextsPtr);
        __gshared WGLEWContext WGLEWContextsPtr;

        WGLEWContext * currentWGLEWContextsPtr = OGRE_THREAD_POINTER_GET(WGLEWContextsPtr);
        if (currentWGLEWContextsPtr == null)
        {
            currentWGLEWContextsPtr = new WGLEWContext();
            OGRE_THREAD_POINTER_SET(WGLEWContextsPtr, currentWGLEWContextsPtr);
            ZeroMemory(currentWGLEWContextsPtr, WGLEWContext.sizeof);
            wglewInit();
        }
        return currentWGLEWContextsPtr;
    }
}*/
