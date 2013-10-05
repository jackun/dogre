module ogregl.windows.window;

version(Windows):
import core.stdc.string: memcpy;
import std.conv;

import derelict.opengl3.gl;
import derelict.opengl3.wgl;
//import derelict.util.wintypes;

import ogre.bindings.mini_win32;
import ogre.compat;
import ogre.general.root;
import ogre.image.images;
import ogre.general.log;
import ogre.exception;
import ogre.general.common;
import ogre.rendersystem.rendersystem;
import ogre.rendersystem.renderwindow;

import ogregl.context;
import ogregl.util;
import ogregl.pixelformat;
import ogregl.windows.support;
import ogregl.windows.context;
import ogre.rendersystem.windoweventutilities;


alias derelict.opengl3.constants.GL_NONE GL_NONE;

struct Win32WindowPtr
{
    Win32Window mWin;
}

class Win32Window : RenderWindow
{
public:
    this(Win32GLSupport glsupport)
    {
        mGLSupport = glsupport;
        mContext = null;
        mIsFullScreen = false;
        mHWnd = null;
        mGlrc = null;
        mIsExternal = false;
        mIsExternalGLControl = false;
        mIsExternalGLContext = false;
        mSizing = false;
        mClosed = false;
        mHidden = false;
        mVSync = false;
        mVSyncInterval = 1;
        mDisplayFrequency = 0;
        mActive = false;
        mDeviceName = null;
        mWindowedWinStyle = 0;
        mFullscreenWinStyle = 0;
    }
    
    ~this()
    {
        this.destroy();
    }
    
