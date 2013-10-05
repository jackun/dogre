module ogregl.pixelformat;
import derelict.opengl3.gl;

import ogre.image.pixelformat;
import ogre.math.bitwise;
import ogre.rendersystem.rendersystem;
import ogre.general.root;

/**
 * Class to do pixel format mapping between GL and OGRE
 */
class GLPixelUtil
{
public:
    /** Takes the OGRE pixel format and returns the appropriate GL one
     @return a GLenum describing the format, or 0 if there is no exactly matching 
     one (and conversion is needed)
     */
    static GLenum getGLOriginFormat(PixelFormat mFormat)
    {
        switch(mFormat)
        {
            case PixelFormat.PF_A8:
                return GL_ALPHA;
            case PixelFormat.PF_L8:
                return GL_LUMINANCE;
            case PixelFormat.PF_L16:
                return GL_LUMINANCE;
            case PixelFormat.PF_BYTE_LA:
                return GL_LUMINANCE_ALPHA;
            case PixelFormat.PF_R3G3B2:
                return GL_RGB;
            case PixelFormat.PF_A1R5G5B5:
                return GL_BGRA;
            case PixelFormat.PF_R5G6B5:
                return GL_RGB;
            case PixelFormat.PF_B5G6R5:
                return GL_BGR;
            case PixelFormat.PF_A4R4G4B4:
                return GL_BGRA;
                version(BigEndian){
                    // Formats are in native endian, so R8G8B8 on little endian is
                    // BGR, on big endian it is RGB.
                    case PixelFormat.PF_R8G8B8:
                    return GL_RGB;
                    case PixelFormat.PF_B8G8R8:
                    return GL_BGR;
                }else{
                    case PixelFormat.PF_R8G8B8:
                    return GL_BGR;
                    case PixelFormat.PF_B8G8R8:
                    return GL_RGB;
                }
            case PixelFormat.PF_X8R8G8B8:
            case PixelFormat.PF_A8R8G8B8:
                return GL_BGRA;
            case PixelFormat.PF_X8B8G8R8:
            case PixelFormat.PF_A8B8G8R8:
                return derelict.opengl3.constants.GL_RGBA;
            case PixelFormat.PF_B8G8R8A8:
                return GL_BGRA;
            case PixelFormat.PF_R8G8B8A8:
                return derelict.opengl3.constants.GL_RGBA;
            case PixelFormat.PF_A2R10G10B10:
                return GL_BGRA;
            case PixelFormat.PF_A2B10G10R10:
                return derelict.opengl3.constants.GL_RGBA;
            case PixelFormat.PF_FLOAT16_R:
                return GL_LUMINANCE;
            case PixelFormat.PF_FLOAT16_GR:
                return GL_LUMINANCE_ALPHA;
            case PixelFormat.PF_FLOAT16_RGB:
                return GL_RGB;
            case PixelFormat.PF_FLOAT16_RGBA:
                return derelict.opengl3.constants.GL_RGBA;
            case PixelFormat.PF_FLOAT32_R:
                return GL_LUMINANCE;
            case PixelFormat.PF_FLOAT32_GR:
                return GL_LUMINANCE_ALPHA;
            case PixelFormat.PF_FLOAT32_RGB:
                return GL_RGB;
            case PixelFormat.PF_FLOAT32_RGBA:
                return derelict.opengl3.constants.GL_RGBA;
            case PixelFormat.PF_SHORT_RGBA:
                return derelict.opengl3.constants.GL_RGBA;
            case PixelFormat.PF_SHORT_RGB:
                return GL_RGB;
            case PixelFormat.PF_SHORT_GR:
                return GL_LUMINANCE_ALPHA;
            case PixelFormat.PF_DXT1:
                return GL_COMPRESSED_RGBA_S3TC_DXT1_EXT;
            case PixelFormat.PF_DXT3:
                return GL_COMPRESSED_RGBA_S3TC_DXT3_EXT;
            case PixelFormat.PF_DXT5:
                return GL_COMPRESSED_RGBA_S3TC_DXT5_EXT;
            default:
                return 0;
        }
    }
    
