module ogregl.sdl.support;
import ogregl.config;

static if(USE_SDL)
{
    import std.string : indexOf;
    import std.conv : to;
    debug import std.stdio;
    import ogre.config;
    import ogre.compat;
    import ogre.exception;
    import ogre.general.common;
    import ogre.general.log;
    import ogre.rendersystem.rendersystem;
    import ogre.rendersystem.renderwindow;

    import derelict.sdl2.sdl;
    import derelict.opengl3.gl;
    import ogregl.support;
    import ogregl.sdl.window;
    import ogregl.rendersystem;


    class SDLGLSupport : GLSupport
    {
    public:
        this()
        {
            DerelictSDL2.load();
            DerelictGL.load();
            if (SDL_Init(SDL_INIT_VIDEO) < 0) {
                throw new Exception("Failed to initialize SDL: " ~ to!string(SDL_GetError()));
            }
            
        }

        ~this() {}
        
        /**
         * Add any special config values to the system.
         * Must have a "Full Screen" value that is a bool and a "Video Mode" value
         * that is a string in the form of wxh
         */
        override void addConfig()
        {
            //mDisplayModes = SDL_ListModes(null, SDL_WINDOW_FULLSCREEN | SDL_WINDOW_OPENGL);
            
            int disps = SDL_GetNumVideoDisplays();
            if (disps < 1)
            {
                throw new RenderingApiError("Wait... no displays?",
                                            "SDLRenderSystem.initConfigOptions");
            }
            
            mDisplayModes.length = disps;
            debug writeln("Display count: ",disps);
            
            foreach(disp; 0..disps)
            {
                int count = SDL_GetNumDisplayModes(disp);
                debug writeln("Display mode count: ",disp, ", ", count);
                if (count < 1 && disp == 0)
                {
                    throw new RenderingApiError("Unable to load video modes",
                                                "SDLRenderSystem.initConfigOptions");
                }
                else if(count < 1)
                    continue; //atleast one works
                
                foreach(uint i; 0..count)
                {
                    SDL_DisplayMode dispmode;
                    SDL_GetDisplayMode(disp, i, &dispmode);
                    mDisplayModes[disp] ~= dispmode;
                    debug writeln(dispmode);
                }
            }
            
            
            ConfigOption optFullScreen;
            ConfigOption optDisplay;
            ConfigOption optVideoMode;
            ConfigOption optFSAA;
            ConfigOption optRTTMode;

            static if(RTSHADER_SYSTEM_BUILD_CORE_SHADERS)
                ConfigOption optEnableFixedPipeline;

            
            // FS setting possibilities
            optFullScreen.name = "Full Screen";
            optFullScreen.possibleValues.insert("Yes");
            optFullScreen.possibleValues.insert("No");
            optFullScreen.currentValue = "Yes";
            optFullScreen._immutable = false;
            
            optDisplay.name = "Display";
            foreach(i; 0..disps)
                optDisplay.possibleValues.insert(std.conv.to!string(cast(char*)SDL_GetDisplayName(i))); //Is a string or just index int?
            optDisplay.currentValue = std.conv.to!string(cast(char*)SDL_GetDisplayName(0));
            optDisplay._immutable = false;
            
            // Video mode possibilities
            optVideoMode.name = "Video Mode";
            optVideoMode._immutable = false;
            //FIXME Multi display support
            for (size_t i = 0; i < mDisplayModes[0].length; i++)
            {
                string tmp = std.conv.text(mDisplayModes[0][i].w, " x ", mDisplayModes[0][i].h, " @ ", mDisplayModes[0][i].refresh_rate);
                optVideoMode.possibleValues.insert(tmp);
                // Make the first one default
                if (i == 0)
                {
                    optVideoMode.currentValue = tmp;
                }
            }
            
            //FSAA possibilities
            optFSAA.name = "FSAA";
            optFSAA.possibleValues.insert("0");
            optFSAA.possibleValues.insert("2");
            optFSAA.possibleValues.insert("4");
            optFSAA.possibleValues.insert("6");
            optFSAA.currentValue = "0";
            optFSAA._immutable = false;
            
            optRTTMode.name = "RTT Preferred Mode";
            optRTTMode.possibleValues.insert("FBO");
            optRTTMode.possibleValues.insert("PBuffer");
            optRTTMode.possibleValues.insert("Copy");
            optRTTMode.currentValue = "FBO";
            optRTTMode._immutable = false;
            
            static if (RTSHADER_SYSTEM_BUILD_CORE_SHADERS)
            {
                optEnableFixedPipeline.name = "Fixed Pipeline Enabled";
                optEnableFixedPipeline.possibleValues.insert( "Yes" );
                optEnableFixedPipeline.possibleValues.insert( "No" );
                optEnableFixedPipeline.currentValue = "Yes";
                optEnableFixedPipeline._immutable = false;
            }
            
            mOptions[optFullScreen.name] = optFullScreen;
            mOptions[optDisplay.name] = optDisplay;
            mOptions[optVideoMode.name] = optVideoMode;
            mOptions[optFSAA.name] = optFSAA;
            mOptions[optRTTMode.name] = optRTTMode;
            static if (RTSHADER_SYSTEM_BUILD_CORE_SHADERS)
                mOptions[optEnableFixedPipeline.name] = optEnableFixedPipeline;
            
        }
        /**
         * Make sure all the extra options are valid
         */
        override string validateConfig()
        {
            return "";
        }
        
        override RenderWindow createWindow(bool autoCreateWindow, GLRenderSystem renderSystem, string windowTitle)
        {
            if (autoCreateWindow)
            {
                ConfigOption* opt = "Full Screen" in mOptions;
                if (opt is null)
                    throw new RenderingApiError("Can't find full screen options!", "SDLGLSupport.createWindow");

                bool fullscreen = (opt.currentValue == "Yes");
                
                opt = "Video Mode" in mOptions;
                if (opt is null)
                    throw new RenderingApiError("Can't find video mode options!", "SDLGLSupport.createWindow");

                ptrdiff_t pos = opt.currentValue.indexOf('x');
                if (pos == -1)
                    throw new RenderingApiError("Invalid Video Mode provided", "SDLGLSupport.createWindow");
                
                string[] vals = opt.currentValue.split(" ");
                debug writeln(vals[0], ", ", vals[2]);
                uint w = to!uint(vals[0]);
                uint h = to!uint(vals[2]);
                
                // Parse FSAA config
                NameValuePairList winOptions;
                winOptions["title"] = windowTitle;
                int fsaa_x_samples = 0;
                opt = "FSAA" in mOptions;
                if(opt !is null)
                {
                    winOptions["FSAA"] = opt.currentValue;
                }
                
                static if (RTSHADER_SYSTEM_BUILD_CORE_SHADERS)
                {
                    opt = "Fixed Pipeline Enabled" in mOptions;
                    if (opt is null)
                        throw new InvalidParamsError("Can't find Fixed Pipeline enabled options!", "SDLGLSupport.createWindow");
                    bool enableFixedPipeline = (opt.currentValue == "Yes");
                    renderSystem.setFixedPipelineEnabled(enableFixedPipeline);
                }
                
                //SDL_VideoInfo* videoInfo = SDL_GetVideoInfo();
                //FIXME Iffy call to createRenderWindow. Maybe meant Root.createRenderWindow ?
                return renderSystem._createRenderWindow(windowTitle, w, h, fullscreen, winOptions);
            }
            else
            {
                // XXX What is the else?
                return null;
            }
        }
        
        /// @copydoc RenderSystem::createRenderWindow
        override RenderWindow newWindow(string name, uint width, uint height, 
                               bool fullScreen, NameValuePairList miscParams = null)
        {
            SDLWindow window = new SDLWindow();
            window.create(name, width, height, fullScreen, miscParams);
            return window;
        }
        
        /**
         * Start anything special
         */
        override void start()
        {
            LogManager.getSingleton().logMessage(
                "******************************\n"
                "*** Starting SDL Subsystem ***\n"
                "******************************");
            
            if (SDL_Init(SDL_INIT_VIDEO) < 0) {
                throw new Exception("Failed to initialize SDL: " ~ to!string(SDL_GetError()));
            }
        }
        /**
         * Stop anything special
         */
        override void stop()
        {
            LogManager.getSingleton().logMessage(
                "******************************\n"
                "*** Stopping SDL Subsystem ***\n"
                "******************************");
            
            //SDL_Quit();
        }
        
        /**
         * Get the address of a function
         */
        override void* getProcAddress(string procname)
        {
            return SDL_GL_GetProcAddress(CSTR(procname));
        }

    private:
        // Allowed video modes
        //SDL_Rect** mDisplayModes;
        SDL_DisplayMode[][] mDisplayModes;
        
        
    } // class SDLGLSupport
}