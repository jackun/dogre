module ogre.general.codec;
import ogre.resources.datastream;
import ogre.compat;
import ogre.exception;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup General
 *  @{
 */

/** Abstract class that defines a 'codec'.
 @remarks
 A codec class works like a two-way filter for data - data entered on
 one end (the decode end) gets processed and transformed into easily
 usable data while data passed the other way around codes it back.
 @par
 The codec concept is a pretty generic one - you can easily understand
 how it can be used for images, sounds, archives, even compressed data.
 */
class Codec //: public CodecAlloc
{
protected:
    //typedef map< String, Codec* >::type CodecList; 
    alias Codec[string] CodecList;
    /** A map that contains all the registered codecs.
     */
    static CodecList msMapCodecs;
    
public:
    static class CodecData //: CodecAlloc
    {
    public:
        ~this() {}
        
        /** Returns the type of the data.
         */
        string dataType(){ return "CodecData"; }
    }
    //NO //alias SharedPtr!CodecData CodecDataPtr;
    alias CodecData CodecDataPtr;
    
    //typedef ConstMapIterator<CodecList> CodecIterator;
    
public:
    ~this() {}
    
    /** Registers a new codec in the database.
     */
    static void registerCodec( Codec pCodec )
    {
        auto i = pCodec.getType() in msMapCodecs;
        if (i !is null)
            throw new DuplicateItemError(
                pCodec.getType() ~ " already has a registered codec. ", "Codec.registerCodec");
        
        msMapCodecs[pCodec.getType()] = pCodec;
    }
    
    /** Return whether a codec is registered already. 
     */
    static bool isCodecRegistered(string codecType )
    {
        return (codecType in msMapCodecs) !is null;
    }
    
    /** Unregisters a codec from the database.
     */
    static void unregisterCodec( Codec pCodec )
    {
        msMapCodecs.remove(pCodec.getType());
    }
    
    /** Gets the iterator for the registered codecs. */
    /*static CodecIterator getCodecIterator(void)
     {
     return CodecIterator(msMapCodecs.begin(), msMapCodecs.end());
     }*/
    static CodecList getCodecs()
    {
        return msMapCodecs;
    }
    
    /** Gets the file extension list for the registered codecs. */
    static auto getExtensions()
    {
        /*StringVector result;
         //result.reserve(msMapCodecs.length);//TODO want?
         
         foreach (k,v; msMapCodecs)
         {
         result.insertBack(k);
         }
         return result;*/
        return msMapCodecs.keysAA;
    }
    
    /** Gets the codec registered for the passed in file extension. */
    static Codec getCodec(string extension)
    {
        string lwrcase = std.string.toLower(extension);
        auto i = lwrcase in msMapCodecs;
        if (i is null)
        {
            string formats_str;
            if(msMapCodecs.emptyAA())
                formats_str = "There are no formats supported (no codecs registered).";
            else
                formats_str = std.conv.text("Supported formats are: ", getExtensions(), ".");
            
            throw new ItemNotFoundError(
                "Can not find codec for '" ~ extension ~ "' image format.\n" ~
                formats_str,
                "Codec.getCodec");
        }
        
        return *i;
    }
    
    /** Gets the codec that can handle the given 'magic' identifier. 
     @param magicNumber ubyte array to a stream of bytes which should identify the file.
     Note that this may be more than needed - each codec may be looking for 
     a different size magic number.
     */
    static Codec getCodec(ref ubyte[] magicNumber)
    {
        return getCodec(magicNumber.ptr, magicNumber.length);
    }
    
    /** Gets the codec that can handle the given 'magic' identifier. 
     @param magicNumberPtr Pointer to a stream of bytes which should identify the file.
     Note that this may be more than needed - each codec may be looking for 
     a different size magic number.
     @param maxbytes The number of bytes passed
     */
    static Codec getCodec(ubyte *magicNumberPtr, size_t maxbytes)
    {
        foreach (k,v; msMapCodecs)
        {
            string ext = v.magicNumberToFileExt(magicNumberPtr, maxbytes);
            if (!ext)
            {
                // check codec type matches
                // if we have a single codec class that can handle many types, 
                // and register many instances of it against different types, we
                // can end up matching the wrong one here, so grab the right one
                if (ext == v.getType())
                    return v;
                else
                    return getCodec(ext);
            }
        }
        
        return null;
        
    }
    
    /** Codes the data in the input stream and saves the result in the output
     stream.
     */
    abstract DataStream encode(MemoryDataStream input, CodecDataPtr pData);
    /** Codes the data in the input chunk and saves the result in the output
     filename provided. Provided for efficiency since coding to memory is
     progressive Therefore memory required is unknown leading to reallocations.
     @param input The input data
     @param outFileName The filename to write to
     @param pData Extra information to be passed to the codec (codec type specific)
     */
    abstract void encodeToFile(MemoryDataStream input,string outFileName, CodecDataPtr pData);
    
    /// Result of a decoding; both a decoded data stream and CodecData metadata
    //typedef std::pair<MemoryDataStreamPtr, CodecDataPtr> DecodeResult;
    alias pair!(MemoryDataStream, CodecDataPtr) DecodeResult;
    /** Codes the data from the input chunk into the output chunk.
     @param input Stream containing the encoded data
     @note
     Has a variable number of arguments, which depend on the codec type.
     */
    abstract DecodeResult decode(DataStream input);
    
    /** Returns the type of the codec as a String
     */
    abstract string getType();
    
    /** Returns the type of the data that supported by this codec as a String
     */
    abstract string getDataType();
    
    /** Returns whether a magic number header matches this codec.
     @param magicNumberPtr Pointer to a stream of bytes which should identify the file.
     Note that this may be more than needed - each codec may be looking for 
     a different size magic number.
     @param maxbytes The number of bytes passed
     */
    bool magicNumberMatch(ubyte *magicNumberPtr, size_t maxbytes)
    { return !magicNumberToFileExt(magicNumberPtr, maxbytes); }
    /** Maps a magic number header to a file extension, if this codec recognises it.
     @param magicNumberPtr Pointer to a stream of bytes which should identify the file.
     Note that this may be more than needed - each codec may be looking for 
     a different size magic number.
     @param maxbytes The number of bytes passed
     @return A blank string if the magic number was unknown, or a file extension.
     */
    abstract string magicNumberToFileExt(ubyte *magicNumberPtr, size_t maxbytes);
}

/** @} */
/** @} */