    override void create(string name, uint width, uint height,
                         bool fullScreen, NameValuePairList miscParams)
    {
        // destroy current window, if any
        if (mHWnd)
            destroy();
        
        //static if (OGRE_STATIC_LIB)
        HINSTANCE hInst = GetModuleHandle( null );
        //else
        //    static if (OGRE_DEBUG_MODE == 1)
        //        HINSTANCE hInst = GetModuleHandle("RenderSystem_GL_d.dll");
        //else
        //    HINSTANCE hInst = GetModuleHandle("RenderSystem_GL.dll");
        
        mHWnd = null;
        mName = name;
        mIsFullScreen = fullScreen;
        mClosed = false;
        mDisplayFrequency = 0;
        mDepthBufferPoolId = DepthBuffer.PoolId.POOL_DEFAULT;
        mColourDepth = mIsFullScreen? 32 : GetDeviceCaps(GetDC(null), BITSPIXEL);
        int left = -1; // Defaults to screen center
        int top = -1; // Defaults to screen center
        HWND parent = null;
        string title = name;
        bool hidden = false;
        string border;
        bool outerSize = false;
        bool hwGamma = false;
        bool enableDoubleClick = false;
        int monitorIndex = -1;
        HMONITOR hMonitor = null;
        
        if(miscParams)
        {
            // Get variable-length params
            string* opt;
            
            if ((opt = "title" in miscParams) !is null)
                title = *opt;
            
            if ((opt = "left" in miscParams) !is null)
                left = _conv!int(*opt, 0);
            
            if ((opt = "top" in miscParams) !is null)
                top = _conv!int(*opt, 0);
            
            if ((opt = "depthBuffer" in miscParams) !is null)
            {
                mDepthBufferPoolId = _conv!bool(*opt, true) ?
                    DepthBuffer.PoolId.POOL_DEFAULT : DepthBuffer.PoolId.POOL_NO_DEPTH;
            }
            
            if ((opt = "vsync" in miscParams) !is null)
                mVSync = _conv!bool(*opt, true);
            
            if ((opt = "hidden" in miscParams) !is null)
                hidden = _conv!bool(*opt, false);
            
            if ((opt = "vsyncInterval" in miscParams) !is null)
                mVSyncInterval = _conv!uint(*opt, 1);
            
            if ((opt = "FSAA" in miscParams) !is null)
                mFSAA = _conv!uint(*opt, 0);
            
            if ((opt = "FSAAHint" in miscParams) !is null)
                mFSAAHint = *opt;
            
            if ((opt = "gamma" in miscParams) !is null)
                hwGamma = _conv!bool(*opt, false);
            
            if ((opt = "externalWindowHandle" in miscParams) !is null)
            {
                mHWnd = cast(HWND*)_conv!size_t(*opt, 0);
                if (mHWnd)
                {
                    mIsExternal = true;
                    mIsFullScreen = false;
                }
                
                if ((opt = "externalGLControl" in miscParams) !is null) {
                    mIsExternalGLControl = _conv!bool(*opt, false);
                }
            }
            if ((opt = "externalGLContext" in miscParams) !is null)
            {
                mGlrc = cast(HGLRC)_conv!size_t(*opt, 0);
                if( mGlrc )
                    mIsExternalGLContext = true;
            }
            
            // window border style
            if((opt = "border" in miscParams) !is null)
                border = *opt;
            // set outer dimensions?
            if((opt = "outerDimensions" in miscParams) !is null)
                outerSize = _conv!bool(*opt, false);
            
            // only available with fullscreen
            if ((opt = "displayFrequency" in miscParams) !is null)
                mDisplayFrequency = _conv!uint(*opt, 60);
                
            if ((opt = "colourDepth" in miscParams) !is null)
            {
                mColourDepth = _conv!uint(*opt, 24);
                if (!mIsFullScreen)
                {
                    // make sure we don't exceed desktop colour depth
                    if (mColourDepth > GetDeviceCaps(GetDC(null), BITSPIXEL))
                        mColourDepth = GetDeviceCaps(GetDC(null), BITSPIXEL);
                }
            }
            
            // incompatible with fullscreen
            if ((opt = "parentWindowHandle" in miscParams) !is null)
                parent = cast(HWND*)_conv!size_t(*opt, 0);
            
            
            // monitor index
            if ((opt = "monitorIndex" in miscParams) !is null)
                monitorIndex = _conv!int(*opt, 0);
            
            // monitor handle
            if ((opt = "monitorHandle" in miscParams) !is null)
                hMonitor = cast(HMONITOR)_conv!size_t(*opt, 0);
            
            // enable double click messages
            if ((opt = "enableDoubleClick" in miscParams) !is null)
                enableDoubleClick = _conv!bool(*opt, true);
            
        }
        
        if (!mIsExternal)
        {
            DWORD         dwStyleEx = 0;
            MONITORINFOEX monitorInfoEx;
            RECT          rc;
            
            // If we didn't specified the adapter index, or if it didn't find it
            if (hMonitor is null)
            {
                POINT windowAnchorPoint;
                
                // Fill in anchor point.
                windowAnchorPoint.x = left;
                windowAnchorPoint.y = top;
                
                
                // Get the nearest monitor to this window.
                hMonitor = MonitorFromPoint(windowAnchorPoint, MONITOR_DEFAULTTOPRIMARY);
            }
            
            // Get the target monitor info
            //memset(&monitorInfoEx, 0, sizeof(MONITORINFOEX));
            monitorInfoEx.cbSize = MONITORINFOEX.sizeof;
            GetMonitorInfo(hMonitor, &monitorInfoEx);
            
            mDeviceName = to!string(monitorInfoEx.szDevice);
            
            // Update window style flags.
            mFullscreenWinStyle = (hidden ? 0 : WS_VISIBLE) | WS_CLIPCHILDREN | WS_POPUP;
            mWindowedWinStyle   = (hidden ? 0 : WS_VISIBLE) | WS_CLIPCHILDREN;
            
            if (parent)
            {
                mWindowedWinStyle |= WS_CHILD;
            }
            else
            {
                if (border == "none")
                    mWindowedWinStyle |= WS_POPUP;
                else if (border == "fixed")
                    mWindowedWinStyle |= WS_OVERLAPPED | WS_BORDER | WS_CAPTION |
                        WS_SYSMENU | WS_MINIMIZEBOX;
                else
                    mWindowedWinStyle |= WS_OVERLAPPEDWINDOW;
                
            }
            
            
            // No specified top left . Center the window in the middle of the monitor
            if (left == -1 || top == -1)
            {
                int screenw = monitorInfoEx.rcWork.right  - monitorInfoEx.rcWork.left;
                int screenh = monitorInfoEx.rcWork.bottom - monitorInfoEx.rcWork.top;
                
                uint winWidth, winHeight;
                adjustWindow(width, height, &winWidth, &winHeight);
                
                // clamp window dimensions to screen size
                int outerw = (winWidth < screenw)? winWidth : screenw;
                int outerh = (winHeight < screenh)? winHeight : screenh;
                
                if (left == -1)
                    left = monitorInfoEx.rcWork.left + (screenw - outerw) / 2;
                else if (monitorIndex != -1)
                    left += monitorInfoEx.rcWork.left;
                
                if (top == -1)
                    top = monitorInfoEx.rcWork.top + (screenh - outerh) / 2;
                else if (monitorIndex != -1)
                    top += monitorInfoEx.rcWork.top;
            }
            else if (monitorIndex != -1)
            {
                left += monitorInfoEx.rcWork.left;
                top += monitorInfoEx.rcWork.top;
            }
            
            mWidth = width;
            mHeight = height;
            mTop = top;
            mLeft = left;
            
            if (mIsFullScreen)
            {
                dwStyleEx |= WS_EX_TOPMOST;
                mTop = monitorInfoEx.rcMonitor.top;
                mLeft = monitorInfoEx.rcMonitor.left;
            }
            else
            {
                int screenw = GetSystemMetrics(SM_CXSCREEN);
                int screenh = GetSystemMetrics(SM_CYSCREEN);
                
                if (!outerSize)
                {
                    // Calculate window dimensions required
                    // to get the requested client area
                    SetRect(&rc, 0, 0, mWidth, mHeight);
                    AdjustWindowRect(&rc, getWindowStyle(fullScreen), false);
                    mWidth = rc.right - rc.left;
                    mHeight = rc.bottom - rc.top;
                    
                    // Clamp window rect to the nearest display monitor.
                    if (mLeft < monitorInfoEx.rcWork.left)
                        mLeft = monitorInfoEx.rcWork.left;
                    
                    if (mTop < monitorInfoEx.rcWork.top)
                        mTop = monitorInfoEx.rcWork.top;
                    
                    if (cast(int)mWidth > monitorInfoEx.rcWork.right - mLeft)
                        mWidth = monitorInfoEx.rcWork.right - mLeft;
                    
                    if (cast(int)mHeight > monitorInfoEx.rcWork.bottom - mTop)
                        mHeight = monitorInfoEx.rcWork.bottom - mTop;
                }
            }
            
            UINT classStyle = CS_OWNDC;
            if (enableDoubleClick)
                classStyle |= CS_DBLCLKS;
            
            // register class and create window
            WNDCLASS wc = WNDCLASS (classStyle, &WindowEventUtilities._WndProc, 0, 0, hInst,
                                    LoadIcon(null, IDI_APPLICATION), LoadCursor(null, IDC_ARROW),
                                    cast(HBRUSH)GetStockObject(BLACK_BRUSH), null, "OgreGLWindow" );
            RegisterClass(&wc);
            
            if (mIsFullScreen)
            {
                DEVMODE displayDeviceMode;
                
                //memset(&displayDeviceMode, 0, sizeof(displayDeviceMode));
                displayDeviceMode.dmSize = DEVMODE.sizeof;
                displayDeviceMode.dmBitsPerPel = mColourDepth;
                displayDeviceMode.dmPelsWidth = mWidth;
                displayDeviceMode.dmPelsHeight = mHeight;
                displayDeviceMode.dmFields = DM_BITSPERPEL | DM_PELSWIDTH | DM_PELSHEIGHT;
                
                if (mDisplayFrequency)
                {
                    displayDeviceMode.dmDisplayFrequency = mDisplayFrequency;
                    displayDeviceMode.dmFields |= DM_DISPLAYFREQUENCY;
                    if (ChangeDisplaySettingsEx(CSTR(mDeviceName), &displayDeviceMode, null, CDS_FULLSCREEN | CDS_TEST, null) != DISP_CHANGE_SUCCESSFUL)
                    {
                        LogManager.getSingleton().logMessage(LML_NORMAL, "ChangeDisplaySettings with user display frequency failed");
                        displayDeviceMode.dmFields ^= DM_DISPLAYFREQUENCY;
                    }
                }
                if (ChangeDisplaySettingsEx(CSTR(mDeviceName), &displayDeviceMode, null, CDS_FULLSCREEN, null) != DISP_CHANGE_SUCCESSFUL)
                    LogManager.getSingleton().logMessage(LML_CRITICAL, "ChangeDisplaySettings failed");
            }
            
            Win32WindowPtr* ptr = new Win32WindowPtr(this); //put us on heap (?) or it gets GCed and GetWindowLongPtr gets garbage as well
            mWinPtrHolder ~= ptr;
            // Pass pointer to self as WM_CREATE parameter
            mHWnd = CreateWindowEx(dwStyleEx, CSTR("OgreGLWindow"), CSTR(title),
                                   getWindowStyle(fullScreen), mLeft, mTop, 
                                   mWidth, mHeight, parent, null, hInst, ptr);
            
            WindowEventUtilities._addRenderWindow(this);
            
            LogManager.getSingleton().stream()
                << "Created Win32Window '"
                    << mName << "' : " << mWidth << "x" << mHeight
                    << ", " << mColourDepth << "bpp\n";
            
        }
        
        HDC old_hdc = wglGetCurrentDC();
        HGLRC old_context = wglGetCurrentContext();
        
        RECT rc;
        // top and left represent outer window position
        GetWindowRect(mHWnd, &rc);
        mTop = rc.top;
        mLeft = rc.left;
        // width and height represent drawable area only
        GetClientRect(mHWnd, &rc);
        mWidth = rc.right;
        mHeight = rc.bottom;
        
        mHDC = GetDC(mHWnd);
        
        if (!mIsExternalGLControl)
        {
            int testFsaa = mFSAA;
            bool testHwGamma = hwGamma;
            bool formatOk = mGLSupport.selectPixelFormat(mHDC, mColourDepth, testFsaa, testHwGamma);
            if (!formatOk)
            {
                if (mFSAA > 0)
                {
                    // try without FSAA
                    testFsaa = 0;
                    formatOk = mGLSupport.selectPixelFormat(mHDC, mColourDepth, testFsaa, testHwGamma);
                }
                
                if (!formatOk && hwGamma)
                {
                    // try without sRGB
                    testHwGamma = false;
                    testFsaa = mFSAA;
                    formatOk = mGLSupport.selectPixelFormat(mHDC, mColourDepth, testFsaa, testHwGamma);
                }
                
                if (!formatOk && hwGamma && (mFSAA > 0))
                {
                    // try without both
                    testHwGamma = false;
                    testFsaa = 0;
                    formatOk = mGLSupport.selectPixelFormat(mHDC, mColourDepth, testFsaa, testHwGamma);
                }
                
                if (!formatOk)
                    throw new RenderingApiError(
                        "selectPixelFormat failed", "Win32Window.create");
                
            }
            // record what gamma option we used in the end
            // this will control enabling of sRGB state flags when used
            mHwGamma = testHwGamma;
            mFSAA = testFsaa;
        }
        if (!mIsExternalGLContext)
        {
            mGlrc = wglCreateContext(mHDC);
            if (!mGlrc)
                throw new RenderingApiError(
                    "wglCreateContext failed: " ~ translateWGLError(), "Win32Window.create");
        }
        
        if (old_context && old_context != mGlrc)
        {
            // Share lists with old context
            if (!wglShareLists(old_context, mGlrc))
                throw new RenderingApiError("wglShareLists() failed", " Win32Window.create");
        }
        
        if (!wglMakeCurrent(mHDC, mGlrc))
            throw new RenderingApiError("wglMakeCurrent", "Win32Window.create");
        
        // Do not change vsync if the external window has the OpenGL control
        if (!mIsExternalGLControl) {
            // Don't use wglew as if this is the first window, we won't have initialised yet
            if (wglSwapIntervalEXT)
                wglSwapIntervalEXT(mVSync? mVSyncInterval : 0);
        }
        
        if (old_context && old_context != mGlrc)
        {
            // Restore old context
            if (!wglMakeCurrent(old_hdc, old_context))
                throw new RenderingApiError("wglMakeCurrent() failed", "Win32Window.create");
        }
        
        // Create RenderSystem context
        mContext = new Win32Context(mHDC, mGlrc);
        
        mActive = true;
        setHidden(hidden);
    }
    
