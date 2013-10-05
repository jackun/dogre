module ogre.general.serializer;
debug import std.stdio;
import ogre.resources.datastream;
import ogre.resources.meshfileformat;
import ogre.math.vector;
import ogre.math.quaternion;
import core.stdc.string;
import ogre.compat;
import ogre.exception;


/// stream overhead = ID + size 
// Keep signed or stuff like .skip(-HEADER_STREAM_ID) skip 0xEFFFF bytes forward instead of 0x1000 backward
enum int STREAM_OVERHEAD_SIZE = ushort.sizeof + uint.sizeof;
enum short HEADER_STREAM_ID = 0x1000;
enum short OTHER_ENDIAN_HEADER_STREAM_ID = 0x0010;


/** Generic class for serialising data to / from binary stream-based files.
 @remarks
 This class provides a number of useful methods for exporting / importing data
 from stream-oriented binary files (e.g. .mesh and .skeleton).
 */
class Serializer// : public SerializerAlloc
{
public:
    this(){}
    ~this(){}
    
    /// The endianness of written files
    enum Endian
    {
        /// Use the platform native endian
        ENDIAN_NATIVE,
        /// Use big endian (0x1000 is serialised as 0x10 0x00)
        ENDIAN_BIG,
        /// Use little endian (0x1000 is serialised as 0x00 0x10)
        ENDIAN_LITTLE
    }
    
    
protected:
    
    uint mCurrentstreamLen;
    DataStream mStream;
    string mVersion = "[Serializer_v1.00]";
    bool mFlipEndian = false; // default to native endian, derive from header
    
    // Internal methods
    void writeFileHeader()
    {
        
        ushort val = HEADER_STREAM_ID;
        writeShorts(&val, 1);
        
        writeString(mVersion);
        
    }
    
    void writeChunkHeader(ushort id, ulong size)
    {
        writeShorts(&id, 1);
        uint uintsize = cast(uint)(size);
        writeInts(&uintsize, 1);
    }
    
    void writeFloats(float* pFloat, size_t count)
    {
        if (mFlipEndian)
        {
            ubyte[] malloc = new ubyte[float.sizeof * count];
            float * pFloatToWrite = cast(float*)malloc.ptr;
            memcpy(pFloatToWrite, pFloat, float.sizeof * count);
            
            flipToLittleEndian(pFloatToWrite, float.sizeof, count);
            writeData(malloc, float.sizeof, count);
            
            destroy(malloc);
        }
        else
        {
            writeData(pFloat, float.sizeof, count);
        }
    }
    
    void writeFloats(double* pDouble, size_t count)
    {
        // Convert to float, then write
        float[] tmp = new float[count];
        for (uint i = 0; i < count; ++i)
        {
            tmp[i] = cast(float)(pDouble[i]);
        }
        if(mFlipEndian)
        {
            flipToLittleEndian(tmp.ptr, float.sizeof, count);
            writeData(tmp.ptr, float.sizeof, count);
        }
        else
        {
            writeData(tmp.ptr, float.sizeof, count);
        }
        destroy(tmp);
    }
    
    void writeShorts(ushort* pShort, size_t count)
    {
        if(mFlipEndian)
        {
            ubyte[] malloc = new ubyte[ushort.sizeof * count];
            ushort * pShortToWrite = cast(ushort *)malloc.ptr;
            memcpy(pShortToWrite, pShort, ushort.sizeof * count);
            
            flipToLittleEndian(pShortToWrite, ushort.sizeof, count);
            writeData(malloc, ushort.sizeof, count);
            
            destroy(malloc);
        }
        else
        {
            writeData(pShort, ushort.sizeof, count);
        }
    }
    
    //TODO Really, allow just uint?
    void writeInts(uint* pInt, size_t count)
    {
        if(mFlipEndian)
        {
            ubyte[] malloc = new ubyte[uint.sizeof * count];
            uint * pIntToWrite = cast(uint *)malloc.ptr;
            memcpy(pIntToWrite, pInt, uint.sizeof * count);
            
            flipToLittleEndian(pIntToWrite, uint.sizeof, count);
            writeData(malloc, uint.sizeof, count);
            
            destroy(malloc);
        }
        else
        {
            writeData(pInt, uint.sizeof, count);
        }
    }
    