    /** Takes the OGRE pixel format and returns type that must be provided
     to GL as data type for reading it into the GPU
     @return a GLenum describing the data type, or 0 if there is no exactly matching 
     one (and conversion is needed)
     */
    static GLenum getGLOriginDataType(PixelFormat mFormat)
    {
        switch(mFormat)
        {
            case PixelFormat.PF_A8:
            case PixelFormat.PF_L8:
            case PixelFormat.PF_R8G8B8:
            case PixelFormat.PF_B8G8R8:
            case PixelFormat.PF_BYTE_LA:
                return GL_UNSIGNED_BYTE;
            case PixelFormat.PF_R3G3B2:
                return GL_UNSIGNED_BYTE_3_3_2;
            case PixelFormat.PF_A1R5G5B5:
                return GL_UNSIGNED_SHORT_1_5_5_5_REV;
            case PixelFormat.PF_R5G6B5:
            case PixelFormat.PF_B5G6R5:
                return GL_UNSIGNED_SHORT_5_6_5;
            case PixelFormat.PF_A4R4G4B4:
                return GL_UNSIGNED_SHORT_4_4_4_4_REV;
            case PixelFormat.PF_L16:
                return GL_UNSIGNED_SHORT;
                version(BigEndian){
                    case PixelFormat.PF_X8B8G8R8:
                    case PixelFormat.PF_A8B8G8R8:
                    return GL_UNSIGNED_INT_8_8_8_8_REV;
                    case PixelFormat.PF_X8R8G8B8:
                    case PixelFormat.PF_A8R8G8B8:
                    return GL_UNSIGNED_INT_8_8_8_8_REV;
                    case PixelFormat.PF_B8G8R8A8:
                    return GL_UNSIGNED_BYTE;
                    case PixelFormat.PF_R8G8B8A8:
                    return GL_UNSIGNED_BYTE;
                }else{
                    case PixelFormat.PF_X8B8G8R8:
                    case PixelFormat.PF_A8B8G8R8:
                    return GL_UNSIGNED_BYTE;
                    case PixelFormat.PF_X8R8G8B8:
                    case PixelFormat.PF_A8R8G8B8:
                    return GL_UNSIGNED_BYTE;
                    case PixelFormat.PF_B8G8R8A8:
                    return GL_UNSIGNED_INT_8_8_8_8;
                    case PixelFormat.PF_R8G8B8A8:
                    return GL_UNSIGNED_INT_8_8_8_8;
                }
            case PixelFormat.PF_A2R10G10B10:
                return GL_UNSIGNED_INT_2_10_10_10_REV;
            case PixelFormat.PF_A2B10G10R10:
                return GL_UNSIGNED_INT_2_10_10_10_REV;
            case PixelFormat.PF_FLOAT16_R:
            case PixelFormat.PF_FLOAT16_GR:
            case PixelFormat.PF_FLOAT16_RGB:
            case PixelFormat.PF_FLOAT16_RGBA:
                return GL_HALF_FLOAT;
            case PixelFormat.PF_FLOAT32_R:
            case PixelFormat.PF_FLOAT32_GR:
            case PixelFormat.PF_FLOAT32_RGB:
            case PixelFormat.PF_FLOAT32_RGBA:
                return GL_FLOAT;
            case PixelFormat.PF_SHORT_RGBA:
            case PixelFormat.PF_SHORT_RGB:
            case PixelFormat.PF_SHORT_GR:
                return GL_UNSIGNED_SHORT;
            default:
                return 0;
        }
    }
    
