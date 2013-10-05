module ogregl.windows.support;

version(Windows):
import std.conv;
import std.array;
import std.string;

import derelict.opengl3.gl;
import derelict.opengl3.wgl;
import ogre.bindings.mini_win32;
import ogre.exception;
import ogre.general.common;
import ogre.general.log;
import ogre.compat;
import ogre.config;
import ogregl.util;
import ogregl.support;
import ogregl.rendersystem;
import ogregl.pbuffer;
import ogre.rendersystem.renderwindow;
import ogre.image.pixelformat;
import ogregl.windows.window;
import ogre.strings;
import ogregl.windows.pbuffer;

alias core.sys.windows.windows.GetLastError GetLastError;
alias core.sys.windows.windows.FormatMessageA FormatMessageA;
alias std.string.split split;

//TODO See also GetErrorStr() in DerelictUtil
string translateWGLError()
{
    int winError = GetLastError();
    char[] errDesc;
    int i;
    
    errDesc = new char[255];
    // Try windows errors first
    i = FormatMessageA(
        FORMAT_MESSAGE_FROM_SYSTEM |
        FORMAT_MESSAGE_IGNORE_INSERTS,
        null,
        winError,
        MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), // Default language
        cast(LPTSTR) errDesc.ptr,
        255,
        null
        );
    
    return to!string(errDesc);
}
class Win32GLSupport : GLSupport
{
    extern(Windows) 
        nothrow static LRESULT dummyWndProc(HWND hwnd, UINT umsg, WPARAM wp, LPARAM lp)
    {
        try
        {
            return DefWindowProc(hwnd, umsg, wp, lp);
        }catch(Exception){}
        return 0;
    }
    
