module ogre.image.freeimage;
import core.stdc.string: memcpy;
import std.array;
import std.string: toLower;
import std.conv: to;

import ogre.compat;
import ogre.exception;
import ogre.image.images;
import derelict.freeimage.freeimage;
import ogre.resources.datastream;
import ogre.image.pixelformat;
import ogre.general.log;
import ogre.general.codec;


// freeimage 3.9.1~3.11.0 interoperability fix
/*
 #ifndef FREEIMAGE_COLORORDER
     // we have freeimage 3.9.1, define these symbols in such way as 3.9.1 really work (do not use 3.11.0 definition, as color order was changed between these two versions on Apple systems)
     #define FREEIMAGE_COLORORDER_BGR    0
     #define FREEIMAGE_COLORORDER_RGB    1
     #if defined(FREEIMAGE_BIGENDIAN)
        #define FREEIMAGE_COLORORDER FREEIMAGE_COLORORDER_RGB
     #else
        #define FREEIMAGE_COLORORDER FREEIMAGE_COLORORDER_BGR
     #endif
 #endif
*/

version(LittleEndian)
{
    version = FREEIMAGE_COLORORDER_BGR;
}
else
{
    version = FREEIMAGE_COLORORDER_RGB;
}


/** \addtogroup Core
 *  @{
 */
/** \addtogroup Image
 *  @{
 */
/** Codec specialized in images loaded using FreeImage.
 @remarks
 The users implementing subclasses of ImageCodec are required to return
 a valid pointer to a ImageData class from the decode(...) function.
 */
class FreeImageCodec : ImageCodec
{
private:
    string mType;
    int mFreeImageType;
    
    //typedef list<ImageCodec*>.type RegisteredCodecList;
    alias ImageCodec[] RegisteredCodecList;
    static RegisteredCodecList msCodecList;
    
