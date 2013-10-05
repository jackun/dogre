module ogregl.windows.pbuffer;
version(Windows):
import std.conv;

import derelict.util.wintypes;
import derelict.opengl3.gl;
import derelict.opengl3.wgl;

import ogre.image.pixelformat;
import ogre.general.log;
import ogre.exception;
import ogregl.windows.context;
import ogregl.context;
import ogregl.pbuffer;

class Win32PBuffer : GLPBuffer
{
public:
    this(PixelComponentType format, size_t width, size_t height)
    {
        super(format, width, height);
        mContext = null;
        
        createPBuffer();
        
        // Create context
        mContext = new Win32Context(mHDC, mGlrc);
        /*static if (false){
         if(mUseBind)
         {
         // Bind texture
         glBindTextureEXT(GL_TEXTURE_2D, static_cast<GLTexture*>(mTexture.get())->getGLID());
         wglBindTexImageARB(mPBuffer, WGL_FRONT_LEFT_ARB);
         }
         }*/
    }
    
    ~this()
    {
        /*static if(false){
         if(mUseBind)
         {
         // Unbind texture
         glBindTextureEXT(GL_TEXTURE_2D,
         static_cast<GLTexture*>(mTexture.get())->getGLID());
         glBindTextureEXT(GL_TEXTURE_2D,
         static_cast<GLTexture*>(mTexture.get())->getGLID());
         wglReleaseTexImageARB(mPBuffer, WGL_FRONT_LEFT_ARB);
         }
         }*/
        // Unregister and destroy mContext
        delete mContext;        
        
        // Destroy pbuffer
        destroyPBuffer();
    }
    