    extern(Windows) static BOOL sCreateMonitorsInfoEnumProc(
        HMONITOR hMonitor,  // handle to display monitor
        HDC hdcMonitor,     // handle to monitor DC
        LPRECT lprcMonitor, // monitor intersection rectangle
        LPARAM dwData       // data
        )
    {
        DisplayMonitorInfoList* pArrMonitorsInfo = cast(DisplayMonitorInfoList*)dwData;
        
        // Get monitor info
        DisplayMonitorInfo displayMonitorInfo;
        
        displayMonitorInfo.hMonitor = hMonitor;
        
        //memset(&displayMonitorInfo.monitorInfoEx, 0, MONITORINFOEX.sizeof);
        displayMonitorInfo.monitorInfoEx.cbSize = MONITORINFOEX.sizeof;
        GetMonitorInfo(hMonitor, &displayMonitorInfo.monitorInfoEx);
        
        (*pArrMonitorsInfo) ~= (displayMonitorInfo);
        
        return 1;
    }
    
public:
    this()
    {
        mInitialWindow = null;
        mHasPixelFormatARB = false;
        mHasMultisample = false;
        mHasHardwareGamma = false;
        // immediately test WGL_ARB_pixel_format and FSAA support
        // so we can set configuration options appropriately
        initialiseWGL();
    } 
    /**
     * Add any special config values to the system.
     * Must have a "Full Screen" value that is a bool and a "Video Mode" value
     * that is a string in the form of wxhxb
     */
    override void addConfig()
    {
        //TODO: EnumDisplayDevices http://msdn.microsoft.com/library/en-us/gdi/devcons_2303.asp
        /*vector<string> DisplayDevices;
         DISPLAY_DEVICE DisplayDevice;
         DisplayDevice.cb = sizeof(DISPLAY_DEVICE);
         DWORD i=0;
         while (EnumDisplayDevices(null, i++, &DisplayDevice, 0) {
         DisplayDevices ~= (DisplayDevice.DeviceName);
         }*/
        
        ConfigOption optFullScreen;
        ConfigOption optVideoMode;
        ConfigOption optColourDepth;
        ConfigOption optDisplayFrequency;
        ConfigOption optVSync;
        ConfigOption optVSyncInterval;
        ConfigOption optFSAA;
        ConfigOption optRTTMode;
        ConfigOption optSRGB;
        static if (RTSHADER_SYSTEM_BUILD_CORE_SHADERS)
            ConfigOption optEnableFixedPipeline;
        
        // FS setting possibilities
        optFullScreen.name = "Full Screen";
        optFullScreen.possibleValues ~= ("Yes");
        optFullScreen.possibleValues ~= ("No");
        optFullScreen.currentValue = "Yes";
        optFullScreen._immutable = false;
        
        // Video mode possibilities
        DEVMODE DevMode;
        DevMode.dmSize = DEVMODE.sizeof;
        optVideoMode.name = "Video Mode";
        optVideoMode._immutable = false;
        for (DWORD i = 0; EnumDisplaySettings(null, i, &DevMode); ++i)
        {
            if (DevMode.dmBitsPerPel < 16 || DevMode.dmPelsHeight < 480)
                continue;
            mDevModes ~= (DevMode);
            string str = text(DevMode.dmPelsWidth, " x ", DevMode.dmPelsHeight);
            optVideoMode.possibleValues ~= str;
        }
        remove_duplicates(optVideoMode.possibleValues);
        optVideoMode.currentValue = optVideoMode.possibleValues.front();
        
        optColourDepth.name = "Colour Depth";
        optColourDepth._immutable = false;
        optColourDepth.currentValue.clear();
        
        optDisplayFrequency.name = "Display Frequency";
        optDisplayFrequency._immutable = false;
        optDisplayFrequency.currentValue.clear();
        
        optVSync.name = "VSync";
        optVSync._immutable = false;
        optVSync.possibleValues ~= ("No");
        optVSync.possibleValues ~= ("Yes");
        optVSync.currentValue = "No";
        
        optVSyncInterval.name = "VSync Interval";
        optVSyncInterval._immutable = false;
        optVSyncInterval.possibleValues ~= ( "1" );
        optVSyncInterval.possibleValues ~= ( "2" );
        optVSyncInterval.possibleValues ~= ( "3" );
        optVSyncInterval.possibleValues ~= ( "4" );
        optVSyncInterval.currentValue = "1";
        
        optFSAA.name = "FSAA";
        optFSAA._immutable = false;
        optFSAA.possibleValues ~= ("0");
        foreach (it; mFSAALevels)
        {
            string val = to!string(it);
            optFSAA.possibleValues ~= val;
            /* not implementing CSAA in GL for now
             if (*it >= 8)
             optFSAA.possibleValues ~= (val + " [Quality]");
             */
            
        }
        optFSAA.currentValue = "0";
        
        optRTTMode.name = "RTT Preferred Mode";
        optRTTMode.possibleValues ~= ("FBO");
        optRTTMode.possibleValues ~= ("PBuffer");
        optRTTMode.possibleValues ~= ("Copy");
        optRTTMode.currentValue = "FBO";
        optRTTMode._immutable = false;
        
        
        // SRGB on auto window
        optSRGB.name = "sRGB Gamma Conversion";
        optSRGB.possibleValues ~= ("Yes");
        optSRGB.possibleValues ~= ("No");
        optSRGB.currentValue = "No";
        optSRGB._immutable = false;
        
        static if (RTSHADER_SYSTEM_BUILD_CORE_SHADERS)
        {
            optEnableFixedPipeline.name = "Fixed Pipeline Enabled";
            optEnableFixedPipeline.possibleValues ~= ( "Yes" );
            optEnableFixedPipeline.possibleValues ~= ( "No" );
            optEnableFixedPipeline.currentValue = "Yes";
            optEnableFixedPipeline._immutable = false;
        }
        
        mOptions[optFullScreen.name] = optFullScreen;
        mOptions[optVideoMode.name] = optVideoMode;
        mOptions[optColourDepth.name] = optColourDepth;
        mOptions[optDisplayFrequency.name] = optDisplayFrequency;
        mOptions[optVSync.name] = optVSync;
        mOptions[optVSyncInterval.name] = optVSyncInterval;
        mOptions[optFSAA.name] = optFSAA;
        mOptions[optRTTMode.name] = optRTTMode;
        mOptions[optSRGB.name] = optSRGB;
        static if (RTSHADER_SYSTEM_BUILD_CORE_SHADERS)
            mOptions[optEnableFixedPipeline.name] = optEnableFixedPipeline;
        
        refreshConfig();
    }
    