    /** Common encoding routine. */
    FIBITMAP* encodeBitmap(MemoryDataStream input, CodecDataPtr pData) //const
    {
        FIBITMAP* ret = null;
        
        ImageData pImgData = cast(ImageData)pData;//.getPointer();
        auto src = new PixelBox(pImgData.width, pImgData.height, pImgData.depth, pImgData.format, input.getPtr());
        
        // The required format, which will adjust to the format
        // actually supported by FreeImage.
        PixelFormat requiredFormat = pImgData.format;
        
        // determine the settings
        FREE_IMAGE_TYPE imageType;
        PixelFormat determiningFormat = pImgData.format;
        
        switch(determiningFormat)
        {
            case PixelFormat.PF_R5G6B5:
            case PixelFormat.PF_B5G6R5:
            case PixelFormat.PF_R8G8B8:
            case PixelFormat.PF_B8G8R8:
            case PixelFormat.PF_A8R8G8B8:
            case PixelFormat.PF_X8R8G8B8:
            case PixelFormat.PF_A8B8G8R8:
            case PixelFormat.PF_X8B8G8R8:
            case PixelFormat.PF_B8G8R8A8:
            case PixelFormat.PF_R8G8B8A8:
            case PixelFormat.PF_A4L4:
            case PixelFormat.PF_BYTE_LA:
            case PixelFormat.PF_R3G3B2:
            case PixelFormat.PF_A4R4G4B4:
            case PixelFormat.PF_A1R5G5B5:
            case PixelFormat.PF_A2R10G10B10:
            case PixelFormat.PF_A2B10G10R10:
                // I'd like to be able to use r/g/b masks to get FreeImage to load the data
                // in it's existing format, but that doesn't work, FreeImage needs to have
                // data in RGB[A] (big endian) and BGR[A] (little endian), always.
                if (PixelUtil.hasAlpha(determiningFormat))
                {
                    version(FREEIMAGE_COLORORDER_RGB)
                        requiredFormat = PixelFormat.PF_BYTE_RGBA;
                    else
                        requiredFormat = PixelFormat.PF_BYTE_BGRA;
                }
                else
                {
                    version(FREEIMAGE_COLORORDER_RGB)
                        requiredFormat = PixelFormat.PF_BYTE_RGB;
                    else
                        requiredFormat = PixelFormat.PF_BYTE_BGR;
                }
                // fall through
            case PixelFormat.PF_L8:
            case PixelFormat.PF_A8:
                imageType = FIT_BITMAP;
                break;
                
            case PixelFormat.PF_L16:
                imageType = FIT_UINT16;
                break;
                
            case PixelFormat.PF_SHORT_GR:
                requiredFormat = PixelFormat.PF_SHORT_RGB;
                // fall through
            case PixelFormat.PF_SHORT_RGB:
                imageType = FIT_RGB16;
                break;
                
            case PixelFormat.PF_SHORT_RGBA:
                imageType = FIT_RGBA16;
                break;
                
            case PixelFormat.PF_FLOAT16_R:
                requiredFormat = PixelFormat.PF_FLOAT32_R;
                // fall through
            case PixelFormat.PF_FLOAT32_R:
                imageType = FIT_FLOAT;
                break;
                
            case PixelFormat.PF_FLOAT16_GR:
            case PixelFormat.PF_FLOAT16_RGB:
            case PixelFormat.PF_FLOAT32_GR:
                requiredFormat = PixelFormat.PF_FLOAT32_RGB;
                // fall through
            case PixelFormat.PF_FLOAT32_RGB:
                imageType = FIT_RGBF;
                break;
                
            case PixelFormat.PF_FLOAT16_RGBA:
                requiredFormat = PixelFormat.PF_FLOAT32_RGBA;
                // fall through
            case PixelFormat.PF_FLOAT32_RGBA:
                imageType = FIT_RGBAF;
                break;
                
            default:
                throw new ItemNotFoundError("Invalid image format", "FreeImageCodec.encode");
        }
        
        // Check support for this image type & bit depth
        if (!FreeImage_FIFSupportsExportType(mFreeImageType, imageType) ||
            !FreeImage_FIFSupportsExportBPP(mFreeImageType, cast(int)PixelUtil.getNumElemBits(requiredFormat)))
        {
            // Ok, need to allocate a fallback
            // Only deal with RGBA . RGB for now
            switch (requiredFormat)
            {
                case PixelFormat.PF_BYTE_RGBA:
                    requiredFormat = PixelFormat.PF_BYTE_RGB;
                    break;
                case PixelFormat.PF_BYTE_BGRA:
                    requiredFormat = PixelFormat.PF_BYTE_BGR;
                    break;
                default:
                    break;
            }
            
        }
        
        bool conversionRequired = false;
        
        ubyte* srcData = input.getPtr();
        
        // Check BPP
        uint bpp = cast(uint)(PixelUtil.getNumElemBits(requiredFormat));
        if (!FreeImage_FIFSupportsExportBPP(mFreeImageType, cast(int)bpp))
        {
            if (bpp == 32 && PixelUtil.hasAlpha(pImgData.format) && FreeImage_FIFSupportsExportBPP(cast(FREE_IMAGE_FORMAT)mFreeImageType, 24))
            {
                // drop to 24 bit (lose alpha)
                version(FREEIMAGE_COLORORDER_RGB)
                    requiredFormat = PixelFormat.PF_BYTE_RGB;
                else
                    requiredFormat = PixelFormat.PF_BYTE_BGR;
                bpp = 24;
            }
            else if (bpp == 128 && PixelUtil.hasAlpha(pImgData.format) && FreeImage_FIFSupportsExportBPP(cast(FREE_IMAGE_FORMAT)mFreeImageType, 96))
            {
                // drop to 96-bit floating point
                requiredFormat = PixelFormat.PF_FLOAT32_RGB;
            }
        }
        
        PixelBox convBox = new PixelBox(pImgData.width, pImgData.height, 1, requiredFormat);
        ubyte[] pdata;
        if (requiredFormat != pImgData.format)
        {
            conversionRequired = true;
            // Allocate memory
            pdata = new ubyte[convBox.getConsecutiveSize()];
            convBox.data = cast(void*)pdata.ptr;
            // perform conversion and reassign source
            PixelBox newSrc = new PixelBox(pImgData.width, pImgData.height, 1, pImgData.format, input.getPtr());
            PixelUtil.bulkPixelConversion(newSrc, convBox);
            srcData = cast(ubyte*)convBox.data;
        }
        
        
        ret = FreeImage_AllocateT(
            imageType, 
            cast(int)(pImgData.width), 
            cast(int)(pImgData.height), 
            cast(int)bpp, 
            0,0,0);
        
        if (ret is null)
        {
            if (conversionRequired)
            {
                convBox.data = null;
                destroy(pdata);
            }
            
            throw new InvalidParamsError(
                "FreeImage_AllocateT failed - possibly out of memory. ", 
                "FreeImageCodec.encode");
                //__FUNCTION__);//dmd 2.063 has this
        }
        
        if (requiredFormat == PixelFormat.PF_L8 || requiredFormat == PixelFormat.PF_A8)
        {
            // Must explicitly tell FreeImage that this is greyscale by setting
            // a "grey" palette (otherwise it will save as a normal RGB
            // palettized image).
            FIBITMAP *tmp = FreeImage_ConvertToGreyscale(ret);
            FreeImage_Unload(ret);
            ret = tmp;
        }
        
        size_t dstPitch = FreeImage_GetPitch(ret);
        size_t srcPitch = pImgData.width * PixelUtil.getNumElemBytes(requiredFormat);
        
        
        // Copy data, invert scanlines and respect FreeImage pitch
        ubyte* pSrc;
        ubyte* pDst = FreeImage_GetBits(ret);
        for (size_t y = 0; y < pImgData.height; ++y)
        {
            pSrc = srcData + (pImgData.height - y - 1) * srcPitch;
            memcpy(pDst, pSrc, srcPitch);
            pDst += dstPitch;
        }
        
        if (conversionRequired)
        {
            // delete temporary conversion area
            //OGRE_FREE(convBox.data, MEMCATEGORY_GENERAL);
            convBox.data = null;
            destroy(pdata);
        }
        
        return ret;
    }
    
public:
    this(string type, int fiType)
    {
        mType = type;
        mFreeImageType = fiType;
    }