    override void setFullscreen(bool fullScreen, uint width, uint height)
    {
        if (mIsFullScreen != fullScreen || width != mWidth || height != mHeight)
        {
            mIsFullScreen = fullScreen;
            
            if (mIsFullScreen)
            {
                
                DEVMODE displayDeviceMode;
                
                //memset(&displayDeviceMode, 0, sizeof(displayDeviceMode));
                displayDeviceMode.dmSize = DEVMODE.sizeof;
                displayDeviceMode.dmBitsPerPel = mColourDepth;
                displayDeviceMode.dmPelsWidth = width;
                displayDeviceMode.dmPelsHeight = height;
                displayDeviceMode.dmFields = DM_BITSPERPEL | DM_PELSWIDTH | DM_PELSHEIGHT;
                if (mDisplayFrequency)
                {
                    displayDeviceMode.dmDisplayFrequency = mDisplayFrequency;
                    displayDeviceMode.dmFields |= DM_DISPLAYFREQUENCY;
                    
                    if (ChangeDisplaySettingsEx(CSTR(mDeviceName), &displayDeviceMode, null,
                                                CDS_FULLSCREEN | CDS_TEST, null) != DISP_CHANGE_SUCCESSFUL)
                    {
                        LogManager.getSingleton().logMessage(LML_NORMAL, "ChangeDisplaySettings with user display frequency failed");
                        displayDeviceMode.dmFields ^= DM_DISPLAYFREQUENCY;
                    }
                }
                else
                {
                    // try a few
                    displayDeviceMode.dmDisplayFrequency = 100;
                    displayDeviceMode.dmFields |= DM_DISPLAYFREQUENCY;
                    if (ChangeDisplaySettingsEx(CSTR(mDeviceName), &displayDeviceMode, null,
                                                CDS_FULLSCREEN | CDS_TEST, null) != DISP_CHANGE_SUCCESSFUL)
                    {
                        displayDeviceMode.dmDisplayFrequency = 75;
                        if (ChangeDisplaySettingsEx(CSTR(mDeviceName), &displayDeviceMode, null,
                                                    CDS_FULLSCREEN | CDS_TEST, null) != DISP_CHANGE_SUCCESSFUL)
                        {
                            displayDeviceMode.dmFields ^= DM_DISPLAYFREQUENCY;
                        }
                    }
                    
                }
                // move window to 0,0 before display switch
                SetWindowPos(mHWnd, HWND_TOPMOST, 0, 0, mWidth, mHeight, SWP_NOACTIVATE);
                
                if (ChangeDisplaySettingsEx(CSTR(mDeviceName), &displayDeviceMode, null, CDS_FULLSCREEN, null) != DISP_CHANGE_SUCCESSFUL)
                    LogManager.getSingleton().logMessage(LML_CRITICAL, "ChangeDisplaySettings failed");
                
                // Get the nearest monitor to this window.
                HMONITOR hMonitor = MonitorFromWindow(mHWnd, MONITOR_DEFAULTTONEAREST);
                
                // Get monitor info
                MONITORINFO monitorInfo;
                
                //memset(&monitorInfo, 0, sizeof(MONITORINFO));
                monitorInfo.cbSize = MONITORINFO.sizeof;
                GetMonitorInfo(hMonitor, &monitorInfo);
                
                mTop = monitorInfo.rcMonitor.top;
                mLeft = monitorInfo.rcMonitor.left;
                
                SetWindowLong(mHWnd, GWL_STYLE, getWindowStyle(mIsFullScreen));
                SetWindowPos(mHWnd, HWND_TOPMOST, mLeft, mTop, width, height,
                             SWP_NOACTIVATE);
                mWidth = width;
                mHeight = height;
                
                
            }
            else
            {
                // drop out of fullscreen
                ChangeDisplaySettingsEx(CSTR(mDeviceName), null, null, 0, null);
                
                // calculate overall dimensions for requested client area
                uint winWidth, winHeight;
                adjustWindow(width, height, &winWidth, &winHeight);
                
                // deal with centering when switching down to smaller resolution
                
                HMONITOR hMonitor = MonitorFromWindow(mHWnd, MONITOR_DEFAULTTONEAREST);
                MONITORINFO monitorInfo;
                //memset(&monitorInfo, 0, sizeof(MONITORINFO));
                monitorInfo.cbSize = MONITORINFO.sizeof;
                GetMonitorInfo(hMonitor, &monitorInfo);
                
                LONG screenw = monitorInfo.rcWork.right  - monitorInfo.rcWork.left;
                LONG screenh = monitorInfo.rcWork.bottom - monitorInfo.rcWork.top;
                
                
                int left = screenw > winWidth ? ((screenw - winWidth) / 2) : 0;
                int top = screenh > winHeight ? ((screenh - winHeight) / 2) : 0;
                
                SetWindowLong(mHWnd, GWL_STYLE, getWindowStyle(mIsFullScreen));
                SetWindowPos(mHWnd, HWND_NOTOPMOST, left, top, winWidth, winHeight,
                             SWP_DRAWFRAME | SWP_FRAMECHANGED | SWP_NOACTIVATE);
                mWidth = width;
                mHeight = height;
                
                windowMovedOrResized();
                
            }
            
        }
    }
    
