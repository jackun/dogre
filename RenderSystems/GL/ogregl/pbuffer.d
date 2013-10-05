module ogregl.pbuffer;
import ogre.image.pixelformat;
import ogregl.context;

/** An off-screen rendering context. These contexts are always RGBA for simplicity, speed and
 convience, but the component format is configurable.
 */
package class GLPBuffer
{
public:
    this(PixelComponentType format, size_t width, size_t height)
    {
        mFormat = format;
        mWidth = width;
        mHeight = height;
    }

    ~this() {}
    
    /** Get the GL context that needs to be active to render to this PBuffer.
     */
    abstract GLContext getContext();
    
    PixelComponentType getFormat() { return mFormat; }
    size_t getWidth() { return mWidth; }
    size_t getHeight() { return mHeight; }
    
    /** Get PBuffer component format for an OGRE pixel format.
     */
    //FIXME undefined? :/
    //static PixelComponentType getPixelComponentType(PixelFormat fmt);
protected:
    PixelComponentType mFormat;
    size_t mWidth, mHeight;
}