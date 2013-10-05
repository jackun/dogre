module ogre.rendersystem.windows.windoweventutilities;

import ogre.compat;
import ogre.rendersystem.renderwindow;
import ogre.rendersystem.windoweventutilities;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup RenderSystem
 *  @{
 */

version(Windows)
{
    import ogre.bindings.mini_win32;

    /**
     @remarks
        Utility class to handle Window Events/Pumping/Messages
     */
    class WindowEventUtilities
    {
        struct RenderWindowPtr
        {
            RenderWindow mWin;
        }
        
    public:

        extern(Windows) nothrow static LRESULT _WndProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
        {
            try
            {
                if (uMsg == WM_CREATE)
                {   // Store pointer to Win32Window in user data area
                    SetWindowLongPtr(hWnd, GWLP_USERDATA, cast(LONG_PTR)((cast(LPCREATESTRUCT)lParam).lpCreateParams));
                    return 0;
                }
                
                // look up window instance
                // note: it is possible to get a WM_SIZE before WM_CREATE
                RenderWindowPtr* _win = cast(RenderWindowPtr*)GetWindowLongPtr(hWnd, GWLP_USERDATA);
                if (_win is null)
                    return DefWindowProc(hWnd, uMsg, wParam, lParam);

                RenderWindow win = _win.mWin;

                //LogManager* log = LogManager::getSingletonPtr();
                //Iterator of all listeners registered to this RenderWindow
                WindowEventListener[] listeners;
                if((win in _msListeners))
                    listeners = _msListeners[win];
                    
                switch( uMsg )
                {
                    case WM_ACTIVATE:
                    {
                        bool active = (LOWORD(wParam) != WA_INACTIVE);
                        if( active )
                        {
                            win.setActive( true );
                        }
                        else
                        {
                            if( win.isDeactivatedOnFocusChange() )
                            {
                                win.setActive( false );
                            }
                        }
                        
                        foreach(l; listeners)
                            l.windowFocusChange(win);
                        break;
                    }
                    case WM_SYSKEYDOWN:
                        switch( wParam )
                        {
                            case VK_CONTROL:
                            case VK_SHIFT:
                            case VK_MENU: //ALT
                                //return zero to bypass defProc and signal we processed the message
                                return 0;
                            default:
                                break;
                        }
                        break;
                    case WM_SYSKEYUP:
                        switch( wParam )
                        {
                            case VK_CONTROL:
                            case VK_SHIFT:
                            case VK_MENU: //ALT
                            case VK_F10:
                                //return zero to bypass defProc and signal we processed the message
                                return 0;
                            default:
                                break;
                        }
                        break;
                    case WM_SYSCHAR:
                        // return zero to bypass defProc and signal we processed the message, unless it's an ALT-space
                        if (wParam != VK_SPACE)
                            return 0;
                        break;
                    case WM_ENTERSIZEMOVE:
                        //log.logMessage("WM_ENTERSIZEMOVE");
                        break;
                    case WM_EXITSIZEMOVE:
                        //log.logMessage("WM_EXITSIZEMOVE");
                        break;
                    case WM_MOVE:
                        //log.logMessage("WM_MOVE");
                        win.windowMovedOrResized();
                        foreach(l; listeners)
                            l.windowMoved(win);
                        break;
                    case WM_DISPLAYCHANGE:
                        win.windowMovedOrResized();
                        foreach(l; listeners)
                            l.windowResized(win);
                        break;
                    case WM_SIZE:
                        //log.logMessage("WM_SIZE");
                        win.windowMovedOrResized();
                        foreach(l; listeners)
                            l.windowResized(win);
                        break;
                    case WM_GETMINMAXINFO:
                        // Prevent the window from going smaller than some minimu size
                        (cast(MINMAXINFO*)lParam).ptMinTrackSize.x = 100;
                        (cast(MINMAXINFO*)lParam).ptMinTrackSize.y = 100;
                        break;
                    case WM_CLOSE:
                    {
                        //log.logMessage("WM_CLOSE");
                        bool close = true;
                        foreach(l; listeners)
                        {
                            if (!l.windowClosing(win))
                                close = false;
                        }
                        if (!close) return 0;
                        
                        foreach(l; listeners)
                            l.windowClosed(win);
                        win.destroy();
                        return 0;
                    }
                    default:
                        break;
                }
                
                return DefWindowProc( hWnd, uMsg, wParam, lParam );
            }
            catch(Exception){}

            return 0;
        }

        /**
         @remarks
             Call this once per frame if not using Root:startRendering(). This will update all registered
             RenderWindows (If using external Windows, you can optionally register those yourself)
         */
        static void messagePump()
        {
            // Windows Message Loop (NULL means check all HWNDs belonging to this context)
            MSG  msg;
            while( PeekMessage( &msg, null, 0U, 0U, PM_REMOVE ) )
            {
                TranslateMessage( &msg );
                DispatchMessage( &msg );
            }
        }
        
        /**
         @remarks
         Add a listener to listen to renderwindow events (multiple listener's per renderwindow is fine)
         The same listener can listen to multiple windows, as the Window Pointer is sent along with
         any messages.
         @param window
         The RenderWindow you are interested in monitoring
         @param listener
         Your callback listener
         */
        static void addWindowEventListener( RenderWindow window, WindowEventListener listener )
        {
            if((window in _msListeners) is null)
                _msListeners[window] = null;
            _msListeners[window].insert(listener);
        }
        
        /**
         @remarks
         Remove previously added listener
         @param window
         The RenderWindow you registered with
         @param listener
         The listener registered
         */
        static void removeWindowEventListener( RenderWindow window, WindowEventListener listener )
        {
            if((window in _msListeners) is null)
                return;
            _msListeners[window].removeFromArray(listener);
        }
        
        /**
         @remarks
         Called by RenderWindows upon creation for Ogre generated windows. You are free to add your
         external windows here too if needed.
         @param window
         The RenderWindow to monitor
         */
        static void _addRenderWindow(RenderWindow window)
        {
            _msWindows.insert(window);
        }
        
        /**
         @remarks
         Called by RenderWindows upon creation for Ogre generated windows. You are free to add your
         external windows here too if needed.
         @param window
         The RenderWindow to remove from list
         */
        static void _removeRenderWindow(RenderWindow window)
        {
            _msWindows.removeFromArray(window);
        }
        
        //These are public only so GLXProc can access them without adding Xlib headers header
        //typedef multimap<RenderWindow*, WindowEventListener*>::type WindowEventListeners;
        //alias WindowEventListener[][RenderWindow] WindowEventListeners;
        static WindowEventListener[][RenderWindow] _msListeners;
        
        //typedef vector<RenderWindow*>.type Windows;
        static RenderWindow[] _msWindows;
    }
}
/** @} */
/** @} */