    override void setConfigOption(string name, string value)
    {
        auto it = name in mOptions;
        
        // Update
        if(it !is null)
            it.currentValue = value;
        else
        {
            throw new InvalidParamsError("Option named '"  ~ name ~ "' does not exist.", "Win32GLSupport.setConfigOption" );
        }
        
        if( name == "Video Mode" )
            refreshConfig();
        
        if( name == "Full Screen" )
        {
            it = "Display Frequency" in mOptions;
            if( value == "No" )
            {
                it.currentValue = "N/A";
                it._immutable = true;
            }
            else
            {
                if (it.currentValue.empty() || it.currentValue == "N/A")
                    it.currentValue = it.possibleValues.front();
                it._immutable = false;
            }
        }
    }
    
    /**
     * Make sure all the extra options are valid
     */
    override string validateConfig()
    {
        // TODO, DX9
        return "";
    }
    
    override RenderWindow createWindow(bool autoCreateWindow, GLRenderSystem renderSystem, string windowTitle = "OGRE Render Window")
    {
        if (autoCreateWindow)
        {
            ConfigOption* opt = null;
            if((opt = "Full Screen" in mOptions) is null)
                throw new InvalidParamsError("Can't find full screen options!", "Win32GLSupport.createWindow");
            bool fullscreen = (opt.currentValue == "Yes");
            
            if((opt = "Video Mode" in mOptions) is null)
                throw new InvalidParamsError("Can't find video mode options!", "Win32GLSupport.createWindow");
            string val = opt.currentValue;
            string[] pos = val.split("x");
            if (pos.length != 2)
                throw new InvalidParamsError("Invalid Video Mode provided", "Win32GLSupport.createWindow");
            
            uint w = _conv!uint(pos[0].strip(), 640);
            uint h = _conv!uint(pos[1].strip(), 480);
            
            // Parse optional parameters
            NameValuePairList winOptions;
            if((opt = "Colour Depth" in mOptions) is null)
                throw new InvalidParamsError("Can't find Colour Depth options!", "Win32GLSupport.createWindow");

            uint colourDepth = _conv!uint(opt.currentValue, 24);
            winOptions["colourDepth"] = to!string(colourDepth);
            
            if((opt = "VSync" in mOptions) is null)
                throw new InvalidParamsError("Can't find VSync options!", "Win32GLSupport.createWindow");

            bool vsync = (opt.currentValue == "Yes");
            winOptions["vsync"] = to!string(vsync);
            renderSystem.setWaitForVerticalBlank(vsync);
            
            if((opt = "VSync Interval" in mOptions) is null)
                throw new InvalidParamsError("Can't find VSync Interval options!", "Win32GLSupport.createWindow");
            winOptions["vsyncInterval"] = to!string(_conv!uint(opt.currentValue, 1));
            
            
            if((opt = "Display Frequency" in mOptions) !is null && opt.currentValue != "N/A")
            {
                uint displayFrequency = _conv!uint(opt.currentValue.split(" ")[0], 60); //TODO Or default to 0?
                winOptions["displayFrequency"] = to!string(displayFrequency);
            }
            
            opt = "FSAA" in mOptions;
            if (opt is null) //TODO Something to freak out about?
                throw new InvalidParamsError("Can't find FSAA options!", "Win32GLSupport.createWindow");

            string[] aavalues = StringUtil.split(opt.currentValue, " ", 1);
            uint multisample = to!uint(aavalues[0]);
            string multisample_hint;
            if (aavalues.length > 1)
                multisample_hint = aavalues[1];
            
            static if (RTSHADER_SYSTEM_BUILD_CORE_SHADERS)
            {
                if((opt = "Fixed Pipeline Enabled" in mOptions) is null)
                    throw new InvalidParamsError("Can't find Fixed Pipeline enabled options!", "Win32GLSupport.createWindow");
                bool enableFixedPipeline = (opt.currentValue == "Yes");
                renderSystem.setFixedPipelineEnabled(enableFixedPipeline);
            }
            
            winOptions["FSAA"] = to!string(multisample);
            winOptions["FSAAHint"] = multisample_hint;
            
            if((opt = "sRGB Gamma Conversion" in mOptions) is null)
                throw new InvalidParamsError("Can't find sRGB options!", "Win32GLSupport.createWindow");
                
            bool hwGamma = (opt.currentValue == "Yes");
            winOptions["gamma"] = to!string(hwGamma);
            
            return renderSystem._createRenderWindow(windowTitle, w, h, fullscreen, winOptions);
        }
        else
        {
            // XXX What is the else?
            return null;
        }
    }
    