    void writeBools(bool* pBool, size_t count)
    {
        //no endian flipping for 1-byte bools
        //XXX Nasty Hack to convert to 1-byte bools
        /*#   if OGRE_PLATFORM == OGRE_PLATFORM_APPLE || OGRE_PLATFORM == OGRE_PLATFORM_APPLE_IOS
         ubyte * pubyteToWrite = cast(ubyte *)malloc(sizeof(ubyte) * count);
         for(uint i = 0; i < count; i++)
         {
         *cast(ubyte *)(pubyteToWrite + i) = *(bool *)(pBool + i);
         }
         
         writeData(pubyteToWrite, sizeof(ubyte), count);
         
         free(pubyteToWrite);
         #   else
         */
        writeData(pBool, bool.sizeof, count);
        //#   endif
        
    }
    
    void writeObject(Vector3 v)
    {
        Real[3] tmp = [ v.x, v.y, v.z ];
        writeFloats(tmp.ptr, 3);
    }
    
    void writeObject(Quaternion q)
    {
        Real[4] tmp = [ q.x, q.y, q.z, q.w ];
        writeFloats(tmp.ptr, 4);
    }
    
    void writeString(string str)
    {
        // Old, backwards compatible way - \n terminated
        mStream.write(str~"\n"); //, str.length);
        // Write terminating newline ubyte
        //ubyte terminator = 10;
        //mStream.write(&terminator, 1);
    }
    
    void writeData(ref ubyte[] buf, size_t size, size_t count = 0)
    {
        mStream.write(buf, size * count);
    }
    
    void writeData(void* pbuf, size_t size, size_t count)
    {
        ubyte[] buf = (cast(ubyte*)pbuf)[0..size*count]; //Slice it
        mStream.write(buf, size * count);
    }
    
    void readFileHeader(DataStream stream)
    {
        ushort headerID;
        
        // Read header ID
        readShorts(stream, &headerID, 1);
        
        if (headerID == HEADER_STREAM_ID)
        {
            // Read version
            string ver = readString(stream);
            if (ver != mVersion)
            {
                throw new InternalError(
                    "Invalid file: version incompatible, file reports " ~ ver ~
                    " Serializer is version " ~ mVersion,
                    "Serializer.readFileHeader");
            }
        }
        else
        {
            throw new InternalError("Invalid file: no header", 
                                    "Serializer.readFileHeader");
        }
        
    }
    
    ushort readChunk(DataStream stream)
    {
        ushort id;
        readShorts(stream, &id, 1);
        
        readInts(stream, &mCurrentstreamLen, 1);
        return id;
    }
    
    void readBools(DataStream stream, bool* pDest, size_t count)
    {
        //XXX Nasty Hack to convert 1 byte bools to 4 byte bools
        /*#   if OGRE_PLATFORM == OGRE_PLATFORM_APPLE || OGRE_PLATFORM == OGRE_PLATFORM_APPLE_IOS
         ubyte * pTemp = cast(ubyte *)malloc(1*count); // to hold 1-byte bools
         stream.read(pTemp, 1 * count);
         for(uint i = 0; i < count; i++)
         *(bool *)(pDest + i) = *cast(ubyte *)(pTemp + i);
         
         free (pTemp);
         #   else
         */
        ubyte[] buf;
        stream.read(buf, bool.sizeof * count);
        memcpy(pDest, buf.ptr, bool.sizeof*count);
        
        //#   endif
        //no flipping on 1-byte datatypes
    }
    
    void readFloats(DataStream stream, float* pDest, size_t count)
    {
        ubyte[]buf;
        stream.read(buf, float.sizeof * count);
        flipFromLittleEndian(pDest, float.sizeof, count);
        memcpy(pDest, buf.ptr, float.sizeof*count);
    }
    
    void readFloats(DataStream stream, double* pDest, size_t count)
    {
        // Read from float, convert to double
        ubyte[] buf = new ubyte[count*float.sizeof];
        stream.read(buf, buf.length);
        
        float* tmp = cast(float*)buf.ptr;
        flipFromLittleEndian(tmp, float.sizeof, count);
        // Convert to doubles (no cast required)
        while(count--)
        {
            *pDest++ = *tmp++;
        }
        //OGRE_FREE(tmp, MEMCATEGORY_GENERAL);
        destroy(buf);
    }
    