    override void destroy()
    {
        if (!mHWnd)
            return;
        
        // Unregister and destroy OGRE GLContext
        delete mContext;
        
        if (!mIsExternalGLContext && mGlrc)
        {
            wglDeleteContext(mGlrc);
            mGlrc = null;
        }
        if (!mIsExternal)
        {
            WindowEventUtilities._removeRenderWindow(this);
            
            if (mIsFullScreen)
                ChangeDisplaySettingsEx(CSTR(mDeviceName), null, null, 0, null);
            DestroyWindow(mHWnd);
        }
        else
        {
            // just release the DC
            ReleaseDC(mHWnd, mHDC);
        }
        
        mActive = false;
        mClosed = true;
        mHDC = null; // no release thanks to CS_OWNDC wndclass style
        mHWnd = null;
    }
    
    override bool isActive()// const
    {
        if (isFullScreen())
            return isVisible();
        
        return mActive && isVisible();
    }
    
    override bool isVisible()// const
    {
        return (mHWnd && !IsIconic(mHWnd));
    }
    
    override bool isHidden() const { return mHidden; }
    override void setHidden(bool hidden)
    {
        mHidden = hidden;
        if (!mIsExternal)
        {
            if (hidden)
                ShowWindow(mHWnd, SW_HIDE);
            else
                ShowWindow(mHWnd, SW_SHOWNORMAL);
        }
    }
    
