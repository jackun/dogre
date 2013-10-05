module ogre.general.glx.configdialog;

import ogre.config;
static if(!OGRE_GTK && OgrePosix)
{
    import std.array;
    import ogre.bindings.mini_x11;
    import ogre.bindings.mini_xaw;
    import ogre.compat;
    import ogre.general.root;
    import ogre.general.common;
    import ogre.exception;
    import ogre.general.log;
    import ogre.resources.datastream;
    import ogre.image.pixelformat;
    import ogre.rendersystem.rendersystem;
    import ogre.image.images;
    import ogre.backdrop;
    debug
        import std.stdio;

    /// Can't pass class to C, wrap it.
    struct GLXConfiguratorPtr
    {
        GLXConfigurator conf;
    }

    /**
     * Single X window with image backdrop, making it possible to configure
     * OGRE in a graphical way.
     * XaW uses a not-very-smart widget positioning system, so I override it to use
     * fixed positions. This works great, but it means you need to define the various
     * positions manually.
     * Furthermore, it has no OptionMenu by default, so I simulate this with dropdown
     * buttons.
     */
    class GLXConfigurator 
    {
        /* GUI constants */
        enum int wWidth = 400;      // Width of window
        enum int wHeight = 340;     // Height of window
        enum int col1x = 20;        // Starting x of column 1 (labels)
        enum int col2x = 180;       // Starting x of column 2 (options)
        enum int col1w = 150;       // Width of column 1 (labels)
        enum int col2w = 200;       // Width of column 2 (options)
        enum int ystart = 105;      // Starting y of option table rows
        enum int rowh = 20;     // Height of one row in the option table
        
    public:
        this()
        {
            //mDisplay = null;
            mWindow = 0;
            //mBackDrop = 0;
            mWidth = wWidth;
            mHeight = wHeight;
            //appContext = 0;
            toplevel = null;
            accept = false;
            //mRenderer = 0;
            This = new GLXConfiguratorPtr(this);
        }
        ~this()
        {
            if(mBackDrop)
                XFreePixmap(mDisplay, mBackDrop);
            if(toplevel) {
                XtUnrealizeWidget(toplevel);
                XtDestroyWidget(toplevel);
            }
            if(mDisplay) {
                XCloseDisplay(mDisplay);
            }
        }
        
        bool CreateWindow()
        {
            char*[] bla = [CSTR("Rendering Settings"), CSTR("-bg"), CSTR("honeydew3"), CSTR("-fg"), CSTR("black"),CSTR("-bd"),CSTR("darkseagreen4")];
            int argc = cast(int)bla.length;

            toplevel = XtVaOpenApplication(&appContext, CSTR("OGRE"), null, 0, &argc, bla.ptr, null, sessionShellWidgetClass,
                                           CSTR("width"), mWidth,
                                           CSTR("height"), mHeight,
                                           CSTR("minWidth"), mWidth,
                                           CSTR("maxWidth"), mWidth,
                                           CSTR("minHeight"), mHeight,
                                           CSTR("maxHeight"), mHeight,
                                           CSTR("allowShellResize"), False,
                                           CSTR("borderWidth"), 0,
                                           CSTR("overrideRedirect"), False,
                                           null, null);
            
            /* Find out display and screen used */
            mDisplay = XtDisplay(toplevel);
            int screen = XDefaultScreen(mDisplay);
            //Window rootWindow = RootWindow(mDisplay,screen);//Returns carbage
            Window rootWindow = XRootWindow(mDisplay,screen);
            
            /* Move to center of display */
            int w = XDisplayWidth(mDisplay, screen);
            int h = XDisplayHeight(mDisplay, screen);
            debug writeln(w,"x",h);
            XtVaSetValues(toplevel,
                          CSTR("x"), w/2-mWidth/2,
                          CSTR("y"), h/2-mHeight/2, 0, null);
            
            /* Backdrop stuff */
            debug writeln("Depth: ", XDefaultDepth(mDisplay,screen));
            mBackDrop = CreateBackdrop(rootWindow, XDefaultDepth(mDisplay,screen));
            
            /* Create toplevel */
            box = XtVaCreateManagedWidget(CSTR("box"),formWidgetClass,toplevel,
                                          CSTR("backgroundPixmap"), mBackDrop,
                                          0,null);
            
            /* Create renderer selection */
            int cury = ystart + 0*rowh;
            
            XtVaCreateManagedWidget(CSTR("topLabel"), labelWidgetClass, box, 
                                    CSTR("label"), CSTR("Select Renderer"), 
                                    CSTR("borderWidth"), 0,
                                    CSTR("width"), col1w,    // Fixed width
                                    CSTR("height"), 18,
                                    CSTR("left"), XawEdgeType.XawChainLeft,
                                    CSTR("top"), XawEdgeType.XawChainTop,
                                    CSTR("right"), XawEdgeType.XawChainLeft,
                                    CSTR("bottom"), XawEdgeType.XawChainTop,
                                    CSTR("horizDistance"), col1x,
                                    CSTR("vertDistance"), cury,
                                    CSTR("justify"), XtJustify.XtJustifyLeft,
                                    null);
            
            string curRenderName = " Select One "; // Name of current renderer, or hint to select one
            if(mRenderer !is null)
                curRenderName = mRenderer.getName();
            Widget mb1 = XtVaCreateManagedWidget(CSTR("Menu"), menuButtonWidgetClass, box, CSTR("label"),
                                                 CSTR(curRenderName),
                                                 CSTR("resize"), false,
                                                 CSTR("resizable"), false,
                                                 CSTR("width"), col2w,    // Fixed width
                                                 CSTR("height"), 18,
                                                 CSTR("left"), XawEdgeType.XawChainLeft,
                                                 CSTR("top"), XawEdgeType.XawChainTop,
                                                 CSTR("right"), XawEdgeType.XawChainLeft,
                                                 CSTR("bottom"), XawEdgeType.XawChainTop,
                                                 CSTR("horizDistance"), col2x,
                                                 CSTR("vertDistance"), cury,
                                                 null);
            
            Widget menu = XtVaCreatePopupShell(CSTR("menu"), simpleMenuWidgetClass, mb1,
                                               0, null);

            version(unittest)
            {
                options["Test Entry"] = ConfigOption("Test Entry", "My name is Test", ["My name is Test", "Another option"], false);
                auto renderers = [new FakeClass("Entry 1"), new FakeClass("Entry 2"), new FakeClass("Entry 3")];
            }
            else
                RenderSystemList renderers = Root.getSingleton().getAvailableRenderers();

            foreach (pRend; renderers) 
            {
                // Create callback data
                mRendererCallbackData.insert(new RendererCallbackData(this, pRend, mb1));
                
                Widget entry = XtVaCreateManagedWidget(CSTR("menuentry"), smeBSBObjectClass, menu,
                                                       CSTR("label"), CSTR(pRend.getName()),
                                                       0, null);
                XtAddCallback(entry, CSTR("callback"), &renderSystemHandler, cast(void*)mRendererCallbackData.back);
            }
            
            Widget bottomPanel = XtVaCreateManagedWidget(CSTR("bottomPanel"), formWidgetClass, box,
                                                         CSTR("sensitive"), True,
                                                         CSTR("borderWidth"), 0,
                                                         CSTR("width"), 150,  // Fixed width
                                                         CSTR("left"), XawEdgeType.XawChainLeft,
                                                         CSTR("top"), XawEdgeType.XawChainTop,
                                                         CSTR("right"), XawEdgeType.XawChainLeft,
                                                         CSTR("bottom"), XawEdgeType.XawChainTop,
                                                         CSTR("horizDistance"), mWidth - 160,
                                                         CSTR("vertDistance"), mHeight - 40,
                                                         null);
            
            Widget helloButton = XtVaCreateManagedWidget(CSTR("cancelButton"), commandWidgetClass, bottomPanel, CSTR("label"),CSTR(" Cancel "), null);
            XtAddCallback(helloButton, CSTR("callback"), cast(XtCallbackProc)&cancelHandler, This);
            
            Widget exitButton = XtVaCreateManagedWidget(CSTR("acceptButton"), commandWidgetClass, bottomPanel, CSTR("label"),CSTR(" Accept "), CSTR("fromHoriz"),helloButton, null);
            XtAddCallback(exitButton, CSTR("callback"), &acceptHandler, This);
            
            XtRealizeWidget(toplevel);
            
            if(mRenderer !is null)
                /* There was already a renderer selected; display its options */
                SetRenderer(mRenderer);
            
            return true;
        }

        void Main()
        {
            XtAppMainLoop(appContext);
        }

        /**
     * Exit from main loop.
     */
        void Exit()
        {
            XtAppSetExitFlag(appContext);
        }

    protected:
        Display *mDisplay;
        Window mWindow;
        Pixmap mBackDrop;
        
        int mWidth, mHeight;
        // Xt
        XtAppContext appContext;
        Widget toplevel;
        GLXConfiguratorPtr* This;

        /**
     * Create backdrop image, and return it as a Pixmap.
     */
        Pixmap CreateBackdrop(Window rootWindow, int depth)
        {
            int bpl;
            /* Find out number of bytes per pixel */
            switch(depth) {
                default:
                    version(unittest)
                    {
                        writeln("GLX backdrop: Unsupported bit depth");
                    }
                    else
                        LogManager.getSingleton().logMessage("GLX backdrop: Unsupported bit depth");
                    /* Unsupported bit depth */
                    return 0;
                case 15:
                case 16:
                    bpl = 2; break;
                case 24:
                case 32:
                    bpl = 4; break;
            }
            /* Create background pixmap */
            //ubyte[] data; // Must be allocated with malloc
            void* data;

            int size = mWidth * mHeight * bpl;

            try {
                string imgType = "png";
                Image img = new Image;
                MemoryDataStream imgStream;
                
                // Load backdrop image using OGRE
                imgStream = new MemoryDataStream(cast(ubyte[])GLX_backdrop_data, false);
                img.load(imgStream, imgType);
                
                PixelBox src = img.getPixelBox(0, 0);
                
                // Convert and copy image
                //data = new ubyte[mWidth * mHeight * bpl]; // Must be allocated with malloc
                data = core.stdc.stdlib.malloc(size);
                core.memory.GC.addRange(data, size);
                
                PixelBox dst = new PixelBox(src, bpl == 2 ? PixelFormat.PF_B5G6R5 : PixelFormat.PF_A8R8G8B8, data);
                
                PixelUtil.bulkPixelConversion(src, dst);
            } catch(Exception e) {
                // Could not find image; never mind
                version(unittest)
                {
                    writeln("WARNING: Can not load backdrop for config dialog. " ~ e.msg, LML_TRIVIAL);
                }
                else
                    LogManager.getSingleton().logMessage("WARNING: Can not load backdrop for config dialog. " ~ e.msg, LML_TRIVIAL);
                return 0;
            }
            
            GC context = XCreateGC (mDisplay, rootWindow, 0, null);
            
            /* put my pixmap data into the client side X image data structure */
            XImage *image = XCreateImage (mDisplay, null, depth, ImageFormat.ZPixmap, 0,
                                          data,
                                          mWidth, mHeight, 8,
                                          mWidth*bpl);
            version(BigEndian)
                image.byte_order = ByteOrder.MSBFirst;
            else
                image.byte_order = ByteOrder.LSBFirst;
            
            /* tell server to start managing my pixmap */
            Pixmap rv = XCreatePixmap(mDisplay, rootWindow, mWidth,
                                      mHeight, depth);

            /* copy from client to server */
            XPutImage(mDisplay, rv, context, image, 0, 0, 0, 0,
                      mWidth, mHeight);
            
            /* free up the client side pixmap data area */
            XDestroyImage(image); // also cleans data
            XFreeGC(mDisplay, context);
            core.memory.GC.removeRange(data);//TODO Yep, removeRange too or double free
            
            return rv;
        }
        /**
         * Called after window initialisation.
         */
        bool Init()
        {
            // Init misc resources
            return true;
        }
        /**
         * Called initially, and on expose.
         */
        void Draw() {}

    public:
        /* Local */
        bool accept;

        version(unittest)
        {
            class FakeClass
            {
                string mName;
            public:
                this(string name) { mName = name; }
                string getName() { return mName; }
                void setConfigOption(string k,string v)
                {
                    options[k].currentValue = v;
                }
            }
            ConfigOptionMap options;
            alias FakeClass _RenderSystem;
        }
        else
            alias RenderSystem _RenderSystem;

        /* Class that binds a callback to a RenderSystem */
        struct RendererCallbackData
        {
        /*public:
            this(GLXConfigurator _parent, RenderSystem _renderer, Widget _optionmenu)
            {
                parent = _parent;
                renderer = _renderer;
                optionmenu = _optionmenu;
            }*/
            GLXConfigurator parent;
            _RenderSystem renderer;
            Widget optionmenu;
        }

        RendererCallbackData*[] mRendererCallbackData;
        
        _RenderSystem mRenderer;
        Widget box;                 // Box'o control widgets
        Widget[] mRenderOptionWidgets; // List of RenderSystem specific

        // widgets for visibility management (cleared when another rendersystem is selected)
        /* Class that binds a callback to a certain configuration option/value */
        struct ConfigCallbackData 
        {
        /*public:
            this(GLXConfigurator _parent, string _optionName, string _valueName, Widget _optionmenu)
            {
                parent = _parent;
                optionName = _optionName;
                valueName = _valueName;
                optionmenu = _optionmenu;
            }*/
            GLXConfigurator parent;
            string optionName, valueName;
            Widget optionmenu;
        }

        ConfigCallbackData*[] mConfigCallbackData;
        
        void SetRenderSystem(_RenderSystem sys) {
            mRenderer = sys;
        }
    private:
        /* Callbacks that terminate modal dialog loop */
        extern (C) static void acceptHandler(Widget w, void *_obj, XtPointer callData) {
            GLXConfigurator* obj = cast(GLXConfigurator*)_obj;
            // Check if a renderer was selected, if not, don't accept
            if(!obj.mRenderer)
                return;
            obj.accept = true;
            obj.Exit();
        }
        extern (C) static void cancelHandler(Widget w, void *_obj, XtPointer callData) {
            GLXConfigurator* obj = cast(GLXConfigurator*)_obj;
            obj.Exit();
        }
        /* Callbacks that set a setting */
        extern (C) static void renderSystemHandler(Widget w, void *_cdata, XtPointer callData) {
            RendererCallbackData* cdata = cast(RendererCallbackData*)_cdata;
            // Set selected renderer its name
            XtVaSetValues(cdata.optionmenu, CSTR("label"), CSTR(cdata.renderer.getName()), 0, null);
            // Notify Configurator (and Ogre)
            cdata.parent.SetRenderer(cdata.renderer);
        }
        extern (C) static void configOptionHandler(Widget w, void *_cdata, XtPointer callData) {
            ConfigCallbackData* cdata = cast(ConfigCallbackData*)_cdata;
            version(unittest)
                writeln("Selected: ",cdata.valueName);
            // Set selected renderer its name
            XtVaSetValues(cdata.optionmenu, CSTR("label"), CSTR(cdata.valueName), 0, null);
            // Notify Configurator (and Ogre)
            cdata.parent.SetConfigOption(cdata.optionName, cdata.valueName);
        }
        
        /* Functions reacting to GUI */
        void SetRenderer(_RenderSystem r)
        {
            mRenderer = r;
            
            // Destroy each widget of GUI of previously selected renderer
            foreach(i; mRenderOptionWidgets)
                XtDestroyWidget(i);
            mRenderOptionWidgets.clear();
            //mConfigCallbackData.back();
            mConfigCallbackData.clear();
            
            // Create option GUI
            int cury = ystart + 1*rowh + 10;

            version(unittest)
            {
                //Nothing
            }
            else
                ConfigOptionMap options = mRenderer.getConfigOptions();

            // Process each option and create an optionmenu widget for it
            foreach (k,v; options) 
            {
                // if the config option does not have any possible value, then skip it.
                // if we create a popup with zero entries, it will crash when you click
                // on it.
                if (!v.possibleValues.length)
                    continue;
                
                Widget lb1 = XtVaCreateManagedWidget(CSTR("topLabel"), labelWidgetClass, box, 
                                                     CSTR("label"), CSTR(v.name), 
                                                     CSTR("borderWidth"), 0,
                                                     CSTR("width"), col1w,    // Fixed width
                                                     CSTR("height"), 18,
                                                     CSTR("left"), XawEdgeType.XawChainLeft,
                                                     CSTR("top"), XawEdgeType.XawChainTop,
                                                     CSTR("right"), XawEdgeType.XawChainLeft,
                                                     CSTR("bottom"), XawEdgeType.XawChainTop,
                                                     CSTR("horizDistance"), col1x,
                                                     CSTR("vertDistance"), cury,
                                                     CSTR("justify"), XtJustify.XtJustifyLeft,
                                                     null);
                mRenderOptionWidgets.insert(lb1);
                Widget mb1 = XtVaCreateManagedWidget(CSTR("Menu"), menuButtonWidgetClass, box, 
                                                     CSTR("label"), CSTR(v.currentValue),
                                                     CSTR("resize"), false,
                                                     CSTR("resizable"), false,
                                                     CSTR("width"), col2w,    // Fixed width
                                                     CSTR("height"), 18,
                                                     CSTR("left"), XawEdgeType.XawChainLeft,
                                                     CSTR("top"), XawEdgeType.XawChainTop,
                                                     CSTR("right"), XawEdgeType.XawChainLeft,
                                                     CSTR("bottom"), XawEdgeType.XawChainTop,
                                                     CSTR("horizDistance"), col2x,
                                                     CSTR("vertDistance"), cury,
                                                     null);
                mRenderOptionWidgets.insert(mb1);
                
                Widget menu = XtVaCreatePopupShell(CSTR("menu"), simpleMenuWidgetClass, mb1,
                                                   0, null);
                
                // Process each choice
                foreach (opt_it; v.possibleValues) 
                {
                    // Create callback data
                    mConfigCallbackData.insert(new ConfigCallbackData(this, v.name, opt_it, mb1));
                    
                    Widget entry = XtVaCreateManagedWidget(CSTR("menuentry"), smeBSBObjectClass, menu,
                                                           CSTR("label"), CSTR(opt_it),
                                                           0, null);
                    XtAddCallback(entry, CSTR("callback"), cast(XtCallbackProc)&configOptionHandler, mConfigCallbackData.back);
                }
                cury += rowh;
            }
        }

        void SetConfigOption(string optionName, string valueName)
        {
            if(mRenderer is null)
                // No renderer set -- how can this be called?
                return;
            mRenderer.setConfigOption(optionName, valueName);
            SetRenderer(mRenderer);
        }
    }

    /** Defines the behaviour of an automatic renderer configuration dialog.
        @remarks
            OGRE comes with it's own renderer configuration dialog, which
            applications can use to easily allow the user to configure the
            settings appropriate to their machine. This class defines the
            interface to this standard dialog. Because dialogs are inherently
            tied to a particular platform's windowing system, there will be a
            different subclass for each platform.
        @author
            Steven J. Streeting
        */
    class ConfigDialog //: public UtilityAlloc
    {
    public:
        this() {}
        
        /** Displays the dialog.
            @remarks
                This method displays the dialog and from then on the dialog
                interacts with the user independently. The dialog will be
                calling the relevant OGRE rendering systems to query them for
                options and to set the options the user selects. The method
                returns when the user closes the dialog.
            @returns
                If the user accepted the dialog, <b>true</b> is returned.
            @par
                If the user cancelled the dialog (indicating the application
                should probably terminate), <b>false</b> is returned.
            @see
                RenderSystem
            */
        bool display()
        {
            GLXConfigurator test = new GLXConfigurator;
            version(unittest)
            {
                //nothing
            }
            else
            {
                /* Select previously selected rendersystem */
                if(Root.getSingleton().getRenderSystem())
                    test.SetRenderSystem(Root.getSingleton().getRenderSystem());
            }

            /* Attempt to create the window */
            if(!test.CreateWindow())
                throw new InternalError("Could not create configuration dialog",
                            "GLXConfig.display");
            
            // Modal loop
            test.Main();
            if(!test.accept) // User did not accept
                return false;

            version(unittest)
            {
                //nothing
            }
            else
            {
                /* All done */
                Root.getSingleton().setRenderSystem(test.mRenderer);
            }
            
            return true;
        }
        
    protected:
        RenderSystem mSelectedRenderSystem;
    }

    unittest
    {
        //For backdrop
        static if(OGRE_FREEIMAGE)
        {
            import ogre.image.freeimage;
            FreeImageCodec.startup();
        }

        import std.stdio;
        writeln(__FILE__, ": ConfigDialog unittest");
        ConfigDialog dlg = new ConfigDialog;
        writeln("Dialog returned: ", dlg.display());

        static if(OGRE_FREEIMAGE)
            FreeImageCodec.shutdown();
    }
}