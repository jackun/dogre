module ogregl.texturemanager;
import std.conv: to;
import derelict.opengl3.gl;
import ogre.resources.texturemanager;
import ogre.resources.texture;
import ogre.image.pixelformat;
import ogre.general.root;
import ogre.image.images;
import ogre.rendersystem.rendersystem;
import ogre.strings;
import ogregl.texture;
import ogregl.support;
import ogre.resources.resource;
import ogre.general.common;
import ogregl.rendertexture;
import ogregl.glew;
import ogre.resources.resourcegroupmanager;

/** GL-specific implementation of a TextureManager 
 * TextureManager is a singleton. Use getSingletonInit.
 */
package class GLTextureManager : TextureManager
{
public:
    this(GLSupport* support)
    {
        super();
        mGLSupport = support;
        mWarningTextureID = 0;
        // register with group manager
        ResourceGroupManager.getSingleton()._registerResourceManager(mResourceType, this);
    }

    ~this()
    {
        // unregister with group manager
        ResourceGroupManager.getSingleton()._unregisterResourceManager(mResourceType);
        // Delete warning texture
        glDeleteTextures(1, &mWarningTextureID);
    }
    
    GLuint getWarningTextureID() { return mWarningTextureID; }
    
    /// @copydoc TextureManager::getNativeFormat
    override PixelFormat getNativeFormat(TextureType ttype, PixelFormat format, int usage)
    {
        // Adjust requested parameters to capabilities
        RenderSystemCapabilities caps = Root.getSingleton().getRenderSystem().getCapabilities();
        
        // Check compressed texture support
        // if a compressed format not supported, revert to PF_A8R8G8B8
        if(PixelUtil.isCompressed(format) &&
           !caps.hasCapability( Capabilities.RSC_TEXTURE_COMPRESSION_DXT ))
        {
            return PixelFormat.PF_A8R8G8B8;
        }
        // if floating point textures not supported, revert to PF_A8R8G8B8
        if(PixelUtil.isFloatingPoint(format) &&
           !caps.hasCapability( Capabilities.RSC_TEXTURE_FLOAT ))
        {
            return PixelFormat.PF_A8R8G8B8;
        }
        
        // Check if this is a valid rendertarget format
        if( usage & TextureUsage.TU_RENDERTARGET )
        {
            /// Get closest supported alternative
            /// If mFormat is supported it's returned
            return GLRTTManager.getSingleton().getSupportedAlternative(format);
        }
        
        // Supported
        return format;
    }

    
    /// @copydoc TextureManager::isHardwareFilteringSupported
    override bool isHardwareFilteringSupported(TextureType ttype, PixelFormat format, int usage,
                                        bool preciseFormatOnly = false)
    {
        if (format == PixelFormat.PF_UNKNOWN)
            return false;
        
        // Check native format
        PixelFormat nativeFormat = getNativeFormat(ttype, format, usage);
        if (preciseFormatOnly && format != nativeFormat)
            return false;
        
        // Assume non-floating point is supported always
        if (!PixelUtil.isFloatingPoint(nativeFormat))
            return true;
        
        // Hack: there are no elegant GL API to detects texture filtering supported,
        // just hard code for cards based on vendor specifications.
        
        // TODO: Add cards that 16 bits floating point filtering supported by
        // hardware below
        static string[] sFloat16SupportedCards =
        [
            // GeForce 8 Series
            "*GeForce*8800*",
            
            // GeForce 7 Series
            "*GeForce*7950*",
            "*GeForce*7900*",
            "*GeForce*7800*",
            "*GeForce*7600*",
            "*GeForce*7500*",
            "*GeForce*7300*",
            
            // GeForce 6 Series
            "*GeForce*6800*",
            "*GeForce*6700*",
            "*GeForce*6600*",
            "*GeForce*6500*",
        ];
        
        // TODO: Add cards that 32 bits floating point flitering supported by
        // hardware below
        static string[] sFloat32SupportedCards =
        [
            // GeForce 8 Series
            "*GeForce*8800*",
        ];
        
        PixelComponentType pct = PixelUtil.getComponentType(nativeFormat);
        string[] supportedCards;
        switch (pct)
        {
            case PixelComponentType.PCT_FLOAT16:
                supportedCards = sFloat16SupportedCards;
                break;
            case PixelComponentType.PCT_FLOAT32:
                supportedCards = sFloat32SupportedCards;
                break;
            default:
                return false;
        }
        
        string pcRenderer = to!string(glGetString(GL_RENDERER));
        
        foreach(card; supportedCards)
        {
            if (StringUtil.match(pcRenderer, card))
            {
                return true;
            }
        }
        
        return false;
    }
    
protected:
    //friend class GLRenderSystem;
    
    /// @copydoc ResourceManager::createImpl
    override Resource createImpl(string name, ResourceHandle handle, 
                         string group, bool isManual, ManualResourceLoader loader, 
                         NameValuePairList createParams)
    {
        return new GLTexture(this, name, handle, group, isManual, loader, mGLSupport);
    }
    
    /// Internal method to create a warning texture (bound when a texture unit is blank)
    package void createWarningTexture()
    {
        // Generate warning texture
        size_t width = 8;
        size_t height = 8;
        uint[] data = new uint[width*height];        // 0xXXRRGGBB
        // Yellow/black stripes
        for(size_t y=0; y<height; ++y)
        {
            for(size_t x=0; x<width; ++x)
            {
                data[y*width+x] = (((x+y)%8)<4)?0x000000:0xFFFF00;
            }
        }
        // Create GL resource
        glGenTextures(1, &mWarningTextureID);
        glBindTexture(GL_TEXTURE_2D, mWarningTextureID);
        if (GLEW_VERSION_1_2)
        {
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB8, cast(GLint)width, cast(GLint)height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, data.ptr);
        }
        else
        {
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB8, cast(GLint)width, cast(GLint)height, 0, GL_BGRA, GL_UNSIGNED_INT, data.ptr);
        }
        // Free memory
        destroy(data);
    }
    
    GLSupport* mGLSupport; //TODO To pointer or not to pointer?
    GLuint mWarningTextureID;
}