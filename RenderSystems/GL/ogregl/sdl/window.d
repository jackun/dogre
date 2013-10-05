module ogregl.sdl.window;
import ogregl.config;
static if(USE_SDL)
{
    import core.stdc.stdlib;
    import core.stdc.string : memcpy;
    import std.conv : to;
    import derelict.sdl2.sdl;
    import derelict.opengl3.gl;
    import ogre.rendersystem.rendertarget;
    import ogre.rendersystem.renderwindow;
    import ogre.rendersystem.rendersystem;
    import ogre.general.log;
    import ogre.general.common;
    import ogre.general.root;
    import ogre.compat;
    import ogre.exception;
    import ogre.image.images;
    import ogre.compat;
    import ogregl.pixelformat;

    alias derelict.opengl3.constants.GL_NONE GL_NONE;
    
    class SDLWindow : RenderWindow
    {
    private:
        SDL_Window* mWindow;
        SDL_Surface* mScreen;
        SDL_GLContext mContext;
        bool mActive;
        bool mClosed;
        
        // Process pending events
        //void processEvents();//TODO undefined???
        
        alias int function (uint *) da_glXGetVideoSyncSGI;
        da_glXGetVideoSyncSGI glXGetVideoSyncSGI;
        alias int function (int, int, uint *) da_glXWaitVideoSyncSGI;
        da_glXWaitVideoSyncSGI glXWaitVideoSyncSGI;
        
    public:
        this()
        {
            //mScreen(NULL), mActive(false), mClosed(false)
        }
        ~this()
        {
            // according to http://www.libsdl.org/cgi/docwiki.cgi/SDL_5fSetVideoMode
            // never free the surface returned from SDL_SetVideoMode
            /*if (mScreen != NULL)
             SDL_FreeSurface(mScreen);*/
        }
        
        override void create(string name, uint width, uint height,
                             bool fullScreen, NameValuePairList miscParams)
        {
            int colourDepth = 24;
            string title = name;
            if(!miscParams.emptyAA)
            {
                // Parse miscellenous parameters
                // Bit depth
                string* opt = "colourDepth" in miscParams;
                if(opt !is null)
                    colourDepth = to!uint(*opt);

                // Full screen antialiasing
                opt = "FSAA" in miscParams;
                if(opt !is null) //check for FSAA parameter, if not ignore it...
                {
                    uint fsaa_x_samples = to!uint(*opt);
                    if(fsaa_x_samples>1) {
                        // If FSAA is enabled in the parameters, enable the MULTISAMPLEBUFFERS
                        // and set the number of samples before the render window is created.
                        SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS,1);
                        SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES,fsaa_x_samples);
                    }
                }

                // Window title
                opt = "title" in miscParams;
                if(opt !is null)
                    title = *opt;
            }
            
            LogManager.getSingleton().logMessage("SDLWindow.create", LML_TRIVIAL);
            SDL_Surface* screen;
            int flags = SDL_WINDOW_SHOWN | SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE;// | SDL_HWPALETTE ;
            
            // Set OpenGL version
            SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
            SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 1);
            
            SDL_GL_SetAttribute( SDL_GL_DOUBLEBUFFER, 1 );
            SDL_GL_SetAttribute( SDL_GL_DEPTH_SIZE, colourDepth );
            LogManager.getSingleton().logMessage(LML_CRITICAL, to!string(colourDepth));
            // request good stencil size if 32-bit colour
            if (colourDepth == 32)
            {
                SDL_GL_SetAttribute( SDL_GL_STENCIL_SIZE, 8 );
            }
            
            if (fullScreen)
                flags |= SDL_WINDOW_FULLSCREEN;
            
            LogManager.getSingleton().logMessage("Create window", LML_TRIVIAL);
            
            mWindow = SDL_CreateWindow(CSTR(title),
                                       SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                                       width, height, flags);
            
            //screen = SDL_SetVideoMode(width, height, colourDepth, flags);
            //SDL_SetWindowDisplayMode
            if (mWindow is null)
            {
                LogManager.getSingleton().logMessage(LML_CRITICAL, 
                                                     "Could not make screen: " ~ to!string(SDL_GetError()));
                exit(1);
            }
            
            mScreen = SDL_GetWindowSurface(mWindow);
            LogManager.getSingleton().logMessage("screen is valid", LML_TRIVIAL);
            mContext = SDL_GL_CreateContext(mWindow);
            LogManager.getSingleton().logMessage("GL context created.", LML_TRIVIAL);
            
            mName = name;
            
            mWidth = width;
            mHeight = height;
            
            mActive = true;
            
            //if (!fullScreen)
            //    SDL_WM_SetCaption(CSTR(title), 0);
            
            glXGetVideoSyncSGI = cast(da_glXGetVideoSyncSGI)SDL_GL_GetProcAddress("glXGetVideoSyncSGI");
            glXWaitVideoSyncSGI = cast(da_glXWaitVideoSyncSGI)SDL_GL_GetProcAddress("glXWaitVideoSyncSGI");
        }

        /** Overridden - see RenderWindow */
        override void destroy()
        {
            // according to http://www.libsdl.org/cgi/docwiki.cgi/SDL_5fSetVideoMode
            // never free the surface returned from SDL_SetVideoMode
            //SDL_FreeSurface(mScreen);
            mScreen = null;
            mActive = false;
            
            Root.getSingleton().getRenderSystem().detachRenderTarget( this.getName() );
        }

        /** Overridden - see RenderWindow */
        override bool isActive() const
        {
            return mActive;
        }

        /** Overridden - see RenderWindow */
        override bool isClosed() const
        {
            return mClosed;
        }

        /** Overridden - see RenderWindow */
        override void reposition(int left, int top)
        {
            // XXX FIXME
        }

        /** Overridden - see RenderWindow */
        override void resize(uint width, uint height)
        {
            SDL_Surface* screen;
            int flags = SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE;// | SDL_HWPALETTE;
            
            LogManager.getSingleton().logMessage("Updating window", LML_TRIVIAL);
            //SDL_DisplayMode mode, closestmode;
            //SDL_GetClosestDisplayMode(SDL_GetWindowDisplayIndex(mWindow), &mode, &closestmode);
            //screen = SDL_SetVideoMode(width, height, mScreen.format.BitsPerPixel, flags);
            
            //FIXME How to resize with opengl?
            SDL_SetWindowSize(mWindow, width, height);
            screen = SDL_GetWindowSurface(mWindow);
            if (screen is null)
            {
                LogManager.getSingleton().logMessage(LML_CRITICAL, 
                                                     "Could not make screen: " ~ to!string(SDL_GetError()));
                exit(1);//FIXME exit? or just throw?
            }
            LogManager.getSingleton().logMessage("screen is valid", LML_TRIVIAL);
            mScreen = screen;
            
            
            mWidth = width;
            mHeight = height;
            
            foreach (k,v; mViewportList)
            {
                v._updateDimensions();
            }
        }
        /** Overridden - see RenderWindow */
        override void swapBuffers(bool waitForVSync)
        {
            if ( waitForVSync && glXGetVideoSyncSGI && glXWaitVideoSyncSGI )
            {
                uint retraceCount;
                glXGetVideoSyncSGI( &retraceCount );
                glXWaitVideoSyncSGI( 2, ( retraceCount + 1 ) & 1, &retraceCount);
            }
            
            SDL_GL_SwapWindow(mWindow);
            // XXX More?
        }
        
        /** Overridden - see RenderTarget. */
        override void copyContentsToMemory(PixelBox dst, FrameBuffer buffer)
        {
            if ((dst.left < 0) || (dst.right > mWidth) ||
                (dst.top < 0) || (dst.bottom > mHeight) ||
                (dst.front != 0) || (dst.back != 1))
            {
                throw new InvalidParamsError(
                    "Invalid box.",
                    "SDLWindow.copyContentsToMemory" );
            }
            
            if (buffer == FrameBuffer.FB_AUTO)
            {
                buffer = mIsFullScreen? FrameBuffer.FB_FRONT : FrameBuffer.FB_BACK;
            }
            
            GLenum format = GLPixelUtil.getGLOriginFormat(dst.format);
            GLenum type = GLPixelUtil.getGLOriginDataType(dst.format);
            
            if ((format == GL_NONE) || (type == 0))
            {
                throw new InvalidParamsError(
                    "Unsupported format.",
                    "SDLWindow.copyContentsToMemory" );
            }
            
            // Switch context if different from current one
            RenderSystem rsys = Root.getSingleton().getRenderSystem();
            rsys._setViewport(this.getViewport(0));
            
            // Must change the packing to ensure no overruns!
            glPixelStorei(GL_PACK_ALIGNMENT, 1);
            
            glReadBuffer((buffer == FrameBuffer.FB_FRONT)? GL_FRONT : GL_BACK);
            glReadPixels(cast(GLint)dst.left, cast(GLint)dst.top,
                         cast(GLsizei)dst.getWidth(), cast(GLsizei)dst.getHeight(),
                         format, type, dst.data);
            
            // restore default alignment
            glPixelStorei(GL_PACK_ALIGNMENT, 4);
            
            //vertical flip
            {
                size_t rowSpan = dst.getWidth() * PixelUtil.getNumElemBytes(dst.format);
                size_t height = dst.getHeight();
                ubyte[] tmpData = new ubyte[rowSpan * height];
                ubyte *srcRow = cast(ubyte *)dst.data, tmpRow = tmpData.ptr + (height - 1) * rowSpan;
                
                while (tmpRow >= tmpData.ptr)
                {
                    memcpy(tmpRow, srcRow, rowSpan);
                    srcRow += rowSpan;
                    tmpRow -= rowSpan;
                }
                memcpy(dst.data, tmpData.ptr, rowSpan * height);
                
                //delete [] tmpData;
                .destroy(tmpData);
            }
        }
        
        /** Overridden - see RenderTarget.
         */
        override void getCustomAttribute( string name, void* pData )
        {
            // NOOP
        }
        
        override bool requiresTextureFlipping() const { return false; }
        
        override bool isFullScreen() const
        {
            return ( mScreen.flags & SDL_WINDOW_FULLSCREEN ) == SDL_WINDOW_FULLSCREEN;
        }
    }
}