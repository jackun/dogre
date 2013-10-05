module ogregl.glx.support;

version(Posix)
{
	pragma(lib, "Xrandr");
    import std.conv: to;
    import std.string;
    import std.array: empty;
    import core.stdc.stdlib;
    import core.stdc.string;

    import derelict.opengl3.gl;
    import derelict.opengl3.glx;
    import derelict.util.xtypes;

    import ogre.config;
    import ogre.bindings.mini_x11;
    import ogregl.support;
    import ogre.general.common;
    import ogre.exception;
    import ogre.rendersystem.renderwindow;
    import ogre.image.images;
    import ogre.image.pixelformat;
    import ogre.general.log;
    import ogre.compat;
    import ogre.resources.resourcegroupmanager;
    import ogregl.glew;
    import ogregl.rendersystem;
    import ogregl.pbuffer;
    import ogregl.glx.window;
    import ogregl.glx.pbuffer;
    import ogregl.util;

    alias derelict.util.xtypes.Display Display;

    class GLXGLSupport : GLSupport
    {

    private:
        static Display *_currentDisplay;
        //static Display *_getCurrentDisplay() { return _currentDisplay; }

    public:
        this()
        {
            // A connection that might be shared with the application for GL rendering:
            mGLDisplay = getGLDisplay();
            
            // A connection that is NOT shared to enable independent event processing:
            mXDisplay  = getXDisplay();
            
            int dummy;
            
            if (XQueryExtension(mXDisplay, "RANDR", &dummy, &dummy, &dummy))
            {
                XRRScreenConfiguration *screenConfig;
                
                screenConfig = XRRGetScreenInfo(mXDisplay, XDefaultRootWindow(mXDisplay));
                
                if (screenConfig) 
                {
                    XRRScreenSize *screenSizes;
                    int nSizes = 0;
                    ushort currentRotation;
                    int currentSizeID = XRRConfigCurrentConfiguration(screenConfig, &currentRotation);
                    
                    screenSizes = XRRConfigSizes(screenConfig, &nSizes);
                    
                    mCurrentMode.first.first = screenSizes[currentSizeID].width;
                    mCurrentMode.first.second = screenSizes[currentSizeID].height;
                    mCurrentMode.second = XRRConfigCurrentRate(screenConfig);
                    
                    mOriginalMode = mCurrentMode;
                    
                    for(int sizeID = 0; sizeID < nSizes; sizeID++) 
                    {
                        short *rates;
                        int nRates = 0;
                        
                        rates = XRRConfigRates(screenConfig, sizeID, &nRates);
                        
                        for (int rate = 0; rate < nRates; rate++)
                        {
                            VideoMode mode;
                            
                            mode.first.first = screenSizes[sizeID].width;
                            mode.first.second = screenSizes[sizeID].height;
                            mode.second = rates[rate];
                            
                            mVideoModes ~= mode;
                        }
                    }
                    XRRFreeScreenConfigInfo(screenConfig);
                }
            }
            else
            {
                mCurrentMode.first.first = XDisplayWidth(mXDisplay, XDefaultScreen(mXDisplay));
                mCurrentMode.first.second = XDisplayHeight(mXDisplay, XDefaultScreen(mXDisplay));
                mCurrentMode.second = 0;
                
                mOriginalMode = mCurrentMode;
                
                mVideoModes ~= mCurrentMode;
            }
            
            GLXFBConfig *fbConfigs;
            int config, nConfigs = 0;
            
            fbConfigs = chooseFBConfig(null, &nConfigs);
            
            for (config = 0; config < nConfigs; config++)
            {
                int caveat, samples;
                
                getFBConfigAttrib (fbConfigs[config], GLX_CONFIG_CAVEAT, &caveat);
                
                if (caveat != GLX_SLOW_CONFIG)
                {
                    getFBConfigAttrib (fbConfigs[config], GLX_SAMPLES, &samples);
                    mSampleLevels ~= to!string(samples);
                }
            }
            
            XFree (fbConfigs);
            
            remove_duplicates(mSampleLevels);
        }
        
        ~this()
        {
            if (mXDisplay)
                XCloseDisplay(mXDisplay);
            
            if (! mIsExternalDisplay && mGLDisplay)
                XCloseDisplay(mGLDisplay);
        }
        
        Atom mAtomDeleteWindow;
        Atom mAtomFullScreen;
        Atom mAtomState;
        
        /** @copydoc GLSupport::addConfig */
        override void addConfig()
        {
            ConfigOption optFullScreen;
            ConfigOption optVideoMode;
            ConfigOption optDisplayFrequency;
            ConfigOption optVSync;
            ConfigOption optFSAA;
            ConfigOption optRTTMode;
            ConfigOption optSRGB;
            static if(RTSHADER_SYSTEM_BUILD_CORE_SHADERS)
                ConfigOption optEnableFixedPipeline;
            
            optFullScreen.name = "Full Screen";
            optFullScreen._immutable = false;
            
            optVideoMode.name = "Video Mode";
            optVideoMode._immutable = false;
            
            optDisplayFrequency.name = "Display Frequency";
            optDisplayFrequency._immutable = false;
            
            optVSync.name = "VSync";
            optVSync._immutable = false;
            
            optFSAA.name = "FSAA";
            optFSAA._immutable = false;
            
            optRTTMode.name = "RTT Preferred Mode";
            optRTTMode._immutable = false;
            
            optSRGB.name = "sRGB Gamma Conversion";
            optSRGB._immutable = false;
            
            static if(RTSHADER_SYSTEM_BUILD_CORE_SHADERS)
            {
                optEnableFixedPipeline.name = "Fixed Pipeline Enabled";
                optEnableFixedPipeline.possibleValues ~= "True";
                optEnableFixedPipeline.possibleValues ~= "False";
                optEnableFixedPipeline.currentValue = "True";
                optEnableFixedPipeline._immutable = false;
            }
            
            optFullScreen.possibleValues ~= ("False");
            optFullScreen.possibleValues ~= ("True");
            
            optFullScreen.currentValue = optFullScreen.possibleValues[1];
            
            foreach(value; mVideoModes)
            {
                string mode = to!string(value.first.first) ~ " x " ~ to!string(value.first.second);
                
                optVideoMode.possibleValues ~= mode;
            }
            
            remove_duplicates(optVideoMode.possibleValues);
            
            optVideoMode.currentValue = to!string(mCurrentMode.first.first) ~ " x " ~ to!string(mCurrentMode.first.second);
            
            refreshConfig();
            
            if (SGI_swap_control)
            {
                optVSync.possibleValues ~= "False";
                optVSync.possibleValues ~= "True";
                
                optVSync.currentValue = optVSync.possibleValues[0];
            }
            
            // Is it worth checking for GL_EXT_framebuffer_object ?
            optRTTMode.possibleValues ~= "FBO";
            
            if (GLXEW_VERSION_1_3)
            {
                optRTTMode.possibleValues ~= ("PBuffer");
            }
            
            optRTTMode.possibleValues ~= ("Copy");
            
            optRTTMode.currentValue = optRTTMode.possibleValues[0];
            
            if (! mSampleLevels.empty())
            {
                foreach(value; mSampleLevels)
                {
                    optFSAA.possibleValues ~= value;
                }
                
                optFSAA.currentValue = optFSAA.possibleValues[0];
            }
            
            //if (GLXEW_EXT_framebuffer_sRGB)
            if (EXT_framebuffer_sRGB)
            {   
                optSRGB.possibleValues ~= "False";
                optSRGB.possibleValues ~= "True";
                
                optSRGB.currentValue = optSRGB.possibleValues[0];
            }
            
            mOptions[optFullScreen.name] = optFullScreen;
            mOptions[optVideoMode.name] = optVideoMode;
            mOptions[optDisplayFrequency.name] = optDisplayFrequency;
            mOptions[optVSync.name] = optVSync;
            mOptions[optRTTMode.name] = optRTTMode;
            mOptions[optFSAA.name] = optFSAA;
            mOptions[optSRGB.name] = optSRGB;
            static if(RTSHADER_SYSTEM_BUILD_CORE_SHADERS)
                mOptions[optEnableFixedPipeline.name] = optEnableFixedPipeline;
            
            refreshConfig();
        }
        
        /** @copydoc GLSupport::validateConfig */
        override string validateConfig()
        {
            // TO DO
            return "";
        }
        
        /** @copydoc GLSupport::setConfigOption */
        override void setConfigOption(string name, string value)
        {
            auto option = name in mOptions;
            
            if(option is null)
            {
                //TODO ignore old config file?
                //throw new InvalidParamsError( "Option named `" ~ name ~ "` does not exist.", "GLXGLSupport.setConfigOption" );
            }
            else
            {
                option.currentValue = value;
            }
            
            if (name == "Video Mode")
            {
                ConfigOption *opt;
                if((opt = "Full Screen" in mOptions) !is null)
                {
                    if (opt.currentValue == "Yes")
                        refreshConfig();
                }
            }
        }
        
        /// @copydoc GLSupport::createWindow
        override RenderWindow createWindow(bool autoCreateWindow, GLRenderSystem renderSystem, string windowTitle)
        {
            RenderWindow window = null;
            ConfigOption *opt;
            if (autoCreateWindow) 
            {
                NameValuePairList miscParams;
                
                bool fullscreen = false;
                uint w = 800, h = 600;
                
                if((opt = "Full Screen" in mOptions) !is null)
                    fullscreen = (opt.currentValue == "Yes");
                
                if((opt = "Display Frequency" in mOptions) !is null)
                    miscParams["displayFrequency"] = opt.currentValue;
                
                if((opt = "Video Mode" in mOptions) !is null)
                {
                    string[] vals = opt.currentValue.split("x");
                    
                    if (vals.length==2)
                    {
                        w = to!uint(vals[0].strip);
                        h = to!uint(vals[1].strip);
                    }
                }
                
                if((opt = "FSAA" in mOptions) !is null)
                    miscParams["FSAA"] = opt.currentValue;
                
                if((opt = "VSync" in mOptions) !is null)
                    miscParams["vsync"] = opt.currentValue;
                
                if((opt = "sRGB Gamma Conversion" in mOptions) !is null)
                    miscParams["gamma"] = opt.currentValue;
                
                static if(RTSHADER_SYSTEM_BUILD_CORE_SHADERS){
                    opt = "Fixed Pipeline Enabled" in mOptions;
                    if (opt is null)
                        throw new InvalidParamsError("Can't find Fixed Pipeline enabled options!", "GLXGLSupport.createWindow");
                    bool enableFixedPipeline = (opt.currentValue == "Yes");
                    renderSystem.setFixedPipelineEnabled(enableFixedPipeline);
                }
                
                window = renderSystem._createRenderWindow(windowTitle, w, h, fullscreen, miscParams);
            } 
            
            return window;
        }
        
        /// @copydoc RenderSystem::createRenderWindow
        override RenderWindow newWindow(string name, uint width, uint height, 
                                        bool fullScreen, NameValuePairList miscParams = null)
        {
            OGLXWindow window = new OGLXWindow(this);
            
            window.create(name, width, height, fullScreen, miscParams);
            
            return window;
        }
        
        /// @copydoc GLSupport::createPBuffer
        override GLPBuffer createPBuffer(PixelComponentType format, size_t width, size_t height)
        {
            return new GLXPBuffer(this, format, width, height);
        }
        
        /** @copydoc GLSupport::start */
        override void start()
        {
            LogManager.getSingleton().logMessage(
                "******************************\n"
                "*** Starting GLX Subsystem ***\n"
                "******************************");
        }
        
        /** @copydoc GLSupport::stop */
        override void stop()
        {
            LogManager.getSingleton().logMessage(
                "******************************\n"
                "*** Stopping GLX Subsystem ***\n"
                "******************************");
        }
        
        /** @copydoc GLSupport::initialiseExtensions */
        override void initialiseExtensions()
        {
            assert (mGLDisplay);
            
            GLSupport.initialiseExtensions();
            
            // This is more realistic than using glXGetClientString:
            string extensionsString = to!string(glXQueryExtensionsString(mGLDisplay, XDefaultScreen(mGLDisplay))); //DefaultScreen macro but mini_x11 Display struct corrupts
            
            LogManager.getSingleton().stream() << "Supported GLX extensions: " << extensionsString;
            
            
            extensionList = extensionsString.split(" ");
        }
        
        /** @copydoc GLSupport::getProcAddress */
        override void* getProcAddress(string procname)
        {
            return cast(void*)glXGetProcAddress(CSTR(procname));
        }
        
        // The remaining functions are internal to the GLX Rendersystem:
        
        /**
         * Get the name of the display and screen used for rendering
         *
         * Ogre normally opens its own connection to the X server 
         * and renders onto the screen where the user logged in
         *
         * However, if Ogre is passed a current GL context when the first
         * RenderTarget is created, then it will connect to the X server
         * using the same connection as that GL context and direct all 
         * subsequent rendering to the screen targeted by that GL context.
         * 
         * @return       Display name.
         */
        string getDisplayName ()
        {
            return to!string(cast(const ubyte*)XDisplayName(XDisplayString(mGLDisplay)));
        }
        
        /**
         * Get the Display connection used for rendering
         *
         * This function establishes the initial connection when necessary.
         * 
         * @return       Display connection
         */
        Display* getGLDisplay()
        {
            if (! mGLDisplay)
            {
                //glXGetCurrentDisplay = cast(PFNGLXGETCURRENTDISPLAYPROC)getProcAddress("glXGetCurrentDisplay");
                
                mGLDisplay = glXGetCurrentDisplay();
                mIsExternalDisplay = true;
                
                if (! mGLDisplay)
                {
                    mGLDisplay = XOpenDisplay(null);
                    mIsExternalDisplay = false;
                }
                
                if(! mGLDisplay)
                {
                    throw new RenderingApiError("Couldn`t open X display " ~ to!string(XDisplayName (null)), "GLXGLSupport.getGLDisplay");
                }
                
                initialiseGLXEW();
                
                if (! GLXEW_VERSION_1_3 && ! (SGIX_fbconfig && EXT_import_context))
                {
                    throw new RenderingApiError("No GLX FBConfig support on your display", "GLXGLSupport.GLXGLSupport");
                }
            }
            
            return mGLDisplay;
        }
        
        /**
         * Get the Display connection used for window management & events
         *
         * @return       Display connection
         */
        Display* getXDisplay()
        {
            if (mXDisplay is null)
            {
                string displayString = mGLDisplay ? to!string(XDisplayString(mGLDisplay)) : null;
                
                mXDisplay = XOpenDisplay(CSTR(displayString));
                
                if (! mXDisplay)
                {
                    throw new RenderingApiError("Couldn`t open X display " ~ displayString, "GLXGLSupport.getXDisplay");
                }
                //Literals should have '\0' appended already
                mAtomDeleteWindow = XInternAtom(mXDisplay, CSTR("WM_DELETE_WINDOW"), True);
                mAtomFullScreen = XInternAtom(mXDisplay, CSTR("_NET_WM_STATE_FULLSCREEN"), True);
                mAtomState = XInternAtom(mXDisplay, CSTR("_NET_WM_STATE"), True); 
            }
            
            return mXDisplay;
        }
        
        /**
         * Switch video modes
         *
         * @param width   Receiver for requested and final width
         * @param height     Receiver for requested and final drawable height
         * @param frequency  Receiver for requested and final drawable frequency
         */
        void switchMode (ref uint width, ref uint height, ref short frequency)
        {
            int size = 0;
            int newSize = -1;
            
            VideoMode *newMode = null;
            size_t imode;
            
            //FIXME not fit to parse this logic right now
            //foreach(ref mode; mVideoModes)
            foreach(i; 0..mVideoModes.length)
            {
                auto mode = mVideoModes[i];
                if (mode.first.first >= width &&
                    mode.first.second >= height)
                {
                    if (newMode is null || 
                        mode.first.first < newMode.first.first ||
                        mode.first.second < newMode.first.second)
                    {
                        newSize = size;
                        newMode = &mVideoModes[i];
                    }
                }
                
                VideoMode* lastMode = &mVideoModes[i];
                imode = i;
                
                while (++imode < mVideoModes.length && mVideoModes[imode].first == lastMode.first)
                {
                    if (lastMode == newMode && mVideoModes[imode].second == frequency)
                    {
                        newMode = &mVideoModes[imode];
                    }
                }
                size++;
            }
            
            if (newMode && *newMode != mCurrentMode)
            {
                XRRScreenConfiguration *screenConfig = XRRGetScreenInfo (mXDisplay, XDefaultRootWindow(mXDisplay)); 
                
                if (screenConfig)
                {
                    ushort currentRotation;
                    
                    XRRConfigCurrentConfiguration (screenConfig, &currentRotation);
                    
                    XRRSetScreenConfigAndRate(mXDisplay, screenConfig, XDefaultRootWindow(mXDisplay), newSize, currentRotation, newMode.second, 0/*CurrentTime*/);
                    
                    XRRFreeScreenConfigInfo(screenConfig);
                    
                    mCurrentMode = *newMode;
                    
                    LogManager.getSingleton().logMessage("Entered video mode " ~ to!string(mCurrentMode.first.first) ~ "x" ~ to!string(mCurrentMode.first.second) ~ " @ " ~ to!string(mCurrentMode.second) ~ "Hz");
                }
            }
        }
        
        /**
         * Switch back to original video mode
         */
        void switchMode ()
        {
            return switchMode(mOriginalMode.first.first, mOriginalMode.first.second, mOriginalMode.second);
        }
        
        /**
         * Loads an icon from an Ogre resource into the X Server. This currently only
         * works for 24 and 32 bit displays. The image must be findable by the Ogre
         * resource system, and of format PF_A8R8G8B8.
         *
         * @param name     Name of image to load
         * @param pix       Receiver for the output pixmap
         * @param mask     Receiver for the output mask (alpha bitmap)
         * @return        true on success
         */     
        bool loadIcon(string name, Pixmap *pixmap, Pixmap *bitmap)
        {
            Image image;
            int width, height;
            ubyte* imageData;
            
            if (! ResourceGroupManager.getSingleton().resourceExists(ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME, name)) 
                return false;
            
            try 
            {
                image = new Image;
                // Try to load image
                image.load(name, ResourceGroupManager.DEFAULT_RESOURCE_GROUP_NAME);
                
                if(image.getFormat() != PixelFormat.PF_A8R8G8B8)
                {
                    // Image format must be RGBA
                    return false;
                }
                
                width  = cast(int)image.getWidth();
                height = cast(int)image.getHeight();
                imageData = image.getData().ptr;
            } 
            catch(Exception e) 
            {
                // Could not find image; never mind
                return false;
            }
            
            int bitmapLineLength = (width + 7) / 8;
            int pixmapLineLength = 4 * width;
            
            ubyte* bitmapData = cast(ubyte*)malloc(bitmapLineLength * height);
            ubyte* pixmapData = cast(ubyte*)malloc(pixmapLineLength * height);
            
            int sptr = 0, dptr = 0;
            
            auto bo = cast(ByteOrder)XImageByteOrder(mXDisplay);
            for(int y = 0; y < height; y++)
            {
                for(int x = 0; x < width; x++) 
                {
                    if (bo == ByteOrder.MSBFirst) //unmacro ImageByteOrder, Display struct is wacked
                    {
                        pixmapData[dptr + 0] = 0;
                        pixmapData[dptr + 1] = imageData[sptr + 0];
                        pixmapData[dptr + 2] = imageData[sptr + 1];
                        pixmapData[dptr + 3] = imageData[sptr + 2];
                    }
                    else
                    {
                        pixmapData[dptr + 3] = 0;
                        pixmapData[dptr + 2] = imageData[sptr + 0];
                        pixmapData[dptr + 1] = imageData[sptr + 1];
                        pixmapData[dptr + 0] = imageData[sptr + 2];
                    }
                    
                    if((cast(ubyte)imageData[sptr + 3])<128) 
                    {
                        bitmapData[y*bitmapLineLength+(x>>3)] &= ~(1<<(x&7));
                    } 
                    else 
                    {
                        bitmapData[y*bitmapLineLength+(x>>3)] |= 1<<(x&7);
                    }
                    sptr += 4;
                    dptr += 4;
                }
            }
            
            // Create bitmap on server and copy over bitmapData
            *bitmap = XCreateBitmapFromData(mXDisplay, XDefaultRootWindow(mXDisplay), bitmapData, width, height);
            
            free(bitmapData);
            
            // Create pixmap on server and copy over pixmapData (via pixmapXImage)
            *pixmap = XCreatePixmap(mXDisplay, XDefaultRootWindow(mXDisplay), width, height, 24);
            
            GC gc = XCreateGC (mXDisplay, XDefaultRootWindow(mXDisplay), 0, null);
            XImage *pixmapXImage = XCreateImage(mXDisplay, null, 24, ImageFormat.ZPixmap, 0, pixmapData, width, height, 8, width*4);
            XPutImage(mXDisplay, *pixmap, gc, pixmapXImage, 0, 0, 0, 0, width, height);
            XDestroyImage(pixmapXImage);
            XFreeGC(mXDisplay, gc);
            
            return true;
        }
        
        
        /**
         * Get the GLXFBConfig used to create a GLXContext
         *
         * @param context   GLXContext 
         * @return        GLXFBConfig used to create the context
         */
        GLXFBConfig getFBConfigFromContext (GLXContext context)
        {
            GLXFBConfig fbConfig = null;
            
            if (GLXEW_VERSION_1_3)
            {
                int[] fbConfigAttrib = [
                                        GLX_FBCONFIG_ID, 0, 
                                        0 //None
                                        ];
                GLXFBConfig *fbConfigs;
                int nElements = 0;
                
                glXQueryContext(mGLDisplay, context, GLX_FBCONFIG_ID, &fbConfigAttrib[1]);
                fbConfigs = glXChooseFBConfig(mGLDisplay, XDefaultScreen(mGLDisplay), fbConfigAttrib.ptr, &nElements);
                
                if (nElements)
                {
                    fbConfig = fbConfigs[0];
                    XFree(fbConfigs);
                }
            }
            //TODO GLXEW_EXT_import_context
            /*else if (GLXEW_EXT_import_context && GLXEW_SGIX_fbconfig)
             {
             VisualID visualid;
             
             if (glXQueryContextInfoEXT(mGLDisplay, context, GLX_VISUAL_ID, (int*)&visualid))
             {
             fbConfig = getFBConfigFromVisualID(visualid);
             }
             }*/
            
            return fbConfig;
        }
        
        /**
         * Get the GLXFBConfig used to create a GLXDrawable.
         * Caveat: GLX version 1.3 is needed when the drawable is a GLXPixmap
         *
         * @param drawable   GLXDrawable 
         * @param width   Receiver for the drawable width
         * @param height     Receiver for the drawable height
         * @return        GLXFBConfig used to create the drawable
         */
        GLXFBConfig getFBConfigFromDrawable (GLXDrawable drawable, uint* width, uint* height)
        {
            GLXFBConfig fbConfig = null;
            
            if (GLXEW_VERSION_1_3)
            {
                int[] fbConfigAttrib = [
                                        GLX_FBCONFIG_ID, 0, 
                                        0 //None
                                        ];
                GLXFBConfig *fbConfigs;
                int nElements = 0;
                
                glXQueryDrawable (mGLDisplay, drawable, GLX_FBCONFIG_ID, cast(uint*)&fbConfigAttrib[1]);
                
                fbConfigs = glXChooseFBConfig(mGLDisplay, XDefaultScreen(mGLDisplay), fbConfigAttrib.ptr, &nElements);
                
                if (nElements)
                {
                    fbConfig = fbConfigs[0];
                    XFree (fbConfigs);
                    
                    glXQueryDrawable(mGLDisplay, drawable, GLX_WIDTH, width);
                    glXQueryDrawable(mGLDisplay, drawable, GLX_HEIGHT, height);
                }
            }
            
            if (! fbConfig && SGIX_fbconfig)
            {
                XWindowAttributes windowAttrib;
                
                if (XGetWindowAttributes(mGLDisplay, drawable, &windowAttrib))
                {
                    VisualID visualid = XVisualIDFromVisual(windowAttrib.visual);
                    
                    fbConfig = getFBConfigFromVisualID(visualid);
                    
                    *width = windowAttrib.width;
                    *height = windowAttrib.height;
                }
            }
            
            return fbConfig;
        }
        
        /**
         * Select an FBConfig given a list of required and a list of desired properties
         *
         * @param minAttribs FBConfig attributes that must be provided with minimum values
         * @param maxAttribs FBConfig attributes that are desirable with maximum values
         * @return        GLXFBConfig with attributes or 0 when unsupported. 
         */
        GLXFBConfig selectFBConfig(int[] minAttribs, int[] maxAttribs)
        {
            GLXFBConfig *fbConfigs;
            GLXFBConfig fbConfig = null;
            int config, nConfigs = 0;
            
            fbConfigs = chooseFBConfig(minAttribs, &nConfigs);
            
            // this is a fix for cases where chooseFBConfig is not supported.
            // On the 10/2010 chooseFBConfig was not supported on VirtualBox
            // http://www.virtualbox.org/ticket/7195
            if (!nConfigs)      
            {           
                fbConfigs = glXGetFBConfigs(mGLDisplay, XDefaultScreen(mGLDisplay), &nConfigs);      
            }
            
            if (! nConfigs) 
                return null;
            
            fbConfig = fbConfigs[0];
            
            if (maxAttribs)
            {
                FBConfigAttribs maximum = new FBConfigAttribs(maxAttribs);
                FBConfigAttribs best = new FBConfigAttribs(maxAttribs);
                FBConfigAttribs candidate = new FBConfigAttribs(maxAttribs);
                
                best.load(this, fbConfig);
                
                for (config = 1; config < nConfigs; config++)
                {
                    candidate.load(this, fbConfigs[config]);
                    
                    if (candidate > maximum)
                        continue;
                    
                    if (candidate > best)
                    {
                        fbConfig = fbConfigs[config];       
                        
                        best.load(this, fbConfig);
                    }
                }
            }
            
            XFree (fbConfigs);
            return fbConfig;
        }
        
        /**
         * Gets a GLXFBConfig compatible with a VisualID
         * 
         * Some platforms fail to implement glXGetFBconfigFromVisualSGIX as
         * part of the GLX_SGIX_fbconfig extension, but this portable
         * alternative suffices for the creation of compatible contexts.
         *
         * @param visualid   VisualID 
         * @return        FBConfig for VisualID
         */
        GLXFBConfig getFBConfigFromVisualID(VisualID visualid)
        {
            GLXFBConfig fbConfig = null;
            
            if (SGIX_fbconfig && glXGetFBConfigFromVisualSGIX)
            {
                XVisualInfo visualInfo;
                
                visualInfo.screen = XDefaultScreen(mGLDisplay);
                visualInfo.depth = XDefaultDepth(mGLDisplay, XDefaultScreen(mGLDisplay));
                visualInfo.visualid = visualid;
                
                fbConfig = glXGetFBConfigFromVisualSGIX(mGLDisplay, &visualInfo);
            }
            
            if (! fbConfig)
            {
                int[] minAttribs = [
                                    GLX_DRAWABLE_TYPE,  GLX_WINDOW_BIT || GLX_PIXMAP_BIT,
                                    GLX_RENDER_TYPE,    GLX_RGBA_BIT,
                                    GLX_RED_SIZE,      1,
                                    GLX_BLUE_SIZE,    1,
                                    GLX_GREEN_SIZE,  1,
                                    0 //None
                                    ];
                int nConfigs = 0;
                
                GLXFBConfig *fbConfigs = chooseFBConfig(minAttribs, &nConfigs);
                
                for (int i = 0; i < nConfigs && ! fbConfig; i++)
                {
                    XVisualInfo *visualInfo = getVisualFromFBConfig(fbConfigs[i]);
                    
                    if (visualInfo.visualid == visualid)
                        fbConfig = fbConfigs[i];
                    
                    XFree(visualInfo);
                }
                
                XFree(fbConfigs);
            }
            
            return fbConfig;
        }
        
        /**
         * Portable replacement for glXChooseFBConfig 
         */
        GLXFBConfig* chooseFBConfig(GLint[] attribList, GLint *nElements)
        {
            GLXFBConfig *fbConfigs;
            
            //if (GLXEW_VERSION_1_3)
            fbConfigs = glXChooseFBConfig(mGLDisplay, XDefaultScreen(mGLDisplay), attribList.ptr, nElements);
            //else
            //    fbConfigs = glXChooseFBConfigSGIX(mGLDisplay, XDefaultScreen(mGLDisplay), attribList.ptr, nElements);
            
            return fbConfigs;
        }
        
        /**
         * Portable replacement for glXCreateNewContext
         */
        GLXContext createNewContext(GLXFBConfig fbConfig, GLint renderType, GLXContext shareList, GLboolean direct) //const
        {
            GLXContext glxContext;
            
            //if (GLXEW_VERSION_1_3)
            glxContext = glXCreateNewContext(mGLDisplay, fbConfig, renderType, shareList, direct);
            //else //TODO SGIX
            //    glxContext = glXCreateContextWithConfigSGIX(mGLDisplay, fbConfig, renderType, shareList, direct);
            
            return glxContext;
        }
        
        /**
         * Portable replacement for glXGetFBConfigAttrib
         */
        GLint getFBConfigAttrib(GLXFBConfig fbConfig, GLint attribute, GLint *value)
        {
            GLint status;
            //TODO SGIX
            //if (GLXEW_VERSION_1_3)
            status = glXGetFBConfigAttrib(mGLDisplay, fbConfig, attribute, value);
            //else
            //    status = glXGetFBConfigAttribSGIX(mGLDisplay, fbConfig, attribute, value);
            
            return status;
        }
        
        /**
         * Portable replacement for glXGetVisualFromFBConfig
         */
        XVisualInfo* getVisualFromFBConfig(GLXFBConfig fbConfig)
        {
            XVisualInfo *visualInfo;
            //TODO SGIX
            //if (GLXEW_VERSION_1_3)
            visualInfo = glXGetVisualFromFBConfig(mGLDisplay, fbConfig);
            //else
            //    visualInfo = glXGetVisualFromFBConfigSGIX(mGLDisplay, fbConfig);
            
            return visualInfo;
        }
        
    private:
        /**
         * Initialise GLXEW without requiring a current GL context
         */
        // Initialise GLXEW
        // 
        // Overloading glXGetCurrentDisplay allows us to call glxewContextInit
        // before establishing a GL context. This approach is a bit of a hack,
        // but it minimises the patches required between glew.c and glew.cpp.
        void initialiseGLXEW()
        {
            if (glxewContextInit(/*this, */ mGLDisplay) != GLEW_OK)
            {
                XCloseDisplay (mGLDisplay);
                XCloseDisplay (mXDisplay);
                throw new RenderingApiError("No GLX 1.1 support on your platform", "GLXGLSupport.initialiseGLXEW");
            }
        }
        
        /**
         * Refresh config options to reflect dependencies
         */
        void refreshConfig()
        {
            auto optVideoMode = "Video Mode" in mOptions;
            auto optDisplayFrequency = "Display Frequency" in mOptions;
            
            if (optVideoMode !is null && optDisplayFrequency !is null)
            {
                optDisplayFrequency.possibleValues.clear();
                
                
                foreach (value; mVideoModes)
                {
                    string mode = to!string(value.first.first) ~ " x " ~ to!string(value.first.second);
                    
                    if (mode == optVideoMode.currentValue)
                    {
                        string frequency = to!string(value.second) ~ " Hz";
                        
                        optDisplayFrequency.possibleValues ~= frequency;
                    }
                }
                
                if (! optDisplayFrequency.possibleValues.empty())
                {
                    optDisplayFrequency.currentValue = optDisplayFrequency.possibleValues[0];
                }
                else
                {
                    optVideoMode.currentValue = to!string(mVideoModes[0].first.first) ~ " x " ~ to!string(mVideoModes[0].first.second);
                    optDisplayFrequency.currentValue = to!string(mVideoModes[0].second) ~ " Hz";
                }
            }
        }
        
        Display* mGLDisplay; // used for GL/GLX commands
        Display* mXDisplay;  // used for other X commands and events
        bool mIsExternalDisplay;
        
        alias pair!(uint, uint)         ScreenSize;
        alias short                     Rate;
        alias pair!(ScreenSize, Rate)   VideoMode;
        alias VideoMode[]               VideoModes;
        
        VideoModes mVideoModes;
        VideoMode  mOriginalMode;
        VideoMode  mCurrentMode;
        
        string[] mSampleLevels;
    }

    // A helper class for the implementation of selectFBConfig

    class FBConfigAttribs
    {
        alias Object.opCmp opCmp;
    public:
        this(int[] attribs)
        {
            fields[GLX_CONFIG_CAVEAT] = 0;
            
            for (int i = 0; attribs[2*i]; i++)
            {
                fields[attribs[2*i]] = attribs[2*i+1];
            }
        }
        
        void load(GLXGLSupport glSupport, GLXFBConfig fbConfig)
        {
            foreach (k,v; fields)
            {
                fields[k] = 0;
                
                glSupport.getFBConfigAttrib(fbConfig, k, &fields[k]);
            }
        }
        
        //TODO fix as opCmp?
        //bool opGT(FBConfigAttribs alternative)
        int opCmp(FBConfigAttribs alternative)
        {
            // Caveats are best avoided, but might be needed for anti-aliasing
            
            if (fields[GLX_CONFIG_CAVEAT] != alternative.fields[GLX_CONFIG_CAVEAT])
            {
                if (fields[GLX_CONFIG_CAVEAT] == GLX_SLOW_CONFIG)
                    return -1;//false;
                
                if ((GLX_SAMPLES in fields) !is null && 
                    fields[GLX_SAMPLES] < alternative.fields[GLX_SAMPLES])
                    return -1;//false;
            }
            
            foreach (k,v; fields)
            {
                if (k != GLX_CONFIG_CAVEAT && fields[k] > alternative.fields[k])
                    return 1;//true;
            }
            
            return -1;//false;
        }
        
        int[int] fields;
    }
}