    override void setVSyncEnabled(bool vsync)
    {
        mVSync = vsync;
        HDC old_hdc = wglGetCurrentDC();
        HGLRC old_context = wglGetCurrentContext();
        if (!wglMakeCurrent(mHDC, mGlrc))
            throw new RenderingApiError("wglMakeCurrent", "Win32Window.setVSyncEnabled");
        
        // Do not change vsync if the external window has the OpenGL control
        if (!mIsExternalGLControl) {
            // Don't use wglew as if this is the first window, we won't have initialised yet
            if (wglSwapIntervalEXT)
                wglSwapIntervalEXT(mVSync? mVSyncInterval : 0);
        }
        
        if (old_context && old_context != mGlrc)
        {
            // Restore old context
            if (!wglMakeCurrent(old_hdc, old_context))
                throw new RenderingApiError("wglMakeCurrent() failed", "Win32Window.setVSyncEnabled");
        }
    }
    
    override bool isVSyncEnabled() const
    {
        return mVSync;
    }
    
    override void setVSyncInterval(uint interval)
    {
        mVSyncInterval = interval;
        if (mVSync)
            setVSyncEnabled(true);
    }
    
    override uint getVSyncInterval() const
    {
        return mVSyncInterval;
    }
    
    override bool isClosed() const
    {
        return mClosed;
    }
    