    /// @copydoc RenderSystem::_createRenderWindow
    override RenderWindow newWindow(string name, uint width, uint height, 
                                    bool fullScreen, NameValuePairList miscParams = null)
    {       
        Win32Window window = new Win32Window(this);
        NameValuePairList newParams;
        
        if (!miscParams.emptyAA)
        {   
            //newParams = *miscParams;//TODO why?
            //miscParams = &newParams;
            
            auto monitorIndexIt = "monitorIndex" in miscParams;
            HMONITOR hMonitor = null;
            int monitorIndex = -1;
            
            // If monitor index found, try to assign the monitor handle based on it.
            if (monitorIndexIt !is null)
            {               
                if (mMonitorInfoList.empty())       
                    EnumDisplayMonitors(null, null, &sCreateMonitorsInfoEnumProc, cast(LPARAM)&mMonitorInfoList);            
                
                monitorIndex = to!int(*monitorIndexIt);
                if (monitorIndex < mMonitorInfoList.length)
                {                       
                    hMonitor = mMonitorInfoList[monitorIndex].hMonitor;                 
                }
            }
            // If we didn't specified the monitor index, or if it didn't find it
            if (hMonitor is null)
            {
                POINT windowAnchorPoint;
                
                string* opt;
                int left = -1;
                int top  = -1;
                
                if ((opt = "left" in miscParams) !is null)//newParams
                    left = _conv!int(*opt, 0);
                
                if ((opt = "top" in miscParams) !is null)
                    top = _conv!int(*opt, 0);
                
                // Fill in anchor point.
                windowAnchorPoint.x = left;
                windowAnchorPoint.y = top;
                
                
                // Get the nearest monitor to this window.
                hMonitor = MonitorFromPoint(windowAnchorPoint, MONITOR_DEFAULTTOPRIMARY);               
            }
            
            newParams["monitorHandle"] = to!string(cast(size_t)hMonitor);                                                               
        }
        
        window.create(name, width, height, fullScreen, miscParams);
        
        if(!mInitialWindow)
            mInitialWindow = window;
        return window;
    }
    
    /**
     * Start anything special
     */
    override void start()
    {
        LogManager.getSingleton().logMessage("*** Starting Win32GL Subsystem ***");
    }
    /**
     * Stop anything special
     */
    override void stop()
    {
        LogManager.getSingleton().logMessage("*** Stopping Win32GL Subsystem ***");
        mInitialWindow = null; // Since there is no removeWindow, although there should be...
    }
    
    /* *
     * Get the address of a function
     */
    override void* getProcAddress(string procname)
    {
        return cast(void*)wglGetProcAddress( CSTR(procname) );
    }
    
