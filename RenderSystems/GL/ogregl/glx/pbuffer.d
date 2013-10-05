module ogregl.glx.pbuffer;
version(Posix)
{
    import std.conv: to;
    import derelict.opengl3.gl;
    import derelict.opengl3.glx;
    import derelict.opengl3.constants;

    import ogre.bindings.mini_x11;
    import ogre.exception;

    import ogregl.pbuffer;
    import ogre.image.pixelformat;
    import ogre.general.log;
    import ogregl.context;
    import ogregl.glx.context;
    import ogregl.glx.support;

    alias derelict.util.xtypes.Display Display;
    alias derelict.opengl3.constants.GL_NONE GL_NONE;

    ///PBuffer aka RenderTexture
    class  GLXPBuffer : GLPBuffer
    {
    public:
        this(GLXGLSupport glsupport, PixelComponentType format, size_t width, size_t height)
        {
            super(format, width, height);
            mContext = null;
            mGLSupport = glsupport;
            
            Display *glDisplay = mGLSupport.getGLDisplay();
            GLXDrawable glxDrawable = 0;
            GLXFBConfig fbConfig = null;
            
            int bits = 0;
            
            switch (mFormat)
            {
                case PixelComponentType.PCT_BYTE:
                    bits = 8; 
                    break;
                    
                case PixelComponentType.PCT_SHORT:
                    bits = 16; 
                    break;
                    
                case PixelComponentType.PCT_FLOAT16:
                    bits = 16; 
                    break;
                    
                case PixelComponentType.PCT_FLOAT32:
                    bits = 32; 
                    break;
                    
                default: 
                    break;
            }
            
            int renderAttrib = GLX_RENDER_TYPE;
            int renderValue  = GLX_RGBA_BIT;
            
            if (mFormat == PixelComponentType.PCT_FLOAT16 || mFormat == PixelComponentType.PCT_FLOAT32)
            {
                /*if (NV_float_buffer)
                 {
                 renderAttrib = GLX_FLOAT_COMPONENTS_NV;
                 renderValue  = GL_TRUE;
                 }
                 
                 if (ATI_pixel_format_float)
                 {
                 renderAttrib = GLX_RENDER_TYPE;
                 renderValue  = GLX_RGBA_FLOAT_ATI_BIT;
                 }*/
                
                if (ARB_fbconfig_float)
                {
                    renderAttrib = GLX_RENDER_TYPE;
                    renderValue  = GLX_RGBA_FLOAT_BIT;
                }
                
                if (renderAttrib == GLX_RENDER_TYPE && renderValue == GLX_RGBA_BIT)
                {
                    throw new NotImplementedError("No support for Floating point PBuffers",  "GLXPBuffer.GLXPBuffer");
                }
            }
            
            int[] minAttribs = [
                                GLX_DRAWABLE_TYPE, GLX_PBUFFER,
                                renderAttrib,     renderValue,
                                GLX_DOUBLEBUFFER,  0,
                                0//None
                                ];
            
            int[] maxAttribs = [
                                GLX_RED_SIZE,     bits,
                                GLX_GREEN_SIZE, bits,
                                GLX_BLUE_SIZE,   bits,
                                GLX_ALPHA_SIZE, bits,
                                GLX_STENCIL_SIZE,  int.max,
                                0//None
                                ];
            
            int[] pBufferAttribs = [
                                    GLX_PBUFFER_WIDTH,    cast(int)mWidth,
                                    GLX_PBUFFER_HEIGHT,  cast(int)mHeight,
                                    GLX_PRESERVED_CONTENTS, GL_TRUE,
                                    0//None
                                    ];
            
            fbConfig = mGLSupport.selectFBConfig(minAttribs, maxAttribs);
            
            glxDrawable = glXCreatePbuffer(glDisplay, fbConfig, pBufferAttribs.ptr);
            
            if (! fbConfig || ! glxDrawable) 
            {
                throw new RenderingApiError("Unable to create Pbuffer", "GLXPBuffer.GLXPBuffer");
            }
            
            GLint fbConfigID;
            GLuint iWidth, iHeight;
            
            glXGetFBConfigAttrib(glDisplay, fbConfig, GLX_FBCONFIG_ID, &fbConfigID);
            glXQueryDrawable(glDisplay, glxDrawable, GLX_WIDTH, &iWidth);
            glXQueryDrawable(glDisplay, glxDrawable, GLX_HEIGHT, &iHeight);
            
            mWidth = iWidth;  
            mHeight = iHeight;
            LogManager.getSingleton().logMessage(LML_NORMAL, "GLXPBuffer::create used final dimensions " ~ to!string(mWidth) ~ " x " ~ to!string(mHeight));
            LogManager.getSingleton().logMessage("GLXPBuffer::create used FBConfigID " ~ to!string(fbConfigID));
            
            mContext = new OGLXContext(mGLSupport, fbConfig, glxDrawable);
        }
        
        ~this()
        {
            glXDestroyPbuffer(mGLSupport.getGLDisplay(), mContext.mDrawable);
            
            delete mContext;
            
            LogManager.getSingleton().logMessage(LML_NORMAL, "GLXPBuffer.PBuffer destroyed");
        }
        
        override GLContext getContext()
        {
            return mContext;
        }
        
    protected:
        OGLXContext   mContext;
        GLXGLSupport mGLSupport;
    }
}