    override void reposition(int left, int top)
    {
        if (mHWnd && !mIsFullScreen)
        {
            SetWindowPos(mHWnd, null, left, top, 0, 0,
                         SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
        }
    }
    
    override void resize(uint width, uint height)
    {
        if (mHWnd && !mIsFullScreen)
        {
            RECT rc = RECT( 0, 0, width, height );
            AdjustWindowRect(&rc, getWindowStyle(mIsFullScreen), false);
            width = rc.right - rc.left;
            height = rc.bottom - rc.top;
            SetWindowPos(mHWnd, null, 0, 0, width, height,
                         SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
        }
    }
    
    override void swapBuffers(bool waitForVSync)
    {
        if (!mIsExternalGLControl) {
            SwapBuffers(mHDC);
        }
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
                "Win32Window.copyContentsToMemory" );
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
                "Win32Window.copyContentsToMemory" );
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
            
            delete tmpData;
        }
    }
    
    override bool requiresTextureFlipping() const { return false; }
    
    HWND getWindowHandle() //const 
    { return mHWnd; }
    HDC getHDC() //const 
    { return mHDC; }
    
    // Method for dealing with resize / move & 3d library
    override void windowMovedOrResized()
    {
        if (!mHWnd || IsIconic(mHWnd))
            return;
        
        updateWindowRect();
    }
    
    override void getCustomAttribute( string name, void* pData )
    {
        if( name == "GLCONTEXT" ) {
            *(cast(GLContext*)pData) = mContext;
            return;
        } else if( name == "WINDOW" )
        {
            HWND *pHwnd = cast(HWND*)pData;
            *pHwnd = getWindowHandle();
            return;
        }
    }
    
    /** Used to set the active state of the render target.
     */
    override void setActive( bool state )
    {
        if (mDeviceName !is null && state == false)
        {
            HWND hActiveWindow = GetActiveWindow();
            enum _MAX_CLASS_NAME_ = 256;//random
            char[_MAX_CLASS_NAME_ + 1] classNameSrc;
            char[_MAX_CLASS_NAME_ + 1] classNameDst;
            
            GetClassName(mHWnd, classNameSrc.ptr, _MAX_CLASS_NAME_);
            GetClassName(hActiveWindow, classNameDst.ptr, _MAX_CLASS_NAME_);
            
            if (classNameDst == classNameSrc)
            {
                state = true;
            }
        }
        
        mActive = state;
        
        if( mIsFullScreen )
        {
            if( state == false )
            {   //Restore Desktop
                ChangeDisplaySettingsEx(CSTR(mDeviceName), null, null, 0, null);
                ShowWindow(mHWnd, SW_SHOWMINNOACTIVE);
            }
            else
            {   //Restore App
                ShowWindow(mHWnd, SW_SHOWNORMAL);
                
                DEVMODE displayDeviceMode;
                
                //memset(&displayDeviceMode, 0, sizeof(displayDeviceMode));
                displayDeviceMode.dmSize = DEVMODE.sizeof;
                displayDeviceMode.dmBitsPerPel = mColourDepth;
                displayDeviceMode.dmPelsWidth = mWidth;
                displayDeviceMode.dmPelsHeight = mHeight;
                displayDeviceMode.dmFields = DM_BITSPERPEL | DM_PELSWIDTH | DM_PELSHEIGHT;
                if (mDisplayFrequency)
                {
                    displayDeviceMode.dmDisplayFrequency = mDisplayFrequency;
                    displayDeviceMode.dmFields |= DM_DISPLAYFREQUENCY;
                }
                ChangeDisplaySettingsEx(CSTR(mDeviceName), &displayDeviceMode, null, CDS_FULLSCREEN, null);
            }
        }
    }
    
    void adjustWindow(uint clientWidth, uint clientHeight,
                      uint* winWidth, uint* winHeight)
    {
        // NB only call this for non full screen
        RECT rc;
        SetRect(&rc, 0, 0, clientWidth, clientHeight);
        AdjustWindowRect(&rc, getWindowStyle(mIsFullScreen), false);
        *winWidth = rc.right - rc.left;
        *winHeight = rc.bottom - rc.top;
        
        // adjust to monitor
        HMONITOR hMonitor = MonitorFromWindow(mHWnd, MONITOR_DEFAULTTONEAREST);
        
        // Get monitor info
        MONITORINFO monitorInfo;
        
        //memset(&monitorInfo, 0, sizeof(MONITORINFO));
        monitorInfo.cbSize = MONITORINFO.sizeof;
        GetMonitorInfo(hMonitor, &monitorInfo);
        
        LONG maxW = monitorInfo.rcWork.right  - monitorInfo.rcWork.left;
        LONG maxH = monitorInfo.rcWork.bottom - monitorInfo.rcWork.top;
        
        if (*winWidth > cast(uint)maxW)
            *winWidth = maxW;
        if (*winHeight > cast(uint)maxH)
            *winHeight = maxH;
        
    }
    