    /** Takes the OGRE pixel format and returns the type that must be provided
     to GL as internal format. GL_NONE if no match exists.
     @param mFormat The pixel format
     @param hwGamma Whether a hardware gamma-corrected version is requested
     */
    static GLenum getGLInternalFormat(PixelFormat mFormat, bool hwGamma = false)
    {
        switch(mFormat) {
            case PixelFormat.PF_L8:
                return GL_LUMINANCE8;
            case PixelFormat.PF_L16:
                return GL_LUMINANCE16;
            case PixelFormat.PF_A8:
                return GL_ALPHA8;
            case PixelFormat.PF_A4L4:
                return GL_LUMINANCE4_ALPHA4;
            case PixelFormat.PF_BYTE_LA:
                return GL_LUMINANCE8_ALPHA8;
            case PixelFormat.PF_R3G3B2:
                return GL_R3_G3_B2;
            case PixelFormat.PF_A1R5G5B5:
                return GL_RGB5_A1;
            case PixelFormat.PF_R5G6B5:
            case PixelFormat.PF_B5G6R5:
                return GL_RGB5;
            case PixelFormat.PF_A4R4G4B4:
                return GL_RGBA4;
            case PixelFormat.PF_R8G8B8:
            case PixelFormat.PF_B8G8R8:
            case PixelFormat.PF_X8B8G8R8:
            case PixelFormat.PF_X8R8G8B8:
                if (hwGamma)
                    return GL_SRGB8;
                else
                    return GL_RGB8;
            case PixelFormat.PF_A8R8G8B8:
            case PixelFormat.PF_B8G8R8A8:
                if (hwGamma)
                    return GL_SRGB8_ALPHA8;
                else
                    return GL_RGBA8;
            case PixelFormat.PF_A2R10G10B10:
            case PixelFormat.PF_A2B10G10R10:
                return GL_RGB10_A2;
            case PixelFormat.PF_FLOAT16_R:
                return GL_LUMINANCE16F_ARB;
            case PixelFormat.PF_FLOAT16_RGB:
                return GL_RGB16F_ARB;
            case PixelFormat.PF_FLOAT16_GR: 
                return GL_LUMINANCE_ALPHA16F_ARB;
            case PixelFormat.PF_FLOAT16_RGBA:
                return GL_RGBA16F_ARB;
            case PixelFormat.PF_FLOAT32_R:
                return GL_LUMINANCE32F_ARB;
            case PixelFormat.PF_FLOAT32_GR:
                return GL_LUMINANCE_ALPHA32F_ARB;
            case PixelFormat.PF_FLOAT32_RGB:
                return GL_RGB32F_ARB;
            case PixelFormat.PF_FLOAT32_RGBA:
                return GL_RGBA32F_ARB;
            case PixelFormat.PF_SHORT_RGBA:
                return GL_RGBA16;
            case PixelFormat.PF_SHORT_RGB:
                return GL_RGB16;
            case PixelFormat.PF_SHORT_GR:
                return GL_LUMINANCE16_ALPHA16;
            case PixelFormat.PF_DXT1:
                if (hwGamma)
                    return GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT;
                else
                    return GL_COMPRESSED_RGBA_S3TC_DXT1_EXT;
            case PixelFormat.PF_DXT3:
                if (hwGamma)
                    return GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT;
                else
                    return GL_COMPRESSED_RGBA_S3TC_DXT3_EXT;
            case PixelFormat.PF_DXT5:
                if (hwGamma)
                    return GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT;
                else
                    return GL_COMPRESSED_RGBA_S3TC_DXT5_EXT;
            default:
                return derelict.opengl3.constants.GL_NONE;
        }
    }
    
    /** Takes the OGRE pixel format and returns the type that must be provided
     to GL as internal format. If no match exists, returns the closest match.
     @param mFormat The pixel format
     @param hwGamma Whether a hardware gamma-corrected version is requested
     */
    static GLenum getClosestGLInternalFormat(PixelFormat mFormat, bool hwGamma = false)
    {
        GLenum format = getGLInternalFormat(mFormat, hwGamma);
        if(format==derelict.opengl3.constants.GL_NONE)
        {
            if (hwGamma)
                return GL_SRGB8;
            else
                return GL_RGBA8;
        }
        else
            return format;
    }
    