    override GLContext getContext() { return mContext; }
protected:
    void createPBuffer()
    {
        
        // Process format
        int bits=0;
        bool isFloat=false;
        //static if (false)
        //    bool hasAlpha=true;
        
        switch(mFormat)
        {
            case PixelComponentType.PCT_BYTE:
                bits=8; isFloat=false;
                break;
            case PixelComponentType.PCT_SHORT:
                bits=16; isFloat=false;
                break;
            case PixelComponentType.PCT_FLOAT16:
                bits=16; isFloat=true;
                break;
            case PixelComponentType.PCT_FLOAT32:
                bits=32; isFloat=true;
                break;
            default: break;
        }
        
        LogManager.getSingleton().logMessage(
            " Win32PBuffer::Creating PBuffer of format bits=" ~
            to!string(bits)~
            " float="~ to!string(isFloat)
            );
        
        
        HDC old_hdc = wglGetCurrentDC();
        HGLRC old_context = wglGetCurrentContext();
        
        // Bind to RGB or RGBA texture
        int bttype = 0;
        /*static if (false)
         {
         if(mUseBind)
         {
         // Only provide bind type when actually binding
         bttype = PixelUtil.hasAlpha(mInternalFormat)?
         WGL_BIND_TO_TEXTURE_RGBA_ARB : WGL_BIND_TO_TEXTURE_RGB_ARB;
         }
         int texformat = hasAlpha?
         WGL_TEXTURE_RGBA_ARB : WGL_TEXTURE_RGB_ARB;
         }*/
        // Make a float buffer?
        int pixeltype = isFloat?
            WGL_TYPE_RGBA_FLOAT_ARB: WGL_TYPE_RGBA_ARB;
        
        int[] attrib = [
                        WGL_RED_BITS_ARB,bits,
                        WGL_GREEN_BITS_ARB,bits,
                        WGL_BLUE_BITS_ARB,bits,
                        WGL_ALPHA_BITS_ARB,bits,
                        WGL_STENCIL_BITS_ARB,1,
                        WGL_DEPTH_BITS_ARB,15,
                        WGL_DRAW_TO_PBUFFER_ARB,1,
                        WGL_SUPPORT_OPENGL_ARB,1,
                        WGL_PIXEL_TYPE_ARB,pixeltype,
                        //WGL_DOUBLE_BUFFER_ARB,true,
                        //WGL_ACCELERATION_ARB,WGL_FULL_ACCELERATION_ARB, // Make sure it is accelerated
                        bttype,1, // must be last, as bttype can be zero
                        0
                        ];
        int[] pattrib_default = [0];
        /*static if(false){
         int pattrib_bind[] = { 
         WGL_TEXTURE_FORMAT_ARB, texformat, 
         WGL_TEXTURE_TARGET_ARB, WGL_TEXTURE_2D_ARB,
         WGL_PBUFFER_LARGEST_ARB, true,
         0 
         };
         }*/
        int format;
        uint count;
        
        // Choose suitable pixel format
        wglChoosePixelFormatARB(old_hdc,attrib.ptr,null,1,&format,&count);
        if(count == 0)
            throw new RenderingApiError("wglChoosePixelFormatARB() failed", " Win32PBuffer::createPBuffer");
        
        // Analyse pixel format
        int[] piAttributes =
            [
             WGL_RED_BITS_ARB,WGL_GREEN_BITS_ARB,WGL_BLUE_BITS_ARB,WGL_ALPHA_BITS_ARB,
             WGL_DEPTH_BITS_ARB,WGL_STENCIL_BITS_ARB
             ];
        
        int[] piValues = new int[piAttributes.length];
        wglGetPixelFormatAttribivARB(old_hdc,format,0,piAttributes.length,piAttributes.ptr,piValues.ptr);
        
        LogManager.getSingleton().stream()
            << " Win32PBuffer::PBuffer -- Chosen pixel format rgba="
                << piValues[0] << ","  
                << piValues[1] << ","  
                << piValues[2] << ","  
                << piValues[3] 
                << " depth=" << piValues[4]
                << " stencil=" << piValues[5];
        
        mPBuffer = wglCreatePbufferARB(old_hdc,format,mWidth,mHeight,pattrib_default.ptr);
        if(mPBuffer is null)
            throw new RenderingApiError("wglCreatePbufferARB() failed", " Win32PBuffer::createPBuffer");
        
        mHDC = wglGetPbufferDCARB(mPBuffer);
        if(mHDC is null) {
            wglDestroyPbufferARB(mPBuffer);
            throw new RenderingApiError("wglGetPbufferDCARB() failed", " Win32PBuffer::createPBuffer");
        }
        
        mGlrc = wglCreateContext(mHDC);
        if(mGlrc is null) {
            wglReleasePbufferDCARB(mPBuffer,mHDC);
            wglDestroyPbufferARB(mPBuffer);
            throw new RenderingApiError("wglCreateContext() failed", " Win32PBuffer::createPBuffer");
        }
        
        if(!wglShareLists(old_context,mGlrc)) {
            wglDeleteContext(mGlrc);
            wglReleasePbufferDCARB(mPBuffer,mHDC);
            wglDestroyPbufferARB(mPBuffer);
            throw new RenderingApiError("wglShareLists() failed", " Win32PBuffer::createPBuffer");
        }
        
        // Query real width and height
        int iWidth, iHeight;
        wglQueryPbufferARB(mPBuffer, WGL_PBUFFER_WIDTH_ARB, &iWidth);
        wglQueryPbufferARB(mPBuffer, WGL_PBUFFER_HEIGHT_ARB, &iHeight);
        mWidth = iWidth;  
        mHeight = iHeight;
        LogManager.getSingleton().stream()
            << "Win32RenderTexture::PBuffer created -- Real dimensions "
                << mWidth << "x" << mHeight;
    }
    
    void destroyPBuffer()
    {
        wglDeleteContext(mGlrc);
        wglReleasePbufferDCARB(mPBuffer,mHDC);
        wglDestroyPbufferARB(mPBuffer);
    }
    
    HDC     mHDC;
    HGLRC   mGlrc;
    HPBUFFERARB mPBuffer;
    Win32Context mContext;
}
