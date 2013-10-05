module ogre.rendersystem.glx.windoweventutilities;

import ogre.compat;
import ogre.rendersystem.renderwindow;
import ogre.rendersystem.windoweventutilities;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup RenderSystem
 *  @{
 */
version(linux)
{
    import ogre.bindings.mini_x11;
    /**
     @remarks
        Utility class to handle Window Events/Pumping/Messages
     */
    class WindowEventUtilities
    {
    public:

        static void GLXProc( RenderWindow win, XEvent event )
        {
            //An iterator for the window listeners
            WindowEventListener[] listeners;
            
            if((win in _msListeners))
                listeners = _msListeners[win];
            
            switch(event.type)
            {
                case EventType.ClientMessage:
                {
                    Atom atom;
                    win.getCustomAttribute("ATOM", &atom);
                    if(event.xclient.format == 32 && event.xclient.data.l[0] == atom)
                    {   //Window closed by window manager
                        //Send message first, to allow app chance to unregister things that need done before
                        //window is shutdown
                        bool close = true;
                        foreach(l; listeners)
                        {
                            if (!l.windowClosing(win))
                                close = false;
                        }
                        if (!close) return;
                        
                        foreach(l; listeners)
                            l.windowClosed(win);
                        win.destroy();
                    }
                    break;
                }
                case EventType.DestroyNotify:
                {
                    if (!win.isClosed())
                    {
                        // Window closed without window manager warning.
                        foreach(l; listeners)
                            l.windowClosed(win);
                        win.destroy();
                    }
                    break;
                }
                case EventType.ConfigureNotify:
                {    
                    // This could be slightly more efficient if windowMovedOrResized took arguments:
                    uint oldWidth, oldHeight, oldDepth;
                    int oldLeft, oldTop;
                    win.getMetrics(oldWidth, oldHeight, oldDepth, oldLeft, oldTop);
                    win.windowMovedOrResized();
                    
                    uint newWidth, newHeight, newDepth;
                    int newLeft, newTop;
                    win.getMetrics(newWidth, newHeight, newDepth, newLeft, newTop);
                    
                    if (newLeft != oldLeft || newTop != oldTop)
                    {
                        foreach(l; listeners)
                            l.windowMoved(win);
                    }
                    
                    if (newWidth != oldWidth || newHeight != oldHeight)
                    {
                        foreach(l; listeners)
                            l.windowResized(win);
                    }
                    break;
                }
                case EventType.FocusIn:     // Gained keyboard focus
                case EventType.FocusOut:    // Lost keyboard focus
                    foreach(l; listeners)
                        l.windowFocusChange(win);
                    break;
                case EventType.MapNotify:   //Restored
                    win.setActive( true );
                    foreach(l; listeners)
                        l.windowFocusChange(win);
                    break;
                case EventType.UnmapNotify: //Minimised
                    win.setActive( false );
                    win.setVisible( false );
                    foreach(l; listeners)
                        l.windowFocusChange(win);
                    break;
                case EventType.VisibilityNotify:
                    switch(event.xvisibility.state)
                    {
                        case VisibilityNotify.VisibilityUnobscured:
                            win.setActive( true );
                            win.setVisible( true );
                            break;
                        case VisibilityNotify.VisibilityPartiallyObscured:
                            win.setActive( true );
                            win.setVisible( true );
                            break;
                        case VisibilityNotify.VisibilityFullyObscured:
                            win.setActive( false );
                            win.setVisible( false );
                            break;
                        default:
                            break;
                    }
                    foreach(l; listeners)
                        l.windowFocusChange(win);
                    break;
                default:
                    break;
            } //End switch event.type
        }
        /**
         @remarks
             Call this once per frame if not using Root:startRendering(). This will update all registered
             RenderWindows (If using external Windows, you can optionally register those yourself)
         */
        static void messagePump()
        {
            //GLX Message Pump
            
            Display* xDisplay = null; // same for all windows
            
            foreach(win; _msWindows)
            {
                XID xid;
                XEvent event;
                
                if (!xDisplay)
                    win.getCustomAttribute("XDISPLAY", &xDisplay);
                
                win.getCustomAttribute("WINDOW", &xid);
                
                while (XCheckWindowEvent (xDisplay, xid, StructureNotifyMask | VisibilityChangeMask | FocusChangeMask, &event))
                {
                    GLXProc(win, event);
                }
                
                // The ClientMessage event does not appear under any Event Mask
                while (XCheckTypedWindowEvent (xDisplay, xid, EventType.ClientMessage, &event))
                {
                    GLXProc(win, event);
                }
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
        
    private:
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