    /** Function to get the closest matching OGRE format to an internal GL format. To be
     precise, the format will be chosen that is most efficient to transfer to the card 
     without losing precision.
     @remarks It is valid for this function to always return PixelFormat.PF_A8R8G8B8.
     */
    static PixelFormat getClosestOGREFormat(GLenum fmt)
    {
        switch(fmt) 
        {
            case GL_LUMINANCE8:
                return PixelFormat.PF_L8;
            case GL_LUMINANCE16:
                return PixelFormat.PF_L16;
            case GL_ALPHA8:
                return PixelFormat.PF_A8;
            case GL_LUMINANCE4_ALPHA4:
                // Unsupported by GL as input format, use the byte packed format
                return PixelFormat.PF_BYTE_LA;
            case GL_LUMINANCE8_ALPHA8:
                return PixelFormat.PF_BYTE_LA;
            case GL_R3_G3_B2:
                return PixelFormat.PF_R3G3B2;
            case GL_RGB5_A1:
                return PixelFormat.PF_A1R5G5B5;
            case GL_RGB5:
                return PixelFormat.PF_R5G6B5;
            case GL_RGBA4:
                return PixelFormat.PF_A4R4G4B4;
            case GL_RGB8:
            case GL_SRGB8:
                return PixelFormat.PF_X8R8G8B8;
            case GL_RGBA8:
            case GL_SRGB8_ALPHA8:
                return PixelFormat.PF_A8R8G8B8;
            case GL_RGB10_A2:
                return PixelFormat.PF_A2R10G10B10;
            case GL_RGBA16:
                return PixelFormat.PF_SHORT_RGBA;
            case GL_RGB16:
                return PixelFormat.PF_SHORT_RGB;
            case GL_LUMINANCE16_ALPHA16:
                return PixelFormat.PF_SHORT_GR;
            /*case GL_LUMINANCE_FLOAT16_ATI:
                return PixelFormat.PF_FLOAT16_R;
            case GL_LUMINANCE_ALPHA_FLOAT16_ATI:
                return PixelFormat.PF_FLOAT16_GR;
            case GL_LUMINANCE_ALPHA_FLOAT32_ATI:
                return PixelFormat.PF_FLOAT32_GR;
            case GL_LUMINANCE_FLOAT32_ATI:
                return PixelFormat.PF_FLOAT32_R;
            case GL_RGB_FLOAT16_ATI: // GL_RGB16F_ARB
                return PixelFormat.PF_FLOAT16_RGB;
            case GL_RGBA_FLOAT16_ATI:
                return PixelFormat.PF_FLOAT16_RGBA;
            case GL_RGB_FLOAT32_ATI:
                return PixelFormat.PF_FLOAT32_RGB;
            case GL_RGBA_FLOAT32_ATI:
                return PixelFormat.PF_FLOAT32_RGBA;*/
            case GL_COMPRESSED_RGB_S3TC_DXT1_EXT:
            case GL_COMPRESSED_RGBA_S3TC_DXT1_EXT:
            case GL_COMPRESSED_SRGB_S3TC_DXT1_EXT:
            case GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT:
                return PixelFormat.PF_DXT1;
            case GL_COMPRESSED_RGBA_S3TC_DXT3_EXT:
            case GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT:
                return PixelFormat.PF_DXT3;
            case GL_COMPRESSED_RGBA_S3TC_DXT5_EXT:
            case GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT:
                return PixelFormat.PF_DXT5;
            default:
                return PixelFormat.PF_A8R8G8B8;
        }
    }
    
    /** Returns the maximum number of Mipmaps that can be generated until we reach
     the mininum format possible. This does not count the base level.
     @param width
     The width of the area
     @param height
     The height of the area
     @param depth
     The depth of the area
     @param format
     The format of the area
     @remarks
     In case that the format is non-compressed, this simply returns
     how many times we can divide this texture in 2 until we reach 1x1.
     For compressed formats, constraints apply on minimum size and alignment
     so this might differ.
     */
    static size_t getMaxMipmaps(size_t width, size_t height, size_t depth, PixelFormat format)
    {
        size_t count = 0;
        if((width > 0) && (height > 0) && (depth > 0))
        {
            do {
                if(width>1)     width = width/2;
                if(height>1)    height = height/2;
                if(depth>1)     depth = depth/2;
                /*
                 NOT needed, compressed formats will have mipmaps up to 1x1
                 if(PixelUtil::isValidExtent(width, height, depth, format))
                 count ++;
                 else
                 break;
                 */
                
                count ++;
            } while(!(width == 1 && height == 1 && depth == 1));
        }       
        return count;
    }
    
    /** Returns next power-of-two size if required by render system, in case
     RSC_NON_POWER_OF_2_TEXTURES is supported it returns value as-is.
     */
    static size_t optionalPO2(size_t value)
    {
        RenderSystemCapabilities caps = Root.getSingleton().getRenderSystem().getCapabilities();
        if(caps.hasCapability(Capabilities.RSC_NON_POWER_OF_2_TEXTURES))
            return value;
        else
            return Bitwise.firstPO2From(cast(uint)value);
    }   
}