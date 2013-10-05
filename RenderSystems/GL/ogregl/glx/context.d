module ogregl.glx.context;
import ogre.exception;
import ogre.general.root;
version(Posix)
{
    import ogregl.context;
    import ogregl.rendersystem;
    import ogregl.glx.support;
    import derelict.opengl3.gl;
    import derelict.opengl3.glx;

    //Unfortunate name choice, prepend 'O'.
    class OGLXContext: GLContext
    {
    public:
        this(GLXGLSupport glsupport, GLXFBConfig fbconfig, GLXDrawable drawable, GLXContext context = null)
        {
            mDrawable = drawable;
            mContext = null;
            mFBConfig = fbconfig;
            mGLSupport = glsupport;
            mExternalContext = false;
            
            GLRenderSystem renderSystem = cast(GLRenderSystem)Root.getSingleton().getRenderSystem();
            OGLXContext mainContext = cast(OGLXContext)renderSystem._getMainContext();
            GLXContext shareContext = null;
            
            if (mainContext)
            {
                shareContext = mainContext.mContext;
            }
            
            if (context)
            {
                mContext = context;
                mExternalContext = true;
            }
            else
            {
                mContext = mGLSupport.createNewContext(mFBConfig, GLX_RGBA_TYPE, shareContext, GL_TRUE);
            }
            
            if (! mContext)
            {
                throw new RenderingApiError("Unable to create a suitable GLXContext", "GLXContext.GLXContext");
            }
        }
        
        ~this()
        {
            GLRenderSystem rs = cast(GLRenderSystem)Root.getSingleton().getRenderSystem();
            
            if (!mExternalContext)
                glXDestroyContext(mGLSupport.getGLDisplay(), mContext);
            
            rs._unregisterContext(this);
        }
        
        /// @copydoc GLContext::setCurrent
        override void setCurrent()
        {
            glXMakeCurrent(mGLSupport.getGLDisplay(), mDrawable, mContext);
        }
        
        /// @copydoc GLContext::endCurrent
        override void endCurrent()
        {
            glXMakeCurrent(mGLSupport.getGLDisplay(), 0, null);
        }
        
        /// @copydoc GLContext::clone
        override GLContext clone()// const
        {
            return new OGLXContext(mGLSupport, mFBConfig, mDrawable);
        } 
        
        GLXDrawable  mDrawable;
        GLXContext   mContext;
        
    private:
        GLXFBConfig  mFBConfig;
        GLXGLSupport  mGLSupport;
        bool mExternalContext;
    }
}