    /**
     * Initialise extensions
     */
    override void initialiseExtensions()
    {
        assert(mInitialWindow !is null);
        // First, initialise the normal extensions
        GLSupport.initialiseExtensions();
        // FIXME wglew init
        //static if (OGRE_THREAD_SUPPORT != 1)
        //    wglewContextInit(this);
        
        // Check for W32 specific extensions probe function
        if(wglGetExtensionsStringARB is null)
            return;
        string wgl_extensions = to!string(wglGetExtensionsStringARB(mInitialWindow.getHDC()));
        LogManager.getSingleton().stream() << "Supported WGL extensions: " << wgl_extensions << "\n";
        // Parse them, and add them to the main list
        extensionList.insert(wgl_extensions.split(" "));
    }
    
    bool selectPixelFormat(HDC hdc, uint colourDepth, int multisample, bool hwGamma)
    {
        PIXELFORMATDESCRIPTOR pfd;
        //memset(&pfd, 0, sizeof(pfd));
        pfd.nSize = pfd.sizeof;
        pfd.nVersion = 1;
        pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
        pfd.iPixelType = PFD_TYPE_RGBA;
        pfd.cColorBits = cast(ubyte)((colourDepth > 16)? 24 : colourDepth);
        pfd.cAlphaBits = (colourDepth > 16)? 8 : 0;
        pfd.cDepthBits = 24;
        pfd.cStencilBits = 8;
        
        int format = 0;
        
        int useHwGamma = hwGamma? GL_TRUE : GL_FALSE;
        
        if (multisample && (!mHasMultisample || !mHasPixelFormatARB))
            return false;
        
        if (hwGamma && !mHasHardwareGamma)
            return false;
        
        if ((multisample || hwGamma) && wglChoosePixelFormatARB !is null)
        {
            
            // Use WGL to test extended caps (multisample, sRGB)
            int[] attribList;
            attribList ~= (WGL_DRAW_TO_WINDOW_ARB); attribList ~= (GL_TRUE);
            attribList ~= (WGL_SUPPORT_OPENGL_ARB); attribList ~= (GL_TRUE);
            attribList ~= (WGL_DOUBLE_BUFFER_ARB); attribList ~= (GL_TRUE);
            attribList ~= (WGL_SAMPLE_BUFFERS_ARB); attribList ~= (GL_TRUE);
            attribList ~= (WGL_ACCELERATION_ARB); attribList ~= (WGL_FULL_ACCELERATION_ARB);
            attribList ~= (WGL_COLOR_BITS_ARB); attribList ~= (pfd.cColorBits);
            attribList ~= (WGL_ALPHA_BITS_ARB); attribList ~= (pfd.cAlphaBits);
            attribList ~= (WGL_DEPTH_BITS_ARB); attribList ~= (24);
            attribList ~= (WGL_STENCIL_BITS_ARB); attribList ~= (8);
            attribList ~= (WGL_SAMPLES_ARB); attribList ~= (multisample);
            if (useHwGamma && mHasHardwareGamma)
            {
                attribList ~= (WGL_FRAMEBUFFER_SRGB_CAPABLE_EXT); attribList ~= (GL_TRUE);
            }
            // terminator
            attribList ~= (0);
            
            
            uint nformats;
            // ChoosePixelFormatARB proc address was obtained when setting up a dummy GL context in initialiseWGL()
            // since glew hasn't been initialized yet, we have to cheat and use the previously obtained address
            if (wglChoosePixelFormatARB(hdc, attribList.ptr, null, 1, &format, &nformats) || nformats <= 0)
                return false;
        }
        else
        {
            format = ChoosePixelFormat(hdc, &pfd);
        }
        
        
        return (format && SetPixelFormat(hdc, format, &pfd));
    }
    
    override bool supportsPBuffers()
    {
        return WGL_ARB_pbuffer;
    }
    
    override GLPBuffer createPBuffer(PixelComponentType format, size_t width, size_t height)
    {
        return new Win32PBuffer(format, width, height);
    }
    
    override uint getDisplayMonitorCount() const
    {
        if (mMonitorInfoList.empty())       
            EnumDisplayMonitors(null, null, &sCreateMonitorsInfoEnumProc, cast(LPARAM)&mMonitorInfoList);
        
        return cast(uint)mMonitorInfoList.length;
    }
    
private:
    // Allowed video modes
    DEVMODE[] mDevModes;
    Win32Window mInitialWindow;
    int[] mFSAALevels;
    bool mHasPixelFormatARB;
    bool mHasMultisample;
    bool mHasHardwareGamma;
    