    ~this() { }
    
    /// @copydoc Codec.code
    override DataStream encode(MemoryDataStream input, CodecDataPtr pData)// const;
    {        
        FIBITMAP* fiBitmap = encodeBitmap(input, pData);
        
        // open memory chunk allocated by FreeImage
        FIMEMORY* mem = FreeImage_OpenMemory(null, 0);
        // write data into memory
        FreeImage_SaveToMemory(cast(FREE_IMAGE_FORMAT)mFreeImageType, fiBitmap, mem, 0);
        // Grab data information
        BYTE* data;
        DWORD size;
        FreeImage_AcquireMemory(mem, &data, &size);
        // Copy data into our own buffer
        // Because we're asking MemoryDataStream to free this, must create in a compatible way
        BYTE[] ourData = new BYTE[size];
        memcpy(ourData.ptr, data, size);
        // Wrap data in stream, tell it to free on close 
        DataStream outstream = new MemoryDataStream(ourData, true);
        // Now free FreeImage memory buffers
        FreeImage_CloseMemory(mem);
        // Unload bitmap
        FreeImage_Unload(fiBitmap);
        
        return outstream;
    }

    /// @copydoc Codec.codeToFile
    override void encodeToFile(MemoryDataStream input, string outFileName, CodecDataPtr pData)// const;
    {
        FIBITMAP* fiBitmap = encodeBitmap(input, pData);
        
        FreeImage_Save(cast(FREE_IMAGE_FORMAT)mFreeImageType, fiBitmap, outFileName.ptr, 0);
        FreeImage_Unload(fiBitmap);
    }