protected:
    
    /** Update the window rect. */
    void updateWindowRect()
    {
        RECT rc;
        BOOL result;
        
        // Update top left parameters
        result = GetWindowRect(mHWnd, &rc);
        if (result == 0)
        {
            mTop = 0;
            mLeft = 0;
            mWidth = 0;
            mHeight = 0;
            return;
        }
        
        mTop = rc.top;
        mLeft = rc.left;
        
        // width and height represent drawable area only
        result = GetClientRect(mHWnd, &rc);
        if (result == 0)
        {
            mTop = 0;
            mLeft = 0;
            mWidth = 0;
            mHeight = 0;
            return;
        }
        uint width = rc.right - rc.left;
        uint height = rc.bottom - rc.top;
        
        // Case window resized.
        if (width != mWidth || height != mHeight)
        {
            mWidth  = rc.right - rc.left;
            mHeight = rc.bottom - rc.top;
            
            // Notify viewports of resize
            foreach( it; mViewportList )
                it._updateDimensions();
        }
    }
    
    /** Return the target window style depending on the fullscreen parameter. */
    DWORD getWindowStyle(bool fullScreen) const { if (fullScreen) return mFullscreenWinStyle; return mWindowedWinStyle; }
    
protected:
    Win32GLSupport mGLSupport;
    HWND    mHWnd;                  // Win32 Window handle
    HDC     mHDC;
    HGLRC   mGlrc;
    bool    mIsExternal;
    string  mDeviceName;
    bool    mIsExternalGLControl;
    bool    mIsExternalGLContext;
    bool    mSizing;
    bool    mClosed;
    bool    mHidden;
    bool    mVSync;
    uint    mVSyncInterval;
    int     mDisplayFrequency;      // fullscreen only, to restore display
    Win32Context mContext;
    DWORD   mWindowedWinStyle;      // Windowed mode window style flags.
    DWORD   mFullscreenWinStyle;    // Fullscreen mode window style flags.
    Win32WindowPtr*[] mWinPtrHolder; //FIXME Can we tell GC to not delete the pointer? Well, record it here so no dangling bits
}