    struct DisplayMonitorInfo
    {
        HMONITOR        hMonitor;
        MONITORINFOEX   monitorInfoEx;
    }
    
    alias DisplayMonitorInfo[] DisplayMonitorInfoList;
    //alias DisplayMonitorInfoList::iterator DisplayMonitorInfoIterator;
    
    DisplayMonitorInfoList mMonitorInfoList;
    
    void refreshConfig()
    {
        auto optVideoMode = "Video Mode" in mOptions;
        auto moptColourDepth = "Colour Depth" in mOptions;
        auto moptDisplayFrequency = "Display Frequency" in mOptions;
        if(optVideoMode is null || moptColourDepth is null || moptDisplayFrequency is null)
            throw new InvalidParamsError("Can't find mOptions!", "Win32GLSupport.refreshConfig");
        ConfigOption optColourDepth = (*moptColourDepth);
        ConfigOption optDisplayFrequency = (*moptDisplayFrequency);
        
        string val = optVideoMode.currentValue;
        string[] pos = val.split("x");
        if (pos.length != 2)
            throw new InvalidParamsError("Invalid Video Mode provided", "Win32GLSupport.refreshConfig");
        
        DWORD width = _conv!DWORD(pos[0].strip(), 640);
        DWORD height = _conv!DWORD(pos[1].strip(), 480);
        
        foreach(i; mDevModes)
        {
            if (i.dmPelsWidth != width || i.dmPelsHeight != height)
                continue;
            optColourDepth.possibleValues.insert(to!string(i.dmBitsPerPel));
            optDisplayFrequency.possibleValues.insert(to!string(i.dmDisplayFrequency));
        }
        remove_duplicates(optColourDepth.possibleValues);
        remove_duplicates(optDisplayFrequency.possibleValues);
        optColourDepth.currentValue = optColourDepth.possibleValues.back();
        bool freqValid = optDisplayFrequency.possibleValues.inArray(optDisplayFrequency.currentValue);
        
        if ( (optDisplayFrequency.currentValue != "N/A") && !freqValid && optDisplayFrequency.possibleValues.length)
            optDisplayFrequency.currentValue = optDisplayFrequency.possibleValues.front();
    }
    