    /// @copydoc Codec.decode
    override DecodeResult decode(DataStream input)// const;
    {

        // Buffer stream into memory (TODO: override IO functions instead?)
        MemoryDataStream memStream = new MemoryDataStream(input, true);

        FIMEMORY* fiMem = FreeImage_OpenMemory(memStream.getPtr(), cast(DWORD)(memStream.size()));
        
        FIBITMAP* fiBitmap = FreeImage_LoadFromMemory(cast(FREE_IMAGE_FORMAT)mFreeImageType, fiMem, 0);
        if (fiBitmap is null)
        {
            throw new InternalError(
                "Error decoding image", 
                "FreeImageCodec.decode");
        }
        
        ImageData imgData = new ImageData();
        MemoryDataStream output;
        
        imgData.depth = 1; // only 2D formats handled by this codec
        imgData.width = FreeImage_GetWidth(fiBitmap);
        imgData.height = FreeImage_GetHeight(fiBitmap);
        imgData.num_mipmaps = 0; // no mipmaps in non-DDS 
        imgData.flags = 0;
        
        // Must derive format first, this may perform conversions
        
        FREE_IMAGE_TYPE imageType = FreeImage_GetImageType(fiBitmap);
        FREE_IMAGE_COLOR_TYPE colourType = FreeImage_GetColorType(fiBitmap);
        uint bpp = FreeImage_GetBPP(fiBitmap);

        switch(imageType)
        {
            case FIT_UNKNOWN:
            case FIT_COMPLEX:
            case FIT_UINT32:
            case FIT_INT32:
            case FIT_DOUBLE:
            default:
                throw new ItemNotFoundError("Unknown or unsupported image format", 
                                            "FreeImageCodec.decode");
                
                break;
            case FIT_BITMAP:
                // Standard image type
                // Perform any colour conversions for greyscale
                if (colourType == FIC_MINISWHITE || colourType == FIC_MINISBLACK)
                {
                    FIBITMAP* newBitmap = FreeImage_ConvertToGreyscale(fiBitmap);
                    // free old bitmap and replace
                    FreeImage_Unload(fiBitmap);
                    fiBitmap = newBitmap;
                    // get new formats
                    bpp = FreeImage_GetBPP(fiBitmap);
                }
                // Perform any colour conversions for RGB
                else if (bpp < 8 || colourType == FIC_PALETTE || colourType == FIC_CMYK)
                {
                    FIBITMAP* newBitmap = null;    
                    if (FreeImage_IsTransparent(fiBitmap))
                    {
                        // convert to 32 bit to preserve the transparency 
                        // (the alpha byte will be 0 if pixel is transparent)
                        newBitmap = FreeImage_ConvertTo32Bits(fiBitmap);
                    }
                    else
                    {
                        // no transparency - only 3 bytes are needed
                        newBitmap = FreeImage_ConvertTo24Bits(fiBitmap);
                    }
                    
                    // free old bitmap and replace
                    FreeImage_Unload(fiBitmap);
                    fiBitmap = newBitmap;
                    // get new formats
                    bpp = FreeImage_GetBPP(fiBitmap);
                }
                
                // by this stage, 8-bit is greyscale, 16/24/32 bit are RGB[A]
                switch(bpp)
                {
                    case 8:
                        imgData.format = PixelFormat.PF_L8;
                        break;
                    case 16:
                        // Determine 555 or 565 from green mask
                        // cannot be 16-bit greyscale since that's FIT_UINT16
                        if(FreeImage_GetGreenMask(fiBitmap) == FI16_565_GREEN_MASK)
                        {
                            imgData.format = PixelFormat.PF_R5G6B5;
                        }
                        else
                        {
                            // FreeImage doesn't support 4444 format so must be 1555
                            imgData.format = PixelFormat.PF_A1R5G5B5;
                        }
                        break;
                    case 24:
                        // FreeImage differs per platform
                        //    PF_BYTE_BGR[A] for little endian (==PF_ARGB native)
                        //    PF_BYTE_RGB[A] for big endian (==PF_RGBA native)
                        version(FREEIMAGE_COLORORDER_RGB)
                            imgData.format = PixelFormat.PF_BYTE_RGB;
                        else
                            imgData.format = PixelFormat.PF_BYTE_BGR;
                        break;
                    case 32:
                        version(FREEIMAGE_COLORORDER_RGB)
                            imgData.format = PixelFormat.PF_BYTE_RGBA;
                        else
                            imgData.format = PixelFormat.PF_BYTE_BGRA;
                        break;
                    default:
                        assert(0, "Unsupported bitdepth");

                }
                break;
            case FIT_UINT16:
            case FIT_INT16:
                // 16-bit greyscale
                imgData.format = PixelFormat.PF_L16;
                break;
            case FIT_FLOAT:
                // Single-component floating point data
                imgData.format = PixelFormat.PF_FLOAT32_R;
                break;
            case FIT_RGB16:
                imgData.format = PixelFormat.PF_SHORT_RGB;
                break;
            case FIT_RGBA16:
                imgData.format = PixelFormat.PF_SHORT_RGBA;
                break;
            case FIT_RGBF:
                imgData.format = PixelFormat.PF_FLOAT32_RGB;
                break;
            case FIT_RGBAF:
                imgData.format = PixelFormat.PF_FLOAT32_RGBA;
                break;
        }

        BYTE* srcData = FreeImage_GetBits(fiBitmap);
        uint srcPitch = FreeImage_GetPitch(fiBitmap);
        
        // Final data - invert image and trim pitch at the same time
        size_t dstPitch = imgData.width * PixelUtil.getNumElemBytes(imgData.format);
        imgData.size = dstPitch * imgData.height;
        // Bind output buffer
        output = new MemoryDataStream(imgData.size);
        
        ubyte* pSrc;
        ubyte* pDst = output.getPtr();
        for (size_t y = 0; y < imgData.height; ++y)
        {
            pSrc = srcData + (imgData.height - y - 1) * srcPitch;
            memcpy(pDst, pSrc, dstPitch);
            pDst += dstPitch;
        }
        
        
        FreeImage_Unload(fiBitmap);
        FreeImage_CloseMemory(fiMem);
        
        
        DecodeResult ret;
        ret.first = output;
        ret.second = cast(CodecDataPtr)(imgData);//FIXME if REALLY is CodecDataPtr.
        return ret;
        
    }
    
    
    override string getType() const
    {
        return mType;
    }
    