    void readShorts(DataStream stream, ushort* pDest, size_t count)
    {
        ubyte[] buf = new ubyte[count*ushort.sizeof];
        stream.read(buf, buf.length);
        
        memcpy(pDest, buf.ptr, buf.length);
        /*ushort* tmp = cast(ushort*)buf.ptr;
        ushort* ptmp = pDest;
        while(count--)
        {
            *ptmp++ = *tmp++;
        }*/
        
        flipFromLittleEndian(pDest, ushort.sizeof, count);
    }
    
    void readInts(DataStream stream, uint* pDest, size_t count)
    {
        ubyte[] buf = new ubyte[count*uint.sizeof];
        stream.read(buf, buf.length);
        memcpy(pDest, buf.ptr, buf.length);
        flipFromLittleEndian(pDest, uint.sizeof, count);
    }
    
    void readObject(DataStream stream, ref Vector3 pDest)
    {
        readFloats(stream, pDest.ptr(), 3);
    }
    
    void readObject(DataStream stream, ref Quaternion pDest)
    {
        float[4] tmp;
        readFloats(stream, tmp.ptr, 4);
        pDest.x = tmp[0];
        pDest.y = tmp[1];
        pDest.z = tmp[2];
        pDest.w = tmp[3];
    }
    
    string readString(DataStream stream)
    {
        return stream.getLine(false);
    }
    
    string readString(DataStream stream, size_t numubytes)
    {
        assert (numubytes <= 255);
        ubyte[] str;
        stream.read(str, numubytes);
        //str[numubytes] = '\0';
        return cast(string)str;
    }
    
    void flipToLittleEndian(void* pData, size_t size, size_t count = 1)
    {
        if(mFlipEndian)
        {
            flipEndian(pData, size, count);
        }
    }
    
    void flipFromLittleEndian(void* pData, size_t size, size_t count = 1)
    {
        if(mFlipEndian)
        {
            flipEndian(pData, size, count);
        }
    }
    
    void flipEndian(void * pData, size_t size, size_t count)
    {
        for(uint index = 0; index < count; index++)
        {
            flipEndian(cast(void *)(cast(size_t)pData + (index * size)), size);
        }
    }
    
    void flipEndian(void * pData, size_t size)
    {
        ubyte swapByte;
        for(uint byteIndex = 0; byteIndex < size/2; byteIndex++)
        {
            swapByte = *cast(ubyte *)(cast(size_t)pData + byteIndex);
            *cast(ubyte *)(cast(size_t)pData + byteIndex) = *cast(ubyte *)(cast(size_t)pData + size - byteIndex - 1);
            *cast(ubyte *)(cast(size_t)pData + size - byteIndex - 1) = swapByte;
        }
    }
    
    /// Determine the endianness of the incoming stream compared to native
    void determineEndianness(DataStream stream)
    {
        if (stream.tell() != 0)
        {
            throw new InvalidParamsError(
                "Can only determine the endianness of the input stream if it "
                "is at the start", "Serializer::determineEndianness");
        }
        
        ubyte[] buf;
        // read header id manually (no conversion)
        size_t actually_read = stream.read(buf, ushort.sizeof);
        // skip back
        stream.skip(0 - cast(long)actually_read);
        if (actually_read != ushort.sizeof)
        {
            // end of file?
            throw new InvalidParamsError(
                "Couldn't read 16 bit header value from input stream.",
                "Serializer.determineEndianness");
        }
        
        ushort dest = *(cast(ushort*)buf.ptr);
        
        if (dest == HEADER_STREAM_ID)
        {
            mFlipEndian = false;
        }
        else if (dest == OTHER_ENDIAN_HEADER_STREAM_ID)
        {
            mFlipEndian = true;
        }
        else
        {
            throw new InvalidParamsError(
                "Header chunk didn't match either endian: Corrupted stream?",
                "Serializer.determineEndianness");
        }
    }
    /// Determine the endianness to write with based on option
    void determineEndianness(Endian requestedEndian)
    {
        switch(requestedEndian)
        {
            case Endian.ENDIAN_NATIVE:
                mFlipEndian = false;
                break;
            case Endian.ENDIAN_BIG:
                version(BigEndian)
                    mFlipEndian = false;
                else
                    mFlipEndian = true;
                
                break;
            case Endian.ENDIAN_LITTLE:
                version(BigEndian)
                    mFlipEndian = true;
                else
                    mFlipEndian = false;
                break;
            default:
                assert(0, "Unknown endianness case.");
        }
    }
}