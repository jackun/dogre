module ogre.resources.datastream;

import std.stdio;
import std.file;
//import std.container;
import std.range;
import core.memory;
//import std.algorithm;
import std.string;
import std.conv: to;
public import ogre.sharedptr;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Resources
 *  @{
 */

/** General purpose class used for encapsulating the reading and writing of data.
 @remarks
 This class performs basically the same tasks as std::basic_istream, 
 except that it does not have any formatting capabilities, and is
 designed to be subclassed to receive data from multiple sources,
 including libraries which have no compatibility with the STL's
 stream interfaces. As such, this is an abstraction of a set of 
 wrapper classes which pretend to be standard stream classes but 
 can actually be implemented quite differently. 
 @par
 Generally, if a plugin or application provides an ArchiveFactory, 
 it should also provide a DataStream subclass which will be used
 to stream data out of that Archive implementation, unless it can 
 use one of the common implementations included.
 @note
 Ogre makes no guarantees about thread safety, for performance reasons.
 If you wish to access stream data asynchronously then you should
 organise your own mutexes to avoid race conditions. 
 */
class DataStream// : public StreamAlloc
{
public:
    enum AccessMode
    {
        READ = 1, 
        WRITE = 2
    }
protected:
    /// The name (e.g. resource name) that can be used to identify the source for his data (optional)
    string mName;       
    /// Size of the data in the stream (may be 0 if size cannot be determined)
    size_t mSize; //stupid size_t keeps changing
    /// What type of access is allowed (AccessMode)
    AccessMode mAccess;

    enum OGRE_STREAM_TEMP_SIZE = 128;
public:
    /// Constructor for creating unnamed streams
    this(AccessMode accessMode = AccessMode.READ)
    {
        mSize = 0;
        mAccess = accessMode;
    }
    /// Constructor for creating named streams
    this(string name, AccessMode accessMode = AccessMode.READ) 
    {
        mName = name;
        mSize = 0;
        mAccess = accessMode;
    }
    /// Returns the name of the stream, if it has one.
    string getName() { return mName; }
    /// Gets the access mode of the stream
    AccessMode getAccessMode(){ return mAccess; }
    /** Reports whether this stream is readable. */
    bool isReadable(){ return (mAccess & AccessMode.READ) != 0; }
    /** Reports whether this stream is writeable. */
    bool isWriteable(){ return (mAccess & AccessMode.WRITE) != 0; }
    ~this() {}

    // Streaming operators
    //template<typename T> DataStream& operator>>(T& val);
    DataStream opBinary(string op, T)(T value)
        if(op == ">>")
    {
        write(&value, T.sizeof);
    }

    /** Read the requisite number of bytes from the stream, 
     stopping at the end of the file.
     @param buf Reference to a buffer pointer
     @param count Number of bytes to read
     @return The number of bytes read
     */
    abstract size_t read(ref ubyte[] buf, size_t count);

    size_t read(void* ptr, size_t len)
    {
        ubyte[]buf = (cast(ubyte*)ptr)[0..len];//ptr into range? Anyway, buf should reference ptr directly
                                               // as tests complained about overlapping memory copy
        return read(buf, len);
    }
    /** Write the requisite number of bytes from the stream (only applicable to 
     streams that are not read-only)
     @param buf Pointer to a buffer containing the bytes to write
     @param count Number of bytes to write
     @return The number of bytes written
     */
    abstract size_t write(ubyte[] buf, size_t count);

    size_t write(void* ptr, size_t len)
    {
        return write((cast(ubyte*)ptr)[0..len], len);
    }

    /** D does something freaky and complains about casting to ubyte[]
     * if this doesn't get overridden in subclasses too. 
     * */
    size_t write(string buf)
    {
        ubyte[] b = cast(ubyte[])buf;
        return write(b, b.length);
    }
    
    /** Read to size_t. 
     @note Smaller than size_t.sizeof read counts get padded with zeros. 
     */
    size_t read(ref size_t buf, size_t count)
    {
        assert(count <= size_t.sizeof, "Read count is more than the size of size_t.");
        ubyte[] b;
        auto ret = read(b, count);
        
        if(ret < size_t.sizeof)
        {
            b.length = size_t.sizeof;
            b[ret .. $] = 0;
        }
        
        buf = cast(size_t)(*(cast(size_t*)b.ptr));
        return ret;
    }
    
    /** Read to int. 
     @note Smaller than size_t.sizeof read counts get padded with zeros. 
     */
    size_t read(ref int buf, size_t count)
    {
        assert(count <= int.sizeof, "Read count is more than the size of int.");
        ubyte[] b;
        auto ret = read(b, count);
        
        if(ret < int.sizeof)
        {
            b.length = int.sizeof;
            b[ret .. $] = 0;
        }
        
        buf = cast(int)(*(cast(int*)b.ptr));
        return ret;
    }
    /** Get a single line from the stream.
     @remarks
     The delimiter character is not included in the data
     returned, and it is skipped over so the next read will occur
     after it. The buffer contents will include a
     terminating character.
     @note
     If you used this function, you <b>must</b> open the stream in <b>binary mode</b>,
     otherwise, it'll produce unexpected results.
     @param buf Reference to a buffer pointer
     @param maxCount The maximum length of data to be read, excluding the terminating character
     @param delim The delimiter to stop at
     @return The number of bytes read, excluding the terminating character
     */
    size_t readLine(ref ubyte[] buf, size_t maxCount = OGRE_STREAM_TEMP_SIZE,string delim = "\n")
    {
        // Deal with both Unix & Windows LFs
        bool trimCR = false;
        if (delim.indexOf('\n') != -1)
        {
            trimCR = true;
        }

        ubyte[/+OGRE_STREAM_TEMP_SIZE+/] tmpBuf;
        if (maxCount == 0) maxCount = OGRE_STREAM_TEMP_SIZE;
        size_t chunkSize = std.algorithm.min(maxCount, cast(size_t)OGRE_STREAM_TEMP_SIZE);
        size_t totalCount = 0;
        size_t readCount; 
        while (chunkSize && (readCount = read(tmpBuf, chunkSize)) != 0)
        {
            // Terminate
            //tmpBuf[readCount] = '\0';
            //tmpBuf.length = readCount; //native arrays, probably slow to keep resizing all the time

            // Find first delimiter
            auto pos = std.algorithm.countUntil(tmpBuf, delim);
            if(pos == -1) pos = readCount; //tmpBuf.length;//strcspn compat

            if (pos < readCount)
            {
                // Found terminator, reposition backwards //XXX to \n right?
                skip(cast(long)(pos + delim.length - readCount));
            }

            // Are we genuinely copying?
            if (buf)
            {
                //memcpy(buf+totalCount, tmpBuf, pos);
                buf/+[0..pos]+/ = tmpBuf[0..pos];
            }
            totalCount += pos;

            if (pos < readCount)
            {
                // Trim off trailing CR if this was a CR/LF entry
                if (trimCR && totalCount && buf && buf[totalCount-1] == '\r')
                {
                    --totalCount;
                }

                // Found terminator, break out
                break;
            }

            // Adjust chunkSize for next time
            chunkSize = std.algorithm.min(maxCount-totalCount, cast(size_t)OGRE_STREAM_TEMP_SIZE);
        }

        // Terminate
        //if(buf)
        //    buf[totalCount] = '\0';

        return totalCount;
    }

    string readLine(string delim = "\n", size_t maxCount = OGRE_STREAM_TEMP_SIZE)
    {
        ubyte[] buf;
        readLine(buf, maxCount, delim);
        return cast(string)buf;
    }

    /** Returns a String containing the next line of data, optionally 
     trimmed for whitespace. 
     @remarks
     This is a convenience method for text streams only, allowing you to 
     retrieve a String object containing the next line of data. The data
     is read up to the next newline character and the result trimmed if
     required.
     @note
     If you used this function, you <b>must</b> open the stream in <b>binary mode</b>,
     otherwise, it'll produce unexpected results.
     @param 
     trimAfter If true, the line is trimmed for whitespace (as in 
     String.trim(true,true))
     */
    string getLine( bool trimAfter = true , string delim = "\n")
    {
        ubyte[/+OGRE_STREAM_TEMP_SIZE+/] tmpBuf;
        string retString;
        size_t readCount;
        // Keep looping while not hitting delimiter
        while ((readCount = read(tmpBuf, OGRE_STREAM_TEMP_SIZE-1)) != 0)
        {
            // Terminate string
            //tmpBuf[readCount] = '\0';
            
            ptrdiff_t p = cast(ptrdiff_t)readCount;
            
            p = std.algorithm.countUntil(tmpBuf, delim); //strchr
            
            if (p != -1)
            {
                // Reposition backwards
                skip(cast(long)(p + cast(long)delim.length - cast(long)readCount)); //FIXME uh unsigned math makes seek() sad
                //tmpBuf[p] = '\0';
                tmpBuf.length = p; //length is fixed for static arrays
            }
            else
                p = readCount;
            
            retString ~= cast(string)tmpBuf[0..p];
            
            if (p != -1)
            {
                // Trim off trailing CR if this was a CR/LF entry
                if (retString.length && delim == "\n" && retString[retString.length-1] == '\r')
                {
                    //retString.erase(retString.length()-1, 1);
                    retString.length -= 1;
                }

                // Found terminator, break out
                break;
            }
        }

        if (trimAfter)
        {
            retString = retString.strip();
        }

        return retString;
    }

    /** Returns a String containing the entire stream. 
     @remarks
     This is a convenience method for text streams only, allowing you to 
     retrieve a String object containing all the data in the stream.
     @todo Check D's performance.
     */
    string getAsString()
    {
        // Read the entire buffer - ideally in one read, but if the size of
        // the buffer is unknown, do multiple fixed size reads.
        size_t bufSize = cast(size_t)(mSize > 0 ? mSize : 4096);
        ubyte[] pBuf = new ubyte[bufSize]; //OGRE_ALLOC_T(char, bufSize, MEMCATEGORY_GENERAL);
        // Ensure read from begin of stream
        seek(0);
        ubyte[] result;
        while (!eof())
        {
            size_t nr = read(pBuf, bufSize);
            result ~= pBuf[0..nr];
        }
        string str = cast(string) result.idup;//FIXME too much allocing
        //OGRE_FREE(pBuf, MEMCATEGORY_GENERAL);
        //destroy(pBuf);
        return str;
    }

    /** Skip a single line from the stream.
     @note
     If you used this function, you <b>must</b> open the stream in <b>binary mode</b>,
     otherwise, it'll produce unexpected results.
     @param delim The delimiter(s) to stop at
     @return The number of bytes skipped
     */
    size_t skipLine(string delim = "\n")
    {
        ubyte[/+OGRE_STREAM_TEMP_SIZE+/] tmpBuf;
        size_t total = 0;
        size_t readCount;
        // Keep looping while not hitting delimiter
        while ((readCount = read(tmpBuf, OGRE_STREAM_TEMP_SIZE-1)) != 0)
        {
            // Terminate string
            //tmpBuf[readCount] = '\0';

            // Find first delimiter
            auto pos = std.algorithm.countUntil(tmpBuf, delim); //strcspn 
            if(pos == -1) pos = readCount;      // compat

            if (pos < readCount)
            {
                // Found terminator, reposition backwards
                skip(cast(long)(pos + delim.length - readCount));

                total += pos + delim.length;

                // break out
                break;
            }

            total += readCount;
        }

        return total;
    }

    /** Skip a defined number of bytes. This can also be a negative value, in which case
     the file pointer rewinds a defined number of bytes. */
    abstract void skip(long count);

    /** Repositions the read point to a specified byte.
     */
    abstract void seek( ulong pos );
    
    /** Returns the current byte offset from beginning */
    abstract ulong tell();

    /** Returns true if the stream has reached the end.
     */
    abstract bool eof();

    /** Returns the total size of the data to be read from the stream, 
     or 0 if this is indeterminate for this stream. 
     */
    size_t size() @property { return mSize; }

    /** Close the stream; this makes further operations invalid. */
    abstract void close();
}

/** Shared pointer to allow data streams to be passed around without
 worrying about deallocation
 */
/*typedef SharedPtr<DataStream> DataStreamPtr;

 /// List of DataStream items
 typedef list<DataStreamPtr>::type DataStreamList;
 /// Shared pointer to list of DataStream items
 typedef SharedPtr<DataStreamList> DataStreamListPtr;
 */


/** Common subclass of DataStream for handling data from chunks of memory.
 */
class MemoryDataStream : DataStream
{
protected:
    /// Pointer to the start of the data area
    ubyte[] mData;
    /// Pointer to the current position in the memory
    size_t mPos;
    /// Pointer to the 'end' of the memory
    size_t mEnd;
    /// Do we delete the memory on close
    bool mFreeOnClose;          
    bool mIsDynamic = false;
public:

    alias DataStream.read read;
    alias DataStream.write write;

    /*void reserve(size_t nbytes)
     in
     {
     assert(mPos + nbytes >= mPos);
     }
     out
     {
     assert(mPos + nbytes <= mData.length);
     }
     body
     {
     //c.stdio.printf("OutBuffer.reserve: length = %d, offset = %d, nbytes = %d\n", data.length, offset, nbytes);
     if (mData.length < mPos + nbytes)
     {
     mData.length = (mPos + nbytes) * 2;
     GC.clrAttr(mData.ptr, GC.BlkAttr.NO_SCAN);
     }
     }*/
    
    /** Wrap an existing memory chunk in a stream.
     @param pMem Pointer to the existing memory
     @param size The size of the memory chunk in bytes
     @param freeOnClose If true, the memory associated will be destroyed
     when the stream is destroyed. Note: it's important that if you set
     this option to true, that you allocated the memory using OGRE_ALLOC_T
     with a category of MEMCATEGORY_GENERAL ensure the freeing of memory 
     matches up.
     @param readOnly Whether to make the stream on this memory read-only once created
     */
    this(/+void*+/ ubyte[] pMem/+, size_t size+/, bool freeOnClose = false, bool readOnly = false)
    {
        super((readOnly ? AccessMode.READ : (AccessMode.READ | AccessMode.WRITE)));
        mData = pMem;//static_cast<uchar*>(pMem);
        mPos = 0;
        mEnd = mSize = pMem.length; //inSize; //TODO if 0 then dynamic size
        //mEnd = mData + mSize;
        mFreeOnClose = freeOnClose;
        //assert(mEnd >= mPos);
        //GC.clrAttr(mData.ptr, GC.BlkAttr.NO_SCAN);
        //assert(pMem.length > 0);
        mIsDynamic = (pMem.length == 0);
    }
    
    /** Wrap an existing memory chunk in a named stream.
     @param name The name to give the stream
     @param pMem Pointer to the existing memory
     @param size The size of the memory chunk in bytes
     @param freeOnClose If true, the memory associated will be destroyed
     when the stream is destroyed. Note: it's important that if you set
     this option to true, that you allocated the memory using OGRE_ALLOC_T
     with a category of MEMCATEGORY_GENERAL ensure the freeing of memory 
     matches up.
     @param readOnly Whether to make the stream on this memory read-only once created
     */
    this(string name, /+void*+/ubyte[] pMem,/+ size_t size, +/
         bool freeOnClose = false, bool readOnly = false)
    {
        super(name, (readOnly ? AccessMode.READ : (AccessMode.READ | AccessMode.WRITE)));
        mData = pMem;
        mPos = 0;//static_cast<uchar*>(pMem);
        mEnd = mSize = pMem.length;// inSize;
        //mEnd = mData + mSize;
        mFreeOnClose = freeOnClose;
        //assert(mEnd >= mPos);
        //GC.clrAttr(mData.ptr, GC.BlkAttr.NO_SCAN);
        //assert(pMem.length > 0);
    }

    /** Create a stream which pre-buffers the contents of another stream.
     @remarks
     This constructor can be used to intentionally read in the entire
     contents of another stream, copying them to the internal buffer
     and thus making them available in memory as a single unit.
     @param sourceStream Another DataStream which will provide the source
     of data
     @param freeOnClose If true, the memory associated will be destroyed
     when the stream is destroyed.
     @param readOnly Whether to make the stream on this memory read-only once created
     */
    this(DataStream sourceStream, bool freeOnClose = true, bool readOnly = false)
    {
        this(null /+name+/, sourceStream, freeOnClose, readOnly);
    }

    /** Create a named stream which pre-buffers the contents of 
     another stream.
     @remarks
     This constructor can be used to intentionally read in the entire
     contents of another stream, copying them to the internal buffer
     and thus making them available in memory as a single unit.
     @param name The name to give the stream
     @param sourceStream Another DataStream which will provide the source
     of data
     @param freeOnClose If true, the memory associated will be destroyed
     when the stream is destroyed.
     @param readOnly Whether to make the stream on this memory read-only once created
     */
    this(string name, DataStream sourceStream, bool freeOnClose = true, bool readOnly = false)
    {
        super(name, (readOnly ? AccessMode.READ : (AccessMode.READ | AccessMode.WRITE)));
        // Copy data from incoming stream
        mSize = sourceStream.size();
        if (mSize == 0 && !sourceStream.eof())
        {
            // size of source is unknown, read all of it into memory
            mData = cast(ubyte[])sourceStream.getAsString();
            mEnd = mSize = mData.length;
            mPos = 0;//mData;
        }
        else
        {
            mData = new ubyte[mSize];
            mPos = 0;//mData;
            //mEnd = mData + sourceStream.read(mData, mSize);
            auto nr = sourceStream.read(mData, mSize);
            mEnd = mData.length = nr;
            mFreeOnClose = freeOnClose;
        }
        //GC.clrAttr(mData.ptr, GC.BlkAttr.NO_SCAN);
        //assert(mEnd >= mPos);
        assert(mData.length > 0);
    }

    /** Create a named stream which pre-buffers the contents of 
     another stream.
     @remarks
     This constructor can be used to intentionally read in the entire
     contents of another stream, copying them to the internal buffer
     and thus making them available in memory as a single unit.
     @param name The name to give the stream
     @param sourceStream Another DataStream which will provide the source
     of data
     @param freeOnClose If true, the memory associated will be destroyed
     when the stream is destroyed.
     @param readOnly Whether to make the stream on this memory read-only once created
     */
    /*this(string name, ref DataStreamPtr sourceStream, 
     bool freeOnClose = true, bool readOnly = false)
     {
     this(name, sourceStream.get(), freeOnClose, readOnly);
     }*/

    /** Create a stream with a brand new empty memory chunk.
     @param size The size of the memory chunk to create in bytes
     @param freeOnClose If true, the memory associated will be destroyed
     when the stream is destroyed.
     @param readOnly Whether to make the stream on this memory read-only once created
     */
    this(size_t size, bool freeOnClose = true, bool readOnly = false)
    {
        this(null, size, freeOnClose, readOnly);
    }
    /** Create a named stream with a brand new empty memory chunk.
     @param name The name to give the stream
     @param size The size of the memory chunk to create in bytes
     @param freeOnClose If true, the memory associated will be destroyed
     when the stream is destroyed.
     @param readOnly Whether to make the stream on this memory read-only once created
     */
    this(string name, size_t size, bool freeOnClose = true, bool readOnly = false)
    {
        assert(size > 0);
        super(name, (readOnly ? AccessMode.READ : (AccessMode.READ | AccessMode.WRITE)));
        mSize = size;
        mFreeOnClose = freeOnClose;
        mData = new ubyte[size];
        //mPos = mData;
        //mEnd = mData + mSize;
        //assert(mEnd >= mPos);
    }

    ~this()
    {
        close();
    }

    /** Get a pointer to the start of the memory block this stream holds. */
    ubyte* getPtr() { return mData.ptr; }
    
    /** Get a pointer to the current position in the memory block this stream holds. */
    ubyte* getCurrentPtr() { return mData.ptr + mPos; }
    
    ubyte[] getData()
    {
        return mData;
    }
    
    /** @copydoc DataStream::read
     */
    override size_t read(ref ubyte[] buf, size_t count)
    {
        size_t cnt = count;

        // Read over end of memory?
        if (mPos + cnt > mEnd)
            cnt = mEnd - mPos;
        if (cnt == 0)
            return 0;

        assert (cnt<=count, "cnt<=count");

        //memcpy(buf, mPos, cnt);
        //buf ~= mData[mPos..mPos+cnt];
        if(buf.length)
        {
            buf.length = cnt;
            buf[0..cnt] = mData[mPos..mPos+cnt];
        }
        else//dynamic array, just append
            buf ~= mData[mPos..mPos+cnt];

        mPos += cnt;
        return cnt;
    }

    /** @copydoc DataStream::write
     * @todo Use memcpy ?
     */
    override size_t write(ubyte[] buf, size_t count)
    {
        size_t written = 0, endwritten = 0;
        if (isWriteable())
        {
            endwritten = written = count;
            // we only allow writing within the extents of allocated memory
            // check for buffer overrun & disallow
            if (mPos + written > mData.length)
            {
                if(!mIsDynamic)
                {
                    endwritten = written = mData.length - mPos;
                }
                else
                {
                    //FIXME bit of wtf-ery
                    mData.length += (mPos + written) - mData.length;
                    endwritten = mData.length - mEnd;
                }
            }
            if (written == 0)
                return 0;
            
            //memcpy(mPos, buf, written);
            //foreach(i; 0..written)
            //    mData[i + mPos] = buf[i];
            mData[mPos..mPos+written] = buf[0..written];

            mPos += written;
            mEnd += endwritten;
        }
        return written;
    }

    // bizarre
    override size_t write(string buf)
    {
        return super.write(buf);
    }

    alias DataStream.readLine readLine;

    /** @copydoc DataStream::readLine
     * @note If you are using dynamic array (ubyte[] buf;) then pass
     * some random maximum value as maxCount or use new buf.
     */
    override size_t readLine(ref ubyte[] buf, size_t maxCount,string delim = "\n")
    {
        // Deal with both Unix & Windows LFs
        bool trimCR = false;
        if (delim.indexOf('\n') != -1)
        {
            trimCR = true;
        }
        
        size_t pos = 0;

        maxCount = std.algorithm.min(maxCount, mEnd - mPos);
        if(maxCount == 0)
        {
            maxCount = mEnd - mPos; // dynamic array was passed,so read as much as possible
            buf.length = 0; //probably reusing buffer too, cull it
        }
        
        ptrdiff_t p = mEnd; // read to end or until delim
        
        p = std.algorithm.countUntil(mData[mPos..mPos+maxCount], delim);
        
        if(p == -1)
            p = mEnd;//- mPos; //TODO
        
        buf.length = p;
        buf[0..p] = mData[mPos..mPos+p];
        pos = p;
        
        mPos += std.algorithm.min(pos + delim.length, mEnd - mPos); // simulate reading

        return pos;
    }
    
    /** @copydoc DataStream::skipLine
     */
    override size_t skipLine(string delim = "\n")
    {
        ptrdiff_t pos = 0;

        // Make sure pos can never go past the end of the data 
        /*while (mPos < mEnd)
         {
             ++pos;
             if (delim.find(*mPos++) != String::npos)
             {
                 // Found terminator, break out
                 break;
             }
         }*/
        
        pos = std.algorithm.countUntil(mData[mPos..$], delim);
        if(pos != -1)
        {
            mPos += pos + delim.length;
        }
        else
        {
            pos = mEnd - mPos;
            mPos = mEnd;
        }
        
        return pos;

    }

    /** @copydoc DataStream::skip
     */
    override void skip(long count)
    {
        size_t newpos = cast(size_t)(mPos + count);
        assert( newpos <= mEnd /+mData.length+/, to!string(newpos)~" <= "~to!string(mEnd) );

        mPos = newpos;
    }

    /** @copydoc DataStream::seek
     */
    override void seek( ulong pos )
    {
        assert( pos <= mEnd /+mData.length+/ ); //size() returns mSize but mEnd is just written data
        mPos = cast(size_t)pos;                                 // legally pos could go til mData.length
    }
    
    /** @copydoc DataStream::tell
     */
    override ulong tell()
    {
        return mPos;
    }

    /** @copydoc DataStream::eof
     */
    override bool eof()
    {
        return mPos >= mEnd;//mData.length;
    }

    /** @copydoc DataStream::close
     */
    override void close()
    {
        if (mFreeOnClose && mData)
        {
            
            //delete mData; //core.exception.InvalidMemoryOperationError?
            //mData = 0;
        }
    }
    
    /** @copydoc DataStream::close
     */
    alias DataStream.size size;
    override size_t size() @property { return mData.length; }
    
    /** Sets whether or not to free the encapsulated memory on close. */
    void setFreeOnClose(bool free) { mFreeOnClose = free; }
}

/** Common subclass of DataStream for handling data from C-style file 
 handles.
 @remarks
 Use of this class is generally discouraged; if you want to wrap file
 access in a DataStream, you should definitely be using the C++ friendly
 FileStreamDataStream. However, since there are quite a few applications
 and libraries still wedded to the old FILE handle access, this stream
 wrapper provides some backwards compatibility.
 @todo tmpfile() returns shared(_iobuf*). Make it a File.
 */
class FileHandleDataStream : DataStream
{
protected:
    File mFileHandle;
public:
    alias DataStream.read read;
    alias DataStream.write write;

    //FIXME Check if opened/readable/created/writable
    this(string name, AccessMode accessMode = AccessMode.READ)
    {
        if(accessMode == AccessMode.READ)
        {
            auto f = File(name, "rb");
            this(name, f, accessMode);
        }
        else if(accessMode == AccessMode.WRITE)
        {
            auto f = File(name, "wb");
            this(name, f, accessMode);
        }
        else
        {
            auto f = File(name, "rwb");
            this(name, f, accessMode);
        }
    }
    /// Create stream from a C file handle
    this(ref File handle, AccessMode accessMode = AccessMode.READ)
    {
        this(null, handle, accessMode);
    }
    /// Create named stream from a C file handle
    this(string name, ref File handle, AccessMode accessMode = AccessMode.READ)
    {
        super(accessMode);
        mName = name;
        mFileHandle = handle;
        
        if(handle.name() !is null)
            mSize = cast(size_t)std.file.getSize(handle.name()); //std.file.FileException
        else
        {
            // Determine size
            mFileHandle.seek(0, SEEK_END);
            mSize = cast(size_t)mFileHandle.tell();
            mFileHandle.seek(0, SEEK_SET);
        }
    }
    ~this()
    {
        close();
    }

    /** @copydoc DataStream::read
     */
    override size_t read(ref ubyte[] buf, size_t count)
    {
        buf.length = count;
        buf = mFileHandle.rawRead(buf);
        return buf.length;
    }

    alias DataStream.readLine readLine;

    /** @copydoc DataStream::write
     * @note count is ignored.
     */
    override size_t write(ubyte[] buf, size_t count = 0)
    {
        if (!isWriteable())
            return 0;

        try
        {
            mFileHandle.rawWrite(buf);
        }
        catch
        {
            return 0;
        }
        
        return buf.length;
    }

    
    void writeln(S...)(S args)
    {
        mFileHandle.writeln(args);
    }

    /** @copydoc DataStream::skip
     */
    override void skip(long count)
    {
        mFileHandle.seek(count, SEEK_CUR);
    }

    /** @copydoc DataStream::seek
     */
    override void seek( ulong pos )
    {
        mFileHandle.seek(pos, SEEK_SET);
    }

    /** @copydoc DataStream::tell
     */
    override ulong tell()
    {
        return mFileHandle.tell();
    }

    /** @copydoc DataStream::eof
     */
    override bool eof()
    {
        return mFileHandle.eof();
    }

    /** @copydoc DataStream::close
     */
    override void close()
    {
        //if(mFileHandle.isOpen())
        {
            mFileHandle.close();
        }
    }

    // bizarre
    override size_t write(string buf)
    {
        return super.write(buf);
    }
}

/** Shared pointer to allow data streams to be passed around without
 worrying about deallocation
 */
/*
 /// List of DataStream items
 typedef list<DataStreamPtr>::type DataStreamList;
 /// Shared pointer to list of DataStream items
 typedef SharedPtr<DataStreamList> DataStreamListPtr;
 */

/** Shared pointer to allow memory data streams to be passed around without
 worrying about deallocation
 */
//typedef SharedPtr<MemoryDataStream> MemoryDataStreamPtr;

//NO //alias SharedPtr!MemoryDataStream MemoryDataStreamPtr;
//NO //alias SharedPtr!FileHandleDataStream FileHandleDataStreamPtr;
//NO //alias SharedPtr!DataStream DataStreamPtr;

//No point in sharedptr probably
alias MemoryDataStream MemoryDataStreamPtr;
alias FileHandleDataStream FileHandleDataStreamPtr;
alias DataStream DataStreamPtr;

alias DataStream[] DataStreamList;


/** @} */
/** @} */

unittest
{

    
    auto mem = new MemoryDataStream(4096, true, false);
    ubyte[] data = cast(ubyte[])"AAAA\nBBBBBB\nC\nDDDDD\n\n";
    mem.write(data, data.length);
    mem.seek(0);
    
    ubyte[] buf;
    auto nr = mem.readLine(buf, 0);
    assert(buf == ['A','A','A','A']);
    
    assert(mem.getLine() == "BBBBBB");
    mem.skipLine();
    
    string s = mem.readLine();
    assert(s == "DDDDD");
    
    assert(mem.getLine() == "");
    assert(mem.getLine() is null); // null should be possible to be used as eof().
    
    /*buf.length = 0;

     auto fh = File("test.txt", "r");
     auto file = new FileHandleDataStream(fh, DataStream.AccessMode.READ);
     nr = file.readLine(buf, 0);
     writeln(cast(string)buf, nr);
     file.skipLine();
     writeln(file.getLine());
     writeln(file.getLine());
     
     auto l = "";
     while(l !is null)
     writeln("-->", (l = file.getLine()) );
     */
}