    /// @copydoc Codec.magicNumberToFileExt
    override string magicNumberToFileExt(ubyte *magicNumberPtr, size_t maxbytes) //const;
    {
        FIMEMORY* fiMem = 
            FreeImage_OpenMemory(cast(BYTE*)magicNumberPtr, cast(DWORD)(maxbytes));
        
        FREE_IMAGE_FORMAT fif = FreeImage_GetFileTypeFromMemory(fiMem, cast(int)maxbytes);
        FreeImage_CloseMemory(fiMem);
        
        if (fif != FIF_UNKNOWN)
        {
            string ext = .to!string(FreeImage_GetFormatFromFIF(fif)).toLower();
            //StringUtil.toLowerCase(ext);
            return ext;
        }
        else
        {
            return null;
        }
    }
    
    /// Static method to startup FreeImage and register the FreeImage codecs
    static void startup()
    {
        DerelictFI.load();
        if(!DerelictFI.isLoaded())
        {
            LogManager.getSingleton().logMessage(
                LML_CRITICAL,
                "FreeImage failed to load.");
            return;
        }
            

        FreeImage_Initialise(false);
        
        LogManager.getSingleton().logMessage(
            LML_NORMAL,
            "FreeImage version: " ~ .to!string(FreeImage_GetVersion()));
        LogManager.getSingleton().logMessage(
            LML_NORMAL,
            .to!string(FreeImage_GetCopyrightMessage()));
        
        // Register codecs
        string strExt = "Supported formats: ";
        bool first = true;
        for (int i = 0; i < FreeImage_GetFIFCount(); ++i)
        {
            
            // Skip DDS codec since FreeImage does not have the option 
            // to keep DXT data compressed, we'll use our own codec
            if (cast(FREE_IMAGE_FORMAT)i == FIF_DDS)
                continue;
            
            string exts = .to!string(FreeImage_GetFIFExtensionList(cast(FREE_IMAGE_FORMAT)i));
            if (!first)
            {
                strExt ~= ",";
            }
            first = false;
            strExt ~= exts;
            
            // Pull off individual formats (separated by comma by FI)
            string[] extsVector = exts.split(",");
            foreach (v; extsVector)
            {
                // FreeImage 3.13 lists many formats twice: once under their own codec and
                // once under the "RAW" codec, which is listed last. Avoid letting the RAW override
                // the dedicated codec!
                if (!Codec.isCodecRegistered(v))
                {
                    ImageCodec codec = new FreeImageCodec(v, i);
                    msCodecList.insert(codec);
                    Codec.registerCodec(codec);
                }
            }
        }

        LogManager.getSingleton().logMessage(
            LML_NORMAL,
            strExt);
        
        // Set error handler
        FreeImage_SetOutputMessage(&FreeImageLoadErrorHandler);
    }

    /// Static method to shutdown FreeImage and unregister the FreeImage codecs
    static void shutdown()
    {
        FreeImage_DeInitialise();
        
        foreach (i; msCodecList)
        {
            Codec.unregisterCodec(i);
            //OGRE_DELETE *i;
        }
        msCodecList.clear();
    }

    extern(C) nothrow static void FreeImageLoadErrorHandler(FREE_IMAGE_FORMAT fif, const(char) *message)
    {
        try
        {
            // Callback method as required by FreeImage to report problems
            string typeName = .to!string(FreeImage_GetFormatFromFIF(fif));
            if (typeName)
            {
                LogManager.getSingleton().stream() 
                    << "FreeImage error: '" << .to!string(message) << "' when loading format "
                    << typeName;
            }
            else
            {
                LogManager.getSingleton().stream() 
                    << "FreeImage error: '" << .to!string(message) << "'";
            }
        }catch(Exception e)
        {

        }
        
    }

    static void FreeImageSaveErrorHandler(FREE_IMAGE_FORMAT fif, const(char) *_message) 
    {
        string message = .to!string(_message);
        // Callback method as required by FreeImage to report problems
        throw new CannotWriteToFileError(
            message, "FreeImageCodec.save");
    }

    unittest
    {
        string utlog = "FreeImageCodec_unittest.log";
        LogManager.getSingleton().createLog(utlog, true, true, true);
        FreeImageCodec.startup();
        FreeImageCodec.shutdown();
        LogManager.getSingleton().destroyLog(utlog);
    }
}
/** @} */
/** @} */