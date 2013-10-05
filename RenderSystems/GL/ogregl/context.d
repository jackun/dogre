module ogregl.context;

import ogre.config;
import derelict.opengl3.gl;

/**
     * Class that encapsulates an GL context. (IE a window/pbuffer). This is a 
     * virtual base class which should be implemented in a GLSupport.
     * This object can also be used to cache renderstate if we decide to do so
     * in the future.
     */
class GLContext
{
public:
    this() { initialized= false; }
    ~this() {}
    
    /**
         * Enable the context. All subsequent rendering commands will go here.
         */
    abstract void setCurrent();
    /**
         * This is called before another context is made current. By default,
         * nothing is done here.
         */
    void endCurrent() {}
    
    bool getInitialized() { return initialized; };
    void setInitialized() { initialized = true; };
    
    /** Create a new context based on the same window/pbuffer as this
            context - mostly useful for additional threads.
        @note The caller is responsible for deleting the returned context.
        */
    abstract GLContext clone();// const;
    
    /**
        * Release the render context.
        */
    void releaseContext() {}
protected:
    bool initialized;
}
/*
static if (OGRE_THREAD_SUPPORT == 1)
{
    // declared in OgreGLPrerequisites.h 
    GLEWContext  glewGetContext()
    {
        //static OGRE_THREAD_POINTER_VAR(GLEWContext, GLEWContextsPtr);
        static GLEWContext GLEWContextsPtr;
        
        GLEWContext * currentGLEWContextsPtr =  OGRE_THREAD_POINTER_GET(GLEWContextsPtr);
        if (currentGLEWContextsPtr is null)
        {
            currentGLEWContextsPtr = new GLEWContext();
            OGRE_THREAD_POINTER_SET(GLEWContextsPtr, currentGLEWContextsPtr);
            memset(currentGLEWContextsPtr, 0, GLEWContext.sizeof);
            glewInit();
        }
        return currentGLEWContextsPtr;
    }
}*/