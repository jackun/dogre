module ogregl.glx.window;
version(Posix)
{
    import core.stdc.string: memcpy;
    import std.string;
    debug import std.stdio;

    import ogre.rendersystem.renderwindow;
    import derelict.opengl3.gl;
    import derelict.opengl3.glx;
    import derelict.util.xtypes;

    import ogre.compat;
    import ogre.config;
    import ogre.exception;
    import ogre.strings;
    import ogre.bindings.mini_xaw;
    import ogre.image.images;
    import ogre.general.root;
    import ogre.general.log;
    import ogre.general.common;
    import ogre.rendersystem.glx.windoweventutilities; //or ogre.rendersystem.windoweventutilities
    import ogre.rendersystem.rendersystem;
    import ogre.bindings.mini_x11;
    import ogregl.glx.support;
    import ogregl.glx.context;
    import ogregl.pixelformat;
    import ogregl.util;

    enum uint None = 0;
    alias derelict.util.xtypes.Display Display;
    alias derelict.opengl3.constants.GL_NONE GL_NONE;
    alias derelict.util.xtypes.Visual Visual;

    class OGLXWindow : RenderWindow
    {
        extern (C)
        {
            static int safeXErrorHandler (Display *display, XErrorEvent *event)
            {
                // Ignore all XErrorEvents
                return 0;
            }
            //int function(Display *, XErrorEvent*) oldXErrorHandler;
            XErrorHandler oldXErrorHandler;
        }
        
    public:
        this(GLXGLSupport glsupport)
        {
            mGLSupport = glsupport;
            mContext = null;
            mWindow = 0;
            
            mIsTopLevel = false;
            mIsFullScreen = false;
            mIsExternal = false;
            mIsExternalGLControl = false;
            mClosed = false;
            mActive = false;
            mHidden = false;
            mVSync = false;
            mVSyncInterval = 1;
        }
        
        ~this()
        {
            Display* xDisplay = mGLSupport.getXDisplay();
            
            destroy();
            
            // Ignore fatal XErrorEvents from stale handles.
            oldXErrorHandler = XSetErrorHandler(&safeXErrorHandler);
            
            if (mWindow)
            {
                XDestroyWindow(xDisplay, mWindow);
            }
            
            if (mContext) 
            {
                delete mContext;
            }
            
            XSetErrorHandler(oldXErrorHandler);
            
            mContext = null;
            mWindow = 0;
        }
                
        override void create(string name, uint width, uint height,
                             bool fullScreen, NameValuePairList miscParams)
        {
            Display *xDisplay = mGLSupport.getXDisplay();
            string title = name;
            uint samples = 0;
            short frequency = 0;
            bool vsync = false;
            bool hidden = false;
            uint vsyncInterval = 1;
            int gamma = 0;
            GLXContext glxContext = null;
            GLXDrawable glxDrawable = 0;
            Window externalWindow = 0;
            Window parentWindow = XDefaultRootWindow(xDisplay);
            int left = XDisplayWidth(xDisplay, XDefaultScreen(xDisplay))/2 - width/2;
            int top  = XDisplayHeight(xDisplay, XDefaultScreen(xDisplay))/2 - height/2;
            string border;
            
            mIsFullScreen = fullScreen;
            
            if(!miscParams.emptyAA)
            {
                string *opt;
                
                // NB: Do not try to implement the externalGLContext option.
                //
                //   Accepting a non-current context would expose us to the 
                //   risk of segfaults when we made it current. Since the
                //   application programmers would be responsible for these
                //   segfaults, they are better discovering them in their code.
                
                if ((opt = "currentGLContext" in miscParams) !is null &&
                    _conv!bool(*opt, false))
                {
                    if (! glXGetCurrentContext())
                    {
                        throw new RenderingApiError("currentGLContext was specified with no current GL context", "GLXWindow.create");
                    }
                    
                    glxContext = glXGetCurrentContext();
                    glxDrawable = glXGetCurrentDrawable();
                }
                
                // Note: Some platforms support AA inside ordinary windows
                if((opt = "FSAA" in miscParams) !is null) 
                    samples = _conv!(uint)(*opt, 0);
                
                if((opt = "displayFrequency" in miscParams) !is null && (*opt) != "N/A") 
                    frequency = _conv!short((*opt).split(" ")[0], 60);
                
                if((opt = "vsync" in miscParams) !is null) 
                    vsync = _conv!(bool)(*opt, false);
                
                if((opt = "hidden" in miscParams) !is null)
                    hidden = _conv!(bool)(*opt, false);
                
                if((opt = "vsyncInterval" in miscParams) !is null)
                    vsyncInterval = _conv!(uint)(*opt, 10); //TODO whatever the default is
                
                if ((opt = "gamma" in miscParams) !is null)
                    gamma = _conv!(bool)(*opt, false);
                
                if((opt = "left" in miscParams) !is null) 
                    left = _conv!(int)(*opt, 0);
                
                if((opt = "top" in miscParams) !is null) 
                    top = _conv!(int)(*opt, 0);
                
                if((opt = "title" in miscParams) !is null) 
                    title = *opt;
                
                if ((opt = "externalGLControl" in miscParams) !is null)
                    mIsExternalGLControl = _conv!(bool)(*opt, false);
                
                if((opt = "parentWindowHandle" in miscParams) !is null) 
                {
                    string[] tokens = StringUtil.split(*opt, " :");
                    
                    if (tokens.length == 3)
                    {
                        // deprecated display:screen:xid format
                        parentWindow = _conv!Window(tokens[2], 0);
                    }
                    else
                    {
                        // xid format
                        parentWindow = _conv!Window(tokens[0], 0);
                    }
                }
                else if((opt = "externalWindowHandle" in miscParams) !is null) 
                {
                    string[] tokens = StringUtil.split(*opt, " :");
                    
                    LogManager.getSingleton().logMessage(
                        "GLXWindow::create: The externalWindowHandle parameter is deprecated.\n"
                        "Use the parentWindowHandle or currentGLContext parameter instead.");
                    
                    if (tokens.length == 3)
                    {
                        // Old display:screen:xid format
                        // The old GLX code always created a "parent" window in this case:
                        parentWindow = _conv!Window(tokens[2], 0);
                    }
                    else if (tokens.length == 4)
                    {
                        // Old display:screen:xid:visualinfo format
                        externalWindow = _conv!Window(tokens[2], 0);
                    }
                    else
                    {
                        // xid format
                        externalWindow = _conv!Window(tokens[0], 0);
                    }
                }
                
                if ((opt = "border" in miscParams) !is null)
                    border = *opt;
            }
            
            // Ignore fatal XErrorEvents during parameter validation:
            oldXErrorHandler = XSetErrorHandler(&safeXErrorHandler);
            // Validate parentWindowHandle
            
            if (parentWindow !=  XDefaultRootWindow(xDisplay))
            {
                XWindowAttributes windowAttrib;
                
                if (! XGetWindowAttributes(xDisplay, parentWindow, &windowAttrib) ||
                    windowAttrib.root != XDefaultRootWindow(xDisplay))
                {
                    throw new RenderingApiError("Invalid parentWindowHandle (wrong server or screen)", "GLXWindow::create");
                }
            }
            
            // Validate externalWindowHandle
            
            if (externalWindow != 0)
            {
                XWindowAttributes windowAttrib;
                
                if (! XGetWindowAttributes(xDisplay, externalWindow, &windowAttrib) ||
                    windowAttrib.root !=  XDefaultRootWindow(xDisplay))
                {
                    throw new RenderingApiError("Invalid externalWindowHandle (wrong server or screen)", "GLXWindow::create");
                }
                glxDrawable = externalWindow;
            }
            
            // Derive fbConfig
            
            GLXFBConfig fbConfig = null;
            
            if (glxDrawable)
            {
                fbConfig = mGLSupport.getFBConfigFromDrawable (glxDrawable, &width, &height);
            }
            
            if (! fbConfig && glxContext)
            {
                fbConfig = mGLSupport.getFBConfigFromContext (glxContext);
            }
            
            mIsExternal = (glxDrawable != 0);
            
            XSetErrorHandler(oldXErrorHandler);
            
            if (! fbConfig)
            {
                int[] minAttribs = [
                                    GLX_DRAWABLE_TYPE,  GLX_WINDOW_BIT,
                                    GLX_RENDER_TYPE,    GLX_RGBA_BIT,
                                    GLX_RED_SIZE,      1,
                                    GLX_BLUE_SIZE,    1,
                                    GLX_GREEN_SIZE,  1,
                                    0 //None
                                    ];
                
                int[] maxAttribs = [
                                    GLX_SAMPLES,        samples,
                                    GLX_DOUBLEBUFFER,   1,
                                    GLX_STENCIL_SIZE,   int.max,
                                    GLX_FRAMEBUFFER_SRGB_CAPABLE_EXT, 1,
                                    0//None
                                    ];
                
                fbConfig = mGLSupport.selectFBConfig(minAttribs, maxAttribs);
                
                if (gamma != 0)
                {
                    mGLSupport.getFBConfigAttrib(fbConfig, GL_FRAMEBUFFER_SRGB_CAPABLE_EXT, &gamma);
                }
                
                mHwGamma = (gamma != 0);
            }
            
            if (! fbConfig)
            {
                // This should never happen.
                throw new RenderingApiError("Unexpected failure to determine a GLXFBConfig","GLXWindow::create");
            }
            
            mIsTopLevel = (! mIsExternal && parentWindow ==  XDefaultRootWindow(xDisplay));
            
            if (! mIsTopLevel)
            {
                mIsFullScreen = false;
                left = top = 0;
            }
            
            if (mIsFullScreen) 
            {
                mGLSupport.switchMode (width, height, frequency);
            }
            
            if (! mIsExternal)
            {
                XSetWindowAttributes attr;
                c_ulong mask;
                XVisualInfo *visualInfo = mGLSupport.getVisualFromFBConfig (fbConfig);
                
                attr.background_pixel = 0;
                attr.border_pixel = 0;
                attr.colormap = XCreateColormap(xDisplay,  XDefaultRootWindow(xDisplay), visualInfo.visual, 0);
                attr.event_mask = StructureNotifyMask | VisibilityChangeMask | FocusChangeMask;
                mask = CWBackPixel | CWBorderPixel | CWColormap | CWEventMask;
                
                if(mIsFullScreen && mGLSupport.mAtomFullScreen == None) 
                {
                    LogManager.getSingleton().logMessage("GLXWindow::switchFullScreen: Your WM has no fullscreen support");
                    
                    // A second best approach for outdated window managers
                    attr.backing_store = 0;
                    attr.save_under = False;
                    attr.override_redirect = True;
                    mask |= CWSaveUnder | CWBackingStore | CWOverrideRedirect;
                    left = top = 0;
                } 
                
                debug stderr.writeln(__FILE__,"@",__LINE__,": ",*visualInfo);
                debug stderr.writeln(__FILE__,"@",__LINE__,": ",*visualInfo.visual);
                debug stderr.writeln(__FILE__,"@",__LINE__,": ",
                                     *(cast(XDisplay*)xDisplay),",", parentWindow,",", left,",", top,",", width,",", height,",", 
                                     0,",", visualInfo.depth,",", 
                                     InputOutput,",", visualInfo.visual,",", mask,",", attr);
                
                // Create window on server
                mWindow = XCreateWindow(xDisplay, parentWindow, left, top, width, height, 0, visualInfo.depth, 
                                        InputOutput, visualInfo.visual, mask, &attr);
                
                XFree(visualInfo);
                
                if(!mWindow) 
                {
                    throw new RenderingApiError("Unable to create an X Window", "GLXWindow::create");
                }
                
                if (mIsTopLevel)
                {
                    XWMHints *wmHints;
                    XSizeHints *sizeHints;
                    
                    if ((wmHints = XAllocWMHints()) !is null) 
                    {
                        wmHints.initial_state = NormalState;
                        wmHints.input = True;
                        wmHints.flags = StateHint | InputHint;
                        
                        int depth = XDisplayPlanes(xDisplay, XDefaultScreen(xDisplay));
                        
                        // Check if we can give it an icon
                        if(depth == 24 || depth == 32) 
                        {
                            if(mGLSupport.loadIcon("GLX_icon.png", &wmHints.icon_pixmap, &wmHints.icon_mask))
                            {
                                wmHints.flags |= IconPixmapHint | IconMaskHint;
                            }
                        }
                    }
                    
                    if ((sizeHints = XAllocSizeHints()) !is null)
                    {
                        // Is this really necessary ? Which broken WM might need it?
                        sizeHints.flags = USPosition;
                        
                        if(!fullScreen && border == "fixed")
                        {
                            sizeHints.min_width = sizeHints.max_width = width;
                            sizeHints.min_height = sizeHints.max_height = height;
                            sizeHints.flags |= PMaxSize | PMinSize;
                        }
                    }
                    
                    XTextProperty titleprop;
                    char *lst = CSTR(title);
                    XStringListToTextProperty(cast(char **)&lst, 1, &titleprop);
                    XSetWMProperties(xDisplay, mWindow, &titleprop, null, null, 0, sizeHints, wmHints, null);
                    
                    XFree(titleprop.value);
                    XFree(wmHints);
                    XFree(sizeHints);
                    
                    XSetWMProtocols(xDisplay, mWindow, &mGLSupport.mAtomDeleteWindow, 1);
                    
                    XWindowAttributes windowAttrib;
                    
                    XGetWindowAttributes(xDisplay, mWindow, &windowAttrib);
                    
                    left = windowAttrib.x;
                    top = windowAttrib.y;
                    width = windowAttrib.width;
                    height = windowAttrib.height;
                }
                
                glxDrawable = mWindow;
                
                // setHidden takes care of mapping or unmapping the window
                // and also calls setFullScreen if appropriate.
                setHidden(hidden);
                XFlush(xDisplay);
                
                WindowEventUtilities._addRenderWindow(this);
            }
            
            mContext = new OGLXContext(mGLSupport, fbConfig, glxDrawable, glxContext);
            
            // apply vsync settings. call setVSyncInterval first to avoid 
            // setting vsync more than once.
            setVSyncInterval(vsyncInterval);
            setVSyncEnabled(vsync);
            
            int fbConfigID;
            
            mGLSupport.getFBConfigAttrib(fbConfig, GLX_FBCONFIG_ID, &fbConfigID);
            
            LogManager.getSingleton().logMessage("GLXWindow::create used FBConfigID = " ~ to!string(fbConfigID));
            
            mName = name;
            mWidth = width;
            mHeight = height;
            mLeft = left;
            mTop = top;
            mActive = true;
            mClosed = false;
        }
        
        /** @copydoc RenderWindow::setFullscreen */
        override void setFullscreen (bool fullscreen, uint width, uint height)
        {
            short frequency = 0;
            
            if (mClosed || ! mIsTopLevel)
                return;
            
            if (fullscreen == mIsFullScreen && width == mWidth && height == mHeight)
                return;
            
            if (mIsFullScreen != fullscreen && mGLSupport.mAtomFullScreen == 0)
            {
                // Without WM support it is best to give up.
                LogManager.getSingleton().logMessage("GLXWindow::switchFullScreen: Your WM has no fullscreen support");
                return;
            }
            else if (fullscreen)
            {
                mGLSupport.switchMode(width, height, frequency);
            }
            else
            {
                mGLSupport.switchMode();
            }
            
            if (mIsFullScreen != fullscreen)
            {
                switchFullScreen(fullscreen);
            }
            
            if (! mIsFullScreen)
            {
                resize(width, height);
                reposition(mLeft, mTop);
            }
        }
        
        /** @copydoc RenderWindow::destroy */
        override void destroy()
        {
            if (mClosed)
                return;
            
            mClosed = true;
            mActive = false;
            
            if (! mIsExternal)
                WindowEventUtilities._removeRenderWindow(this);
            
            if (mIsFullScreen) 
            {
                mGLSupport.switchMode();
                switchFullScreen(false);
            }
        }
        
        /** @copydoc RenderWindow::isClosed */
        override bool isClosed() const
        {
            return mClosed;
        }
        
        /** @copydoc RenderWindow::isVisible */
        override bool isVisible() const
        {
            return mVisible;
        }
        
        /** @copydoc RenderWindow::setVisible */
        override void setVisible(bool visible)
        {
            mVisible = visible;
        }
        
        /** @copydoc RenderWindow::isHidden */
        override bool isHidden() const { return mHidden; }
        
        /** @copydoc RenderWindow::setHidden */
        override void setHidden(bool hidden)
        {
            mHidden = hidden;
            // ignore for external windows as these should handle
            // this externally
            if (mIsExternal)
                return;
            
            if (hidden)
            {
                XUnmapWindow(mGLSupport.getXDisplay(), mWindow);
            }
            else
            {
                XMapWindow(mGLSupport.getXDisplay(), mWindow);
                if (mIsFullScreen)
                {
                    switchFullScreen(true);
                }
            }
        }
        
        /** @copydoc RenderWindow::setVSyncEnabled */
        override void setVSyncEnabled(bool vsync)
        {
            mVSync = vsync;
            // we need to make our context current to set vsync
            // store previous context to restore when finished.
            GLXDrawable oldDrawable = glXGetCurrentDrawable();
            GLXContext  oldContext  = glXGetCurrentContext();
            
            mContext.setCurrent();
            
            if (! mIsExternalGLControl && SGI_swap_control)
            {
                glXSwapIntervalSGI (vsync ? mVSyncInterval : 0);
            }
            
            mContext.endCurrent();
            
            glXMakeCurrent (mGLSupport.getGLDisplay(), oldDrawable, oldContext);
        }
        
        /** @copydoc RenderWindow::isVSyncEnabled */
        override bool isVSyncEnabled() const
        {
            return mVSync;
        }
        
        /** @copydoc RenderWindow::setVSyncInterval */
        override void setVSyncInterval(uint interval)
        {
            mVSyncInterval = interval;
            if (mVSync)
                setVSyncEnabled(true);
        }
        
        /** @copydoc RenderWindow::getVSyncInterval */
        override uint getVSyncInterval() const
        {
            return mVSyncInterval;
        }
        
        /** @copydoc RenderWindow::reposition */
        override void reposition(int left, int top)
        {
            if (mClosed || ! mIsTopLevel)
                return;
            
            XMoveWindow(mGLSupport.getXDisplay(), mWindow, left, top);
        }
        
        /** @copydoc RenderWindow::resize */
        override void resize(uint width, uint height)
        {
            if (mClosed)
                return;
            
            if(mWidth == width && mHeight == height)
                return;
            
            if(width != 0 && height != 0)
            {
                if (!mIsExternal)
                {
                    XResizeWindow(mGLSupport.getXDisplay(), mWindow, width, height);
                }
                else
                {
                    mWidth = width;
                    mHeight = height;
                    
                    foreach (k,v; mViewportList)
                        v._updateDimensions();
                }
            }
        }
        
        /** @copydoc RenderWindow::windowMovedOrResized */
        override void windowMovedOrResized()
        {
            if (mClosed || !mWindow)
                return;
            
            Display* xDisplay = mGLSupport.getXDisplay();
            XWindowAttributes windowAttrib;
            
            if (mIsTopLevel && !mIsFullScreen)
            {
                Window parent, root;
                Window *children;
                uint nChildren;
                
                XQueryTree(xDisplay, mWindow, &root, &parent, &children, &nChildren);
                
                if (children !is null)
                    XFree(children);
                
                XGetWindowAttributes(xDisplay, parent, &windowAttrib);
                
                mLeft = windowAttrib.x;
                mTop  = windowAttrib.y;
            }
            
            XGetWindowAttributes(xDisplay, mWindow, &windowAttrib);
            
            if (mWidth == cast(uint)windowAttrib.width && mHeight == cast(uint)windowAttrib.height)
                return;
            
            mWidth = windowAttrib.width;
            mHeight = windowAttrib.height;
            
            foreach (k,v; mViewportList)
                v._updateDimensions();
        }
        
        /** @copydoc RenderWindow::swapBuffers */
        override void swapBuffers(bool waitForVSync)
        {
            if (mClosed || mIsExternalGLControl) 
                return;
            
            glXSwapBuffers(mGLSupport.getGLDisplay(), mContext.mDrawable);
        }
        
        /** @copydoc RenderTarget::copyContentsToMemory */
        override void copyContentsToMemory(PixelBox dst, FrameBuffer buffer)
        {
            if (mClosed)
                return;
            
            if ((dst.right > mWidth) ||
                (dst.bottom > mHeight) ||
                (dst.front != 0) || (dst.back != 1))
            {
                throw new InvalidParamsError("Invalid box.", "GLXWindow.copyContentsToMemory" );
            }
            
            if (buffer == FrameBuffer.FB_AUTO)
            {
                buffer = mIsFullScreen? FrameBuffer.FB_FRONT : FrameBuffer.FB_BACK;
            }
            
            GLenum format = GLPixelUtil.getGLOriginFormat(dst.format);
            GLenum type = GLPixelUtil.getGLOriginDataType(dst.format);
            
            if ((format == GL_NONE) || (type == 0))
            {
                throw new InvalidParamsError("Unsupported format.", "GLXWindow.copyContentsToMemory" );
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
                ubyte *srcRow = cast(ubyte*)dst.data, tmpRow = tmpData.ptr + (height - 1) * rowSpan;
                
                while (tmpRow >= tmpData.ptr)
                {
                    memcpy(tmpRow, srcRow, rowSpan);
                    srcRow += rowSpan;
                    tmpRow -= rowSpan;
                }
                memcpy(dst.data, tmpData.ptr, rowSpan * height);
                
                .destroy(tmpData);// not OGLXWindow.destroy
            }
        }
        
        /**
         @remarks
         * Get custom attribute; the following attributes are valid:
         * WINDOW      The X Window target for rendering.
         * GLCONTEXT    The Ogre GLContext used for rendering.
         * DISPLAY        The X Display connection behind that context.
         * DISPLAYNAME    The X Server name for the connected display.
         * ATOM          The X Atom used in client delete events.
         */
        override void getCustomAttribute(string name, void* pData)
        {
            if( name == "DISPLAY NAME" ) 
            {
                *(cast(string*)pData) = mGLSupport.getDisplayName();
                return;
            }
            else if( name == "DISPLAY" ) 
            {
                *(cast(Display**)pData) = mGLSupport.getGLDisplay();
                return;
            }
            else if( name == "GLCONTEXT" ) 
            {
                *(cast(OGLXContext*)pData) = mContext;
                return;
            } 
            else if( name == "XDISPLAY" ) 
            {
                *(cast(Display**)pData) = mGLSupport.getXDisplay();
                return;
            }
            else if( name == "ATOM" ) 
            {
                *(cast(Atom*)pData) = mGLSupport.mAtomDeleteWindow;
                return;
            } 
            else if( name == "WINDOW" ) 
            {
                *(cast(Window*)pData) = mWindow;
                return;
            } 
        }
        
        override bool requiresTextureFlipping() const { return false; }
        
    private:
        bool mClosed;
        bool mVisible;//TODO Is user supposed to set this to true? Otherwise black window
        bool mHidden;
        bool mIsTopLevel;
        bool mIsExternal;
        bool mIsExternalGLControl;
        bool mVSync;
        int mVSyncInterval;
        
        GLXGLSupport mGLSupport;
        Window      mWindow;
        OGLXContext   mContext;
        
        void switchFullScreen(bool fullscreen)
        {
            if (mGLSupport.mAtomFullScreen != 0)
            {
                Display* xDisplay = mGLSupport.getXDisplay();
                XClientMessageEvent xMessage;
                
                xMessage.type = 33;//ClientMessage;
                xMessage.serial = 0;
                xMessage.send_event = True;
                xMessage.window = mWindow;
                xMessage.message_type = mGLSupport.mAtomState;
                xMessage.format = 32;
                xMessage.data.l[0] = (fullscreen ? 1 : 0);
                xMessage.data.l[1] = mGLSupport.mAtomFullScreen;
                xMessage.data.l[2] = 0;
                
                XSendEvent(xDisplay, XDefaultRootWindow(xDisplay), False, SubstructureRedirectMask | SubstructureNotifyMask, cast(XEvent*)&xMessage); 
                
                mIsFullScreen = fullscreen;
            }
        }
    }
}
