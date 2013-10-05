module ogre.rendersystem.windoweventutilities;
import ogre.rendersystem.renderwindow;


/** \addtogroup Core
 *  @{
 */
/** \addtogroup RenderSystem
 *  @{
 */
/**
 @remarks
 Callback class used to send out window events to client app
 */
interface WindowEventListener
{   
    /**
     @remarks
     Window has moved position
     @param rw
     The RenderWindow which created this events
     */
    void windowMoved(RenderWindow rw);
    
    /**
     @remarks
     Window has resized
     @param rw
     The RenderWindow which created this events
     */
    void windowResized(RenderWindow rw);
    
    /**
     @remarks
     Window is closing (Only triggered if user pressed the [X] button)
     @param rw
     The RenderWindow which created this events
     @return True will close the window(default).
     */
    bool windowClosing(RenderWindow rw);
    
    /**
     @remarks
     Window has been closed (Only triggered if user pressed the [X] button)
     @param rw
     The RenderWindow which created this events
     @note
     The window has not actually close yet when this event triggers. It's only closed after
     all windowClosed events are triggered. This allows apps to deinitialise properly if they
     have services that needs the window to exist when deinitialising.
     */
    void windowClosed(RenderWindow rw);
    
    /**
     @remarks
     Window has lost/gained focus
     @param rw
     The RenderWindow which created this events
     */
    void windowFocusChange(RenderWindow rw);
    
    template Impl()
    {    
        public
        {
            void windowMoved(RenderWindow rw){}
            void windowResized(RenderWindow rw){}
            bool windowClosing(RenderWindow rw){ return true; }
            void windowClosed(RenderWindow rw){}
            void windowFocusChange(RenderWindow rw){}
        }
    }
}

//FIXME Better not to just use platform version, could be using SDL etc.
version(Windows)
{
    import ogre.rendersystem.windows.windoweventutilities;
    alias ogre.rendersystem.windows.windoweventutilities.WindowEventUtilities WindowEventUtilities;
}
else version(linux)
{
    import ogre.rendersystem.glx.windoweventutilities;
    alias ogre.rendersystem.glx.windoweventutilities.WindowEventUtilities WindowEventUtilities;
}

/** @} */
/** @} */