module ogregl.support;

import std.algorithm;
import std.string : indexOf, lastIndexOf, split;
import std.conv;

import derelict.opengl3.gl;

import ogre.compat;
import ogre.rendersystem.renderwindow;
import ogre.general.log;
import ogre.general.common;
import ogre.image.pixelformat;

import ogregl.pbuffer;
import ogregl.rendersystem;

class GLSupport
{
public:
    this() { }
    ~this() { }
    
    /**
    * Add any special config values to the system.
    * Must have a "Full Screen" value that is a bool and a "Video Mode" value
    * that is a string in the form of wxh
    */
    abstract void addConfig();
    
    void setConfigOption(string name, string value)
    {
        auto it = name in mOptions;
        
        if (it !is null)
            it.currentValue = value;
    }
    
    /**
    * Make sure all the extra options are valid
    * @return string with error message
    */
    abstract string validateConfig();
    
    ConfigOptionMap getConfigOptions()
    {
        return mOptions;
    }
    
    abstract RenderWindow createWindow(bool autoCreateWindow, GLRenderSystem renderSystem, string windowTitle);
    
    /// @copydoc RenderSystem::_createRenderWindow
    abstract RenderWindow newWindow(string name, uint width, uint height, 
                                    bool fullScreen, NameValuePairList miscParams = null);
    
    bool supportsPBuffers()
    {
        return (ARB_pixel_buffer_object || EXT_pixel_buffer_object) != GL_FALSE;
    }

    GLPBuffer createPBuffer(PixelComponentType format, size_t width, size_t height)
    {
        return null;
    }
    
    /**
    * Start anything special
    */
    abstract void start();
    /**
    * Stop anything special
    */
    abstract void stop();
    
    /**
    * Get vendor information
    */
    string getGLVendor() const
    {
        return mVendor;
    }
    
    /**
    * Get version information
    */
    string getGLVersion() const
    {
        return mVersion;
    }
    
    /**
    * Compare GL version numbers
    */
    bool checkMinGLVersion(string v) const
    {
        uint first, second, third;
        uint cardFirst, cardSecond, cardThird;
        if(v == mVersion)
            return true;

        auto pos = v.indexOf(".");
        if(pos == -1)
            return false;
        
        auto pos1 = v.lastIndexOf(".");
        if(pos1 == -1)
            return false;
        
        first = to!int(v[0..pos]);
        second = to!int(v[pos + 1..pos1 - (pos + 1)]);
        third = to!int(v[pos1 + 1..$]);
        
        pos = mVersion.indexOf(".");
        if(pos == -1)
            return false;
        
        pos1 = mVersion.lastIndexOf(".");
        if(pos1 == -1)
            return false;
        
        cardFirst  = to!int(mVersion[0..pos]);
        cardSecond = to!int(mVersion[pos + 1..pos1 - (pos + 1)]);
        cardThird  = to!int(mVersion[pos1 + 1..$]);

        if(first <= cardFirst && second <= cardSecond && third <= cardThird)
            return true;
        
        return false;
    }
    
    /**
    * Check if an extension is available
    */
    bool checkExtension(string ext) //const
    {
        assert(extensionList.length > 0, "ExtensionList is empty!" );
        
        return extensionList.inArray(ext);
    }
    /**
    * Get the address of a function
    */
    abstract void* getProcAddress(string procname);
    
    /** Initialises GL extensions, must be done AFTER the GL context has been
        established.
    */
    void initialiseExtensions()
    {
        // Set version string
        string pcVer = to!string(glGetString(GL_VERSION));
        
        assert(pcVer !is null, "Problems getting GL version string using glGetString");

        LogManager.getSingleton().logMessage("GL_VERSION = " ~ pcVer);
        mVersion = pcVer.split(" ")[0];
        
        // Get vendor
        string pcVendor = to!string(glGetString(GL_VENDOR));
        LogManager.getSingleton().logMessage("GL_VENDOR = " ~ pcVendor);
        mVendor = pcVendor.split(" ")[0];
        
        // Get renderer
        string pcRenderer = to!string(glGetString(GL_RENDERER));
        LogManager.getSingleton().logMessage("GL_RENDERER = " ~ pcRenderer);
        
        // Set extension list
        string pcExt = to!string(glGetString(GL_EXTENSIONS));
        LogManager.getSingleton().logMessage("GL_EXTENSIONS = " ~ pcExt);
        
        assert(pcExt !is null && pcExt.length, "Problems getting GL extension string using glGetString");

        extensionList = pcExt.split(" ");
    }

    
    /// @copydoc RenderSystem::getDisplayMonitorCount
    uint getDisplayMonitorCount() const
    {
        return 1;
    }
    
protected:
    // Stored options
    ConfigOptionMap mOptions;
    
    // This contains the complete list of supported extensions
    string[] extensionList;
private:
    string mVersion;
    string mVendor;
    
} // class GLSupport