    void initialiseWGL()
    {
        // wglGetProcAddress does not work without an active OpenGL context,
        // but we need wglChoosePixelFormatARB's address before we can
        // create our main window.  Thank you very much, Microsoft!
        //
        // The solution is to create a dummy OpenGL window first, and then
        // test for WGL_ARB_pixel_format support.  If it is not supported,
        // we make sure to never call the ARB pixel format functions.
        //
        // If is is supported, we call the pixel format functions at least once
        // to initialise them (pointers are stored by glprocs.h).  We can also
        // take this opportunity to enumerate the valid FSAA modes.
        DerelictGL.load();

        LPCSTR dummyText = CSTR("OgreWglDummy");
        //static if (OGRE_STATIC_LIB)
        HINSTANCE hinst = GetModuleHandle( null );
        //else
        //static if (OGRE_DEBUG_MODE == 1)
        //    HINSTANCE hinst = GetModuleHandle("RenderSystem_GL_d.dll");
        //else
        //    HINSTANCE hinst = GetModuleHandle("RenderSystem_GL.dll");
        
        WNDCLASS dummyClass;
        //memset(&dummyClass, 0, sizeof(WNDCLASS));
        dummyClass.style = CS_OWNDC;
        dummyClass.hInstance = hinst;
        dummyClass.lpfnWndProc = &dummyWndProc;
        dummyClass.lpszClassName = dummyText;
        RegisterClassA(&dummyClass);
        
        HWND hwnd = CreateWindowA(dummyText, dummyText,
                                  WS_POPUP | WS_CLIPCHILDREN,
                                  0, 0, 32, 32, null, null, hinst, null);
        
        // if a simple CreateWindow fails, then boy are we in trouble...
        if (hwnd is null)
            throw new RenderingApiError("CreateWindow() failed", "Win32GLSupport.initializeWGL");
        
        
        // no chance of failure and no need to release thanks to CS_OWNDC
        HDC hdc = GetDC(hwnd); 
        
        // assign a simple OpenGL pixel format that everyone supports
        PIXELFORMATDESCRIPTOR pfd;
        //memset(&pfd, 0, sizeof(PIXELFORMATDESCRIPTOR));
        pfd.nSize = PIXELFORMATDESCRIPTOR.sizeof;
        pfd.nVersion = 1;
        pfd.cColorBits = 16;
        pfd.cDepthBits = 15;
        pfd.dwFlags = PFD_DRAW_TO_WINDOW|PFD_SUPPORT_OPENGL|PFD_DOUBLEBUFFER;
        pfd.iPixelType = PFD_TYPE_RGBA;
        
        // if these fail, wglCreateContext will also quietly fail
        int format;
        if ((format = ChoosePixelFormat(hdc, &pfd)) != 0)
            SetPixelFormat(hdc, format, &pfd);
        
        HGLRC hrc = wglCreateContext(hdc);
        if (hrc)
        {
            HGLRC oldrc = wglGetCurrentContext();
            HDC oldhdc = wglGetCurrentDC();
            // if wglMakeCurrent fails, wglGetProcAddress will return null
            wglMakeCurrent(hdc, hrc);
            
            //FIXME Yes????
            DerelictGL.reload();
            
            // check for pixel format and multisampling support
            if (wglGetExtensionsStringARB)
            {
                string wglexts = to!string(wglGetExtensionsStringARB(hdc));
                string[]ext = wglexts.split(" ");
                mHasPixelFormatARB = ext.inArray("WGL_ARB_pixel_format");
                mHasMultisample = ext.inArray("WGL_ARB_multisample");
                mHasHardwareGamma = ext.inArray("WGL_EXT_framebuffer_sRGB");
            }
            
            if (mHasPixelFormatARB && mHasMultisample)
            {
                // enumerate all formats w/ multisampling
                static const int[] iattr = [
                                            WGL_DRAW_TO_WINDOW_ARB, GL_TRUE,
                                            WGL_SUPPORT_OPENGL_ARB, GL_TRUE,
                                            WGL_DOUBLE_BUFFER_ARB, GL_TRUE,
                                            WGL_SAMPLE_BUFFERS_ARB, GL_TRUE,
                                            WGL_ACCELERATION_ARB, WGL_FULL_ACCELERATION_ARB,
                                            /* We are no matter about the colour, depth and stencil buffers here
                                             WGL_COLOR_BITS_ARB, 24,
                                             WGL_ALPHA_BITS_ARB, 8,
                                             WGL_DEPTH_BITS_ARB, 24,
                                             WGL_STENCIL_BITS_ARB, 8,
                                             */
                                            WGL_SAMPLES_ARB, 2,
                                            0
                                            ];
                int[256] formats;
                uint count;
                // cheating here.  wglChoosePixelFormatARB procc address needed later on
                // when a valid GL context does not exist and glew is not initialized yet.
                if (wglChoosePixelFormatARB(hdc, iattr.ptr, null, 256, formats.ptr, &count))
                {
                    // determine what multisampling levels are offered
                    int query = WGL_SAMPLES_ARB, samples;
                    foreach (i; 0..count)
                    {
                        if (wglGetPixelFormatAttribivARB(hdc, formats[i], 0, 1, &query, &samples))
                        {
                            mFSAALevels ~= samples;
                        }
                    }
                    remove_duplicates(mFSAALevels);
                }
            }
            
            wglMakeCurrent(oldhdc, oldrc);
            wglDeleteContext(hrc);
        }
        
        // clean up our dummy window and class
        DestroyWindow(hwnd);
        UnregisterClass(dummyText, hinst);
    }
}
