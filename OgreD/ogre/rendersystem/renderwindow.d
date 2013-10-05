module ogre.rendersystem.renderwindow;
import ogre.rendersystem.rendertarget;
import ogre.general.common;
import ogre.image.pixelformat;

/** Manages the target rendering window.
        @remarks
            This class handles a window into which the contents
            of a scene are rendered. There is a many-to-1 relationship
            between instances of this class an instance of RenderSystem
            which controls the rendering of the scene. There may be
            more than one window in the case of level editor tools etc.
            This class is abstract since there may be
            different implementations for different windowing systems.
        @remarks
            Instances are created and communicated with by the render system
            although client programs can get a reference to it from
            the render system if required for resizing or moving.
            Note that you can have multiple viewpoints
            in the window for effects like rear-view mirrors and
            picture-in-picture views (see Viewport and Camera).
        @author
            Steven Streeting
        @version
            1.0
    */
class RenderWindow : RenderTarget
{
    
public:
    /** Default constructor.
        */
    this()
    {
        mIsPrimary = false;
        mAutoDeactivatedOnFocusChange = true;
    }
    
    
    /** Creates & displays the new window.
            @param
                width The width of the window in pixels.
            @param
                height The height of the window in pixels.
            @param
                colourDepth The colour depth in bits. Ignored if
                fullScreen is false since the desktop depth is used.
            @param
                fullScreen If true, the window fills the screen,
                with no title bar or border.
            @param
                left The x-position of the window. Ignored if
                fullScreen = true.
            @param
                top The y-position of the window. Ignored if
                fullScreen = true.
            @param
                depthBuffer Specify true to include a depth-buffer.
            @param
                miscParams A variable number of pointers to platform-specific arguments. The
                actual requirements must be defined by the implementing subclasses.
        */
    abstract void create(string name, uint width, uint height,
                         bool fullScreen, NameValuePairList miscParams);
    
    /** Alter fullscreen mode options. 
        @note Nothing will happen unless the settings here are different from the
            current settings.
        @param fullScreen Whether to use fullscreen mode or not. 
        @param width The new width to use
        @param height The new height to use
        */
    void setFullscreen(bool fullScreen, uint width, uint height) {}
    
    /** Destroys the window.
        */
    abstract void destroy();
    
    /** Alter the size of the window.
        */
    abstract void resize(uint width, uint height);
    
    /** Notify that the window has been resized
        @remarks
            You don't need to call this unless you created the window externally.
        */
    void windowMovedOrResized() {}
    
    /** Reposition the window.
        */
    abstract void reposition(int left, int top);
    
    /** Indicates whether the window is visible (not minimized or obscured)
        */
    bool isVisible(){ return true; }
    
    /** Set the visibility state
        */
    void setVisible(bool visible) {}
    
    /** Indicates whether the window was set to hidden (not displayed)
        */
    bool isHidden(){ return false; }
    
    /** Hide (or show) the window. If called with hidden=true, this
            will make the window completely invisible to the user.
        @remarks
            Setting a window to hidden is useful to create a dummy primary
            RenderWindow hidden from the user so that you can create and
            recreate your actual RenderWindows without having to recreate
            all your resources.
        */
    void setHidden(bool hidden) {}
    
    /** Enable or disable vertical sync for the RenderWindow.
        */
    void setVSyncEnabled(bool vsync) {}
    
    /** Indicates whether vertical sync is activated for the window.
        */
    bool isVSyncEnabled(){ return false; }
    
    /** Set the vertical sync interval. This indicates the number of vertical retraces to wait for
            before swapping buffers. A value of 1 is the default.
        */
    void setVSyncInterval(uint interval) {}
    
    /** Returns the vertical sync interval. 
        */
    uint getVSyncInterval(){ return 1; }
    
    
    /** Overridden from RenderTarget, flags invisible windows as inactive
        */
    override bool isActive(){ return mActive && isVisible(); }
    
    /** Indicates whether the window has been closed by the user.
        */
    abstract bool isClosed();
    
    /** Indicates whether the window is the primary window. The
            primary window is special in that it is destroyed when 
            ogre is shut down, and cannot be destroyed directly.
            This is the case because it holds the context for vertex,
            index buffers and textures.
        */
    override bool isPrimary()
    {
        return mIsPrimary;
    }
    
    /** Returns true if window is running in fullscreen mode.
        */
    bool isFullScreen() const
    {
        return mIsFullScreen;
    }
    
    /** Overloaded version of getMetrics from RenderTarget, including extra details
            specific to windowing systems.
        */
    void getMetrics(out uint width, out uint height, out uint colourDepth, 
                    out int left, out int top)
    {
        width = mWidth;
        height = mHeight;
        colourDepth = mColourDepth;
        left = mLeft;
        top = mTop;
    }
    
    /// Override since windows don't usually have alpha
    override PixelFormat suggestPixelFormat(){ return PixelFormat.PF_BYTE_RGB; }
    
    /** Returns true if the window will automatically de-activate itself when it loses focus.
        */
    bool isDeactivatedOnFocusChange()
    {
        return mAutoDeactivatedOnFocusChange;
    }
    
    /** Indicates whether the window will automatically deactivate itself when it loses focus.
          * \param deactivate a value of 'true' will cause the window to deactivate itself when it loses focus.  'false' will allow it to continue to render even when window focus is lost.
          * \note 'true' is the default behavior.
          */
    void setDeactivateOnFocusChange(bool deactivate)
    {
        mAutoDeactivatedOnFocusChange = deactivate;
    }
    
protected:
    bool mIsFullScreen;
    bool mIsPrimary;
    bool mAutoDeactivatedOnFocusChange;
    int mLeft;
    int mTop;

public: //FIXME Public for friendlies

    /** Indicates that this is the primary window. Only to be called by
            Ogre::Root
        */
    void _setPrimary() { mIsPrimary = true; }
    
    //friend class Root;
}
