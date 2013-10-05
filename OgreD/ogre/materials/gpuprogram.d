module ogre.materials.gpuprogram;

private
{
    import std.range;
    import core.sync.mutex;
    //import std.container;
    import std.algorithm;
    import core.stdc.string : memcpy;
}

public import ogre.sharedptr;
import ogre.compat;
import ogre.general.colourvalue;
import ogre.resources.datastream;
import ogre.exception;
import ogre.general.log;
import ogre.general.generals;
import ogre.math.matrix;
import ogre.math.vector;
import ogre.singleton;
import ogre.resources.highlevelgpuprogram;
import ogre.compat;
import ogre.rendersystem.rendersystem;
import ogre.general.root;
import ogre.general.common;
import ogre.resources.resource;
import ogre.resources.resourcemanager;
import ogre.materials.autoparamdatasource;
import ogre.materials.pass;
import ogre.math.dualquaternion;
import ogre.math.maths;
import ogre.resources.resourcegroupmanager;
import ogre.general.serializer;


/** \addtogroup Core
 *  @{
 */
/** \addtogroup Materials
 *  @{
 */
/** Enumeration of the types of constant we may encounter in programs. 
 @note Low-level programs, by definition, will always use either
 float4 or int4 constant types since that is the fundamental underlying
 type in assembler.
 */
enum GpuConstantType
{
    GCT_FLOAT1 = 1,
    GCT_FLOAT2 = 2,
    GCT_FLOAT3 = 3,
    GCT_FLOAT4 = 4,
    GCT_SAMPLER1D = 5,
    GCT_SAMPLER2D = 6,
    GCT_SAMPLER3D = 7,
    GCT_SAMPLERCUBE = 8,
    GCT_SAMPLERRECT = 9,
    GCT_SAMPLER1DSHADOW = 10,
    GCT_SAMPLER2DSHADOW = 11,
    GCT_SAMPLER2DARRAY = 12,
    GCT_MATRIX_2X2 = 13,
    GCT_MATRIX_2X3 = 14,
    GCT_MATRIX_2X4 = 15,
    GCT_MATRIX_3X2 = 16,
    GCT_MATRIX_3X3 = 17,
    GCT_MATRIX_3X4 = 18,
    GCT_MATRIX_4X2 = 19,
    GCT_MATRIX_4X3 = 20,
    GCT_MATRIX_4X4 = 21,
    GCT_INT1 = 22,
    GCT_INT2 = 23,
    GCT_INT3 = 24,
    GCT_INT4 = 25,
    GCT_SUBROUTINE = 26,
    GCT_DOUBLE1 = 27,
    GCT_DOUBLE2 = 28,
    GCT_DOUBLE3 = 29,
    GCT_DOUBLE4 = 30,
    GCT_MATRIX_DOUBLE_2X2 = 31,
    GCT_MATRIX_DOUBLE_2X3 = 32,
    GCT_MATRIX_DOUBLE_2X4 = 33,
    GCT_MATRIX_DOUBLE_3X2 = 34,
    GCT_MATRIX_DOUBLE_3X3 = 35,
    GCT_MATRIX_DOUBLE_3X4 = 36,
    GCT_MATRIX_DOUBLE_4X2 = 37,
    GCT_MATRIX_DOUBLE_4X3 = 38,
    GCT_MATRIX_DOUBLE_4X4 = 39,
    GCT_UNKNOWN = 99
}

/** The variability of a GPU parameter, as derived from auto-params targeting it.
 These values must be powers of two since they are used in masks.
 */
enum GpuParamVariability
{
    /// No variation except by manual setting - the default
    GPV_GLOBAL = 1, 
    /// Varies per object (based on an auto param usually), but not per light setup
    GPV_PER_OBJECT = 2, 
    /// Varies with light setup
    GPV_LIGHTS = 4, 
    /// Varies with pass iteration number
    GPV_PASS_ITERATION_NUMBER = 8,
    
    
    /// Full mask (16-bit)
    GPV_ALL = 0xFFFF
    
}

/** Information about predefined programants. 
 @note Only available for high-level programs but is referenced generically
 by GpuProgramParameters.
 */
struct GpuConstantDefinition
{
    /// Data type
    GpuConstantType constType = GpuConstantType.GCT_UNKNOWN;
    /// Physical start index in buffer (either float or int buffer)
    size_t physicalIndex = size_t.max;
    /// Logical index - used to communicate this constant to the rendersystem
    size_t logicalIndex;
    /** Number of raw buffer slots per element 
     (some programs pack each array element to float4, some do not) */
    size_t elementSize;
    /// Length of array
    size_t arraySize = 1;
    /// How this parameter varies (bitwise combination of GpuProgramVariability)
    //mutable 
    ushort variability = GpuParamVariability.GPV_GLOBAL;
    
    bool isFloat()
    {
        return isFloat(constType);
    }
    
    static bool isFloat(GpuConstantType c)
    {
        switch(c)
        {
            case GpuConstantType.GCT_INT1:
            case GpuConstantType.GCT_INT2:
            case GpuConstantType.GCT_INT3:
            case GpuConstantType.GCT_INT4:
            case GpuConstantType.GCT_SAMPLER1D:
            case GpuConstantType.GCT_SAMPLER2D:
            case GpuConstantType.GCT_SAMPLER2DARRAY:
            case GpuConstantType.GCT_SAMPLER3D:
            case GpuConstantType.GCT_SAMPLERCUBE:
            case GpuConstantType.GCT_SAMPLER1DSHADOW:
            case GpuConstantType.GCT_SAMPLER2DSHADOW:
                return false;
            default:
                return true;
        }
        
    }
    
    bool isDouble() const
    {
        return isDouble(constType);
    }
    
    static bool isDouble(GpuConstantType c)
    {
        switch(c)
        {
            case GpuConstantType.GCT_INT1:
            case GpuConstantType.GCT_INT2:
            case GpuConstantType.GCT_INT3:
            case GpuConstantType.GCT_INT4:
            case GpuConstantType.GCT_FLOAT1:
            case GpuConstantType.GCT_FLOAT2:
            case GpuConstantType.GCT_FLOAT3:
            case GpuConstantType.GCT_FLOAT4:
            case GpuConstantType.GCT_SAMPLER1D:
            case GpuConstantType.GCT_SAMPLER2D:
            case GpuConstantType.GCT_SAMPLER2DARRAY:
            case GpuConstantType.GCT_SAMPLER3D:
            case GpuConstantType.GCT_SAMPLERCUBE:
            case GpuConstantType.GCT_SAMPLER1DSHADOW:
            case GpuConstantType.GCT_SAMPLER2DSHADOW:
                return false;
            default:
                return true;
        }
        
    }
    
    bool isSampler()
    {
        return isSampler(constType);
    }
    
    static bool isSampler(GpuConstantType c)
    {
        switch(c)
        {
            case GpuConstantType.GCT_SAMPLER1D:
            case GpuConstantType.GCT_SAMPLER2D:
            case GpuConstantType.GCT_SAMPLER2DARRAY:
            case GpuConstantType.GCT_SAMPLER3D:
            case GpuConstantType.GCT_SAMPLERCUBE:
            case GpuConstantType.GCT_SAMPLER1DSHADOW:
            case GpuConstantType.GCT_SAMPLER2DSHADOW:
                return true;
            default:
                return false;
        }
        
    }
    
    bool isSubroutine()
    {
        return isSubroutine(constType);
    }
    
    static bool isSubroutine(GpuConstantType c)
    {
        return c == GpuConstantType.GCT_SUBROUTINE;
    }
    
    /** Get the element size of a given type, including whether to pad the 
     elements into multiples of 4 (e.g. SM1 and D3D does, GLSL doesn't)
     */
    static size_t getElementSize(GpuConstantType ctype, bool padToMultiplesOf4)
    {
        if (padToMultiplesOf4)
        {
            switch(ctype)
            {
                case GpuConstantType.GCT_FLOAT1:
                case GpuConstantType.GCT_INT1:
                case GpuConstantType.GCT_SAMPLER1D:
                case GpuConstantType.GCT_SAMPLER2D:
                case GpuConstantType.GCT_SAMPLER2DARRAY:
                case GpuConstantType.GCT_SAMPLER3D:
                case GpuConstantType.GCT_SAMPLERCUBE:
                case GpuConstantType.GCT_SAMPLER1DSHADOW:
                case GpuConstantType.GCT_SAMPLER2DSHADOW:
                case GpuConstantType.GCT_FLOAT2:
                case GpuConstantType.GCT_INT2:
                case GpuConstantType.GCT_FLOAT3:
                case GpuConstantType.GCT_INT3:
                case GpuConstantType.GCT_FLOAT4:
                case GpuConstantType.GCT_INT4:
                    return 4;
                case GpuConstantType.GCT_MATRIX_2X2:
                case GpuConstantType.GCT_MATRIX_2X3:
                case GpuConstantType.GCT_MATRIX_2X4:
                case GpuConstantType.GCT_DOUBLE1:
                case GpuConstantType.GCT_DOUBLE2:
                case GpuConstantType.GCT_DOUBLE3:
                case GpuConstantType.GCT_DOUBLE4:
                    return 8; // 2 float4s
                case GpuConstantType.GCT_MATRIX_3X2:
                case GpuConstantType.GCT_MATRIX_3X3:
                case GpuConstantType.GCT_MATRIX_3X4:
                    return 12; // 3 float4s
                case GpuConstantType.GCT_MATRIX_4X2:
                case GpuConstantType.GCT_MATRIX_4X3:
                case GpuConstantType.GCT_MATRIX_4X4:
                case GpuConstantType.GCT_MATRIX_DOUBLE_2X2:
                case GpuConstantType.GCT_MATRIX_DOUBLE_2X3:
                case GpuConstantType.GCT_MATRIX_DOUBLE_2X4:
                    return 16; // 4 float4s
                case GpuConstantType.GCT_MATRIX_DOUBLE_3X2:
                case GpuConstantType.GCT_MATRIX_DOUBLE_3X3:
                case GpuConstantType.GCT_MATRIX_DOUBLE_3X4:
                    return 24;
                case GpuConstantType.GCT_MATRIX_DOUBLE_4X2:
                case GpuConstantType.GCT_MATRIX_DOUBLE_4X3:
                case GpuConstantType.GCT_MATRIX_DOUBLE_4X4:
                    return 32;
                default:
                    return 4;
            }
        }
        else
        {
            switch(ctype)
            {
                case GpuConstantType.GCT_FLOAT1:
                case GpuConstantType.GCT_DOUBLE1:
                case GpuConstantType.GCT_INT1:
                case GpuConstantType.GCT_SAMPLER1D:
                case GpuConstantType.GCT_SAMPLER2D:
                case GpuConstantType.GCT_SAMPLER2DARRAY:
                case GpuConstantType.GCT_SAMPLER3D:
                case GpuConstantType.GCT_SAMPLERCUBE:
                case GpuConstantType.GCT_SAMPLER1DSHADOW:
                case GpuConstantType.GCT_SAMPLER2DSHADOW:
                    return 1;
                case GpuConstantType.GCT_FLOAT2:
                case GpuConstantType.GCT_DOUBLE2:
                case GpuConstantType.GCT_INT2:
                    return 2;
                case GpuConstantType.GCT_FLOAT3:
                case GpuConstantType.GCT_DOUBLE3:
                case GpuConstantType.GCT_INT3:
                    return 3;
                case GpuConstantType.GCT_FLOAT4:
                case GpuConstantType.GCT_DOUBLE4:
                case GpuConstantType.GCT_INT4:
                    return 4;
                case GpuConstantType.GCT_MATRIX_2X2:
                case GpuConstantType.GCT_MATRIX_DOUBLE_2X2:
                    return 4;
                case GpuConstantType.GCT_MATRIX_2X3:
                case GpuConstantType.GCT_MATRIX_3X2:
                case GpuConstantType.GCT_MATRIX_DOUBLE_2X3:
                case GpuConstantType.GCT_MATRIX_DOUBLE_3X2:
                    return 6;
                case GpuConstantType.GCT_MATRIX_2X4:
                case GpuConstantType.GCT_MATRIX_4X2:
                case GpuConstantType.GCT_MATRIX_DOUBLE_2X4:
                case GpuConstantType.GCT_MATRIX_DOUBLE_4X2:
                    return 8; 
                case GpuConstantType.GCT_MATRIX_3X3:
                case GpuConstantType.GCT_MATRIX_DOUBLE_3X3:
                    return 9;
                case GpuConstantType.GCT_MATRIX_3X4:
                case GpuConstantType.GCT_MATRIX_4X3:
                case GpuConstantType.GCT_MATRIX_DOUBLE_3X4:
                case GpuConstantType.GCT_MATRIX_DOUBLE_4X3:
                    return 12; 
                case GpuConstantType.GCT_MATRIX_4X4:
                case GpuConstantType.GCT_MATRIX_DOUBLE_4X4:
                    return 16; 
                default:
                    return 4;
            }
            
        }
    }
    
    /*this()
     {
     constType = GpuConstantType.GCT_UNKNOWN;
     physicalIndex = size_t.max;
     logicalIndex = 0;
     elementSize = 0;
     arraySize = 1;
     variability = GpuConstantType.GPV_GLOBAL;
     }*/
}
//typedef map<string, GpuConstantDefinition>.type GpuConstantDefinitionMap;
//typedef ConstMapIterator<GpuConstantDefinitionMap> GpuConstantDefinitionIterator;
//TODO Make GpuConstantDefinition a pointer type?
alias GpuConstantDefinition[string] GpuConstantDefinitionMap;

/// Struct collecting together the information for named constants.
struct GpuNamedConstants// : GpuParamsAlloc
{
    /// Total size of the float buffer required
    size_t floatBufferSize;
    /// Total size of the double buffer required
    size_t doubleBufferSize;
    /// Total size of the int buffer required
    size_t intBufferSize;
    /// Map of parameter names to GpuConstantDefinition
    GpuConstantDefinitionMap map;
    
    size_t calculateSize() //const
    {
        size_t memSize = 0;
        
        // Buffer size refs
        memSize += 3 * size_t.sizeof;
        
        // Tally up constant defs
        memSize += GpuConstantDefinition.sizeof * map.length;
        
        return memSize;
    }
    
    //this() : floatBufferSize(0), intBufferSize(0) {}
    
    /** Generate additional constant entries for arrays based on a base definition.
     @remarks
     Array uniforms will be added just with their base name with no array
     suffix. This method will add named entries for array suffixes too
     so individual array entries can be addressed. Note that we only 
     individually index array elements if the array size is up to 16
     entries in size. Anything larger than that only gets a [0] entry
     as well as the main entry, to save cluttering up the name map. After
     all, you can address the larger arrays in a bulk fashion much more
     easily anyway. 
     */
    void generateConstantDefinitionArrayEntries(string paramName, 
                                                ref GpuConstantDefinition baseDef)
    {
        //TODO Copy definition for use with arrays
        GpuConstantDefinition arrayDef = baseDef;//.save();
        arrayDef.arraySize = 1;
        string arrayName;
        
        // Add parameters for array accessors
        // [0] will ref er to the same location, [1+] will increment
        // only populate others individually up to 16 array slots so as not to get out of hand,
        // unless the system has been explicitly configured to allow all the parameters to be added
        
        // paramName[0] version will always exist 
        size_t maxArrayIndex = 1;
        if (baseDef.arraySize <= 16 || msGenerateAllConstantDefinitionArrayEntries)
            maxArrayIndex = baseDef.arraySize;
        
        foreach (i; 0..maxArrayIndex)
        {
            arrayName = paramName ~ "[" ~ std.conv.to!string(i) ~ "]";
            map[arrayName] = arrayDef;
            // increment location
            arrayDef.physicalIndex += arrayDef.elementSize;
        }
        // note no increment of buffer sizes since this is shared with main array def
        
    }
    
    /// Indicates whether all array entries will be generated and added to the definitions map
    static bool getGenerateAllConstantDefinitionArrayEntries()
    {
        return msGenerateAllConstantDefinitionArrayEntries;
    }
    
    /** Sets whether all array entries will be generated and added to the definitions map.
     @remarks
     Usually, array entries can only be individually indexed if they're up to 16 entries long,
     to save memory - arrays larger than that can be set but only via the bulk setting
     methods. This option allows you to choose to individually index every array entry. 
     */
    static void setGenerateAllConstantDefinitionArrayEntries(bool generateAll)
    {
        msGenerateAllConstantDefinitionArrayEntries = generateAll;
    }
    
    /** Saves constant definitions to a file, compatible with GpuProgram.setManualNamedConstantsFile. 
     @see GpuProgram.setManualNamedConstantsFile
     */
    void save(string filename)
    {
        GpuNamedConstantsSerializer ser;
        ser.exportNamedConstants(this, filename);
    }
    /** Loads constant definitions from a stream, compatible with GpuProgram.setManualNamedConstantsFile. 
     @see GpuProgram.setManualNamedConstantsFile
     */
    void load(ref DataStream stream)
    {
        GpuNamedConstantsSerializer ser;
        ser.importNamedConstants(stream, this);
    }
    
protected:
    /** Indicates whether all array entries will be generated and added to the definitions map
     @remarks
     Normally, the number of array entries added to the definitions map is capped at 16
     to save memory. Setting this value to <code>true</code> allows all of the entries
     to be generated and added to the map.
     */
    static bool msGenerateAllConstantDefinitionArrayEntries;
}
//alias SharedPtr!(GpuNamedConstants*) GpuNamedConstantsPtr;

/// Simple class for loading / saving GpuNamedConstants
class GpuNamedConstantsSerializer : Serializer
{
public:
    this()
    {
        mVersion = "[v1.0]";
    }
    ~this() {}
    
    void exportNamedConstants(ref GpuNamedConstants pConsts, string filename,
                              Endian endianMode = Endian.ENDIAN_NATIVE)
    {
        DataStream stream = new FileHandleDataStream(filename, DataStream.AccessMode.WRITE);
        
        exportNamedConstants(pConsts, stream, endianMode);
        
        stream.close();
    }

    void exportNamedConstants(ref GpuNamedConstants pConsts, ref DataStream stream,
                              Endian endianMode = Endian.ENDIAN_NATIVE)
    {
        // Decide on endian mode
        determineEndianness(endianMode);
        
        string msg;
        mStream =stream;
        if (!stream.isWriteable())
        {
            //OGRE_EXCEPT(Exception.ERR_CANNOT_WRITE_TO_FILE,
            throw new FileNotFoundError(
                "Unable to write to stream " ~ stream.getName(),
                "GpuNamedConstantsSerializer.exportSkeleton");
        }
        
        writeFileHeader();
        
        writeInts((cast(uint*)&pConsts.floatBufferSize), 1);
        writeInts((cast(uint*)&pConsts.intBufferSize), 1);
        
        // simple export of all the named constants, no chunks
        // name, physical index
        foreach (name, def; pConsts.map)
        {
            writeString(name);
            writeInts((cast(uint*)&def.physicalIndex), 1);
            writeInts((cast(uint*)&def.logicalIndex), 1);
            uint constType = cast(uint)(def.constType);
            writeInts(&constType, 1);
            writeInts((cast(uint*)&def.elementSize), 1);
            writeInts((cast(uint*)&def.arraySize), 1);
        }
        
    }
    void importNamedConstants(ref DataStream stream, ref GpuNamedConstants pDest)
    {
        // Determine endianness (must be the first thing we do!)
        determineEndianness(stream);
        
        // Check header
        readFileHeader(stream);
        
        // simple file structure, no chunks
        pDest.map.clear();
        
        readInts(stream, (cast(uint*)&pDest.floatBufferSize), 1);
        readInts(stream, (cast(uint*)&pDest.intBufferSize), 1);
        
        while (!stream.eof())
        {
            GpuConstantDefinition def;
            string name = readString(stream);
            // Hmm, deal with trailing information
            if (name is null)
                continue;
            readInts(stream, (cast(uint*)&def.physicalIndex), 1);
            readInts(stream, (cast(uint*)&def.logicalIndex), 1);
            uint constType;
            readInts(stream, &constType, 1);
            def.constType = cast(GpuConstantType)(constType);
            readInts(stream, (cast(uint*)&def.elementSize), 1);
            readInts(stream, (cast(uint*)&def.arraySize), 1);
            
            pDest.map[name] = def;
            
        }
    }
}

/** Structure recording the use of a physical buffer by a logical parameter
 index. Only used for low-level programs.
 */
struct GpuLogicalIndexUse
{
    /// Physical buffer index
    size_t physicalIndex = 99999;
    /// Current physical size allocation
    size_t currentSize = 0;
    /// How the contents of this slot vary
    //mutable 
    ushort variability = GpuParamVariability.GPV_GLOBAL;
    
    /*this() 
     {
     physicalIndex = 99999;
     currentSize = 0;
     variability =  GpuParamVariability.GPV_GLOBAL;
     }*/
    this(size_t bufIdx, size_t curSz, ushort v) 
    {
        physicalIndex = bufIdx;
        currentSize = curSz;
        variability = v;
    }
}
//typedef map<size_t, GpuLogicalIndexUse>.type GpuLogicalIndexUseMap;
alias GpuLogicalIndexUse[size_t] GpuLogicalIndexUseMap;
/// Container struct to allow params to safely & update shared list of logical buffer assignments
//struct 
class GpuLogicalBufferStruct //: GpuParamsAlloc
{
    //OGRE_MUTEX(mutex)
    Mutex mLock;
    /// Map from logical index to physical buffer location
    GpuLogicalIndexUseMap map;
    /// Shortcut to know the buffer size needs
    size_t bufferSize = 0;
    this() { mLock = new Mutex; }
    this( int bs = 0 ) { bufferSize = bs; mLock = new Mutex; }
}

//alias SharedPtr!GpuLogicalBufferStruct GpuLogicalBufferStructPtr;

/** Definition of container that holds the current float constants.
 @note Not necessarily in direct index order to constant indexes, logical
 to physical index map is derived from GpuProgram
 */
//typedef vector<float>.type FloatConstantList;
alias float[] FloatConstantList;

/** Definition of container that holds the current double constants.
     @note Not necessarily in direct index order to constant indexes, logical
     to physical index map is derived from GpuProgram
     */
alias double[] DoubleConstantList;
/** Definition of container that holds the current float constants.
 @note Not necessarily in direct index order to constant indexes, logical
 to physical index map is derived from GpuProgram
 */
//typedef vector<int>.type IntConstantList;
alias int[] IntConstantList;

/** A group of manually updated parameters that are shared between many parameter sets.
 @remarks
 Sometimes you want to set some common parameters across many otherwise 
 different parameter sets, and keep them all in sync together. This class
 allows you to define a set of parameters that you can share across many
 parameter sets and have the parameters that match automatically be pulled
 from the shared set, rather than you having to set them on all the parameter
 sets individually.
 @par
 Parameters in a shared set are matched up with instances in a GpuProgramParameters
 structure by matching names. It is up to you to define the named parameters
 that a shared set contains, and ensuring the definition matches.
 @note
 Shared parameter sets can be named, and looked up using the GpuProgramManager.
 */
class GpuSharedParameters //: GpuParamsAlloc
{
protected:
    GpuNamedConstants mNamedConstants;
    FloatConstantList mFloatConstants;
    DoubleConstantList mDoubleConstants;
    IntConstantList mIntConstants;
    string mName;
    
    // Optional data the rendersystem might want to store
    //mutable 
    Any mRenderSystemData;
    
    /// Not used when copying data, but might be useful to RS using shared buffers
    size_t mFrameLastUpdated;
    
    /// Version number of the definitions in this buffer
    ulong mVersion; 
    
public:
    this(string name)
    {
        mName = name;
        //TODO ulong cast to size_t , 32 bit gonna get reamed
        mFrameLastUpdated = cast(size_t)Root.getSingleton().getNextFrameNumber();
        mVersion = 0;
    }
    
    ~this() {}
    
    size_t calculateSize() const
    {
        size_t memSize = 0;
        
        memSize += float.sizeof * mFloatConstants.length;
        memSize += double.sizeof * mDoubleConstants.length;
        memSize += int.sizeof * mIntConstants.length;
        memSize += mName.length * char.sizeof;
        memSize += Any.sizeof;
        memSize += size_t.sizeof;
        memSize += ulong.sizeof;
        
        return memSize;
    }
    
    /// Get the name of this shared parameter set
    string getName() { return mName; }
    
    /** Add a newant definition to this shared set of parameters.
     @remarks
     Unlike GpuProgramParameters, where the parameter list is defined by the
     program being compiled, this shared parameter set is defined by the
     user. Only parameters which have been predefined here may be later
     updated.
     */
    void addConstantDefinition(string name, GpuConstantType constType, size_t arraySize = 1)
    {
        if ((name in mNamedConstants.map) is null)
        {
            throw new InvalidParamsError(
                "Constant entry with name '" ~ name ~ "' already exists. ", 
                "GpuSharedParameters.addConstantDefinition");
        }
        GpuConstantDefinition def;
        def.arraySize = arraySize;
        def.constType = constType;
        // for compatibility we do not pad values to multiples of 4
        // when it comes to arrays, user is responsible for creating matching defs
        def.elementSize = GpuConstantDefinition.getElementSize(constType, false);
        
        // not used
        def.logicalIndex = 0;
        def.variability = cast(ushort) GpuParamVariability.GPV_GLOBAL;
        
        if (def.isFloat())
        {
            def.physicalIndex = mFloatConstants.length;
            mFloatConstants.length = (mFloatConstants.length + def.arraySize * def.elementSize);
        }
        else
        {
            def.physicalIndex = mIntConstants.length;
            mIntConstants.length = (mIntConstants.length + def.arraySize * def.elementSize);
        }
        
        mNamedConstants.map[name] = def;
        
        ++mVersion;
    }
    
    /** Remove a constant definition from this shared set of parameters.
     */
    void removeConstantDefinition(string name)
    {
        auto i = name in mNamedConstants.map;
        if (i !is null)
        {
            GpuConstantDefinition def = *i;
            bool isFloat = def.isFloat();
            size_t numElems = def.elementSize * def.arraySize;
            
            foreach (k, otherDef; mNamedConstants.map)
            {
                bool otherIsFloat = otherDef.isFloat();
                
                // same type, and comes after in the buffer
                if ( ((isFloat && otherIsFloat) || (!isFloat && !otherIsFloat)) && 
                    otherDef.physicalIndex > def.physicalIndex)
                {
                    // adjust index
                    otherDef.physicalIndex -= numElems;
                }
            }
            
            // remove floats and reduce buffer
            if (isFloat)
            {
                mNamedConstants.floatBufferSize -= numElems;
                
                /*FloatConstantList.iterator beg = mFloatConstants.begin();
                 std.advance(beg, def.physicalIndex);
                 FloatConstantList.iterator en = beg;
                 std.advance(en, numElems);
                 mFloatConstants.erase(beg, en);*/
                mFloatConstants.removeFromArrayIdx(def.physicalIndex, def.physicalIndex+numElems);
            }
            else
            {
                mNamedConstants.intBufferSize -= numElems;
                
                /*IntConstantList.iterator beg = mIntConstants.begin();
                 std.advance(beg, def.physicalIndex);
                 IntConstantList.iterator en = beg;
                 std.advance(en, numElems);
                 mIntConstants.erase(beg, en);*/
                mIntConstants.removeFromArrayIdx(def.physicalIndex, def.physicalIndex+numElems);
                
            }
            
            ++mVersion;
            
        }
        
    }
    
    /** Remove a constant definition from this shared set of parameters.
     */
    void removeAllConstantDefinitions()
    {
        mNamedConstants.map.clear();
        mNamedConstants.floatBufferSize = 0;
        mNamedConstants.intBufferSize = 0;
        mFloatConstants.clear();
        mIntConstants.clear();
    }
    
    /** Get the version number of this shared parameter set, can be used to identify when 
     changes have occurred. 
     */
    ulong getVersion(){ return mVersion; }
    
    /** Mark the shared set as being dirty (values modified).
     @remarks
     You do not need to call this yourself, set is marked as dirty whenever
     setNamedConstant or (non) getFloatPointer et al are called.
     */
    void _markDirty()
    {
        //TODO casting size_t to ulong
        mFrameLastUpdated = cast(size_t)Root.getSingleton().getNextFrameNumber();
    }
    
    /// Get the frame in which this shared parameter set was last updated
    size_t getFrameLastUpdated(){ return mFrameLastUpdated; }
    
    /** Gets an iterator over the named GpuConstantDefinition instances as defined
     by the user. 
     */
    //GpuConstantDefinitionIterator getConstantDefinitionIterator();
    ref GpuConstantDefinitionMap getConstantDefinitionMap()
    {
        return mNamedConstants.map;
    }
    
    /** Get a specific GpuConstantDefinition for a named parameter.
     */
    ref GpuConstantDefinition getConstantDefinition(string name)
    {
        auto i = name in mNamedConstants.map;
        if (i is null)
        {
            throw new InvalidParamsError(
                "Constant entry with name '" ~ name ~ "' does not exist. ", 
                "GpuSharedParameters.getConstantDefinition");
        }
        return *i;
    }
    
    /** Get the full list of GpuConstantDefinition instances.
     */
    GpuNamedConstants* getConstantDefinitions()
    {
        return &mNamedConstants;
    }
    
    /** @copydoc GpuProgramParameters.setNamedConstant(string name, Real val) */
    void setNamedConstant(string name, Real val)
    {
        setNamedConstant(name, &val, 1);
    }
    /** @copydoc GpuProgramParameters.setNamedConstant(string name, int val) */
    void setNamedConstant(string name, int val)
    {
        setNamedConstant(name, &val, 1);
    }
    /** @copydoc GpuProgramParameters.setNamedConstant(string name, ref Vector4 vec) */
    void setNamedConstant(string name, ref Vector4 vec)
    {
        setNamedConstant(name, vec.ptr(), 4);
    }
    /** @copydoc GpuProgramParameters.setNamedConstant(string name, ref Vector3 vec) */
    void setNamedConstant(string name, ref Vector3 vec)
    {
        setNamedConstant(name, vec.ptr(), 3);
    }
    /** @copydoc GpuProgramParameters.setNamedConstant(string name, ref Matrix4 m) */
    void setNamedConstant(string name, ref Matrix4 m)
    {
        setNamedConstant(name, m.ptr, 16);
    }
    /** @copydoc GpuProgramParameters.setNamedConstant(string name,Matrix4* m, size_t numEntries) */
    void setNamedConstant(string name,Matrix4* m, size_t numEntries)
    {
        setNamedConstant(name, cast(Real*)&m[0], 16 * numEntries);
    }
    /** @copydoc GpuProgramParameters.setNamedConstant(string name,float *val, size_t count) */
    void setNamedConstant(string name,float *val, size_t count)
    {
        auto i = name in mNamedConstants.map;
        if (i !is null)
        {
            GpuConstantDefinition def = *i;
            memcpy(&mFloatConstants[def.physicalIndex], val, 
                   float.sizeof * std.algorithm.min(count, def.elementSize * def.arraySize));
        }
        
        _markDirty();
        
    }
    /** @copydoc GpuProgramParameters.setNamedConstant(string name,double *val, size_t count) */
    void setNamedConstant(string name,double *val, size_t count)
    {
        auto i = name in mNamedConstants.map;
        if (i !is null)
        {
            GpuConstantDefinition def = *i;
            
            count = std.algorithm.min(count, def.elementSize * def.arraySize);
            double* src = val;
            float* dst = &mFloatConstants[def.physicalIndex];
            for (size_t v = 0; v < count; ++v)
            {
                *dst++ = cast(float)(*src++);
            }
        }
        
        _markDirty();
        
    }
    /** @copydoc GpuProgramParameters.setNamedConstant(string name,ColourValue colour) */
    void setNamedConstant(string name,ColourValue colour)
    {
        setNamedConstant(name, colour.ptr(), 4);
    }
    /** @copydoc GpuProgramParameters.setNamedConstant(string name,int *val, size_t count) */
    void setNamedConstant(string name,int *val, size_t count)
    {
        auto i = name in mNamedConstants.map;
        if (i !is null)
        {
            GpuConstantDefinition def = *i;
            memcpy(&mIntConstants[def.physicalIndex], val, 
                   int.sizeof * std.algorithm.min(count, def.elementSize * def.arraySize));
        }
        
        _markDirty();
        
    }
    
    /// Get a pointer to the 'nth' item in the float buffer
    float* getFloatPointer(size_t pos) { _markDirty(); return &mFloatConstants[pos]; }
    /// Get a pointer to the 'nth' item in the double buffer
    double* getDoublePointer(size_t pos) { _markDirty(); return &mDoubleConstants[pos]; }
    /// Get a pointer to the 'nth' item in the float buffer
    //float* getFloatPointer(size_t pos) const { return &mFloatConstants[pos]; }
    /// Get a pointer to the 'nth' item in the int buffer
    int* getIntPointer(size_t pos) { _markDirty(); return &mIntConstants[pos]; }
    /// Get a pointer to the 'nth' item in the int buffer
    //int* getIntPointer(size_t pos) const { return &mIntConstants[pos]; }
    
    /// Get a reference to the list of float constants
    ref FloatConstantList getFloatConstantList(){ return mFloatConstants; }
    /// Get a reference to the list of int constants
    ref IntConstantList getIntConstantList(){ return mIntConstants; }
    
    /** Internal method that the RenderSystem might use to store optional data. */
    void _setRenderSystemData(Any data){ mRenderSystemData = data; }
    /** Internal method that the RenderSystem might use to store optional data. */
    ref Any _getRenderSystemData(){ return mRenderSystemData; }
    
}

/// Shared pointer used to hold references to GpuProgramParameters instances
//alias SharedPtr!GpuSharedParameters GpuSharedParametersPtr;

/** This class records the usage of a set of shared parameters in a concrete
 set of GpuProgramParameters.
 */
class GpuSharedParametersUsage //: GpuParamsAlloc
{
protected:
    SharedPtr!GpuSharedParameters mSharedParams;
    // Not a shared pointer since this is also parent
    GpuProgramParameters mParams;
    // list of physical mappings that we are going to bring in
    struct CopyDataEntry
    {
        GpuConstantDefinition* srcDefinition;
        GpuConstantDefinition* dstDefinition;
    }
    //typedef vector<CopyDataEntry>.type CopyDataList;
    alias CopyDataEntry[] CopyDataList;
    
    CopyDataList mCopyDataList;
    
    // Optional data the rendersystem might want to store
    //mutable 
    Any mRenderSystemData;
    
    /// Version of shared params we based the copydata on
    ulong mCopyDataVersion;
    
    void initCopyData()
    {
        
        mCopyDataList.clear();
        
        GpuConstantDefinitionMap sharedmap = mSharedParams.get().getConstantDefinitions().map;
        foreach (pName, shareddef; sharedmap)
        {
            GpuConstantDefinition* instdef = mParams._findNamedConstantDefinition(pName, false);
            if (instdef)
            {
                // Check that the definitions are the same 
                if (instdef.constType == shareddef.constType && 
                    instdef.arraySize <= shareddef.arraySize)
                {
                    CopyDataEntry e;
                    e.srcDefinition = &sharedmap[pName];
                    e.dstDefinition = instdef;
                    mCopyDataList.insert(e);
                }
            }
            
        }
        
        mCopyDataVersion = mSharedParams.get().getVersion();
        
    }
    
    
public:
    /// Construct usage
    this(SharedPtr!GpuSharedParameters sharedParams, 
         GpuProgramParameters params)
    {
        mSharedParams = sharedParams;
        mParams = params;
        initCopyData();
    }
    
    /** Update the target parameters by copying the data from the shared
     parameters.
     @note This method  may not actually be called if the RenderSystem
     supports using shared parameters directly in their own shared buffer; in
     which case the values should not be copied out of the shared area
     into the individual parameter set, but bound separately.
     */
    void _copySharedParamsToTargetParams()
    {
        // check copy data version
        if (mCopyDataVersion != mSharedParams.get().getVersion())
            initCopyData();
        
        foreach (CopyDataEntry e; mCopyDataList)
        {            
            if (e.dstDefinition.isFloat())
            {   
                float* pSrc = mSharedParams.get().getFloatPointer(e.srcDefinition.physicalIndex);
                float* pDst = mParams.getFloatPointer(e.dstDefinition.physicalIndex);
                
                // Deal with matrix transposition here!!!
                // transposition is specific to the dest param set, shared params don't do it
                if (mParams.getTransposeMatrices() && e.dstDefinition.constType == GpuConstantType.GCT_MATRIX_4X4)
                {
                    // for each matrix that needs to be transposed and copied,
                    for (size_t iMat = 0; iMat < e.dstDefinition.arraySize; ++iMat)
                    {
                        for (int row = 0; row < 4; ++row)
                            for (int col = 0; col < 4; ++col)
                            pDst[row * 4 + col] = pSrc[col * 4 + row];
                        pSrc += 16;
                        pDst += 16;
                    }
                    
                }
                else
                {
                    if (e.dstDefinition.elementSize == e.srcDefinition.elementSize)
                    {
                        // simple copy
                        memcpy(pDst, pSrc, float.sizeof * e.dstDefinition.elementSize * e.dstDefinition.arraySize);
                    }
                    else
                    {
                        // target params may be padded to 4 elements, shared params are packed
                        assert(e.dstDefinition.elementSize % 4 == 0);
                        size_t iterations = e.dstDefinition.elementSize / 4 
                            * e.dstDefinition.arraySize;
                        assert(iterations > 0);
                        size_t valsPerIteration = e.srcDefinition.elementSize / iterations;
                        for (size_t l = 0; l < iterations; ++l)
                        {
                            memcpy(pDst, pSrc, float.sizeof * valsPerIteration);
                            pSrc += valsPerIteration;
                            pDst += 4;
                        }
                    }
                }
            }
            else if (e.dstDefinition.isDouble())
            {
                double* pSrc = mSharedParams.get().getDoublePointer(e.srcDefinition.physicalIndex);
                double* pDst = mParams.getDoublePointer(e.dstDefinition.physicalIndex);
                
                // Deal with matrix transposition here!!!
                // transposition is specific to the dest param set, shared params don't do it
                if (mParams.getTransposeMatrices() && (e.dstDefinition.constType == GpuConstantType.GCT_MATRIX_DOUBLE_4X4))
                {
                    // for each matrix that needs to be transposed and copied,
                    for (size_t iMat = 0; iMat < e.dstDefinition.arraySize; ++iMat)
                    {
                        for (int row = 0; row < 4; ++row)
                            for (int col = 0; col < 4; ++col)
                            pDst[row * 4 + col] = pSrc[col * 4 + row];
                        pSrc += 16;
                        pDst += 16;
                    }
                }
                else
                {
                    if (e.dstDefinition.elementSize == e.srcDefinition.elementSize)
                    {
                        // simple copy
                        memcpy(pDst, pSrc, double.sizeof * e.dstDefinition.elementSize * e.dstDefinition.arraySize);
                    }
                    else
                    {
                        // target params may be padded to 4 elements, shared params are packed
                        assert(e.dstDefinition.elementSize % 4 == 0);
                        size_t iterations = e.dstDefinition.elementSize / 4
                            * e.dstDefinition.arraySize;
                        assert(iterations > 0);
                        size_t valsPerIteration = e.srcDefinition.elementSize;
                        for (size_t l = 0; l < iterations; ++l)
                        {
                            memcpy(pDst, pSrc, double.sizeof * valsPerIteration);
                            pSrc += valsPerIteration;
                            pDst += 4;
                        }
                    }
                }
            }
            else
            {
                int* pSrc = mSharedParams.get().getIntPointer(e.srcDefinition.physicalIndex);
                int* pDst = mParams.getIntPointer(e.dstDefinition.physicalIndex);
                
                if (e.dstDefinition.elementSize == e.srcDefinition.elementSize)
                {
                    // simple copy
                    memcpy(pDst, pSrc, int.sizeof * e.dstDefinition.elementSize * e.dstDefinition.arraySize);
                }
                else
                {
                    // target params may be padded to 4 elements, shared params are packed
                    assert(e.dstDefinition.elementSize % 4 == 0);
                    size_t iterations = (e.dstDefinition.elementSize / 4)
                        * e.dstDefinition.arraySize;
                    assert(iterations > 0);
                    size_t valsPerIteration = e.srcDefinition.elementSize;// / iterations;
                    for (size_t l = 0; l < iterations; ++l)
                    {
                        memcpy(pDst, pSrc, int.sizeof * valsPerIteration);
                        pSrc += valsPerIteration;
                        pDst += 4;
                    }
                }
            }
        }
    }
    
    /// Get the name of the shared parameter set
    string getName(){ return mSharedParams.get().getName(); }
    
    ref SharedPtr!GpuSharedParameters getSharedParams(){ return mSharedParams; }
    ref GpuProgramParameters getTargetParams(){ return mParams; }
    
    /** Internal method that the RenderSystem might use to store optional data. */
    void _setRenderSystemData(Any data){ mRenderSystemData = data; }
    /** Internal method that the RenderSystem might use to store optional data. */
    ref Any _getRenderSystemData(){ return mRenderSystemData; }
}

/** Collects together the program parameters used for a GpuProgram.
 @remarks
 Gpu program state includes constant parameters used by the program, and
 bindings to render system state which is propagated into the constants 
 by the engine automatically if requested.
 @par
 GpuProgramParameters objects should be created through the GpuProgram and
 may be shared between multiple Pass instances. For this reason they
 are managed using a shared pointer, which will ensure they are automatically
 deleted when no Pass is using them anymore. 
 @par
 High-level programs use named parameters (uniforms), low-level programs 
 use indexed constants. This class supports both, but you can tell whether 
 named constants are supported by calling hasNamedParameters(). There are
 references in the documentation below to 'logical' and 'physical' indexes;
 logical indexes are the indexes used by low-level programs and represent 
 indexes into an array of float4's, some of which may be settable, some of
 which may be predefined constants in the program. We only store those
 constants which have actually been set, Therefore our buffer could have 
 gaps if we used the logical indexes in our own buffers. So instead we map
 these logical indexes to physical indexes in our buffer. When using 
 high-level programs, logical indexes don't necessarily exist, although they
 might if the high-level program has a direct, exposed mapping from parameter
 names to logical indexes. In addition, high-level languages may or may not pack
 arrays of elements that are smaller than float4 (e.g. float2/vec2) contiguously.
 This kind of information is held in the ConstantDefinition structure which 
 is only populated for high-level programs. You don't have to worry about
 any of this unless you intend to read parameters back from this structure
 rather than just setting them.
 */
class GpuProgramParameters //: GpuParamsAlloc
{
public:

    size_t calculateSize() //const
    {
        size_t memSize = 0;
        
        memSize += float.sizeof * mFloatConstants.length;
        memSize += double.sizeof * mDoubleConstants.length;
        memSize += int.sizeof * mIntConstants.length;
        memSize += Any.sizeof;
        memSize += size_t.sizeof;
        memSize += bool.sizeof * 2;
        memSize += ushort.sizeof;
        
        foreach (i; mAutoConstants)
        {
            memSize += i.sizeof;
        }
        
        if(!mFloatLogicalToPhysical.isNull())
            memSize += mFloatLogicalToPhysical.bufferSize;
        if(!mDoubleLogicalToPhysical.isNull())
            memSize += mDoubleLogicalToPhysical.bufferSize;
        if(!mIntLogicalToPhysical.isNull())
            memSize += mIntLogicalToPhysical.bufferSize;
        
        return memSize;
    }
    /** Defines the types of automatically updated values that may be bound to GpuProgram
     parameters, or used to modify parameters on a per-object basis.
     */
    enum AutoConstantType
    {
        /// The current world matrix
        ACT_WORLD_MATRIX,
        /// The current world matrix, inverted
        ACT_INVERSE_WORLD_MATRIX,
        /** Provides transpose of world matrix.
         Equivalent to RenderMonkey's "WorldTranspose".
         */
        ACT_TRANSPOSE_WORLD_MATRIX,
        /// The current world matrix, inverted & transposed
        ACT_INVERSE_TRANSPOSE_WORLD_MATRIX,
        
        /// The current array of world matrices, as a 3x4 matrix, used for blending
        ACT_WORLD_MATRIX_ARRAY_3x4,
        /// The current array of world matrices, used for blending
        ACT_WORLD_MATRIX_ARRAY,
        /// The current array of world matrices transformed to an array of dual quaternions, represented as a 2x4 matrix
        ACT_WORLD_DUALQUATERNION_ARRAY_2x4,
        /// The scale and shear components of the current array of world matrices
        ACT_WORLD_SCALE_SHEAR_MATRIX_ARRAY_3x4,
        
        /// The current view matrix
        ACT_VIEW_MATRIX,
        /// The current view matrix, inverted
        ACT_INVERSE_VIEW_MATRIX,
        /** Provides transpose of view matrix.
         Equivalent to RenderMonkey's "ViewTranspose".
         */
        ACT_TRANSPOSE_VIEW_MATRIX,
        /** Provides inverse transpose of view matrix.
         Equivalent to RenderMonkey's "ViewInverseTranspose".
         */
        ACT_INVERSE_TRANSPOSE_VIEW_MATRIX,
        
        
        /// The current projection matrix
        ACT_PROJECTION_MATRIX,
        /** Provides inverse of projection matrix.
         Equivalent to RenderMonkey's "ProjectionInverse".
         */
        ACT_INVERSE_PROJECTION_MATRIX,
        /** Provides transpose of projection matrix.
         Equivalent to RenderMonkey's "ProjectionTranspose".
         */
        ACT_TRANSPOSE_PROJECTION_MATRIX,
        /** Provides inverse transpose of projection matrix.
         Equivalent to RenderMonkey's "ProjectionInverseTranspose".
         */
        ACT_INVERSE_TRANSPOSE_PROJECTION_MATRIX,
        
        
        /// The current view & projection matrices concatenated
        ACT_VIEWPROJ_MATRIX,
        /** Provides inverse of concatenated view and projection matrices.
         Equivalent to RenderMonkey's "ViewProjectionInverse".
         */
        ACT_INVERSE_VIEWPROJ_MATRIX,
        /** Provides transpose of concatenated view and projection matrices.
         Equivalent to RenderMonkey's "ViewProjectionTranspose".
         */
        ACT_TRANSPOSE_VIEWPROJ_MATRIX,
        /** Provides inverse transpose of concatenated view and projection matrices.
         Equivalent to RenderMonkey's "ViewProjectionInverseTranspose".
         */
        ACT_INVERSE_TRANSPOSE_VIEWPROJ_MATRIX,
        
        
        /// The current world & view matrices concatenated
        ACT_WORLDVIEW_MATRIX,
        /// The current world & view matrices concatenated, then inverted
        ACT_INVERSE_WORLDVIEW_MATRIX,
        /** Provides transpose of concatenated world and view matrices.
         Equivalent to RenderMonkey's "WorldViewTranspose".
         */
        ACT_TRANSPOSE_WORLDVIEW_MATRIX,
        /// The current world & view matrices concatenated, then inverted & transposed
        ACT_INVERSE_TRANSPOSE_WORLDVIEW_MATRIX,
        /// view matrices.
        
        
        /// The current world, view & projection matrices concatenated
        ACT_WORLDVIEWPROJ_MATRIX,
        /** Provides inverse of concatenated world, view and projection matrices.
         Equivalent to RenderMonkey's "WorldViewProjectionInverse".
         */
        ACT_INVERSE_WORLDVIEWPROJ_MATRIX,
        /** Provides transpose of concatenated world, view and projection matrices.
         Equivalent to RenderMonkey's "WorldViewProjectionTranspose".
         */
        ACT_TRANSPOSE_WORLDVIEWPROJ_MATRIX,
        /** Provides inverse transpose of concatenated world, view and projection
         matrices. Equivalent to RenderMonkey's "WorldViewProjectionInverseTranspose".
         */
        ACT_INVERSE_TRANSPOSE_WORLDVIEWPROJ_MATRIX,
        
        
        /// render target related values
        /** -1 if requires texture flipping, +1 otherwise. It's useful when you bypassed
         projection matrix transform, still able use this value to adjust transformed y position.
         */
        ACT_RENDER_TARGET_FLIPPING,
        
        /** -1 if the winding has been inverted (e.g. for reflections), +1 otherwise.
         */
        ACT_VERTEX_WINDING,
        
        /// Fog colour
        ACT_FOG_COLOUR,
        /// Fog params: density, linear start, linear end, 1/(end-start)
        ACT_FOG_PARAMS,
        
        
        /// Surface ambient colour, as set in Pass.setAmbient
        ACT_SURFACE_AMBIENT_COLOUR,
        /// Surface diffuse colour, as set in Pass.setDiffuse
        ACT_SURFACE_DIFFUSE_COLOUR,
        /// Surface specular colour, as set in Pass.setSpecular
        ACT_SURFACE_SPECULAR_COLOUR,
        /// Surface emissive colour, as set in Pass.setSelfIllumination
        ACT_SURFACE_EMISSIVE_COLOUR,
        /// Surface shininess, as set in Pass.setShininess
        ACT_SURFACE_SHININESS,
        /// Surface alpha rejection value, not as set in Pass::setAlphaRejectionValue, but a floating number between 0.0f and 1.0f instead (255.0f / Pass::getAlphaRejectionValue())
        ACT_SURFACE_ALPHA_REJECTION_VALUE,
        
        
        /// The number of active light sources (better than gl_MaxLights)
        ACT_LIGHT_COUNT,
        
        
        /// The ambient light colour set in the scene
        ACT_AMBIENT_LIGHT_COLOUR, 
        
        /// Light diffuse colour (index determined by setAutoConstant call)
        ACT_LIGHT_DIFFUSE_COLOUR,
        /// Light specular colour (index determined by setAutoConstant call)
        ACT_LIGHT_SPECULAR_COLOUR,
        /// Light attenuation parameters, Vector4(range, constant, linear, quadric)
        ACT_LIGHT_ATTENUATION,
        /** Spotlight parameters, Vector4(innerFactor, outerFactor, falloff, isSpot)
         innerFactor and outerFactor are cos(angle/2)
         The isSpot parameter is 0.0f for non-spotlights, 1.0f for spotlights.
         Also for non-spotlights the inner and outer factors are 1 and nearly 1 respectively
         */ 
        ACT_SPOTLIGHT_PARAMS,
        /// A light position in world space (index determined by setAutoConstant call)
        ACT_LIGHT_POSITION,
        /// A light position in object space (index determined by setAutoConstant call)
        ACT_LIGHT_POSITION_OBJECT_SPACE,
        /// A light position in view space (index determined by setAutoConstant call)
        ACT_LIGHT_POSITION_VIEW_SPACE,
        /// A light direction in world space (index determined by setAutoConstant call)
        ACT_LIGHT_DIRECTION,
        /// A light direction in object space (index determined by setAutoConstant call)
        ACT_LIGHT_DIRECTION_OBJECT_SPACE,
        /// A light direction in view space (index determined by setAutoConstant call)
        ACT_LIGHT_DIRECTION_VIEW_SPACE,
        /** The distance of the light from the center of the object
         a useful approximation as an alternative to per-vertex distance
         calculations.
         */
        ACT_LIGHT_DISTANCE_OBJECT_SPACE,
        /** Light power level, a single scalar as set in Light.setPowerScale  (index determined by setAutoConstant call) */
        ACT_LIGHT_POWER_SCALE,
        /// Light diffuse colour pre-scaled by Light.setPowerScale (index determined by setAutoConstant call)
        ACT_LIGHT_DIFFUSE_COLOUR_POWER_SCALED,
        /// Light specular colour pre-scaled by Light.setPowerScale (index determined by setAutoConstant call)
        ACT_LIGHT_SPECULAR_COLOUR_POWER_SCALED,
        /// Array of light diffuse colours (count set by extra param)
        ACT_LIGHT_DIFFUSE_COLOUR_ARRAY,
        /// Array of light specular colours (count set by extra param)
        ACT_LIGHT_SPECULAR_COLOUR_ARRAY,
        /// Array of light diffuse colours scaled by light power (count set by extra param)
        ACT_LIGHT_DIFFUSE_COLOUR_POWER_SCALED_ARRAY,
        /// Array of light specular colours scaled by light power (count set by extra param)
        ACT_LIGHT_SPECULAR_COLOUR_POWER_SCALED_ARRAY,
        /// Array of light attenuation parameters, Vector4(range, constant, linear, quadric) (count set by extra param)
        ACT_LIGHT_ATTENUATION_ARRAY,
        /// Array of light positions in world space (count set by extra param)
        ACT_LIGHT_POSITION_ARRAY,
        /// Array of light positions in object space (count set by extra param)
        ACT_LIGHT_POSITION_OBJECT_SPACE_ARRAY,
        /// Array of light positions in view space (count set by extra param)
        ACT_LIGHT_POSITION_VIEW_SPACE_ARRAY,
        /// Array of light directions in world space (count set by extra param)
        ACT_LIGHT_DIRECTION_ARRAY,
        /// Array of light directions in object space (count set by extra param)
        ACT_LIGHT_DIRECTION_OBJECT_SPACE_ARRAY,
        /// Array of light directions in view space (count set by extra param)
        ACT_LIGHT_DIRECTION_VIEW_SPACE_ARRAY,
        /** Array of distances of the lights from the center of the object
         a useful approximation as an alternative to per-vertex distance
         calculations. (count set by extra param)
         */
        ACT_LIGHT_DISTANCE_OBJECT_SPACE_ARRAY,
        /** Array of light power levels, a single scalar as set in Light.setPowerScale 
         (count set by extra param)
         */
        ACT_LIGHT_POWER_SCALE_ARRAY,
        /** Spotlight parameters array of Vector4(innerFactor, outerFactor, falloff, isSpot)
         innerFactor and outerFactor are cos(angle/2)
         The isSpot parameter is 0.0f for non-spotlights, 1.0f for spotlights.
         Also for non-spotlights the inner and outer factors are 1 and nearly 1 respectively.
         (count set by extra param)
         */ 
        ACT_SPOTLIGHT_PARAMS_ARRAY,
        
        /** The derived ambient light colour, with 'r', 'g', 'b' components filled with
         product of surface ambient colour and ambient light colour, respectively,
         and 'a' component filled with surface ambient alpha component.
         */
        ACT_DERIVED_AMBIENT_LIGHT_COLOUR,
        /** The derived scene colour, with 'r', 'g' and 'b' components filled with sum
         of derived ambient light colour and surface emissive colour, respectively,
         and 'a' component filled with surface diffuse alpha component.
         */
        ACT_DERIVED_SCENE_COLOUR,
        
        /** The derived light diffuse colour (index determined by setAutoConstant call),
         with 'r', 'g' and 'b' components filled with product of surface diffuse colour,
         light power scale and light diffuse colour, respectively, and 'a' component filled with surface
         diffuse alpha component.
         */
        ACT_DERIVED_LIGHT_DIFFUSE_COLOUR,
        /** The derived light specular colour (index determined by setAutoConstant call),
         with 'r', 'g' and 'b' components filled with product of surface specular colour
         and light specular colour, respectively, and 'a' component filled with surface
         specular alpha component.
         */
        ACT_DERIVED_LIGHT_SPECULAR_COLOUR,
        
        /// Array of derived light diffuse colours (count set by extra param)
        ACT_DERIVED_LIGHT_DIFFUSE_COLOUR_ARRAY,
        /// Array of derived light specular colours (count set by extra param)
        ACT_DERIVED_LIGHT_SPECULAR_COLOUR_ARRAY,
        /** The absolute light number of a local light index. Each pass may have
         a number of lights passed to it, and each of these lights will have
         an index in the overall light list, which will differ from the local
         light index due to factors like setStartLight and setIteratePerLight.
         This binding provides the global light index for a local index.
         */
        ACT_LIGHT_NUMBER,
        /// Returns (int) 1 if the  given light casts shadows, 0 otherwise (index set in extra param)
        ACT_LIGHT_CASTS_SHADOWS,
        /// Returns (int) 1 if the  given light casts shadows, 0 otherwise (index set in extra param)
        ACT_LIGHT_CASTS_SHADOWS_ARRAY,
        
        
        /** The distance a shadow volume should be extruded when using
         finite extrusion programs.
         */
        ACT_SHADOW_EXTRUSION_DISTANCE,
        /// The current camera's position in world space
        ACT_CAMERA_POSITION,
        /// The current camera's position in object space 
        ACT_CAMERA_POSITION_OBJECT_SPACE,
        /// The view/projection matrix of the assigned texture projection frustum
        ACT_TEXTURE_VIEWPROJ_MATRIX,
        /// Array of view/projection matrices of the first n texture projection frustums
        ACT_TEXTURE_VIEWPROJ_MATRIX_ARRAY,
        /** The view/projection matrix of the assigned texture projection frustum, 
         combined with the current world matrix
         */
        ACT_TEXTURE_WORLDVIEWPROJ_MATRIX,
        /// Array of world/view/projection matrices of the first n texture projection frustums
        ACT_TEXTURE_WORLDVIEWPROJ_MATRIX_ARRAY,
        /// The view/projection matrix of a given spotlight
        ACT_SPOTLIGHT_VIEWPROJ_MATRIX,
        /// Array of view/projection matrix of a given spotlight
        ACT_SPOTLIGHT_VIEWPROJ_MATRIX_ARRAY,
        /** The view/projection matrix of a given spotlight projection frustum, 
         combined with the current world matrix
         */
        ACT_SPOTLIGHT_WORLDVIEWPROJ_MATRIX,
        /** An array of the view/projection matrix of a given spotlight projection frustum,
             combined with the current world matrix
             */
        ACT_SPOTLIGHT_WORLDVIEWPROJ_MATRIX_ARRAY,
        /// A custom parameter which will come from the renderable, using 'data' as the identifier
        ACT_CUSTOM,
        /** provides current elapsed time
         */
        ACT_TIME,
        /** Single float value, which repeats itself based on given as
         parameter "cycle time". Equivalent to RenderMonkey's "Time0_X".
         */
        ACT_TIME_0_X,
        /// Cosine of "Time0_X". Equivalent to RenderMonkey's "CosTime0_X".
        ACT_COSTIME_0_X,
        /// Sine of "Time0_X". Equivalent to RenderMonkey's "SinTime0_X".
        ACT_SINTIME_0_X,
        /// Tangent of "Time0_X". Equivalent to RenderMonkey's "TanTime0_X".
        ACT_TANTIME_0_X,
        /** Vector of "Time0_X", "SinTime0_X", "CosTime0_X", 
         "TanTime0_X". Equivalent to RenderMonkey's "Time0_X_Packed".
         */
        ACT_TIME_0_X_PACKED,
        /** Single float value, which represents scaled time value [0..1],
         which repeats itself based on given as parameter "cycle time".
         Equivalent to RenderMonkey's "Time0_1".
         */
        ACT_TIME_0_1,
        /// Cosine of "Time0_1". Equivalent to RenderMonkey's "CosTime0_1".
        ACT_COSTIME_0_1,
        /// Sine of "Time0_1". Equivalent to RenderMonkey's "SinTime0_1".
        ACT_SINTIME_0_1,
        /// Tangent of "Time0_1". Equivalent to RenderMonkey's "TanTime0_1".
        ACT_TANTIME_0_1,
        /** Vector of "Time0_1", "SinTime0_1", "CosTime0_1",
         "TanTime0_1". Equivalent to RenderMonkey's "Time0_1_Packed".
         */
        ACT_TIME_0_1_PACKED,
        /** Single float value, which represents scaled time value [0..2*Pi],
         which repeats itself based on given as parameter "cycle time".
         Equivalent to RenderMonkey's "Time0_2PI".
         */
        ACT_TIME_0_2PI,
        /// Cosine of "Time0_2PI". Equivalent to RenderMonkey's "CosTime0_2PI".
        ACT_COSTIME_0_2PI,
        /// Sine of "Time0_2PI". Equivalent to RenderMonkey's "SinTime0_2PI".
        ACT_SINTIME_0_2PI,
        /// Tangent of "Time0_2PI". Equivalent to RenderMonkey's "TanTime0_2PI".
        ACT_TANTIME_0_2PI,
        /** Vector of "Time0_2PI", "SinTime0_2PI", "CosTime0_2PI",
         "TanTime0_2PI". Equivalent to RenderMonkey's "Time0_2PI_Packed".
         */
        ACT_TIME_0_2PI_PACKED,
        /// provides the scaled frame time, returned as a floating point value.
        ACT_FRAME_TIME,
        /// provides the calculated frames per second, returned as a floating point value.
        ACT_FPS,
        /// viewport-related values
        /** Current viewport width (in pixels) as floating point value.
         Equivalent to RenderMonkey's "ViewportWidth".
         */
        ACT_VIEWPORT_WIDTH,
        /** Current viewport height (in pixels) as floating point value.
         Equivalent to RenderMonkey's "ViewportHeight".
         */
        ACT_VIEWPORT_HEIGHT,
        /** This variable represents 1.0/ViewportWidth. 
         Equivalent to RenderMonkey's "ViewportWidthInverse".
         */
        ACT_INVERSE_VIEWPORT_WIDTH,
        /** This variable represents 1.0/ViewportHeight.
         Equivalent to RenderMonkey's "ViewportHeightInverse".
         */
        ACT_INVERSE_VIEWPORT_HEIGHT,
        /** Packed of "ViewportWidth", "ViewportHeight", "ViewportWidthInverse",
         "ViewportHeightInverse".
         */
        ACT_VIEWPORT_SIZE,
        
        /// view parameters
        /** This variable provides the view direction vector (world space).
         Equivalent to RenderMonkey's "ViewDirection".
         */
        ACT_VIEW_DIRECTION,
        /** This variable provides the view side vector (world space).
         Equivalent to RenderMonkey's "ViewSideVector".
         */
        ACT_VIEW_SIDE_VECTOR,
        /** This variable provides the view up vector (world space).
         Equivalent to RenderMonkey's "ViewUpVector".
         */
        ACT_VIEW_UP_VECTOR,
        /** This variable provides the field of view as a floating point value.
         Equivalent to RenderMonkey's "FOV".
         */
        ACT_FOV,
        /** This variable provides the near clip distance as a floating point value.
         Equivalent to RenderMonkey's "NearClipPlane".
         */
        ACT_NEAR_CLIP_DISTANCE,
        /** This variable provides the far clip distance as a floating point value.
         Equivalent to RenderMonkey's "FarClipPlane".
         */
        ACT_FAR_CLIP_DISTANCE,
        
        /** provides the pass index number within the technique
         of the active materil.
         */
        ACT_PASS_NUMBER,
        
        /** provides the current iteration number of the pass. The iteration
         number is the number of times the current render operation has
         been drawn for the active pass.
         */
        ACT_PASS_ITERATION_NUMBER,
        
        
        /** Provides a parametric animation value [0..1], only available
         where the renderable specifically implements it.
         */
        ACT_ANIMATION_PARAMETRIC,
        
        /** Provides the texel offsets required by this rendersystem to map
         texels to pixels. Packed as 
         float4(absoluteHorizontalOffset, absoluteVerticalOffset, 
         horizontalOffset / viewportWidth, verticalOffset / viewportHeight)
         */
        ACT_TEXEL_OFFSETS,
        
        /** Provides information about the depth range of the scene as viewed
         from the current camera. 
         Passed as float4(minDepth, maxDepth, depthRange, 1 / depthRange)
         */
        ACT_SCENE_DEPTH_RANGE,
        
        /** Provides information about the depth range of the scene as viewed
         from a given shadow camera. Requires an index parameter which maps
         to a light index relative to the current light list.
         Passed as float4(minDepth, maxDepth, depthRange, 1 / depthRange)
         */
        ACT_SHADOW_SCENE_DEPTH_RANGE,
        
        /** Provides an array of information about the depth range of the scene as viewed
             from a given shadow camera. Requires an index parameter which maps
             to a light index relative to the current light list.
             Passed as float4(minDepth, maxDepth, depthRange, 1 / depthRange)
             */
        ACT_SHADOW_SCENE_DEPTH_RANGE_ARRAY,
        
        /** Provides the fixed shadow colour as configured via SceneManager.setShadowColour;
         useful for integrated modulative shadows.
         */
        ACT_SHADOW_COLOUR,
        /** Provides texture size of the texture unit (index determined by setAutoConstant
         call). Packed as float4(width, height, depth, 1)
         */
        ACT_TEXTURE_SIZE,
        /** Provides inverse texture size of the texture unit (index determined by setAutoConstant
         call). Packed as float4(1 / width, 1 / height, 1 / depth, 1)
         */
        ACT_INVERSE_TEXTURE_SIZE,
        /** Provides packed texture size of the texture unit (index determined by setAutoConstant
         call). Packed as float4(width, height, 1 / width, 1 / height)
         */
        ACT_PACKED_TEXTURE_SIZE,
        
        /** Provides the current transform matrix of the texture unit (index determined by setAutoConstant
         call), as seen by the fixed-function pipeline. 
         */
        ACT_TEXTURE_MATRIX, 
        
        /** Provides the position of the LOD camera in world space, allowing you 
         to perform separate LOD calculations in shaders independent of the rendering
         camera. If there is no separate LOD camera then this is the real camera
         position. See Camera.setLodCamera.
         */
        ACT_LOD_CAMERA_POSITION, 
        /** Provides the position of the LOD camera in object space, allowing you 
         to perform separate LOD calculations in shaders independent of the rendering
         camera. If there is no separate LOD camera then this is the real camera
         position. See Camera.setLodCamera.
         */
        ACT_LOD_CAMERA_POSITION_OBJECT_SPACE, 
        /** Binds custom per-lightants to the shaders. */
        ACT_LIGHT_CUSTOM
    }
    
    /** Defines the type of the extra data item used by the auto constant.

     */
    enum ACDataType {
        /// no data is required
        ACDT_NONE,
        /// the auto constant requires data of type int
        ACDT_INT,
        /// the auto constant requires data of type real
        ACDT_REAL
    }
    
    /** Defines the base element type of the auto constant
     */
    enum ElementType {
        ET_INT,
        ET_REAL
    }
    
    /** Structure defining an auto constant that's available for use in 
     a parameters object.
     */
    struct AutoConstantDefinition
    {
        AutoConstantType acType;
        string name;
        size_t elementCount;
        /// The type of the constant in the program
        ElementType elementType;
        /// The type of any extra data
        ACDataType dataType;
        
        this(AutoConstantType _acType, string _name, 
             size_t _elementCount, ElementType _elementType, 
             ACDataType _dataType)
        {
            acType = _acType;
            name = _name;
            elementCount = _elementCount;
            elementType = _elementType;
            dataType = _dataType;
        }
    }
    
    /** Structure recording the use of an automatic parameter. */
    class AutoConstantEntry
    {
    public:
        /// The type of parameter
        AutoConstantType paramType;
        /// The target (physical) constant index
        size_t physicalIndex;
        /** The number of elements per individual entry in this constant
         Used in case people used packed elements smaller than 4 (e.g. GLSL)
         and bind an auto which is 4-element packed to it */
        size_t elementCount;
        /// Additional information to go with the parameter
        union{
            size_t data;
            Real fData;
        }
        /// The variability of this parameter (see GpuParamVariability)
        ushort variability;
        
        this(AutoConstantType theType, size_t theIndex, size_t theData, 
             ushort theVariability, size_t theElemCount = 4)
        {
            paramType = theType;
            physicalIndex = theIndex;
            elementCount = theElemCount;
            data = theData;
            variability = theVariability;
        }
        
        this(AutoConstantType theType, size_t theIndex, Real theData, 
             ushort theVariability, size_t theElemCount = 4)
        {
            paramType = theType;
            physicalIndex = theIndex;
            elementCount = theElemCount;
            fData = theData;
            variability = theVariability;
        }
        
    }
    // Auto parameter storage
    //typedef vector<AutoConstantEntry>.type AutoConstantList;
    alias AutoConstantEntry[] AutoConstantList;
    
    //typedef vector<GpuSharedParametersUsage>.type GpuSharedParamUsageList;
    alias GpuSharedParametersUsage[] GpuSharedParamUsageList;
    
    // Map that store subroutines associated with slots
    //typedef HashMap<uint, string> SubroutineMap;
    //typedef HashMap<uint, string>.const_iterator SubroutineIterator;
    //uint
    alias string[size_t] SubroutineMap;
    
protected:
    SubroutineMap mSubroutineMap;
    
    static AutoConstantDefinition[] AutoConstantDictionary = 
    [
        AutoConstantDefinition(AutoConstantType.ACT_WORLD_MATRIX,                  "world_matrix",                16,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_INVERSE_WORLD_MATRIX,          "inverse_world_matrix",        16,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_TRANSPOSE_WORLD_MATRIX,         "transpose_world_matrix",     16,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_INVERSE_TRANSPOSE_WORLD_MATRIX, "inverse_transpose_world_matrix", 16,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        
        AutoConstantDefinition(AutoConstantType.ACT_WORLD_MATRIX_ARRAY_3x4,        "world_matrix_array_3x4",      12,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_WORLD_MATRIX_ARRAY,            "world_matrix_array",          16,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_WORLD_DUALQUATERNION_ARRAY_2x4, "world_dualquaternion_array_2x4",      8,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_WORLD_SCALE_SHEAR_MATRIX_ARRAY_3x4, "world_scale_shear_matrix_array_3x4", 9,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_VIEW_MATRIX,                   "view_matrix",                 16,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_INVERSE_VIEW_MATRIX,           "inverse_view_matrix",         16,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_TRANSPOSE_VIEW_MATRIX,         "transpose_view_matrix",       16,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_INVERSE_TRANSPOSE_VIEW_MATRIX, "inverse_transpose_view_matrix", 16,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        
        AutoConstantDefinition(AutoConstantType.ACT_PROJECTION_MATRIX,                  "projection_matrix",           16,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_INVERSE_PROJECTION_MATRIX,          "inverse_projection_matrix",   16,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_TRANSPOSE_PROJECTION_MATRIX,        "transpose_projection_matrix", 16,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_INVERSE_TRANSPOSE_PROJECTION_MATRIX, "inverse_transpose_projection_matrix", 16,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        
        AutoConstantDefinition(AutoConstantType.ACT_VIEWPROJ_MATRIX,               "viewproj_matrix",             16,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_INVERSE_VIEWPROJ_MATRIX,       "inverse_viewproj_matrix",     16,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_TRANSPOSE_VIEWPROJ_MATRIX,          "transpose_viewproj_matrix",         16,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_INVERSE_TRANSPOSE_VIEWPROJ_MATRIX,   "inverse_transpose_viewproj_matrix", 16,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        
        AutoConstantDefinition(AutoConstantType.ACT_WORLDVIEW_MATRIX,              "worldview_matrix",            16,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_INVERSE_WORLDVIEW_MATRIX,      "inverse_worldview_matrix",    16,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_TRANSPOSE_WORLDVIEW_MATRIX,         "transpose_worldview_matrix",        16,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_INVERSE_TRANSPOSE_WORLDVIEW_MATRIX, "inverse_transpose_worldview_matrix", 16,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        
        AutoConstantDefinition(AutoConstantType.ACT_WORLDVIEWPROJ_MATRIX,          "worldviewproj_matrix",        16,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_INVERSE_WORLDVIEWPROJ_MATRIX,       "inverse_worldviewproj_matrix",      16,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_TRANSPOSE_WORLDVIEWPROJ_MATRIX,     "transpose_worldviewproj_matrix",    16,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_INVERSE_TRANSPOSE_WORLDVIEWPROJ_MATRIX, "inverse_transpose_worldviewproj_matrix", 16,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        
        AutoConstantDefinition(AutoConstantType.ACT_RENDER_TARGET_FLIPPING,          "render_target_flipping",         1,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_VERTEX_WINDING,          "vertex_winding",         1,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        
        AutoConstantDefinition(AutoConstantType.ACT_FOG_COLOUR,                    "fog_colour",                   4,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_FOG_PARAMS,                    "fog_params",                   4,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        
        AutoConstantDefinition(AutoConstantType.ACT_SURFACE_AMBIENT_COLOUR,          "surface_ambient_colour",           4,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_SURFACE_DIFFUSE_COLOUR,          "surface_diffuse_colour",           4,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_SURFACE_SPECULAR_COLOUR,         "surface_specular_colour",          4,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_SURFACE_EMISSIVE_COLOUR,         "surface_emissive_colour",          4,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_SURFACE_SHININESS,               "surface_shininess",                1,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_SURFACE_ALPHA_REJECTION_VALUE,   "surface_alpha_rejection_value",    1,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        
        
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_COUNT,                   "light_count",                  1,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        
        AutoConstantDefinition(AutoConstantType.ACT_AMBIENT_LIGHT_COLOUR,          "ambient_light_colour",         4,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_DIFFUSE_COLOUR,          "light_diffuse_colour",         4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_SPECULAR_COLOUR,         "light_specular_colour",        4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_ATTENUATION,             "light_attenuation",            4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_SPOTLIGHT_PARAMS,              "spotlight_params",             4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_POSITION,                "light_position",               4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_POSITION_OBJECT_SPACE,   "light_position_object_space",  4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_POSITION_VIEW_SPACE,          "light_position_view_space",    4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_DIRECTION,               "light_direction",              4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_DIRECTION_OBJECT_SPACE,  "light_direction_object_space", 4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_DIRECTION_VIEW_SPACE,         "light_direction_view_space",   4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_DISTANCE_OBJECT_SPACE,   "light_distance_object_space",  1,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_POWER_SCALE,             "light_power",  1,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_DIFFUSE_COLOUR_POWER_SCALED, "light_diffuse_colour_power_scaled",         4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_SPECULAR_COLOUR_POWER_SCALED, "light_specular_colour_power_scaled",        4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_DIFFUSE_COLOUR_ARRAY,          "light_diffuse_colour_array",         4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_SPECULAR_COLOUR_ARRAY,         "light_specular_colour_array",        4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_DIFFUSE_COLOUR_POWER_SCALED_ARRAY, "light_diffuse_colour_power_scaled_array",         4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_SPECULAR_COLOUR_POWER_SCALED_ARRAY, "light_specular_colour_power_scaled_array",        4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_ATTENUATION_ARRAY,             "light_attenuation_array",            4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_POSITION_ARRAY,                "light_position_array",               4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_POSITION_OBJECT_SPACE_ARRAY,   "light_position_object_space_array",  4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_POSITION_VIEW_SPACE_ARRAY,          "light_position_view_space_array",    4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_DIRECTION_ARRAY,               "light_direction_array",              4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_DIRECTION_OBJECT_SPACE_ARRAY,  "light_direction_object_space_array", 4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_DIRECTION_VIEW_SPACE_ARRAY,         "light_direction_view_space_array",   4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_DISTANCE_OBJECT_SPACE_ARRAY,   "light_distance_object_space_array",  1,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_POWER_SCALE_ARRAY,           "light_power_array",  1,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_SPOTLIGHT_PARAMS_ARRAY,              "spotlight_params_array",             4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        
        AutoConstantDefinition(AutoConstantType.ACT_DERIVED_AMBIENT_LIGHT_COLOUR,    "derived_ambient_light_colour",     4,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_DERIVED_SCENE_COLOUR,            "derived_scene_colour",             4,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_DERIVED_LIGHT_DIFFUSE_COLOUR,    "derived_light_diffuse_colour",     4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_DERIVED_LIGHT_SPECULAR_COLOUR,   "derived_light_specular_colour",    4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_DERIVED_LIGHT_DIFFUSE_COLOUR_ARRAY,  "derived_light_diffuse_colour_array",   4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_DERIVED_LIGHT_SPECULAR_COLOUR_ARRAY, "derived_light_specular_colour_array",  4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_NUMBER,                      "light_number",  1,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_CASTS_SHADOWS,               "light_casts_shadows",  1,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_CASTS_SHADOWS_ARRAY,     "light_casts_shadows_array",  1, ElementType.ET_REAL, ACDataType.ACDT_INT),
        
        AutoConstantDefinition(AutoConstantType.ACT_SHADOW_EXTRUSION_DISTANCE,     "shadow_extrusion_distance",    1,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_CAMERA_POSITION,               "camera_position",              3,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_CAMERA_POSITION_OBJECT_SPACE,  "camera_position_object_space", 3,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_TEXTURE_VIEWPROJ_MATRIX,       "texture_viewproj_matrix",     16,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_TEXTURE_VIEWPROJ_MATRIX_ARRAY, "texture_viewproj_matrix_array", 16,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_TEXTURE_WORLDVIEWPROJ_MATRIX,  "texture_worldviewproj_matrix",16,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_TEXTURE_WORLDVIEWPROJ_MATRIX_ARRAY, "texture_worldviewproj_matrix_array",16,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_SPOTLIGHT_VIEWPROJ_MATRIX,       "spotlight_viewproj_matrix",     16,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_SPOTLIGHT_VIEWPROJ_MATRIX_ARRAY, "spotlight_viewproj_matrix_array", 16,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_SPOTLIGHT_WORLDVIEWPROJ_MATRIX,  "spotlight_worldviewproj_matrix",16,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_SPOTLIGHT_WORLDVIEWPROJ_MATRIX_ARRAY,  "spotlight_worldviewproj_matrix_array",16, ElementType.ET_REAL, ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_CUSTOM,                        "custom",                       4,ElementType.ET_REAL,ACDataType.ACDT_INT),  // *** needs to be tested
        AutoConstantDefinition(AutoConstantType.ACT_TIME,                               "time",                               1,ElementType.ET_REAL,ACDataType.ACDT_REAL),
        AutoConstantDefinition(AutoConstantType.ACT_TIME_0_X,                      "time_0_x",                     4,ElementType.ET_REAL,ACDataType.ACDT_REAL),
        AutoConstantDefinition(AutoConstantType.ACT_COSTIME_0_X,                   "costime_0_x",                  4,ElementType.ET_REAL,ACDataType.ACDT_REAL),
        AutoConstantDefinition(AutoConstantType.ACT_SINTIME_0_X,                   "sintime_0_x",                  4,ElementType.ET_REAL,ACDataType.ACDT_REAL),
        AutoConstantDefinition(AutoConstantType.ACT_TANTIME_0_X,                   "tantime_0_x",                  4,ElementType.ET_REAL,ACDataType.ACDT_REAL),
        AutoConstantDefinition(AutoConstantType.ACT_TIME_0_X_PACKED,               "time_0_x_packed",              4,ElementType.ET_REAL,ACDataType.ACDT_REAL),
        AutoConstantDefinition(AutoConstantType.ACT_TIME_0_1,                      "time_0_1",                     4,ElementType.ET_REAL,ACDataType.ACDT_REAL),
        AutoConstantDefinition(AutoConstantType.ACT_COSTIME_0_1,                   "costime_0_1",                  4,ElementType.ET_REAL,ACDataType.ACDT_REAL),
        AutoConstantDefinition(AutoConstantType.ACT_SINTIME_0_1,                   "sintime_0_1",                  4,ElementType.ET_REAL,ACDataType.ACDT_REAL),
        AutoConstantDefinition(AutoConstantType.ACT_TANTIME_0_1,                   "tantime_0_1",                  4,ElementType.ET_REAL,ACDataType.ACDT_REAL),
        AutoConstantDefinition(AutoConstantType.ACT_TIME_0_1_PACKED,               "time_0_1_packed",              4,ElementType.ET_REAL,ACDataType.ACDT_REAL),
        AutoConstantDefinition(AutoConstantType.ACT_TIME_0_2PI,                    "time_0_2pi",                   4,ElementType.ET_REAL,ACDataType.ACDT_REAL),
        AutoConstantDefinition(AutoConstantType.ACT_COSTIME_0_2PI,                 "costime_0_2pi",                4,ElementType.ET_REAL,ACDataType.ACDT_REAL),
        AutoConstantDefinition(AutoConstantType.ACT_SINTIME_0_2PI,                 "sintime_0_2pi",                4,ElementType.ET_REAL,ACDataType.ACDT_REAL),
        AutoConstantDefinition(AutoConstantType.ACT_TANTIME_0_2PI,                 "tantime_0_2pi",                4,ElementType.ET_REAL,ACDataType.ACDT_REAL),
        AutoConstantDefinition(AutoConstantType.ACT_TIME_0_2PI_PACKED,             "time_0_2pi_packed",            4,ElementType.ET_REAL,ACDataType.ACDT_REAL),
        AutoConstantDefinition(AutoConstantType.ACT_FRAME_TIME,                    "frame_time",                   1,ElementType.ET_REAL,ACDataType.ACDT_REAL),
        AutoConstantDefinition(AutoConstantType.ACT_FPS,                           "fps",                          1,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_VIEWPORT_WIDTH,                "viewport_width",               1,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_VIEWPORT_HEIGHT,               "viewport_height",              1,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_INVERSE_VIEWPORT_WIDTH,        "inverse_viewport_width",       1,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_INVERSE_VIEWPORT_HEIGHT,       "inverse_viewport_height",      1,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_VIEWPORT_SIZE,                 "viewport_size",                4,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_VIEW_DIRECTION,                "view_direction",               3,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_VIEW_SIDE_VECTOR,              "view_side_vector",             3,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_VIEW_UP_VECTOR,                "view_up_vector",               3,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_FOV,                           "fov",                          1,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_NEAR_CLIP_DISTANCE,            "near_clip_distance",           1,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_FAR_CLIP_DISTANCE,             "far_clip_distance",            1,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_PASS_NUMBER,                   "pass_number",                  1,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_PASS_ITERATION_NUMBER,         "pass_iteration_number",        1,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_ANIMATION_PARAMETRIC,          "animation_parametric",         4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_TEXEL_OFFSETS,               "texel_offsets",                  4,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_SCENE_DEPTH_RANGE,           "scene_depth_range",              4,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_SHADOW_SCENE_DEPTH_RANGE,    "shadow_scene_depth_range",       4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_SHADOW_SCENE_DEPTH_RANGE_ARRAY,    "shadow_scene_depth_range_array",          4, ElementType.ET_REAL, ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_SHADOW_COLOUR,               "shadow_colour",                  4,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_TEXTURE_SIZE,                "texture_size",                   4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_INVERSE_TEXTURE_SIZE,        "inverse_texture_size",           4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_PACKED_TEXTURE_SIZE,         "packed_texture_size",            4,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_TEXTURE_MATRIX,  "texture_matrix", 16,ElementType.ET_REAL,ACDataType.ACDT_INT),
        AutoConstantDefinition(AutoConstantType.ACT_LOD_CAMERA_POSITION,               "lod_camera_position",              3,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_LOD_CAMERA_POSITION_OBJECT_SPACE,  "lod_camera_position_object_space", 3,ElementType.ET_REAL,ACDataType.ACDT_NONE),
        AutoConstantDefinition(AutoConstantType.ACT_LIGHT_CUSTOM,    "light_custom", 4,ElementType.ET_REAL,ACDataType.ACDT_INT)
    ];
    
    /// Packed list of floating-point constants (physical indexing)
    FloatConstantList mFloatConstants;
    /// Packed list of double-point constants (physical indexing)
    DoubleConstantList mDoubleConstants;
    /// Packed list of integer constants (physical indexing)
    IntConstantList mIntConstants;
    /** Logical index to physical index map - for low-level programs
     or high-level programs which pass params this way. */
    SharedPtr!GpuLogicalBufferStruct mFloatLogicalToPhysical;
    /** Logical index to physical index map - for low-level programs
        or high-level programs which pass params this way. */
    GpuLogicalBufferStructPtr mDoubleLogicalToPhysical;
    /** Logical index to physical index map - for low-level programs
     or high-level programs which pass params this way. */
    SharedPtr!GpuLogicalBufferStruct mIntLogicalToPhysical;
    /// Mapping from parameter names to def - high-level programs are expected to populate this
    SharedPtr!(GpuNamedConstants*) mNamedConstants;
    /// List of automatically updated parameters
    AutoConstantList mAutoConstants;
    /// The combined variability masks of all parameters
    ushort mCombinedVariability;
    /// Do we need to transpose matrices?
    bool mTransposeMatrices;
    /// flag to indicate if names not found will be ignored
    bool mIgnoreMissingParams;
    /// physical index for active pass iteration parameter real constant entry;
    size_t mActivePassIterationIndex;
    
    /** Gets the low-level structure for a logical index. 
     */
    GpuLogicalIndexUse* _getFloatConstantLogicalIndexUse(size_t logicalIndex, size_t requestedSize, ushort variability)
    {
        if (mFloatLogicalToPhysical.isNull())
            return null;
        
        GpuLogicalIndexUse* indexUse = null;
        //OGRE_LOCK_MUTEX(mFloatLogicalToPhysical.mutex)
        synchronized(mFloatLogicalToPhysical.get().mLock)
        {
            auto logi = logicalIndex in mFloatLogicalToPhysical.get().map;
            if (logi is null)
            {
                if (requestedSize)
                {
                    size_t physicalIndex = mFloatConstants.length;
                    
                    // Expand at buffer end
                    //mFloatConstants.insert(mFloatConstants.end(), requestedSize, 0.0f);
                    mFloatConstants.length += requestedSize;
                    
                    // Record extended size for future GPU params re-using this information
                    mFloatLogicalToPhysical.get().bufferSize = mFloatConstants.length;
                    
                    // low-level programs will not know about mapping ahead of time, so 
                    // populate it. Other params objects will be able to just use this
                    // accepted mapping since the constant structure will be the same
                    
                    // Set up a mapping for all items in the count
                    size_t currPhys = physicalIndex;
                    size_t count = requestedSize / 4;
                    //GpuLogicalIndexUseMap.iterator insertedIterator;
                    
                    for (size_t logicalNum = 0; logicalNum < count; ++logicalNum)
                    {
                        mFloatLogicalToPhysical.get().map[logicalIndex + logicalNum] =
                            GpuLogicalIndexUse(currPhys, requestedSize, variability);
                        currPhys += 4;
                        
                        if (logicalNum == 0)
                            //insertedIterator = it;
                        indexUse = &mFloatLogicalToPhysical.get().map[logicalIndex + logicalNum];
                    }
                    
                    //indexUse = &(insertedIterator.second);
                }
                else
                {
                    // no match & ignore
                    return null;
                }
                
            }
            else
            {
                size_t physicalIndex = logi.physicalIndex;
                indexUse = logi; //&(logi.second);
                // check size
                if (logi.currentSize < requestedSize)
                {
                    // init buffer entry wasn't big enough; could be a mistake on the part
                    // of the original use, or perhaps a variable length we can't predict
                    // until first actual runtime use e.g. world matrix array
                    size_t insertCount = requestedSize - logi.currentSize;
                    /*FloatConstantList.iterator insertPos = mFloatConstants.begin();
                     std.advance(insertPos, physicalIndex);
                     mFloatConstants.insert(insertPos, insertCount, 0.0f);*/
                    
                    mFloatConstants.insertBeforeIdx(physicalIndex+1, 0.0f);
                    
                    // shift all physical positions after this one
                    foreach (k,v; mFloatLogicalToPhysical.get().map)
                    {
                        if (v.physicalIndex > physicalIndex)
                            v.physicalIndex += insertCount;
                    }
                    mFloatLogicalToPhysical.get().bufferSize += insertCount;
                    foreach (i; mAutoConstants)
                    {
                        AutoConstantDefinition* def = getAutoConstantDefinition(i.paramType);
                        if (i.physicalIndex > physicalIndex &&
                            //def && 
                            def.elementType == ElementType.ET_REAL)
                        {
                            i.physicalIndex += insertCount;
                        }
                    }
                    if (!mNamedConstants.isNull())
                    {
                        foreach (k,v; mNamedConstants.get().map)
                        {
                            if (v.isFloat() && v.physicalIndex > physicalIndex)
                                v.physicalIndex += insertCount;
                        }
                        mNamedConstants.get().floatBufferSize += insertCount;
                    }
                    
                    logi.currentSize += insertCount;
                }
            }
        }
        if (indexUse)
            indexUse.variability = variability;
        
        return indexUse;
        
    }
    
    /** Gets the physical buffer index associated with a logical double constant index. 
     */
    
    GpuLogicalIndexUse* _getDoubleConstantLogicalIndexUse(
        size_t logicalIndex, size_t requestedSize, ushort variability)
    {
        if (mDoubleLogicalToPhysical.isNull())
            return null;
        
        GpuLogicalIndexUse* indexUse = null;
        //OGRE_LOCK_MUTEX(mDoubleLogicalToPhysical.mutex)
        synchronized(mDoubleLogicalToPhysical.get().mLock)
        {
            auto logi = logicalIndex in mDoubleLogicalToPhysical.get().map;
            if (logi is null)
            {
                if (requestedSize)
                {
                    size_t physicalIndex = mFloatConstants.length;
                    
                    // Expand at buffer end
                    //mFloatConstants.insert(mFloatConstants.end(), requestedSize, 0.0f);
                    mFloatConstants.length += requestedSize;
                    
                    // Record extended size for future GPU params re-using this information
                    mDoubleLogicalToPhysical.get().bufferSize = mFloatConstants.length;
                    
                    // low-level programs will not know about mapping ahead of time, so 
                    // populate it. Other params objects will be able to just use this
                    // accepted mapping since the constant structure will be the same
                    
                    // Set up a mapping for all items in the count
                    size_t currPhys = physicalIndex;
                    size_t count = requestedSize / 4;
                    //GpuLogicalIndexUseMap.iterator insertedIterator;
                    
                    for (size_t logicalNum = 0; logicalNum < count; ++logicalNum)
                    {
                        mDoubleLogicalToPhysical.get().map[logicalIndex + logicalNum] =
                            GpuLogicalIndexUse(currPhys, requestedSize, variability);
                        currPhys += 4;
                        
                        if (logicalNum == 0)
                            //insertedIterator = it;
                        indexUse = &mDoubleLogicalToPhysical.get().map[logicalIndex + logicalNum];
                    }
                    
                    //indexUse = &(insertedIterator.second);
                }
                else
                {
                    // no match & ignore
                    return null;
                }
                
            }
            else
            {
                size_t physicalIndex = logi.physicalIndex;
                indexUse = logi; //&(logi.second);
                // check size
                if (logi.currentSize < requestedSize)
                {
                    // init buffer entry wasn't big enough; could be a mistake on the part
                    // of the original use, or perhaps a variable length we can't predict
                    // until first actual runtime use e.g. world matrix array
                    size_t insertCount = requestedSize - logi.currentSize;
                    /*FloatConstantList.iterator insertPos = mFloatConstants.begin();
                     std.advance(insertPos, physicalIndex);
                     mFloatConstants.insert(insertPos, insertCount, 0.0f);*/
                    
                    mDoubleConstants.insertBeforeIdx(physicalIndex+1, 0.0);
                    
                    // shift all physical positions after this one
                    foreach (k,v; mDoubleLogicalToPhysical.get().map)
                    {
                        if (v.physicalIndex > physicalIndex)
                            v.physicalIndex += insertCount;
                    }
                    mDoubleLogicalToPhysical.get().bufferSize += insertCount;
                    foreach (i; mAutoConstants)
                    {
                        AutoConstantDefinition* def = getAutoConstantDefinition(i.paramType);
                        if (i.physicalIndex > physicalIndex &&
                            //def && 
                            def.elementType == ElementType.ET_REAL)
                        {
                            i.physicalIndex += insertCount;
                        }
                    }
                    if (!mNamedConstants.isNull())
                    {
                        foreach (k,v; mNamedConstants.get().map)
                        {
                            if (v.isDouble() && v.physicalIndex > physicalIndex)
                                v.physicalIndex += insertCount;
                        }
                        mNamedConstants.get().doubleBufferSize += insertCount;
                    }
                    
                    logi.currentSize += insertCount;
                }
            }
        }
        if (indexUse)
            indexUse.variability = variability;
        
        return indexUse;
        
    }
    
    /** Gets the physical buffer index associated with a logical int constant index. 
     */
    GpuLogicalIndexUse* _getIntConstantLogicalIndexUse(size_t logicalIndex, size_t requestedSize, ushort variability)
    {
        if (mIntLogicalToPhysical.isNull())
            throw new InvalidParamsError( 
                                         "This is not a low-level parameter parameter object",
                                         "GpuProgramParameters._getIntConstantPhysicalIndex");
        
        GpuLogicalIndexUse* indexUse = null;
        //OGRE_LOCK_MUTEX(mIntLogicalToPhysical.mutex)
        synchronized(mIntLogicalToPhysical.get().mLock)
        {
            auto logi = logicalIndex in mIntLogicalToPhysical.get().map;
            if (logi is null)
            {
                if (requestedSize)
                {
                    size_t physicalIndex = mIntConstants.length;
                    
                    // Expand at buffer end
                    //mIntConstants.insert(mIntConstants.end(), requestedSize, 0);
                    mIntConstants.length += requestedSize;
                    
                    // Record extended size for future GPU params re-using this information
                    mIntLogicalToPhysical.get().bufferSize = mIntConstants.length;
                    
                    // low-level programs will not know about mapping ahead of time, so 
                    // populate it. Other params objects will be able to just use this
                    // accepted mapping since the constant structure will be the same
                    
                    // Set up a mapping for all items in the count
                    size_t currPhys = physicalIndex;
                    size_t count = requestedSize / 4;
                    //GpuLogicalIndexUseMap.iterator insertedIterator;
                    for (size_t logicalNum = 0; logicalNum < count; ++logicalNum)
                    {
                        mIntLogicalToPhysical.get().map[logicalIndex + logicalNum] = 
                            GpuLogicalIndexUse(currPhys, requestedSize, variability);
                        if (logicalNum == 0)
                            //insertedIterator = it;
                        indexUse = &mIntLogicalToPhysical.get().map[logicalIndex + logicalNum];
                        currPhys += 4;
                    }
                    //indexUse = &(insertedIterator.second);
                    
                }
                else
                {
                    // no match
                    return null;
                }
                
            }
            else
            {
                size_t physicalIndex = logi.physicalIndex;
                indexUse = logi;//&(logi.second);
                
                // check size
                if (logi.currentSize < requestedSize)
                {
                    // init buffer entry wasn't big enough; could be a mistake on the part
                    // of the original use, or perhaps a variable length we can't predict
                    // until first actual runtime use e.g. world matrix array
                    size_t insertCount = requestedSize - logi.currentSize;
                    /*IntConstantList.iterator insertPos = mIntConstants.begin();
                     std.advance(insertPos, physicalIndex);
                     mIntConstants.insert(insertPos, insertCount, 0);*/
                    
                    mIntConstants.insertBeforeIdx(physicalIndex+1, 0);
                    
                    // shift all physical positions after this one
                    foreach (k,v; mIntLogicalToPhysical.get().map)
                    {
                        if (v.physicalIndex > physicalIndex)
                            v.physicalIndex += insertCount;
                    }
                    mIntLogicalToPhysical.get().bufferSize += insertCount;
                    foreach (i; mAutoConstants)
                    {
                        auto def = getAutoConstantDefinition(i.paramType);
                        if (i.physicalIndex > physicalIndex &&
                            //def && 
                            def.elementType == ElementType.ET_INT)
                        {
                            i.physicalIndex += insertCount;
                        }
                    }
                    if (!mNamedConstants.isNull())
                    {
                        foreach (k,v; mNamedConstants.get().map)
                        {
                            if (!v.isFloat() && v.physicalIndex > physicalIndex)
                                v.physicalIndex += insertCount;
                        }
                        mNamedConstants.get().intBufferSize += insertCount;
                    }
                    
                    logi.currentSize += insertCount;
                }
            }
        }
        if (indexUse)
            indexUse.variability = variability;
        
        return indexUse;
        
    }
    
    /// Return the variability for an auto constant
    ushort deriveVariability(AutoConstantType act)
    {
        switch(act)
        {
            case AutoConstantType.ACT_VIEW_MATRIX:
            case AutoConstantType.ACT_INVERSE_VIEW_MATRIX:
            case AutoConstantType.ACT_TRANSPOSE_VIEW_MATRIX:
            case AutoConstantType.ACT_INVERSE_TRANSPOSE_VIEW_MATRIX:
            case AutoConstantType.ACT_PROJECTION_MATRIX:
            case AutoConstantType.ACT_INVERSE_PROJECTION_MATRIX:
            case AutoConstantType.ACT_TRANSPOSE_PROJECTION_MATRIX:
            case AutoConstantType.ACT_INVERSE_TRANSPOSE_PROJECTION_MATRIX:
            case AutoConstantType.ACT_VIEWPROJ_MATRIX:
            case AutoConstantType.ACT_INVERSE_VIEWPROJ_MATRIX:
            case AutoConstantType.ACT_TRANSPOSE_VIEWPROJ_MATRIX:
            case AutoConstantType.ACT_INVERSE_TRANSPOSE_VIEWPROJ_MATRIX:
            case AutoConstantType.ACT_RENDER_TARGET_FLIPPING:
            case AutoConstantType.ACT_VERTEX_WINDING:
            case AutoConstantType.ACT_AMBIENT_LIGHT_COLOUR: 
            case AutoConstantType.ACT_DERIVED_AMBIENT_LIGHT_COLOUR:
            case AutoConstantType.ACT_DERIVED_SCENE_COLOUR:
            case AutoConstantType.ACT_FOG_COLOUR:
            case AutoConstantType.ACT_FOG_PARAMS:
            case AutoConstantType.ACT_SURFACE_AMBIENT_COLOUR:
            case AutoConstantType.ACT_SURFACE_DIFFUSE_COLOUR:
            case AutoConstantType.ACT_SURFACE_SPECULAR_COLOUR:
            case AutoConstantType.ACT_SURFACE_EMISSIVE_COLOUR:
            case AutoConstantType.ACT_SURFACE_SHININESS:
            case AutoConstantType.ACT_SURFACE_ALPHA_REJECTION_VALUE:
            case AutoConstantType.ACT_CAMERA_POSITION:
            case AutoConstantType.ACT_TIME:
            case AutoConstantType.ACT_TIME_0_X:
            case AutoConstantType.ACT_COSTIME_0_X:
            case AutoConstantType.ACT_SINTIME_0_X:
            case AutoConstantType.ACT_TANTIME_0_X:
            case AutoConstantType.ACT_TIME_0_X_PACKED:
            case AutoConstantType.ACT_TIME_0_1:
            case AutoConstantType.ACT_COSTIME_0_1:
            case AutoConstantType.ACT_SINTIME_0_1:
            case AutoConstantType.ACT_TANTIME_0_1:
            case AutoConstantType.ACT_TIME_0_1_PACKED:
            case AutoConstantType.ACT_TIME_0_2PI:
            case AutoConstantType.ACT_COSTIME_0_2PI:
            case AutoConstantType.ACT_SINTIME_0_2PI:
            case AutoConstantType.ACT_TANTIME_0_2PI:
            case AutoConstantType.ACT_TIME_0_2PI_PACKED:
            case AutoConstantType.ACT_FRAME_TIME:
            case AutoConstantType.ACT_FPS:
            case AutoConstantType.ACT_VIEWPORT_WIDTH:
            case AutoConstantType.ACT_VIEWPORT_HEIGHT:
            case AutoConstantType.ACT_INVERSE_VIEWPORT_WIDTH:
            case AutoConstantType.ACT_INVERSE_VIEWPORT_HEIGHT:
            case AutoConstantType.ACT_VIEWPORT_SIZE:
            case AutoConstantType.ACT_TEXEL_OFFSETS:
            case AutoConstantType.ACT_TEXTURE_SIZE:
            case AutoConstantType.ACT_INVERSE_TEXTURE_SIZE:
            case AutoConstantType.ACT_PACKED_TEXTURE_SIZE:
            case AutoConstantType.ACT_SCENE_DEPTH_RANGE:
            case AutoConstantType.ACT_VIEW_DIRECTION:
            case AutoConstantType.ACT_VIEW_SIDE_VECTOR:
            case AutoConstantType.ACT_VIEW_UP_VECTOR:
            case AutoConstantType.ACT_FOV:
            case AutoConstantType.ACT_NEAR_CLIP_DISTANCE:
            case AutoConstantType.ACT_FAR_CLIP_DISTANCE:
            case AutoConstantType.ACT_PASS_NUMBER:
            case AutoConstantType.ACT_TEXTURE_MATRIX:
            case AutoConstantType.ACT_LOD_CAMERA_POSITION:
                
                return cast(ushort) GpuParamVariability.GPV_GLOBAL;
                
            case AutoConstantType.ACT_WORLD_MATRIX:
            case AutoConstantType.ACT_INVERSE_WORLD_MATRIX:
            case AutoConstantType.ACT_TRANSPOSE_WORLD_MATRIX:
            case AutoConstantType.ACT_INVERSE_TRANSPOSE_WORLD_MATRIX:
            case AutoConstantType.ACT_WORLD_MATRIX_ARRAY_3x4:
            case AutoConstantType.ACT_WORLD_MATRIX_ARRAY:
            case AutoConstantType.ACT_WORLD_DUALQUATERNION_ARRAY_2x4:
            case AutoConstantType.ACT_WORLD_SCALE_SHEAR_MATRIX_ARRAY_3x4:
            case AutoConstantType.ACT_WORLDVIEW_MATRIX:
            case AutoConstantType.ACT_INVERSE_WORLDVIEW_MATRIX:
            case AutoConstantType.ACT_TRANSPOSE_WORLDVIEW_MATRIX:
            case AutoConstantType.ACT_INVERSE_TRANSPOSE_WORLDVIEW_MATRIX:
            case AutoConstantType.ACT_WORLDVIEWPROJ_MATRIX:
            case AutoConstantType.ACT_INVERSE_WORLDVIEWPROJ_MATRIX:
            case AutoConstantType.ACT_TRANSPOSE_WORLDVIEWPROJ_MATRIX:
            case AutoConstantType.ACT_INVERSE_TRANSPOSE_WORLDVIEWPROJ_MATRIX:
            case AutoConstantType.ACT_CAMERA_POSITION_OBJECT_SPACE:
            case AutoConstantType.ACT_LOD_CAMERA_POSITION_OBJECT_SPACE:
            case AutoConstantType.ACT_CUSTOM:
            case AutoConstantType.ACT_ANIMATION_PARAMETRIC:
                
                return cast(ushort) GpuParamVariability.GPV_PER_OBJECT;
                
            case AutoConstantType.ACT_LIGHT_POSITION_OBJECT_SPACE:
            case AutoConstantType.ACT_LIGHT_DIRECTION_OBJECT_SPACE:
            case AutoConstantType.ACT_LIGHT_DISTANCE_OBJECT_SPACE:
            case AutoConstantType.ACT_LIGHT_POSITION_OBJECT_SPACE_ARRAY:
            case AutoConstantType.ACT_LIGHT_DIRECTION_OBJECT_SPACE_ARRAY:
            case AutoConstantType.ACT_LIGHT_DISTANCE_OBJECT_SPACE_ARRAY:
            case AutoConstantType.ACT_TEXTURE_WORLDVIEWPROJ_MATRIX:
            case AutoConstantType.ACT_TEXTURE_WORLDVIEWPROJ_MATRIX_ARRAY:
            case AutoConstantType.ACT_SPOTLIGHT_WORLDVIEWPROJ_MATRIX:
            case AutoConstantType.ACT_SPOTLIGHT_WORLDVIEWPROJ_MATRIX_ARRAY:
            case AutoConstantType.ACT_SHADOW_EXTRUSION_DISTANCE:
                
                // These depend on BOTH lights and objects
                return (cast(ushort) GpuParamVariability.GPV_PER_OBJECT) | (cast(ushort) GpuParamVariability.GPV_LIGHTS);
                
            case AutoConstantType.ACT_LIGHT_COUNT:
            case AutoConstantType.ACT_LIGHT_DIFFUSE_COLOUR:
            case AutoConstantType.ACT_LIGHT_SPECULAR_COLOUR:
            case AutoConstantType.ACT_LIGHT_POSITION:
            case AutoConstantType.ACT_LIGHT_DIRECTION:
            case AutoConstantType.ACT_LIGHT_POSITION_VIEW_SPACE:
            case AutoConstantType.ACT_LIGHT_DIRECTION_VIEW_SPACE:
            case AutoConstantType.ACT_SHADOW_SCENE_DEPTH_RANGE:
            case AutoConstantType.ACT_SHADOW_SCENE_DEPTH_RANGE_ARRAY:
            case AutoConstantType.ACT_SHADOW_COLOUR:
            case AutoConstantType.ACT_LIGHT_POWER_SCALE:
            case AutoConstantType.ACT_LIGHT_DIFFUSE_COLOUR_POWER_SCALED:
            case AutoConstantType.ACT_LIGHT_SPECULAR_COLOUR_POWER_SCALED:
            case AutoConstantType.ACT_LIGHT_NUMBER:
            case AutoConstantType.ACT_LIGHT_CASTS_SHADOWS:
            case AutoConstantType.ACT_LIGHT_CASTS_SHADOWS_ARRAY:
            case AutoConstantType.ACT_LIGHT_ATTENUATION:
            case AutoConstantType.ACT_SPOTLIGHT_PARAMS:
            case AutoConstantType.ACT_LIGHT_DIFFUSE_COLOUR_ARRAY:
            case AutoConstantType.ACT_LIGHT_SPECULAR_COLOUR_ARRAY:
            case AutoConstantType.ACT_LIGHT_DIFFUSE_COLOUR_POWER_SCALED_ARRAY:
            case AutoConstantType.ACT_LIGHT_SPECULAR_COLOUR_POWER_SCALED_ARRAY:
            case AutoConstantType.ACT_LIGHT_POSITION_ARRAY:
            case AutoConstantType.ACT_LIGHT_DIRECTION_ARRAY:
            case AutoConstantType.ACT_LIGHT_POSITION_VIEW_SPACE_ARRAY:
            case AutoConstantType.ACT_LIGHT_DIRECTION_VIEW_SPACE_ARRAY:
            case AutoConstantType.ACT_LIGHT_POWER_SCALE_ARRAY:
            case AutoConstantType.ACT_LIGHT_ATTENUATION_ARRAY:
            case AutoConstantType.ACT_SPOTLIGHT_PARAMS_ARRAY:
            case AutoConstantType.ACT_TEXTURE_VIEWPROJ_MATRIX:
            case AutoConstantType.ACT_TEXTURE_VIEWPROJ_MATRIX_ARRAY:
            case AutoConstantType.ACT_SPOTLIGHT_VIEWPROJ_MATRIX:
            case AutoConstantType.ACT_SPOTLIGHT_VIEWPROJ_MATRIX_ARRAY:
            case AutoConstantType.ACT_LIGHT_CUSTOM:
                
                return cast(ushort) GpuParamVariability.GPV_LIGHTS;
                
            case AutoConstantType.ACT_DERIVED_LIGHT_DIFFUSE_COLOUR:
            case AutoConstantType.ACT_DERIVED_LIGHT_SPECULAR_COLOUR:
            case AutoConstantType.ACT_DERIVED_LIGHT_DIFFUSE_COLOUR_ARRAY:
            case AutoConstantType.ACT_DERIVED_LIGHT_SPECULAR_COLOUR_ARRAY:
                
                return (cast(ushort) GpuParamVariability.GPV_GLOBAL | cast(ushort) GpuParamVariability.GPV_LIGHTS);
                
            case AutoConstantType.ACT_PASS_ITERATION_NUMBER:
                
                return cast(ushort) GpuParamVariability.GPV_PASS_ITERATION_NUMBER;
                
            default:
                return cast(ushort) GpuParamVariability.GPV_GLOBAL;
        };
        
    }
    
    void copySharedParamSetUsage(GpuSharedParamUsageList srcList)
    {
        mSharedParamSets.clear();
        foreach (i; srcList)
        {
            mSharedParamSets.insert(new GpuSharedParametersUsage(i.getSharedParams(), this));
        }
        
    }
    
    GpuSharedParamUsageList mSharedParamSets;
    
    // Optional data the rendersystem might want to store
    //mutable 
    Any mRenderSystemData;
    
    
    
public:
    this()
    {
        mCombinedVariability = GpuParamVariability.GPV_GLOBAL;
        mTransposeMatrices = false;
        mIgnoreMissingParams = false;
        mActivePassIterationIndex = size_t.max;
    }
    ~this() {}
    
    /// Copy constructor
    this(GpuProgramParameters oth)
    {
        this.copyFrom(oth);
    }
    /// Operator = overload
    //GpuProgramParameters& operator=(GpuProgramParameters oth);
    void copyFrom(GpuProgramParameters oth)
    {
        // let compiler perform shallow copies of structures 
        // AutoConstantEntry, RealConstantEntry, IntConstantEntry
        mFloatConstants = oth.mFloatConstants;
        mDoubleConstants = oth.mDoubleConstants;
        mIntConstants  = oth.mIntConstants;
        mAutoConstants = oth.mAutoConstants;
        mFloatLogicalToPhysical = oth.mFloatLogicalToPhysical;
        mDoubleLogicalToPhysical = oth.mDoubleLogicalToPhysical;
        mIntLogicalToPhysical = oth.mIntLogicalToPhysical;
        mNamedConstants = oth.mNamedConstants;
        copySharedParamSetUsage(oth.mSharedParamSets);
        
        mCombinedVariability = oth.mCombinedVariability;
        mTransposeMatrices = oth.mTransposeMatrices;
        mIgnoreMissingParams  = oth.mIgnoreMissingParams;
        mActivePassIterationIndex = oth.mActivePassIterationIndex;
        
        //return *this;
    }
    
    /** Internal method for providing a link to a name.definition map for parameters. */
    void _setNamedConstants(SharedPtr!(GpuNamedConstants*) namedConstants)
    {
        mNamedConstants = namedConstants;
        
        // Determine any extension to local buffers
        
        // Size and reset buffer (fill with zero to make comparison later ok)
        if (namedConstants.get().floatBufferSize > mFloatConstants.length)
        {
            mFloatConstants.length +=
                namedConstants.get().floatBufferSize - mFloatConstants.length;
        }
        if (namedConstants.get().intBufferSize > mIntConstants.length)
        {
            mIntConstants.length +=
                namedConstants.get().intBufferSize - mIntConstants.length;
        }
    }
    
    /** Internal method for providing a link to a logical index.physical index map for parameters. */
    void _setLogicalIndexes(SharedPtr!GpuLogicalBufferStruct floatIndexMap, 
                            SharedPtr!GpuLogicalBufferStruct doubleIndexMap,
                            SharedPtr!GpuLogicalBufferStruct intIndexMap)
    {
        mFloatLogicalToPhysical = floatIndexMap;
        mDoubleLogicalToPhysical = doubleIndexMap;
        mIntLogicalToPhysical = intIndexMap;
        
        // resize the internal buffers
        // Note that these will only contain something after the first parameter
        // set has set some parameters
        
        // Size and reset buffer (fill with zero to make comparison later ok)
        if (!floatIndexMap.isNull() && floatIndexMap.get().bufferSize > mFloatConstants.length)
        {
            mFloatConstants.length +=
                floatIndexMap.get().bufferSize - mFloatConstants.length;
        }
        if (!doubleIndexMap.isNull() && doubleIndexMap.bufferSize > mDoubleConstants.length)
        {
            mDoubleConstants.length +=
                doubleIndexMap.get().bufferSize - mDoubleConstants.length;
        }
        
        if (!intIndexMap.isNull() &&  intIndexMap.get().bufferSize > mIntConstants.length)
        {
            mIntConstants.length +=
                intIndexMap.get().bufferSize - mIntConstants.length;
        }
        
    }
    
    
    /// Does this parameter set include named parameters?
    bool hasNamedParameters(){ return !mNamedConstants.isNull(); }
    /** Does this parameter set include logically indexed parameters?
     @note Not mutually exclusive with hasNamedParameters since some high-level
     programs still use logical indexes to set the parameters on the 
     rendersystem.
     */
    bool hasLogicalIndexedParameters(){ return !mFloatLogicalToPhysical.isNull(); }
    
    /** Sets a 4-element floating-point parameter to the program.
     @param index The logical constant index at which to place the parameter 
     (each constant is a 4D float)
     @param vec The value to set
     */
    void setConstant(size_t index, Vector4 vec)
    {
        setConstant(index, vec.ptr(), 1);
    }
    /** Sets a single floating-point parameter to the program.
     @note This is actually equivalent to calling 
     setConstant(index Vector4(val, 0, 0, 0)) since all constants are 4D.
     @param index The logical constant index at which to place the parameter (each constant is
     a 4D float)
     @param val The value to set
     */
    void setConstant(size_t index, Real val)
    {
        setConstant(index, Vector4(val, 0.0f, 0.0f, 0.0f));
    }
    /** Sets a 4-element floating-point parameter to the program via Vector3.
     @param index The logical constant index at which to place the parameter (each constant is
     a 4D float).
     Note that since you're passing a Vector3, the last element of the 4-element
     value will be set to 1 (a homogeneous vector)
     @param vec The value to set
     */
    void setConstant(size_t index, Vector3 vec)
    {
        setConstant(index, Vector4(vec.x, vec.y, vec.z, 1.0f));
    }
    /** Sets a Matrix4 parameter to the program.
     @param index The logical constant index at which to place the parameter (each constant is
     a 4D float).
     NB since a Matrix4 is 16 floats long, this parameter will take up 4 indexes.
     @param m The value to set
     */
    void setConstant(size_t index, Matrix4 m)
    {
        // set as 4x 4-element floats
        if (mTransposeMatrices)
        {
            Matrix4 t = m.transpose();
            GpuProgramParameters.setConstant(index, t.ptr, 4);
        }
        else
        {
            GpuProgramParameters.setConstant(index, m.ptr, 4);
        }
        
    }
    /** Sets a list of Matrix4 parameters to the program.
     @param index The logical constant index at which to start placing the parameter (each constant is
     a 4D float).
     NB since a Matrix4 is 16 floats long, so each entry will take up 4 indexes.
     @param m Pointer to an array of matrices to set
     @param numEntries Number of Matrix4 entries
     */
    void setConstant(size_t index,Matrix4* pMatrix, size_t numEntries)
    {
        if (mTransposeMatrices)
        {
            for (size_t i = 0; i < numEntries; ++i)
            {
                Matrix4 t = pMatrix[i].transpose();
                GpuProgramParameters.setConstant(index, t[0].ptr, 4);
                index += 4;
            }
        }
        else
        {
            //FIXME Correct pointer acrobatics?
            GpuProgramParameters.setConstant(index, cast(Real*)&pMatrix[0]/*[0][0]*/, 4 * numEntries);
        }
        
    }
    /** Sets a multiple value constants floating-point parameter to the program.
     @param index The logical constant index at which to start placing parameters (each constant is
     a 4D float)
     @param val Pointer to the values to write, must contain 4*count floats
     @param count The number of groups of 4 floats to write
     */
    void setConstant(size_t index,float *val, size_t count)
    {
        // Raw buffer size is 4x count
        size_t rawCount = count * 4;
        // get physical index
        assert(!mFloatLogicalToPhysical.isNull(), "GpuProgram hasn't set up the logical . physical map!");
        
        size_t physicalIndex = _getFloatConstantPhysicalIndex(index, rawCount,  GpuParamVariability.GPV_GLOBAL);
        
        // Copy 
        _writeRawConstants(physicalIndex, val, rawCount);
        
    }
    
    /** Sets a multiple value constants floating-point parameter to the program.
     @param index The logical constant index at which to start placing parameters (each constant is
     a 4D float)
     @param val Pointer to the values to write, must contain 4*count floats
     @param count The number of groups of 4 floats to write
     */
    void setConstant(size_t index,double *val, size_t count)
    {
        // Raw buffer size is 4x count
        size_t rawCount = count * 4;
        // get physical index
        assert(!mFloatLogicalToPhysical.isNull(), "GpuProgram hasn't set up the logical . physical map!");
        
        size_t physicalIndex = _getFloatConstantPhysicalIndex(index, rawCount, GpuParamVariability.GPV_GLOBAL);
        assert(physicalIndex + rawCount <= mFloatConstants.length);
        // Copy manually since cast required
        for (size_t i = 0; i < rawCount; ++i)
        {
            mFloatConstants[physicalIndex + i] = 
                cast(float)(val[i]);
        }
        
    }
    
    /** Sets a ColourValue parameter to the program.
     @param index The logical constant index at which to place the parameter (each constant is
     a 4D float)
     @param colour The value to set
     */
    void setConstant(size_t index,ColourValue colour)
    {
        setConstant(index, colour.ptr(), 1);
    }
    /** Sets a multiple value constants integer parameter to the program.
     @remarks
     Different types of GPU programs support different types of constant parameters.
     For example, it's relatively common to find that vertex programs only support
     floating point constants, and that fragment programs only support integer (fixed point)
     parameters. This can vary depending on the program version supported by the
     graphics card being used. You should consult the documentation for the type of
     low level program you are using, or alternatively use the methods
     provided on RenderSystemCapabilities to determine the options.
     @param index The logical constant index at which to place the parameter (each constant is
     a 4D integer)
     @param val Pointer to the values to write, must contain 4*count ints
     @param count The number of groups of 4 ints to write
     */
    void setConstant(size_t index,int *val, size_t count)
    {
        // Raw buffer size is 4x count
        size_t rawCount = count * 4;
        // get physical index
        assert(!mIntLogicalToPhysical.isNull(), "GpuProgram hasn't set up the logical . physical map!");
        
        size_t physicalIndex = _getIntConstantPhysicalIndex(index, rawCount,  GpuParamVariability.GPV_GLOBAL);
        // Copy 
        _writeRawConstants(physicalIndex, val, rawCount);
    }
    
    /** Write a series of floating point values into the underlying float 
     constant buffer at the given physical index.
     @param physicalIndex The buffer position to start writing
     @param val Pointer to a list of values to write
     @param count The number of floats to write
     */
    void _writeRawConstants(size_t physicalIndex,float* val, size_t count)
    {
        assert(physicalIndex + count <= mFloatConstants.length);
        for (size_t i = 0; i < count; ++i)
        {
            mFloatConstants[physicalIndex+i] = cast(float)(val[i]);
        }
    }
    
    /** Write a series of floating point values into the underlying float 
     constant buffer at the given physical index.
     @param physicalIndex The buffer position to start writing
     @param val Pointer to a list of values to write
     @param count The number of floats to write
     */
    void _writeRawConstants(size_t physicalIndex,double* val, size_t count)
    {
        assert(physicalIndex + count <= mFloatConstants.length);
        memcpy(&mFloatConstants[physicalIndex], val, float.sizeof * count);
    }
    
    /** Write a series of integer values into the underlying integer
     constant buffer at the given physical index.
     @param physicalIndex The buffer position to start writing
     @param val Pointer to a list of values to write
     @param count The number of ints to write
     */
    void _writeRawConstants(size_t physicalIndex,int* val, size_t count)
    {
        assert(physicalIndex + count <= mIntConstants.length);
        memcpy(&mIntConstants[physicalIndex], val, int.sizeof * count);
    }
    
    /** Read a series of floating point values from the underlying float 
     constant buffer at the given physical index.
     @param physicalIndex The buffer position to start reading
     @param count The number of floats to read
     @param dest Pointer to a buffer to receive the values
     */
    void _readRawConstants(size_t physicalIndex, size_t count, float* dest)
    {
        assert(physicalIndex + count <= mFloatConstants.length);
        memcpy(dest, &mFloatConstants[physicalIndex], float.sizeof * count);
    }
    /** Read a series of integer values from the underlying integer 
     constant buffer at the given physical index.
     @param physicalIndex The buffer position to start reading
     @param count The number of ints to read
     @param dest Pointer to a buffer to receive the values
     */
    void _readRawConstants(size_t physicalIndex, size_t count, int* dest)
    {
        assert(physicalIndex + count <= mIntConstants.length);
        memcpy(dest, &mIntConstants[physicalIndex], int.sizeof * count);
    }
    
    /** Write a 4-element floating-point parameter to the program directly to 
     the underlying constants buffer.
     @note You can use these methods if you have already derived the physical
     constant buffer location, for a slight speed improvement over using
     the named / logical index versions.
     @param physicalIndex The physical buffer index at which to place the parameter 
     @param vec The value to set
     @param count The number of floats to write; if for example
     the uniformant 'slot' is smaller than a Vector4
     */
    void _writeRawConstant(size_t physicalIndex, Vector4 vec, 
                           size_t count = 4)
    {
        // remember, raw content access uses raw float count rather than float4
        // write either the number requested (for packed types) or up to 4
        _writeRawConstants(physicalIndex, vec.ptr(), std.algorithm.min(count, cast(size_t)4));
    }
    /** Write a single floating-point parameter to the program.
     @note You can use these methods if you have already derived the physical
     constant buffer location, for a slight speed improvement over using
     the named / logical index versions.
     @param physicalIndex The physical buffer index at which to place the parameter 
     @param val The value to set
     */
    void _writeRawConstant(size_t physicalIndex, Real val)
    {
        _writeRawConstants(physicalIndex, &val, 1);
    }
    
    /** Write a variable number of floating-point parameters to the program.
     @note You can use these methods if you have already derived the physical
     constant buffer location, for a slight speed improvement over using
     the named / logical index versions.
     @param physicalIndex The physical buffer index at which to place the parameter
     @param val The value to set
     */
    void _writeRawConstant(size_t physicalIndex, Real val, size_t count)
    {
        _writeRawConstants(physicalIndex, &val, count);
    }
    
    /** Write a single integer parameter to the program.
     @note You can use these methods if you have already derived the physical
     constant buffer location, for a slight speed improvement over using
     the named / logical index versions.
     @param physicalIndex The physical buffer index at which to place the parameter 
     @param val The value to set
     */
    void _writeRawConstant(size_t physicalIndex, int val)
    {
        _writeRawConstants(physicalIndex, &val, 1);
    }
    
    /** Write a 3-element floating-point parameter to the program via Vector3.
     @note You can use these methods if you have already derived the physical
     constant buffer location, for a slight speed improvement over using
     the named / logical index versions.
     @param physicalIndex The physical buffer index at which to place the parameter 
     @param vec The value to set
     */
    void _writeRawConstant(size_t physicalIndex, Vector3 vec)
    {
        _writeRawConstants(physicalIndex, vec.ptr(), 3);
    }
    /** Write a Matrix4 parameter to the program.
     @note You can use these methods if you have already derived the physical
     constant buffer location, for a slight speed improvement over using
     the named / logical index versions.
     @param physicalIndex The physical buffer index at which to place the parameter 
     @param m The value to set
     @param elementCount actual element count used with shader
     */
    void _writeRawConstant(size_t physicalIndex, Matrix4 m, size_t elementCount)
    {
        
        // remember, raw content access uses raw float count rather than float4
        if (mTransposeMatrices)
        {
            Matrix4 t = m.transpose();
            _writeRawConstants(physicalIndex, cast(Real*)&t, elementCount>16?16:elementCount);
        }
        else
        {
            _writeRawConstants(physicalIndex, cast(Real*)&m, elementCount>16?16:elementCount);
        }
        
    }
    /** Write a list of Matrix4 parameters to the program.
     @note You can use these methods if you have already derived the physical
     constant buffer location, for a slight speed improvement over using
     the named / logical index versions.
     @param physicalIndex The physical buffer index at which to place the parameter 
     @param numEntries Number of Matrix4 entries
     */
    void _writeRawConstant(size_t physicalIndex, Matrix4[] pMatrix, size_t numEntries)
    {
        // remember, raw content access uses raw float count rather than float4
        if (mTransposeMatrices)
        {
            for (size_t i = 0; i < numEntries; ++i)
            {
                Matrix4 t = pMatrix[i].transpose();
                _writeRawConstants(physicalIndex, cast(Real*)&t, 16);
                physicalIndex += 16;
            }
        }
        else
        {
            _writeRawConstants(physicalIndex, cast(Real*)pMatrix.ptr, 16 * numEntries);
        }
    }
    
    /** Write a ColourValue parameter to the program.
     @note You can use these methods if you have already derived the physical
     constant buffer location, for a slight speed improvement over using
     the named / logical index versions.
     @param physicalIndex The physical buffer index at which to place the parameter 
     @param colour The value to set
     @param count The number of floats to write; if for example
     the uniformant 'slot' is smaller than a Vector4
     */
    void _writeRawConstant(size_t physicalIndex,ColourValue colour, 
                           size_t count = 4)
    {
        // write either the number requested (for packed types) or up to 4
        _writeRawConstants(physicalIndex, colour.ptr(), std.algorithm.min(count, 4));
    }
    
    /** Gets an iterator over the named GpuConstantDefinition instances as defined
     by the program for which these parameters exist.
     @note
     Only available if this parameters object has named parameters.
     */
    //GpuConstantDefinitionIterator getConstantDefinitionIterator();
    ref GpuConstantDefinitionMap getConstantDefinitionMap()
    {
        if (mNamedConstants.isNull())
            throw new InvalidParamsError(
                "This params object is not based on a program with named parameters.",
                "GpuProgramParameters.getConstantDefinitionIterator");
        
        return mNamedConstants.get().map;
    }

    
    /** Get a specific GpuConstantDefinition for a named parameter.
     @note
     Only available if this parameters object has named parameters.
     */
    GpuConstantDefinition* getConstantDefinition(string name)
    {
        if (mNamedConstants.isNull())
            throw new InvalidParamsError( 
                                         "This params object is not based on a program with named parameters.",
                                         "GpuProgramParameters.getConstantDefinitionIterator");
        
        
        // locate, and throw exception if not found
        GpuConstantDefinition* def = _findNamedConstantDefinition(name, true);
        
        return def;
        
    }
    
    /** Get the full list of GpuConstantDefinition instances.
     @note
     Only available if this parameters object has named parameters.
     */
    SharedPtr!(GpuNamedConstants*) getConstantDefinitions()
    {
        if (mNamedConstants.isNull())
            throw new InvalidParamsError( 
                                         "This params object is not based on a program with named parameters.",
                                         "GpuProgramParameters.getConstantDefinitionIterator");
        
        return mNamedConstants;
    }
    
    /** Get the current list of mappings from low-level logical param indexes
     to physical buffer locations in the float buffer.
     @note
     Only applicable to low-level programs.
     */
    ref SharedPtr!GpuLogicalBufferStruct getFloatLogicalBufferStruct(){ return mFloatLogicalToPhysical; }
    
    /** Retrieves the logical index relating to a physical index in the float
     buffer, for programs which support that (low-level programs and 
     high-level programs which use logical parameter indexes).
     @return size_t.max if not found
     */
    size_t getFloatLogicalIndexForPhysicalIndex(size_t physicalIndex)
    {
        // perhaps build a reverse map of this sometime (shared in GpuProgram)
        foreach (k,v; mFloatLogicalToPhysical.get().map)
        {
            if (v.physicalIndex == physicalIndex)
                return k;
        }
        return size_t.max;
        
    }
    
    /** Get the current list of mappings from low-level logical param indexes
     to physical buffer locations in the double buffer.
     @note
     Only applicable to low-level programs.
     */
    ref SharedPtr!GpuLogicalBufferStruct getDoubleLogicalBufferStruct(){ return mDoubleLogicalToPhysical; }
    
    /** Retrieves the logical index relating to a physical index in the double
     buffer, for programs which support that (low-level programs and 
     high-level programs which use logical parameter indexes).
     @return size_t.max if not found
     */
    size_t getDoubleLogicalIndexForPhysicalIndex(size_t physicalIndex)
    {
        // perhaps build a reverse map of this sometime (shared in GpuProgram)
        foreach (k,v; mDoubleLogicalToPhysical.get().map)
        {
            if (v.physicalIndex == physicalIndex)
                return k;
        }
        return size_t.max;
    }
    
    
    /** Retrieves the logical index relating to a physical index in the int
     buffer, for programs which support that (low-level programs and 
     high-level programs which use logical parameter indexes).
     @return size_t.max if not found
     */
    size_t getIntLogicalIndexForPhysicalIndex(size_t physicalIndex)
    {
        // perhaps build a reverse map of this sometime (shared in GpuProgram)
        foreach (k,v; mIntLogicalToPhysical.get().map)
        {
            if (v.physicalIndex == physicalIndex)
                return k;
        }
        return size_t.max;
        
    }
    
    /** Get the current list of mappings from low-level logical param indexes
     to physical buffer locations in the integer buffer.
     @note
     Only applicable to low-level programs.
     */
    ref SharedPtr!GpuLogicalBufferStruct getIntLogicalBufferStruct(){ return mIntLogicalToPhysical; }
    /// Get a reference to the list of float constants
    ref FloatConstantList getFloatConstantList(){ return mFloatConstants; }
    /// Get a pointer to the 'nth' item in the float buffer
    //float* getFloatPointer(size_t pos) const { return &mFloatConstants[pos]; }
    /// Get a pointer to the 'nth' item in the float buffer
    float* getFloatPointer(size_t pos){ return &mFloatConstants[pos]; }
    /// Get a reference to the list of double constants
    ref DoubleConstantList getDoubleConstantList() { return mDoubleConstants; }
    ref const (DoubleConstantList) getDoubleConstantList() const { return mDoubleConstants; }
    /// Get a pointer to the 'nth' item in the double buffer
    double* getDoublePointer(size_t pos) { return &mDoubleConstants[pos]; }
    /// Get a pointer to the 'nth' item in the double buffer
    const (double)* getDoublePointer(size_t pos) const { return &mDoubleConstants[pos]; }
    /// Get a reference to the list of int constants
    ref IntConstantList getIntConstantList(){ return mIntConstants; }
    /// Get a pointer to the 'nth' item in the int buffer
    //int* getIntPointer(size_t pos) const { return &mIntConstants[pos]; }
    /// Get a pointer to the 'nth' item in the int buffer
    int* getIntPointer(size_t pos){ return &mIntConstants[pos]; }
    /// Get a reference to the list of auto constant bindings
    ref AutoConstantList getAutoConstantList(){ return mAutoConstants; }
    
    /** Sets up aant which will automatically be updated by the system.
     @remarks
     Vertex and fragment programs often need parameters which are to do with the
     current render state, or particular values which may very well change over time,
     and often between objects which are being rendered. This feature allows you 
     to set up a certain number of predefined parameter mappings that are kept up to 
     date for you.
     @param index The location in the constant list to place this updated constant every time
     it is changed. Note that because of the nature of the types, we know how big the 
     parameter details will be so you don't need to set that like you do for manual constants.
     @param acType The type of automatic constant to set
     @param extraInfo If the constant type needs more information (like a light index) put it here.
     */
    void setAutoConstant(size_t index, AutoConstantType acType, size_t extraInfo = 0)
    {
        // Get auto constant definition for sizing
        AutoConstantDefinition* autoDef = getAutoConstantDefinition(acType);
        
        if(!autoDef)
            throw new ItemNotFoundError("No constant definition found for type " ~ 
                                        std.conv.to!string(acType),
                                        "GpuProgramParameters.setAutoConstant");
        
        // round up to nearest multiple of 4
        size_t sz = autoDef.elementCount;
        if (sz % 4 > 0)
        {
            sz += 4 - (sz % 4);
        }
        
        GpuLogicalIndexUse* indexUse = _getFloatConstantLogicalIndexUse(index, sz, deriveVariability(acType));
        
        if(indexUse)
            _setRawAutoConstant(indexUse.physicalIndex, acType, extraInfo, indexUse.variability, sz);
    }
    
    void setAutoConstantReal(size_t index, AutoConstantType acType, Real rData)
    {
        // Get auto constant definition for sizing
        AutoConstantDefinition* autoDef = getAutoConstantDefinition(acType);
        
        if(!autoDef)
            throw new ItemNotFoundError("No constant definition found for type " ~ 
                                        std.conv.to!string(acType),
                                        "GpuProgramParameters.setAutoConstantReal");
        
        // round up to nearest multiple of 4
        size_t sz = autoDef.elementCount;
        if (sz % 4 > 0)
        {
            sz += 4 - (sz % 4);
        }
        
        GpuLogicalIndexUse* indexUse = _getFloatConstantLogicalIndexUse(index, sz, deriveVariability(acType));
        
        _setRawAutoConstantReal(indexUse.physicalIndex, acType, rData, indexUse.variability, sz);
    }
    
    /** Sets up aant which will automatically be updated by the system.
     @remarks
     Vertex and fragment programs often need parameters which are to do with the
     current render state, or particular values which may very well change over time,
     and often between objects which are being rendered. This feature allows you 
     to set up a certain number of predefined parameter mappings that are kept up to 
     date for you.
     @param index The location in the constant list to place this updated constant every time
     it is changed. Note that because of the nature of the types, we know how big the 
     parameter details will be so you don't need to set that like you do for manual constants.
     @param acType The type of automatic constant to set
     @param extraInfo1 The first extra parameter required by the auto constants type
     @param extraInfo2 The first extra parameter required by the auto constants type
     */
    void setAutoConstant(size_t index, AutoConstantType acType, ushort extraInfo1, ushort extraInfo2)
    {
        size_t extraInfo = cast(size_t)extraInfo1 | (cast(size_t)extraInfo2) << 16;
        
        // Get auto constants definition for sizing
        AutoConstantDefinition* autoDef = getAutoConstantDefinition(acType);
        
        if(!autoDef)
            throw new ItemNotFoundError("No constant definition found for type " ~ 
                                        std.conv.to!string(acType),
                                        "GpuProgramParameters.setAutoConstant");
        
        // round up to nearest multiple of 4
        size_t sz = autoDef.elementCount;
        if (sz % 4 > 0)
        {
            sz += 4 - (sz % 4);
        }
        
        GpuLogicalIndexUse* indexUse = _getFloatConstantLogicalIndexUse(index, sz, deriveVariability(acType));
        
        _setRawAutoConstant(indexUse.physicalIndex, acType, extraInfo, indexUse.variability, sz);
    }
    
    /** As setAutoConstant, but sets up the auto constants directly against a
     physical buffer index.
     */
    void _setRawAutoConstant(size_t physicalIndex, AutoConstantType acType, size_t extraInfo, 
                             ushort variability, size_t elementSize = 4)
    {
        // update existing index if it exists
        bool found = false;
        foreach (i; mAutoConstants)
        {
            if (i.physicalIndex == physicalIndex)
            {
                i.paramType = acType;
                i.data = extraInfo;
                i.elementCount = elementSize;
                i.variability = variability;
                found = true;
                break;
            }
        }
        if (!found)
            mAutoConstants.insert(new AutoConstantEntry(acType, physicalIndex, extraInfo, variability, elementSize));
        
        mCombinedVariability |= variability;
        
        
    }
    /** As setAutoConstantReal, but sets up the auto constants directly against a
     physical buffer index.
     */
    void _setRawAutoConstantReal(size_t physicalIndex, AutoConstantType acType, Real rData, 
                                 ushort variability, size_t elementSize = 4)
    {
        // update existing index if it exists
        bool found = false;
        foreach (i; mAutoConstants)
        {
            if (i.physicalIndex == physicalIndex)
            {
                i.paramType = acType;
                i.fData = rData;
                i.elementCount = elementSize;
                i.variability = variability;
                found = true;
                break;
            }
        }
        if (!found)
            mAutoConstants.insert(new AutoConstantEntry(acType, physicalIndex, rData, variability, elementSize));
        
        mCombinedVariability |= variability;
    }
    
    
    /** Unbind an auto constants so that the constant is manually controlled again. */
    void clearAutoConstant(size_t index)
    {
        GpuLogicalIndexUse* indexUse = _getFloatConstantLogicalIndexUse(index, 0, GpuParamVariability.GPV_GLOBAL);
        
        if (indexUse)
        {
            indexUse.variability = GpuParamVariability.GPV_GLOBAL;
            size_t physicalIndex = indexUse.physicalIndex;
            // update existing index if it exists
            foreach (i; mAutoConstants)
            {
                if (i.physicalIndex == physicalIndex)
                {
                    mAutoConstants.removeFromArray(i);
                    break;
                }
            }
        }
    }
    
    /** Sets a named parameter up to track a derivation of the current time.
     @param index The index of the parameter
     @param factor The amount by which to scale the time value
     */  
    void setConstantFromTime(size_t index, Real factor)
    {
        setAutoConstantReal(index,AutoConstantType.ACT_TIME, factor);
    }
    
    /** Clears all the existing automatic constants. */
    void clearAutoConstants()
    {
        mAutoConstants.clear();
        mCombinedVariability =  GpuParamVariability.GPV_GLOBAL;
    }
    
    //typedef ConstVectorIterator<AutoConstantList> AutoConstantIterator;
    /** Gets an iterator over the automatic constant bindings currently in place. */
    //AutoConstantIterator getAutoConstantIterator();
    /// Gets the number of int constants that have been set
    size_t getAutoConstantCount(){ return mAutoConstants.length; }
    /** Gets a specific Auto Constant entry if index is in valid range
     otherwise returns a NULL
     @param index which entry is to be retrieved
     */
    AutoConstantEntry* getAutoConstantEntry(size_t index)
    {
        if (index < mAutoConstants.length)
        {
            return &(mAutoConstants[index]);
        }
        else
        {
            return null;
        }
    }
    /** Returns true if this instance has any automatic constants. */
    bool hasAutoConstants(){ return !(mAutoConstants.empty()); }
    /** Finds an auto constants that's affecting a given logical parameter 
     index for floating-point values.
     @note Only applicable for low-level programs.
     */
    AutoConstantEntry findFloatAutoConstantEntry(size_t logicalIndex)
    {
        if (mFloatLogicalToPhysical.isNull())
            throw new InvalidParamsError( 
                                         "This is not a low-level parameter parameter object",
                                         "GpuProgramParameters.findFloatAutoConstantEntry");
        
        return _findRawAutoConstantEntryFloat(
            _getFloatConstantPhysicalIndex(logicalIndex, 0, GpuParamVariability.GPV_GLOBAL));
        
    }
    
    /** Finds an auto constant that's affecting a given logical parameter
         index for double-point values.
         @note Only applicable for low-level programs.
         */
    AutoConstantEntry findDoubleAutoConstantEntry(size_t logicalIndex)
    {
        if (mDoubleLogicalToPhysical.isNull())
            throw new InvalidParamsError( 
                                         "This is not a low-level parameter parameter object",
                                        "GpuProgramParameters.findDoubleAutoConstantEntry");
        
        return _findRawAutoConstantEntryDouble(
            _getDoubleConstantPhysicalIndex(logicalIndex, 0, GpuParamVariability.GPV_GLOBAL));
    }
    
    /** Finds an auto constants that's affecting a given logical parameter 
     index for integer values.
     @note Only applicable for low-level programs.
     */
    AutoConstantEntry findIntAutoConstantEntry(size_t logicalIndex)
    {
        if (mIntLogicalToPhysical.isNull())
            throw new InvalidParamsError( 
                                         "This is not a low-level parameter parameter object",
                                         "GpuProgramParameters.findIntAutoConstantEntry");
        
        return _findRawAutoConstantEntryInt(
            _getIntConstantPhysicalIndex(logicalIndex, 0, GpuParamVariability.GPV_GLOBAL));
        
        
    }
    
    /** Finds an auto constants that's affecting a given named parameter index.
     @note Only applicable to high-level programs.
     */
    AutoConstantEntry findAutoConstantEntry(string paramName)
    {
        if (mNamedConstants.isNull())
            throw new InvalidParamsError( 
                                         "This params object is not based on a program with named parameters.",
                                         "GpuProgramParameters.findAutoConstantEntry");
        
        GpuConstantDefinition* def = getConstantDefinition(paramName);
        if (def.isFloat())
        {
            return _findRawAutoConstantEntryFloat(def.physicalIndex);
        }
        else
        {
            return _findRawAutoConstantEntryInt(def.physicalIndex);
        }
    }
    /** Finds an auto constants that's affecting a given physical position in 
     the floating-point buffer
     */
    AutoConstantEntry _findRawAutoConstantEntryFloat(size_t physicalIndex)
    {
        foreach(ac; mAutoConstants)
        {
            // should check that auto is float and not int so that physicalIndex
            // doesn't have any ambiguity
            // However, all autos are float I think so no need
            if (ac.physicalIndex == physicalIndex)
                return ac;
        }
        
        return null;
        
    }
    
    /** Finds an auto constants that's affecting a given physical position in 
     the double-point buffer
     */
    AutoConstantEntry _findRawAutoConstantEntryDouble(size_t physicalIndex)
    {
        foreach(ac; mAutoConstants)
        {
            // should check that auto is double and not int or float so that physicalIndex
            // doesn't have any ambiguity
            // However, all autos are float I think so no need
            if (ac.physicalIndex == physicalIndex)
                return ac;
        }
        
        return null;
        
    }
    
    /** Finds an auto constants that's affecting a given physical position in 
     the integer buffer
     */
    AutoConstantEntry _findRawAutoConstantEntryInt(size_t physicalIndex)
    {
        // No autos are float?
        return null;
    }
    
    /** Update automatic parameters.
     @param source The source of the parameters
     @param variabilityMask A mask of GpuParamVariability which identifies which autos will need updating
     */
    void _updateAutoParams(AutoParamDataSource source, ushort variabilityMask)
    {
        // abort early if no autos
        if (!hasAutoConstants()) return; 
        // abort early if variability doesn't match any param
        if (!(variabilityMask & mCombinedVariability)) 
            return; 
        
        size_t index;
        size_t numMatrices;
        Matrix4[] pMatrix;
        size_t m;
        Vector3 vec3;
        Vector4 vec4;
        Matrix3 m3;
        Matrix4 scaleM;
        DualQuaternion dQuat;
        
        mActivePassIterationIndex = size_t.max;
        
        // Autoconstant index is not a physical index
        foreach (i; mAutoConstants)
        {
            // Only update needed slots
            if (i.variability & variabilityMask)
            {
                
                switch(i.paramType)
                {
                    case AutoConstantType.ACT_VIEW_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getViewMatrix(),i.elementCount);
                        break;
                    case AutoConstantType.ACT_INVERSE_VIEW_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getInverseViewMatrix(),i.elementCount);
                        break;
                    case AutoConstantType.ACT_TRANSPOSE_VIEW_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getTransposeViewMatrix(),i.elementCount);
                        break;
                    case AutoConstantType.ACT_INVERSE_TRANSPOSE_VIEW_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getInverseTransposeViewMatrix(),i.elementCount);
                        break;
                        
                    case AutoConstantType.ACT_PROJECTION_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getProjectionMatrix(),i.elementCount);
                        break;
                    case AutoConstantType.ACT_INVERSE_PROJECTION_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getInverseProjectionMatrix(),i.elementCount);
                        break;
                    case AutoConstantType.ACT_TRANSPOSE_PROJECTION_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getTransposeProjectionMatrix(),i.elementCount);
                        break;
                    case AutoConstantType.ACT_INVERSE_TRANSPOSE_PROJECTION_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getInverseTransposeProjectionMatrix(),i.elementCount);
                        break;
                        
                    case AutoConstantType.ACT_VIEWPROJ_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getViewProjectionMatrix(),i.elementCount);
                        break;
                    case AutoConstantType.ACT_INVERSE_VIEWPROJ_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getInverseViewProjMatrix(),i.elementCount);
                        break;
                    case AutoConstantType.ACT_TRANSPOSE_VIEWPROJ_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getTransposeViewProjMatrix(),i.elementCount);
                        break;
                    case AutoConstantType.ACT_INVERSE_TRANSPOSE_VIEWPROJ_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getInverseTransposeViewProjMatrix(),i.elementCount);
                        break;
                    case AutoConstantType.ACT_RENDER_TARGET_FLIPPING:
                        _writeRawConstant(i.physicalIndex, source.getCurrentRenderTarget().requiresTextureFlipping() ? -1f : +1f);
                        break;
                    case AutoConstantType.ACT_VERTEX_WINDING:
                    {
                        RenderSystem rsys = Root.getSingleton().getRenderSystem();
                        _writeRawConstant(i.physicalIndex, rsys.getInvertVertexWinding() ? -1f : +1f);
                    }
                        break;
                        
                        // NB ambient light still here because it's not related to a specific light
                    case AutoConstantType.ACT_AMBIENT_LIGHT_COLOUR: 
                        _writeRawConstant(i.physicalIndex, source.getAmbientLightColour(), 
                                          i.elementCount);
                        break;
                    case AutoConstantType.ACT_DERIVED_AMBIENT_LIGHT_COLOUR:
                        _writeRawConstant(i.physicalIndex, source.getDerivedAmbientLightColour(),
                                          i.elementCount);
                        break;
                    case AutoConstantType.ACT_DERIVED_SCENE_COLOUR:
                        _writeRawConstant(i.physicalIndex, source.getDerivedSceneColour(),
                                          i.elementCount);
                        break;
                        
                    case AutoConstantType.ACT_FOG_COLOUR:
                        _writeRawConstant(i.physicalIndex, source.getFogColour());
                        break;
                    case AutoConstantType.ACT_FOG_PARAMS:
                        _writeRawConstant(i.physicalIndex, source.getFogParams(), i.elementCount);
                        break;
                        
                    case AutoConstantType.ACT_SURFACE_AMBIENT_COLOUR:
                        _writeRawConstant(i.physicalIndex, source.getSurfaceAmbientColour(),
                                          i.elementCount);
                        break;
                    case AutoConstantType.ACT_SURFACE_DIFFUSE_COLOUR:
                        _writeRawConstant(i.physicalIndex, source.getSurfaceDiffuseColour(),
                                          i.elementCount);
                        break;
                    case AutoConstantType.ACT_SURFACE_SPECULAR_COLOUR:
                        _writeRawConstant(i.physicalIndex, source.getSurfaceSpecularColour(),
                                          i.elementCount);
                        break;
                    case AutoConstantType.ACT_SURFACE_EMISSIVE_COLOUR:
                        _writeRawConstant(i.physicalIndex, source.getSurfaceEmissiveColour(),
                                          i.elementCount);
                        break;
                    case AutoConstantType.ACT_SURFACE_SHININESS:
                        _writeRawConstant(i.physicalIndex, source.getSurfaceShininess());
                        break;
                    case AutoConstantType.ACT_SURFACE_ALPHA_REJECTION_VALUE:
                        _writeRawConstant(i.physicalIndex, source.getSurfaceAlphaRejectionValue());
                        break;
                        
                    case AutoConstantType.ACT_CAMERA_POSITION:
                        _writeRawConstant(i.physicalIndex, source.getCameraPosition(), i.elementCount);
                        break;
                    case AutoConstantType.ACT_TIME:
                        _writeRawConstant(i.physicalIndex, source.getTime() * i.fData);
                        break;
                    case AutoConstantType.ACT_TIME_0_X:
                        _writeRawConstant(i.physicalIndex, source.getTime_0_X(i.fData));
                        break;
                    case AutoConstantType.ACT_COSTIME_0_X:
                        _writeRawConstant(i.physicalIndex, source.getCosTime_0_X(i.fData));
                        break;
                    case AutoConstantType.ACT_SINTIME_0_X:
                        _writeRawConstant(i.physicalIndex, source.getSinTime_0_X(i.fData));
                        break;
                    case AutoConstantType.ACT_TANTIME_0_X:
                        _writeRawConstant(i.physicalIndex, source.getTanTime_0_X(i.fData));
                        break;
                    case AutoConstantType.ACT_TIME_0_X_PACKED:
                        _writeRawConstant(i.physicalIndex, source.getTime_0_X_packed(i.fData), i.elementCount);
                        break;
                    case AutoConstantType.ACT_TIME_0_1:
                        _writeRawConstant(i.physicalIndex, source.getTime_0_1(i.fData));
                        break;
                    case AutoConstantType.ACT_COSTIME_0_1:
                        _writeRawConstant(i.physicalIndex, source.getCosTime_0_1(i.fData));
                        break;
                    case AutoConstantType.ACT_SINTIME_0_1:
                        _writeRawConstant(i.physicalIndex, source.getSinTime_0_1(i.fData));
                        break;
                    case AutoConstantType.ACT_TANTIME_0_1:
                        _writeRawConstant(i.physicalIndex, source.getTanTime_0_1(i.fData));
                        break;
                    case AutoConstantType.ACT_TIME_0_1_PACKED:
                        _writeRawConstant(i.physicalIndex, source.getTime_0_1_packed(i.fData), i.elementCount);
                        break;
                    case AutoConstantType.ACT_TIME_0_2PI:
                        _writeRawConstant(i.physicalIndex, source.getTime_0_2Pi(i.fData));
                        break;
                    case AutoConstantType.ACT_COSTIME_0_2PI:
                        _writeRawConstant(i.physicalIndex, source.getCosTime_0_2Pi(i.fData));
                        break;
                    case AutoConstantType.ACT_SINTIME_0_2PI:
                        _writeRawConstant(i.physicalIndex, source.getSinTime_0_2Pi(i.fData));
                        break;
                    case AutoConstantType.ACT_TANTIME_0_2PI:
                        _writeRawConstant(i.physicalIndex, source.getTanTime_0_2Pi(i.fData));
                        break;
                    case AutoConstantType.ACT_TIME_0_2PI_PACKED:
                        _writeRawConstant(i.physicalIndex, source.getTime_0_2Pi_packed(i.fData), i.elementCount);
                        break;
                    case AutoConstantType.ACT_FRAME_TIME:
                        _writeRawConstant(i.physicalIndex, source.getFrameTime() * i.fData);
                        break;
                    case AutoConstantType.ACT_FPS:
                        _writeRawConstant(i.physicalIndex, source.getFPS());
                        break;
                    case AutoConstantType.ACT_VIEWPORT_WIDTH:
                        _writeRawConstant(i.physicalIndex, source.getViewportWidth());
                        break;
                    case AutoConstantType.ACT_VIEWPORT_HEIGHT:
                        _writeRawConstant(i.physicalIndex, source.getViewportHeight());
                        break;
                    case AutoConstantType.ACT_INVERSE_VIEWPORT_WIDTH:
                        _writeRawConstant(i.physicalIndex, source.getInverseViewportWidth());
                        break;
                    case AutoConstantType.ACT_INVERSE_VIEWPORT_HEIGHT:
                        _writeRawConstant(i.physicalIndex, source.getInverseViewportHeight());
                        break;
                    case AutoConstantType.ACT_VIEWPORT_SIZE:
                        _writeRawConstant(i.physicalIndex, Vector4(
                        source.getViewportWidth(),
                        source.getViewportHeight(),
                        source.getInverseViewportWidth(),
                        source.getInverseViewportHeight()), i.elementCount);
                        break;
                    case AutoConstantType.ACT_TEXEL_OFFSETS:
                    {
                        RenderSystem rsys = Root.getSingleton().getRenderSystem();
                        _writeRawConstant(i.physicalIndex, Vector4(
                            rsys.getHorizontalTexelOffset(), 
                            rsys.getVerticalTexelOffset(), 
                            rsys.getHorizontalTexelOffset() * source.getInverseViewportWidth(),
                            rsys.getVerticalTexelOffset() * source.getInverseViewportHeight()),
                                          i.elementCount);
                    }
                        break;
                    case AutoConstantType.ACT_TEXTURE_SIZE:
                        _writeRawConstant(i.physicalIndex, source.getTextureSize(i.data), i.elementCount);
                        break;
                    case AutoConstantType.ACT_INVERSE_TEXTURE_SIZE:
                        _writeRawConstant(i.physicalIndex, source.getInverseTextureSize(i.data), i.elementCount);
                        break;
                    case AutoConstantType.ACT_PACKED_TEXTURE_SIZE:
                        _writeRawConstant(i.physicalIndex, source.getPackedTextureSize(i.data), i.elementCount);
                        break;
                    case AutoConstantType.ACT_SCENE_DEPTH_RANGE:
                        _writeRawConstant(i.physicalIndex, source.getSceneDepthRange(), i.elementCount);
                        break;
                    case AutoConstantType.ACT_VIEW_DIRECTION:
                        _writeRawConstant(i.physicalIndex, source.getViewDirection());
                        break;
                    case AutoConstantType.ACT_VIEW_SIDE_VECTOR:
                        _writeRawConstant(i.physicalIndex, source.getViewSideVector());
                        break;
                    case AutoConstantType.ACT_VIEW_UP_VECTOR:
                        _writeRawConstant(i.physicalIndex, source.getViewUpVector());
                        break;
                    case AutoConstantType.ACT_FOV:
                        _writeRawConstant(i.physicalIndex, source.getFOV());
                        break;
                    case AutoConstantType.ACT_NEAR_CLIP_DISTANCE:
                        _writeRawConstant(i.physicalIndex, source.getNearClipDistance());
                        break;
                    case AutoConstantType.ACT_FAR_CLIP_DISTANCE:
                        _writeRawConstant(i.physicalIndex, source.getFarClipDistance());
                        break;
                    case AutoConstantType.ACT_PASS_NUMBER:
                        _writeRawConstant(i.physicalIndex, cast(float)source.getPassNumber());
                        break;
                    case AutoConstantType.ACT_PASS_ITERATION_NUMBER:
                        // this is actually just an initial set-up, it's bound separately, so still global
                        _writeRawConstant(i.physicalIndex, 0.0f);
                        mActivePassIterationIndex = i.physicalIndex;
                        break;
                    case AutoConstantType.ACT_TEXTURE_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getTextureTransformMatrix(i.data),i.elementCount);
                        break;
                    case AutoConstantType.ACT_LOD_CAMERA_POSITION:
                        _writeRawConstant(i.physicalIndex, source.getLodCameraPosition(), i.elementCount);
                        break;
                        
                    case AutoConstantType.ACT_TEXTURE_WORLDVIEWPROJ_MATRIX:
                        // can also be updated in lights
                        _writeRawConstant(i.physicalIndex, source.getTextureWorldViewProjMatrix(i.data),i.elementCount);
                        break;
                    case AutoConstantType.ACT_TEXTURE_WORLDVIEWPROJ_MATRIX_ARRAY:
                        for (size_t l = 0; l < i.data; ++l)
                        {
                            // can also be updated in lights
                            _writeRawConstant(i.physicalIndex + l*i.elementCount, 
                                              source.getTextureWorldViewProjMatrix(l),i.elementCount);
                        }
                        break;
                    case AutoConstantType.ACT_SPOTLIGHT_WORLDVIEWPROJ_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getSpotlightWorldViewProjMatrix(i.data),i.elementCount);
                        break;
                    case AutoConstantType.ACT_SPOTLIGHT_WORLDVIEWPROJ_MATRIX_ARRAY:
                        for (size_t l = 0; l < i.data; ++l)
                            _writeRawConstant(i.physicalIndex + l*i.elementCount, source.getSpotlightWorldViewProjMatrix(i.data), i.elementCount);
                        break;
                        
                    case AutoConstantType.ACT_LIGHT_POSITION_OBJECT_SPACE:
                        _writeRawConstant(i.physicalIndex, 
                                          source.getInverseWorldMatrix().transformAffine(
                        source.getLightAs4DVector(i.data)), 
                                          i.elementCount);
                        break;
                    case AutoConstantType.ACT_LIGHT_DIRECTION_OBJECT_SPACE:
                        // We need the inverse of the inverse transpose 
                        source.getInverseTransposeWorldMatrix().inverse().extract3x3Matrix(m3);
                        vec3 = m3 * source.getLightDirection(i.data);
                        vec3.normalise();
                        // Set as 4D vector for compatibility
                        _writeRawConstant(i.physicalIndex, Vector4(vec3.x, vec3.y, vec3.z, 0.0f), i.elementCount);
                        break;
                    case AutoConstantType.ACT_LIGHT_DISTANCE_OBJECT_SPACE:
                        vec3 = source.getInverseWorldMatrix().transformAffine(source.getLightPosition(i.data));
                        _writeRawConstant(i.physicalIndex, vec3.length());
                        break;
                    case AutoConstantType.ACT_LIGHT_POSITION_OBJECT_SPACE_ARRAY:
                        for (size_t l = 0; l < i.data; ++l)
                            _writeRawConstant(i.physicalIndex + l*i.elementCount, 
                                              source.getInverseWorldMatrix().transformAffine(
                                source.getLightAs4DVector(l)), 
                                              i.elementCount);
                        break;
                        
                    case AutoConstantType.ACT_LIGHT_DIRECTION_OBJECT_SPACE_ARRAY:
                        // We need the inverse of the inverse transpose 
                        source.getInverseTransposeWorldMatrix().inverse().extract3x3Matrix(m3);
                        for (size_t l = 0; l < i.data; ++l)
                        {
                            vec3 = m3 * source.getLightDirection(l);
                            vec3.normalise();
                            _writeRawConstant(i.physicalIndex + l*i.elementCount, 
                                              Vector4(vec3.x, vec3.y, vec3.z, 0.0f), i.elementCount); 
                        }
                        break;
                        
                    case AutoConstantType.ACT_LIGHT_DISTANCE_OBJECT_SPACE_ARRAY:
                        for (size_t l = 0; l < i.data; ++l)
                        {
                            vec3 = source.getInverseWorldMatrix().transformAffine(source.getLightPosition(l));
                            _writeRawConstant(i.physicalIndex + l*i.elementCount, vec3.length());
                        }
                        break;
                        
                    case AutoConstantType.ACT_WORLD_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getWorldMatrix(),i.elementCount);
                        break;
                    case AutoConstantType.ACT_INVERSE_WORLD_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getInverseWorldMatrix(),i.elementCount);
                        break;
                    case AutoConstantType.ACT_TRANSPOSE_WORLD_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getTransposeWorldMatrix(),i.elementCount);
                        break;
                    case AutoConstantType.ACT_INVERSE_TRANSPOSE_WORLD_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getInverseTransposeWorldMatrix(),i.elementCount);
                        break;
                        
                    case AutoConstantType.ACT_WORLD_MATRIX_ARRAY_3x4:
                        // Loop over matrices
                        pMatrix = source.getWorldMatrixArray();
                        numMatrices = source.getWorldMatrixCount();
                        index = i.physicalIndex;
                        for (m = 0; m < numMatrices; ++m)
                        {
                            _writeRawConstant(index, pMatrix[m], 12);
                            index += 12;
                        }
                        break;
                    case AutoConstantType.ACT_WORLD_MATRIX_ARRAY:
                        _writeRawConstant(i.physicalIndex, source.getWorldMatrixArray(), 
                                          source.getWorldMatrixCount());
                        break;
                    case AutoConstantType.ACT_WORLD_DUALQUATERNION_ARRAY_2x4:
                        // Loop over matrices
                        pMatrix = source.getWorldMatrixArray();
                        numMatrices = source.getWorldMatrixCount();
                        index = i.physicalIndex;
                        for (m = 0; m < numMatrices; ++m)
                        {
                            dQuat.fromTransformationMatrix(pMatrix[m]);
                            _writeRawConstants(index, dQuat.ptr(), 8);
                            index += 8;
                        }
                        break;
                    case AutoConstantType.ACT_WORLD_SCALE_SHEAR_MATRIX_ARRAY_3x4:
                        // Loop over matrices
                        pMatrix = source.getWorldMatrixArray();
                        numMatrices = source.getWorldMatrixCount();
                        index = i.physicalIndex;
                        
                        scaleM = Matrix4.IDENTITY;
                        
                        for (m = 0; m < numMatrices; ++m)
                        {
                            //Based on Matrix4.decompostion, but we don't need the rotation or position components
                            //but do need the scaling and shearing. Shearing isn't available from Matrix4.decomposition
                            assert(pMatrix[m].isAffine());
                            
                            pMatrix[m].extract3x3Matrix(m3);
                            
                            Matrix3 matQ;
                            Vector3 scale;
                            
                            //vecU is the scaling component with vecU[0] = u01, vecU[1] = u02, vecU[2] = u12
                            //vecU[0] is shearing (x,y), vecU[1] is shearing (x,z), and vecU[2] is shearing (y,z)
                            //The first component represents the coordinate that is being sheared,
                            //while the second component represents the coordinate which performs the shearing.
                            Vector3 vecU;
                            m3.QDUDecomposition( matQ, scale, vecU );
                            
                            scaleM[0, 0] = scale.x;
                            scaleM[1, 1] = scale.y;
                            scaleM[2, 2] = scale.z;
                            
                            scaleM[0, 1] = vecU[0];
                            scaleM[0, 2] = vecU[1];
                            scaleM[1, 2] = vecU[2];
                            
                            _writeRawConstants(index, scaleM.ptr, 12);
                            index += 12;
                        }
                        break;
                    case AutoConstantType.ACT_WORLDVIEW_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getWorldViewMatrix(),i.elementCount);
                        break;
                    case AutoConstantType.ACT_INVERSE_WORLDVIEW_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getInverseWorldViewMatrix(),i.elementCount);
                        break;
                    case AutoConstantType.ACT_TRANSPOSE_WORLDVIEW_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getTransposeWorldViewMatrix(),i.elementCount);
                        break;
                    case AutoConstantType.ACT_INVERSE_TRANSPOSE_WORLDVIEW_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getInverseTransposeWorldViewMatrix(),i.elementCount);
                        break;
                        
                    case AutoConstantType.ACT_WORLDVIEWPROJ_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getWorldViewProjMatrix(),i.elementCount);
                        break;
                    case AutoConstantType.ACT_INVERSE_WORLDVIEWPROJ_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getInverseWorldViewProjMatrix(),i.elementCount);
                        break;
                    case AutoConstantType.ACT_TRANSPOSE_WORLDVIEWPROJ_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getTransposeWorldViewProjMatrix(),i.elementCount);
                        break;
                    case AutoConstantType.ACT_INVERSE_TRANSPOSE_WORLDVIEWPROJ_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getInverseTransposeWorldViewProjMatrix(),i.elementCount);
                        break;
                    case AutoConstantType.ACT_CAMERA_POSITION_OBJECT_SPACE:
                        _writeRawConstant(i.physicalIndex, source.getCameraPositionObjectSpace(), i.elementCount);
                        break;
                    case AutoConstantType.ACT_LOD_CAMERA_POSITION_OBJECT_SPACE:
                        _writeRawConstant(i.physicalIndex, source.getLodCameraPositionObjectSpace(), i.elementCount);
                        break;
                        
                    case AutoConstantType.ACT_CUSTOM:
                    case AutoConstantType.ACT_ANIMATION_PARAMETRIC:
                        source.getCurrentRenderable()._updateCustomGpuParameter(i, this);
                        break;
                    case AutoConstantType.ACT_LIGHT_CUSTOM:
                        source.updateLightCustomGpuParameter(i, this);
                        break;
                    case AutoConstantType.ACT_LIGHT_COUNT:
                        _writeRawConstant(i.physicalIndex, source.getLightCount());
                        break;
                    case AutoConstantType.ACT_LIGHT_DIFFUSE_COLOUR:
                        _writeRawConstant(i.physicalIndex, source.getLightDiffuseColour(i.data), i.elementCount);
                        break;
                    case AutoConstantType.ACT_LIGHT_SPECULAR_COLOUR:
                        _writeRawConstant(i.physicalIndex, source.getLightSpecularColour(i.data), i.elementCount);
                        break;
                    case AutoConstantType.ACT_LIGHT_POSITION:
                        // Get as 4D vector, works for directional lights too
                        // Use element count in case uniform slot is smaller
                        _writeRawConstant(i.physicalIndex, 
                                          source.getLightAs4DVector(i.data), i.elementCount);
                        break;
                    case AutoConstantType.ACT_LIGHT_DIRECTION:
                        vec3 = source.getLightDirection(i.data);
                        // Set as 4D vector for compatibility
                        // Use element count in case uniform slot is smaller
                        _writeRawConstant(i.physicalIndex, Vector4(vec3.x, vec3.y, vec3.z, 1.0f), i.elementCount);
                        break;
                    case AutoConstantType.ACT_LIGHT_POSITION_VIEW_SPACE:
                        _writeRawConstant(i.physicalIndex, 
                                          source.getViewMatrix().transformAffine(source.getLightAs4DVector(i.data)), i.elementCount);
                        break;
                    case AutoConstantType.ACT_LIGHT_DIRECTION_VIEW_SPACE:
                        source.getInverseTransposeViewMatrix().extract3x3Matrix(m3);
                        // inverse transpose in case of scaling
                        vec3 = m3 * source.getLightDirection(i.data);
                        vec3.normalise();
                        // Set as 4D vector for compatibility
                        _writeRawConstant(i.physicalIndex, Vector4(vec3.x, vec3.y, vec3.z, 0.0f),i.elementCount);
                        break;
                    case AutoConstantType.ACT_SHADOW_EXTRUSION_DISTANCE:
                        // extrusion is in object-space, so we have to rescale by the inverse
                        // of the world scaling to deal with scaled objects
                        source.getWorldMatrix().extract3x3Matrix(m3);
                        _writeRawConstant(i.physicalIndex, source.getShadowExtrusionDistance() / 
                                          Math.Sqrt(std.algorithm.max(std.algorithm.max(m3.GetColumn(0).squaredLength(), 
                                                                  m3.GetColumn(1).squaredLength()), m3.GetColumn(2).squaredLength())));
                        break;
                    case AutoConstantType.ACT_SHADOW_SCENE_DEPTH_RANGE:
                        _writeRawConstant(i.physicalIndex, source.getShadowSceneDepthRange(i.data));
                        break;
                    case AutoConstantType.ACT_SHADOW_SCENE_DEPTH_RANGE_ARRAY:
                        for (size_t l = 0; l < i.data; ++l)
                            _writeRawConstant(i.physicalIndex + l*i.elementCount, source.getShadowSceneDepthRange(i.data), i.elementCount);
                        break;
                    case AutoConstantType.ACT_SHADOW_COLOUR:
                        _writeRawConstant(i.physicalIndex, source.getShadowColour(), i.elementCount);
                        break;
                    case AutoConstantType.ACT_LIGHT_POWER_SCALE:
                        _writeRawConstant(i.physicalIndex, source.getLightPowerScale(i.data));
                        break;
                    case AutoConstantType.ACT_LIGHT_DIFFUSE_COLOUR_POWER_SCALED:
                        _writeRawConstant(i.physicalIndex, source.getLightDiffuseColourWithPower(i.data), i.elementCount);
                        break;
                    case AutoConstantType.ACT_LIGHT_SPECULAR_COLOUR_POWER_SCALED:
                        _writeRawConstant(i.physicalIndex, source.getLightSpecularColourWithPower(i.data), i.elementCount);
                        break;
                    case AutoConstantType.ACT_LIGHT_NUMBER:
                        _writeRawConstant(i.physicalIndex, source.getLightNumber(i.data));
                        break;
                    case AutoConstantType.ACT_LIGHT_CASTS_SHADOWS:
                        _writeRawConstant(i.physicalIndex, source.getLightCastsShadows(i.data));
                        break;
                    case AutoConstantType.ACT_LIGHT_CASTS_SHADOWS_ARRAY:
                        for (size_t l = 0; l < i.data; ++l)
                            _writeRawConstant(i.physicalIndex + l*i.elementCount, source.getLightCastsShadows(i.data), i.elementCount);
                        break;
                    case AutoConstantType.ACT_LIGHT_ATTENUATION:
                        _writeRawConstant(i.physicalIndex, source.getLightAttenuation(i.data), i.elementCount);
                        break;
                    case AutoConstantType.ACT_SPOTLIGHT_PARAMS:
                        _writeRawConstant(i.physicalIndex, source.getSpotlightParams(i.data), i.elementCount);
                        break;
                    case AutoConstantType.ACT_LIGHT_DIFFUSE_COLOUR_ARRAY:
                        for (size_t l = 0; l < i.data; ++l)
                            _writeRawConstant(i.physicalIndex + l*i.elementCount, 
                                              source.getLightDiffuseColour(l), i.elementCount);
                        break;
                        
                    case AutoConstantType.ACT_LIGHT_SPECULAR_COLOUR_ARRAY:
                        for (size_t l = 0; l < i.data; ++l)
                            _writeRawConstant(i.physicalIndex + l*i.elementCount, 
                                              source.getLightSpecularColour(l), i.elementCount);
                        break;
                    case AutoConstantType.ACT_LIGHT_DIFFUSE_COLOUR_POWER_SCALED_ARRAY:
                        for (size_t l = 0; l < i.data; ++l)
                            _writeRawConstant(i.physicalIndex + l*i.elementCount, 
                                              source.getLightDiffuseColourWithPower(l), i.elementCount);
                        break;
                        
                    case AutoConstantType.ACT_LIGHT_SPECULAR_COLOUR_POWER_SCALED_ARRAY:
                        for (size_t l = 0; l < i.data; ++l)
                            _writeRawConstant(i.physicalIndex + l*i.elementCount, 
                                              source.getLightSpecularColourWithPower(l), i.elementCount);
                        break;
                        
                    case AutoConstantType.ACT_LIGHT_POSITION_ARRAY:
                        // Get as 4D vector, works for directional lights too
                        for (size_t l = 0; l < i.data; ++l)
                            _writeRawConstant(i.physicalIndex + l*i.elementCount, 
                                              source.getLightAs4DVector(l), i.elementCount);
                        break;
                        
                    case AutoConstantType.ACT_LIGHT_DIRECTION_ARRAY:
                        for (size_t l = 0; l < i.data; ++l)
                        {
                            vec3 = source.getLightDirection(l);
                            // Set as 4D vector for compatibility
                            _writeRawConstant(i.physicalIndex + l*i.elementCount, 
                                              Vector4(vec3.x, vec3.y, vec3.z, 0.0f), i.elementCount);
                        }
                        break;
                        
                    case AutoConstantType.ACT_LIGHT_POSITION_VIEW_SPACE_ARRAY:
                        for (size_t l = 0; l < i.data; ++l)
                            _writeRawConstant(i.physicalIndex + l*i.elementCount, 
                                              source.getViewMatrix().transformAffine(
                                source.getLightAs4DVector(l)),
                                              i.elementCount);
                        break;
                        
                    case AutoConstantType.ACT_LIGHT_DIRECTION_VIEW_SPACE_ARRAY:
                        source.getInverseTransposeViewMatrix().extract3x3Matrix(m3);
                        for (size_t l = 0; l < i.data; ++l)
                        {
                            vec3 = m3 * source.getLightDirection(l);
                            vec3.normalise();
                            // Set as 4D vector for compatibility
                            _writeRawConstant(i.physicalIndex + l*i.elementCount, 
                                              Vector4(vec3.x, vec3.y, vec3.z, 0.0f), i.elementCount);
                        }
                        break;
                        
                    case AutoConstantType.ACT_LIGHT_POWER_SCALE_ARRAY:
                        for (size_t l = 0; l < i.data; ++l)
                            _writeRawConstant(i.physicalIndex + l*i.elementCount, 
                                              source.getLightPowerScale(l));
                        break;
                        
                    case AutoConstantType.ACT_LIGHT_ATTENUATION_ARRAY:
                        for (size_t l = 0; l < i.data; ++l)
                        {
                            _writeRawConstant(i.physicalIndex + l*i.elementCount, 
                                              source.getLightAttenuation(l), i.elementCount);
                        }
                        break;
                    case AutoConstantType.ACT_SPOTLIGHT_PARAMS_ARRAY:
                        for (size_t l = 0 ; l < i.data; ++l)
                        {
                            _writeRawConstant(i.physicalIndex + l*i.elementCount, source.getSpotlightParams(l), 
                                              i.elementCount);
                        }
                        break;
                    case AutoConstantType.ACT_DERIVED_LIGHT_DIFFUSE_COLOUR:
                        _writeRawConstant(i.physicalIndex,
                                          source.getLightDiffuseColourWithPower(i.data) * source.getSurfaceDiffuseColour(),
                                          i.elementCount);
                        break;
                    case AutoConstantType.ACT_DERIVED_LIGHT_SPECULAR_COLOUR:
                        _writeRawConstant(i.physicalIndex,
                                          source.getLightSpecularColourWithPower(i.data) * source.getSurfaceSpecularColour(),
                                          i.elementCount);
                        break;
                    case AutoConstantType.ACT_DERIVED_LIGHT_DIFFUSE_COLOUR_ARRAY:
                        for (size_t l = 0; l < i.data; ++l)
                        {
                            _writeRawConstant(i.physicalIndex + l*i.elementCount, 
                                              source.getLightDiffuseColourWithPower(l) * source.getSurfaceDiffuseColour(),
                                              i.elementCount);
                        }
                        break;
                    case AutoConstantType.ACT_DERIVED_LIGHT_SPECULAR_COLOUR_ARRAY:
                        for (size_t l = 0; l < i.data; ++l)
                        {
                            _writeRawConstant(i.physicalIndex + l*i.elementCount, 
                                              source.getLightSpecularColourWithPower(l) * source.getSurfaceSpecularColour(),
                                              i.elementCount);
                        }
                        break;
                    case AutoConstantType.ACT_TEXTURE_VIEWPROJ_MATRIX:
                        // can also be updated in lights
                        _writeRawConstant(i.physicalIndex, source.getTextureViewProjMatrix(i.data),i.elementCount);
                        break;
                    case AutoConstantType.ACT_TEXTURE_VIEWPROJ_MATRIX_ARRAY:
                        for (size_t l = 0; l < i.data; ++l)
                        {
                            // can also be updated in lights
                            _writeRawConstant(i.physicalIndex + l*i.elementCount, 
                                              source.getTextureViewProjMatrix(l),i.elementCount);
                        }
                        break;
                    case AutoConstantType.ACT_SPOTLIGHT_VIEWPROJ_MATRIX:
                        _writeRawConstant(i.physicalIndex, source.getSpotlightViewProjMatrix(i.data),i.elementCount);
                        break;
                    case AutoConstantType.ACT_SPOTLIGHT_VIEWPROJ_MATRIX_ARRAY:
                        for (size_t l = 0; l < i.data; ++l)
                        {
                            // can also be updated in lights
                            _writeRawConstant(i.physicalIndex + l*i.elementCount, 
                                              source.getSpotlightViewProjMatrix(l),i.elementCount);
                        }
                        break;
                        
                    default:
                        break;
                }
            }
        }
        
    }
    
    /** Tells the program whether to ignore missing parameters or not.
     */
    void setIgnoreMissingParams(bool state) { mIgnoreMissingParams = state; }
    
    /** Sets a single value constants floating-point parameter to the program.
     @remarks
     Different types of GPU programs support different types of constant parameters.
     For example, it's relatively common to find that vertex programs only support
     floating point constants, and that fragment programs only support integer (fixed point)
     parameters. This can vary depending on the program version supported by the
     graphics card being used. You should consult the documentation for the type of
     low level program you are using, or alternatively use the methods
     provided on RenderSystemCapabilities to determine the options.
     @par
     Another possible limitation is that some systems only allowants to be set
     on certain boundaries, e.g. in sets of 4 values for example. Again, see
     RenderSystemCapabilities for full details.
     @note
     This named option will only work if you are using a parameters object created
     from a high-level program (HighLevelGpuProgram).
     @param name The name of the parameter
     @param val The value to set
     */
    void setNamedConstant(string name, Real val)
    {
        // look up, and throw an exception if we're not ignoring missing
        GpuConstantDefinition* def = 
            _findNamedConstantDefinition(name, !mIgnoreMissingParams);
        if (def)
            _writeRawConstant(def.physicalIndex, val);
    }
    /** Sets a single value constants integer parameter to the program.
     @remarks
     Different types of GPU programs support different types of constant parameters.
     For example, it's relatively common to find that vertex programs only support
     floating point constants, and that fragment programs only support integer (fixed point)
     parameters. This can vary depending on the program version supported by the
     graphics card being used. You should consult the documentation for the type of
     low level program you are using, or alternatively use the methods
     provided on RenderSystemCapabilities to determine the options.
     @par
     Another possible limitation is that some systems only allowants to be set
     on certain boundaries, e.g. in sets of 4 values for example. Again, see
     RenderSystemCapabilities for full details.
     @note
     This named option will only work if you are using a parameters object created
     from a high-level program (HighLevelGpuProgram).
     @param name The name of the parameter
     @param val The value to set
     */
    void setNamedConstant(string name, int val)
    {
        // look up, and throw an exception if we're not ignoring missing
        GpuConstantDefinition* def = 
            _findNamedConstantDefinition(name, !mIgnoreMissingParams);
        if (def)
            _writeRawConstant(def.physicalIndex, val);
    }
    /** Sets a Vector4 parameter to the program.
     @param name The name of the parameter
     @param vec The value to set
     */
    void setNamedConstant(string name, ref Vector4 vec)
    {
        // look up, and throw an exception if we're not ignoring missing
        GpuConstantDefinition* def = 
            _findNamedConstantDefinition(name, !mIgnoreMissingParams);
        if (def)
            _writeRawConstant(def.physicalIndex, vec, def.elementSize);
    }
    /** Sets a Vector3 parameter to the program.
     @note
     This named option will only work if you are using a parameters object created
     from a high-level program (HighLevelGpuProgram).
     @param index The index at which to place the parameter
     NB this index ref ers to the number of floats, so a Vector3 is 3. Note that many 
     rendersystems & programs assume that every floating point parameter is passed in
     as a vector of 4 items, so you are strongly advised to check with 
     RenderSystemCapabilities before using this version - if in doubt use Vector4
     or ColourValue instead (both are 4D).
     @param vec The value to set
     */
    void setNamedConstant(string name, ref Vector3 vec)
    {
        // look up, and throw an exception if we're not ignoring missing
        GpuConstantDefinition* def = 
            _findNamedConstantDefinition(name, !mIgnoreMissingParams);
        if (def)
            _writeRawConstant(def.physicalIndex, vec);
    }
    /** Sets a Matrix4 parameter to the program.
     @param name The name of the parameter
     @param m The value to set
     */
    void setNamedConstant(string name, ref Matrix4 m)
    {
        // look up, and throw an exception if we're not ignoring missing
        GpuConstantDefinition* def = 
            _findNamedConstantDefinition(name, !mIgnoreMissingParams);
        if (def)
            _writeRawConstant(def.physicalIndex, m, def.elementSize);
    }
    /** Sets a list of Matrix4 parameters to the program.
     @param name The name of the parameter; this must be the first index of an array,
     for examples 'matrices[0]'
     NB since a Matrix4 is 16 floats long, so each entry will take up 4 indexes.
     @param m Pointer to an array of matrices to set
     @param numEntries Number of Matrix4 entries
     */
    void setNamedConstant(string name, Matrix4 m, size_t numEntries)
    {
        // look up, and throw an exception if we're not ignoring missing
        GpuConstantDefinition* def = 
            _findNamedConstantDefinition(name, !mIgnoreMissingParams);
        if (def)
            _writeRawConstant(def.physicalIndex, m, numEntries);
    }
    /** Sets a multiple value constants floating-point parameter to the program.
     @par
     Some systems only allowants to be set on certain boundaries, 
     e.g. in sets of 4 values for example. The 'multiple' parameter allows
     you to control that although you should only change it if you know
     your chosen language supports that (at the time of writing, only
     GLSL allow constants which are not a multiple of 4).
     @note
     This named option will only work if you are using a parameters object created
     from a high-level program (HighLevelGpuProgram).
     @param name The name of the parameter
     @param val Pointer to the values to write
     @param count The number of 'multiples' of floats to write
     @param multiple The number of raw entries in each element to write, 
     the default is 4 so count = 1 would write 4 floats.
     */
    void setNamedConstant(string name,float *val, size_t count, 
                          size_t multiple = 4)
    {
        size_t rawCount = count * multiple;
        // look up, and throw an exception if we're not ignoring missing
        GpuConstantDefinition* def = 
            _findNamedConstantDefinition(name, !mIgnoreMissingParams);
        if (def)
            _writeRawConstants(def.physicalIndex, val, rawCount);
    }
    /** Sets a multiple value constants floating-point parameter to the program.
     @par
     Some systems only allowants to be set on certain boundaries, 
     e.g. in sets of 4 values for example. The 'multiple' parameter allows
     you to control that although you should only change it if you know
     your chosen language supports that (at the time of writing, only
     GLSL allow constants which are not a multiple of 4).
     @note
     This named option will only work if you are using a parameters object created
     from a high-level program (HighLevelGpuProgram).
     @param name The name of the parameter
     @param val Pointer to the values to write
     @param count The number of 'multiples' of floats to write
     @param multiple The number of raw entries in each element to write, 
     the default is 4 so count = 1 would write 4 floats.
     */
    void setNamedConstant(string name,double *val, size_t count, 
                          size_t multiple = 4)
    {
        size_t rawCount = count * multiple;
        // look up, and throw an exception if we're not ignoring missing
        GpuConstantDefinition* def = 
            _findNamedConstantDefinition(name, !mIgnoreMissingParams);
        if (def)
            _writeRawConstants(def.physicalIndex, val, rawCount);
    }
    /** Sets a ColourValue parameter to the program.
     @param name The name of the parameter
     @param colour The value to set
     */
    void setNamedConstant(string name,ColourValue colour)
    {
        // look up, and throw an exception if we're not ignoring missing
        GpuConstantDefinition* def = 
            _findNamedConstantDefinition(name, !mIgnoreMissingParams);
        if (def)
            _writeRawConstant(def.physicalIndex, colour, def.elementSize);
    }
    
    /** Sets a multiple value constants floating-point parameter to the program.
     @par
     Some systems only allowants to be set on certain boundaries, 
     e.g. in sets of 4 values for example. The 'multiple' parameter allows
     you to control that although you should only change it if you know
     your chosen language supports that (at the time of writing, only
     GLSL allow constants which are not a multiple of 4).
     @note
     This named option will only work if you are using a parameters object created
     from a high-level program (HighLevelGpuProgram).
     @param name The name of the parameter
     @param val Pointer to the values to write
     @param count The number of 'multiples' of floats to write
     @param multiple The number of raw entries in each element to write, 
     the default is 4 so count = 1 would write 4 floats.
     */
    void setNamedConstant(string name,int *val, size_t count, 
                          size_t multiple = 4)
    {
        size_t rawCount = count * multiple;
        // look up, and throw an exception if we're not ignoring missing
        GpuConstantDefinition* def = 
            _findNamedConstantDefinition(name, !mIgnoreMissingParams);
        if (def)
            _writeRawConstants(def.physicalIndex, val, rawCount);
    }
    
    /** Sets up aant which will automatically be updated by the system.
     @remarks
     Vertex and fragment programs often need parameters which are to do with the
     current render state, or particular values which may very well change over time,
     and often between objects which are being rendered. This feature allows you 
     to set up a certain number of predefined parameter mappings that are kept up to 
     date for you.
     @note
     This named option will only work if you are using a parameters object created
     from a high-level program (HighLevelGpuProgram).
     @param name The name of the parameter
     @param acType The type of automatic constant to set
     @param extraInfo If the constant type needs more information (like a light index) put it here.
     */
    void setNamedAutoConstant(string name, AutoConstantType acType, size_t extraInfo = 0)
    {
        // look up, and throw an exception if we're not ignoring missing
        GpuConstantDefinition* def = 
            _findNamedConstantDefinition(name, !mIgnoreMissingParams);
        if (def)
        {
            def.variability = deriveVariability(acType);
            // make sure we also set variability on the logical index map
            GpuLogicalIndexUse* indexUse = _getFloatConstantLogicalIndexUse(def.logicalIndex, def.elementSize * def.arraySize, def.variability);
            if (indexUse)
                indexUse.variability = def.variability;
            
            _setRawAutoConstant(def.physicalIndex, acType, extraInfo, def.variability, def.elementSize);
        }
        
    }
    
    void setNamedAutoConstantReal(string name, AutoConstantType acType, Real rData)
    {
        // look up, and throw an exception if we're not ignoring missing
        GpuConstantDefinition* def = 
            _findNamedConstantDefinition(name, !mIgnoreMissingParams);
        if (def)
        {
            def.variability = deriveVariability(acType);
            // make sure we also set variability on the logical index map
            GpuLogicalIndexUse* indexUse = _getFloatConstantLogicalIndexUse(def.logicalIndex, def.elementSize * def.arraySize, def.variability);
            if (indexUse)
                indexUse.variability = def.variability;
            _setRawAutoConstantReal(def.physicalIndex, acType, rData, def.variability, def.elementSize);
        }
    }
    
    /** Sets up aant which will automatically be updated by the system.
     @remarks
     Vertex and fragment programs often need parameters which are to do with the
     current render state, or particular values which may very well change over time,
     and often between objects which are being rendered. This feature allows you 
     to set up a certain number of predefined parameter mappings that are kept up to 
     date for you.
     @note
     This named option will only work if you are using a parameters object created
     from a high-level program (HighLevelGpuProgram).
     @param name The name of the parameter
     @param acType The type of automatic constant to set
     @param extraInfo1 The first extra info required by this auto constants type
     @param extraInfo2 The first extra info required by this auto constants type
     */
    void setNamedAutoConstant(string name, AutoConstantType acType, ushort extraInfo1, ushort extraInfo2)
    {
        size_t extraInfo = cast(size_t)extraInfo1 | (cast(size_t)extraInfo2) << 16;
        
        // look up, and throw an exception if we're not ignoring missing
        GpuConstantDefinition* def = 
            _findNamedConstantDefinition(name, !mIgnoreMissingParams);
        if (def)
        {
            def.variability = deriveVariability(acType);
            // make sure we also set variability on the logical index map
            GpuLogicalIndexUse* indexUse = _getFloatConstantLogicalIndexUse(def.logicalIndex, def.elementSize * def.arraySize, def.variability);
            if (indexUse)
                indexUse.variability = def.variability;
            
            _setRawAutoConstant(def.physicalIndex, acType, extraInfo, def.variability, def.elementSize);
        }
        
    }
    
    /** Sets a named parameter up to track a derivation of the current time.
     @note
     This named option will only work if you are using a parameters object created
     from a high-level program (HighLevelGpuProgram).
     @param name The name of the parameter
     @param factor The amount by which to scale the time value
     */  
    void setNamedConstantFromTime(string name, Real factor)
    {
        setNamedAutoConstantReal(name,AutoConstantType.ACT_TIME, factor);
    }
    
    /** Unbind an auto constants so that the constant is manually controlled again. */
    void clearNamedAutoConstant(string name)
    {
        GpuConstantDefinition* def = _findNamedConstantDefinition(name);
        if (def)
        {
            def.variability = GpuParamVariability.GPV_GLOBAL;
            
            // Autos are always floating point
            if (def.isFloat())
            {
                foreach (i; mAutoConstants)
                {
                    if (i.physicalIndex == def.physicalIndex)
                    {
                        mAutoConstants.removeFromArray(i);
                        break;
                    }
                }
            }
            
        }
    }
    
    /** Find aant definition for a named parameter.
     @remarks
     This method returns null if the named parameter did not exist, unlike
     getConstantDefinition which is more strict; unless you set the 
     last parameter to true.
     @param name The name to look up
     @param throwExceptionIfMissing If set to true, failure to find an entry
     will throw an exception.
     */
    GpuConstantDefinition* _findNamedConstantDefinition(
        string name, bool throwExceptionIfMissing = false)
    {
        if (mNamedConstants.isNull())
        {
            if (throwExceptionIfMissing)
                throw new InvalidParamsError( 
                                             "named constants have not been initialised, perhaps a compile error.",
                                             "GpuProgramParameters._findNamedConstantDefinition");
            return null;
        }
        
        auto i = name in mNamedConstants.get().map;
        if (i is null)
        {
            if (throwExceptionIfMissing)
                throw new InvalidParamsError( 
                                             "Parameter called " ~ name ~ " does not exist. ",
                                             "GpuProgramParameters._findNamedConstantDefinition");
            return null;
        }
        else
        {
            return i;
        }
    }
    /** Gets the physical buffer index associated with a logical float constant index. 
     @note Only applicable to low-level programs.
     @param logicalIndex The logical parameter index
     @param requestedSize The requested size - pass 0 to ignore missing entries
     and return size_t.max 
     */
    size_t _getFloatConstantPhysicalIndex(size_t logicalIndex, size_t requestedSize, ushort variability)
    {
        GpuLogicalIndexUse* indexUse = _getFloatConstantLogicalIndexUse(logicalIndex, requestedSize, variability);
        return indexUse ? indexUse.physicalIndex : 0;
    }
    
    /** Gets the physical buffer index associated with a logical double constant index. 
     @note Only applicable to low-level programs.
     @param logicalIndex The logical parameter index
     @param requestedSize The requested size - pass 0 to ignore missing entries
     and return size_t.max 
     */
    size_t _getDoubleConstantPhysicalIndex(size_t logicalIndex, size_t requestedSize, ushort variability)
    {
        GpuLogicalIndexUse* indexUse = _getDoubleConstantLogicalIndexUse(logicalIndex, requestedSize, variability);
        return indexUse ? indexUse.physicalIndex : 0;
    }
    
    /** Gets the physical buffer index associated with a logical int constant index. 
     @note Only applicable to low-level programs.
     @param logicalIndex The logical parameter index
     @param requestedSize The requested size - pass 0 to ignore missing entries
     and return size_t.max 
     */
    size_t _getIntConstantPhysicalIndex(size_t logicalIndex, size_t requestedSize, ushort variability)
    {
        GpuLogicalIndexUse* indexUse = _getIntConstantLogicalIndexUse(logicalIndex, requestedSize, variability);
        return indexUse ? indexUse.physicalIndex : 0;
    }
    
    /** Sets whether or not we need to transpose the matrices passed in from the rest of OGRE.
     @remarks
     D3D uses transposed matrices compared to GL and OGRE; this is not important when you
     use programs which are written to process row-major matrices, such as those generated
     by Cg, but if you use a program written to D3D's matrix layout you will need to enable
     this flag.
     */
    void setTransposeMatrices(bool val) { mTransposeMatrices = val; } 
    /// Gets whether or not matrices are to be transposed when set
    bool getTransposeMatrices(){ return mTransposeMatrices; } 
    
    /** Copies the values of all constants (including auto constantss) from another
     GpuProgramParameters object.
     @note This copes the internal storage of the paarameters object and Therefore
     can only be used for parameters objects created from the same GpuProgram.
     To merge parameters that match from different programs, use copyMatchingNamedConstantsFrom.
     */
    void copyConstantsFrom(GpuProgramParameters source)
    {
        // Pull buffers & auto constants list over directly
        mFloatConstants = source.getFloatConstantList();
        mIntConstants = source.getIntConstantList();
        mAutoConstants = source.getAutoConstantList();
        mCombinedVariability = source.mCombinedVariability;
        copySharedParamSetUsage(source.mSharedParamSets);
    }
    
    /** Copies the values of all matching named constants (including auto constantss) from 
     another GpuProgramParameters object. 
     @remarks
     This method iterates over the named constants in another parameters object
     and copies across the values where they match. This method is safe to
     use when the 2 parameters objects came from different programs, but only
     works for named parameters.
     */
    void copyMatchingNamedConstantsFrom(GpuProgramParameters source)
    {
        if (!mNamedConstants.isNull() && !source.mNamedConstants.isNull())
        {
            string[size_t] srcToDestNamedMap;
            foreach (paramName, olddef; source.mNamedConstants.get().map)
            {
                GpuConstantDefinition* newdef = _findNamedConstantDefinition(paramName, false);
                if (newdef)
                {
                    // Copy data across, based on smallest common definition size
                    size_t srcsz = olddef.elementSize * olddef.arraySize;
                    size_t destsz = newdef.elementSize * newdef.arraySize;
                    size_t sz = std.algorithm.min(srcsz, destsz);
                    if (newdef.isFloat())
                    {
                        
                        memcpy(getFloatPointer(newdef.physicalIndex), 
                               source.getFloatPointer(olddef.physicalIndex),
                               sz * float.sizeof);
                    }
                    else if (newdef.isDouble())
                    {
                        
                        memcpy(getDoublePointer(newdef.physicalIndex),
                               source.getDoublePointer(olddef.physicalIndex),
                               sz * double.sizeof);
                        
                    }
                    else
                    {
                        memcpy(getIntPointer(newdef.physicalIndex), 
                               source.getIntPointer(olddef.physicalIndex),
                               sz * int.sizeof);
                    }
                    // we'll use this map to resolve autos later
                    // ignore the [0] aliases
                    if (!paramName.endsWith("[0]"))
                    srcToDestNamedMap[olddef.physicalIndex] = paramName;
                }
            }
            
            foreach (autoEntry; source.mAutoConstants)
            {
                // find dest physical index
                auto mi = autoEntry.physicalIndex in srcToDestNamedMap;
                if (mi !is null)
                {
                    if (autoEntry.fData)
                    {
                        setNamedAutoConstantReal(*mi, autoEntry.paramType, autoEntry.fData);
                    }
                    else
                    {
                        setNamedAutoConstant(*mi, autoEntry.paramType, autoEntry.data);
                    }
                }
                
            }
            
            // Copy shared param sets
            foreach (usage; source.mSharedParamSets)
            {
                if (!isUsingSharedParameters(usage.getName()))
                {
                    addSharedParameters(usage.getSharedParams());
                }
            }
        }
    }
    
    /** gets the auto constants definition associated with name if found else returns NULL
     @param name The name of the auto constants
     */
    static AutoConstantDefinition* getAutoConstantDefinition(string name)
    {
        // find aant definition that matches name by iterating through the 
        // constant definition array
        bool nameFound = false;
        size_t i = 0;
        size_t numDefs = getNumAutoConstantDefinitions();
        while (!nameFound && (i < numDefs))
        {
            if (name == AutoConstantDictionary[i].name) 
                nameFound = true;
            else
                ++i;
        }
        
        if (nameFound)
        return &AutoConstantDictionary[i];
        else
            return null;
    }
    
    /** gets the auto constants definition using an index into the auto constants definition array.
     If the index is out of bounds then NULL is returned;
     @param idx The auto constants index
     */
    static AutoConstantDefinition* getAutoConstantDefinition(size_t idx)
    {
        
        if (idx < getNumAutoConstantDefinitions())
        {
            // verify index is equal to acType
            // if they are not equal then the dictionary was not setup properly
            assert(idx == cast(size_t)(AutoConstantDictionary[idx].acType));
            return &AutoConstantDictionary[idx];
        }
        else
            return null;
    }
    /** Returns the number of auto constants definitions
     */
    static size_t getNumAutoConstantDefinitions()
    {
        //return AutoConstantDictionary.sizeof/AutoConstantDefinition.sizeof;
        return AutoConstantDictionary.length;
    }
    
    
    /** increments the multipass number entry by 1 if it exists
     */
    void incPassIterationNumber()
    {
        if (mActivePassIterationIndex != size_t.max)
        {
            // This is a physical index
            ++mFloatConstants[mActivePassIterationIndex];
        }
    }
    
    /** Does this parameters object have a pass iteration numberant? */
    bool hasPassIterationNumber()
    { return mActivePassIterationIndex != size_t.max; }
    /** Get the physical buffer index of the pass iteration numberant */
    size_t getPassIterationNumberIndex()
    { return mActivePassIterationIndex; }
    
    
    /** Use a set of shared parameters in this parameters object.
     @remarks
     Allows you to use a set of shared parameters to automatically update 
     this parameter set.
     */
    void addSharedParameters(SharedPtr!GpuSharedParameters sharedParams)
    {
        if (!isUsingSharedParameters(sharedParams.get().getName()))
        {
            mSharedParamSets.insert(new GpuSharedParametersUsage(sharedParams, this));
        }
    }
    
    /** Use a set of shared parameters in this parameters object.
     @remarks
     Allows you to use a set of shared parameters to automatically update 
     this parameter set.
     @param sharedParamsName The name of a shared parameter set as defined in
     GpuProgramManager
     */
    void addSharedParameters(string sharedParamsName)
    {
        addSharedParameters(GpuProgramManager.getSingleton().getSharedParameters(sharedParamsName));
    }
    
    /** Returns whether this parameter set is using the named shared parameter set. */
    bool isUsingSharedParameters(string sharedParamsName)
    {
        foreach (i; mSharedParamSets)
        {
            if (i.getName() == sharedParamsName)
                return true;
        }
        return false;
    }
    
    /** Stop using the named shared parameter set. */
    void removeSharedParameters(string sharedParamsName)
    {
        foreach (i; mSharedParamSets)
        {
            if (i.getName() == sharedParamsName)
            {
                mSharedParamSets.removeFromArray(i);
                break;
            }
        }
    }
    
    /** Stop using all shared parameter sets. */
    void removeAllSharedParameters()
    {
        mSharedParamSets.clear();
    }
    
    /** Get the list of shared parameter sets. */
    ref GpuSharedParamUsageList getSharedParameters()
    {
        return mSharedParamSets;
    }
    
    /** Internal method that the RenderSystem might use to store optional data. */
    void _setRenderSystemData(Any data){ mRenderSystemData = data; }
    /** Internal method that the RenderSystem might use to store optional data. */
    ref Any _getRenderSystemData(){ return mRenderSystemData; }
    
    /** Update the parameters by copying the data from the shared
     parameters.
     @note This method  may not actually be called if the RenderSystem
     supports using shared parameters directly in their own shared buffer; in
     which case the values should not be copied out of the shared area
     into the individual parameter set, but bound separately.
     */
    void _copySharedParams()
    {
        foreach (i; mSharedParamSets)
        {
            i._copySharedParamsToTargetParams();
        }
    }
    
    /** Set subroutine name by slot name
     */
    void setNamedSubroutine(string subroutineSlot, string subroutine)
    {
        GpuConstantDefinition* def = 
            _findNamedConstantDefinition(subroutineSlot, !mIgnoreMissingParams);
        if (def)
        {
            setSubroutine(def.logicalIndex, subroutine);
        }
    }
    
    /** Set subroutine name by slot index
     */
    void setSubroutine(size_t index, string subroutine)
    {
        mSubroutineMap[index] = subroutine;
    }
    
    /** Get map with 
     */
    ref SubroutineMap getSubroutineMap(){ return mSubroutineMap; }
}

/// Shared pointer used to hold references to GpuProgramParameters instances
//alias GpuProgramParametersPtr GpuProgramParametersPtr;
//alias GpuProgramParameters GpuProgramParametersPtr;

/** This class makes the usage of a vertex and fragment programs (low-level or high-level), 
 with a given set of parameters, explicit.
 @remarks
 Using a vertex or fragment program can get fairly complex; besides the fairly rudimentary
 process of binding a program to the GPU for rendering, managing usage has few
 complications, such as:
 <ul>
 <li>Programs can be high level (e.g. Cg, RenderMonkey) or low level (assembler). Using
 either should be relatively seamless, although high-level programs give you the advantage
 of being able to use named parameters, instead of just indexed registers</li>
 <li>Programs and parameters can be shared between multiple usages, in order to save
 memory</li>
 <li>When you define a user of a program, such as a material, you often want to be able to
 set up the definition but not load / compile / assemble the program at that stage, because
 it is not needed just yet. The program should be loaded when it is first needed, or
 earlier if specifically requested. The program may not be defined at this time, you
 may want to have scripts that can set up the definitions independent of the order in which
 those scripts are loaded.</li>
 </ul>
 This class packages up those details so you don't have to worry about them. For example,
 this class lets you define a high-level program and set up the parameters for it, without
 having loaded the program (which you normally could not do). When the program is loaded and
 compiled, this class will then validate the parameters you supplied earlier and turn them
 into runtime parameters.
 @par
 Just incase it wasn't clear from the above, this class provides linkage to both 
 GpuProgram and HighLevelGpuProgram, despite its name.
 */
class GpuProgramUsage : Resource.Listener//, public PassAlloc
{
    // compiler chokes in TemplateDeclaration::overloadInsert
    //mixin Resource.Listener.Listener.Resource_Listener_Impl;
    mixin Resource.Resource_Listener_Impl;
    
    //void backgroundLoadingComplete(ref Resource r){}
    //void backgroundPreparingComplete(ref Resource r){}
    //void preparingComplete(ref Resource r){}

protected:
    GpuProgramType mType;
    Pass mParent;
    // The program link
    SharedPtr!GpuProgram mProgram;
    
    /// program parameters
    GpuProgramParametersPtr mParameters;
    
    /// Whether to recreate parameters next load
    bool mRecreateParams;
    
    void recreateParameters()
    {
        // Keep a reference to old ones to copy
        GpuProgramParametersPtr savedParams = mParameters;
        
        // Create new params
        mParameters = mProgram.getAs().createParameters();
        
        // Copy old (matching) values across
        // Don't use copyConstantsFrom since program may be different
        if (!savedParams.isNull())
            mParameters.get().copyMatchingNamedConstantsFrom(savedParams.get());
        
        mRecreateParams = false;
        
    }
    
public:
    /** Default constructor.
     @param gptype The type of program to link to
     */
    this(GpuProgramType gptype, Pass parent)
    {
        mType = gptype;
        mParent = parent;
        //mProgram = ;
        mRecreateParams = false;
    }
    
    /** Copy constructor */
    this(GpuProgramUsage oth, Pass parent)
    {
        mType = oth.mType;
        mParent = parent;
        mProgram = oth.mProgram;
        // nfz: parameters should be copied not just use a shared ptr to the original
        mParameters = GpuProgramParametersPtr(new GpuProgramParameters(oth.mParameters.get()));
        
        mRecreateParams = false;
        
    }
    
    ~this()
    {
        if (!mProgram.isNull())
            mProgram.getAs().removeListener(this);
    }
    
    /** Gets the type of program we're trying to link to. */
    GpuProgramType getType(){ return mType; }
    
    /** Sets the name of the program to use. 
     @param name The name of the program to use
     @param resetParams
     If true, this will create a fresh set of parameters from the
     new program being linked, so if you had previously set parameters
     you will have to set them again. If you set this to false, you must
     be absolutely sure that the parameters match perfectly, and in the
     case of named parameters ref ers to the indexes underlying them, 
     not just the names.
     */
    void setProgramName(string name, bool resetParams = true)
    {
        if (!mProgram.isNull())
        {
            mProgram.getAs().removeListener(this);
            mRecreateParams = true;
        }
        
        mProgram = GpuProgramManager.getSingleton().getByName(name);
        
        if (mProgram.isNull())
        {
            string progType = "fragment";
            if (mType == GpuProgramType.GPT_VERTEX_PROGRAM)
            {
                progType = "vertex";
            }
            else if (mType == GpuProgramType.GPT_GEOMETRY_PROGRAM)
            {
                progType = "geometry";
            }
            else if (mType == GpuProgramType.GPT_DOMAIN_PROGRAM)
            {
                progType = "domain";
            }
            else if (mType == GpuProgramType.GPT_HULL_PROGRAM)
            {
                progType = "hull";
            }
            
            throw new ItemNotFoundError(
                "Unable to locate " ~ progType ~ " program called " ~ name ~ ".",
                "GpuProgramUsage.setProgramName");
        }
        
        // Reset parameters 
        if (resetParams || mParameters.isNull() || mRecreateParams)
        {
            recreateParameters();
        }
        
        // Listen in on reload events so we can regenerate params
        mProgram.getAs().addListener(this);
        
    }
    /** Sets the program to use.
     @remarks
     Note that this will create a fresh set of parameters from the
     new program being linked, so if you had previously set parameters
     you will have to set them again.
     */
    void setProgram(ref SharedPtr!GpuProgram prog)
    {
        mProgram = prog;
        // Reset parameters 
        mParameters = mProgram.getAs().createParameters();
    }
    /** Gets the program being used. */
    ref SharedPtr!GpuProgram getProgram(){ return mProgram; }
    /** Gets the program being used. */
    string getProgramName(){ return mProgram.getAs().getName(); }
    
    /** Sets the program parameters that should be used; because parameters can be
     shared between multiple usages for efficiency, this method is here for you
     to register externally created parameter objects. Otherwise, the parameters
     will be created for you when a program is linked.
     */
    void setParameters(GpuProgramParametersPtr params)
    {
        mParameters = params;
    }
    /** Gets the parameters being used here. 
     */
    GpuProgramParametersPtr getParameters()
    {
        if (mParameters.isNull())
        {
            throw new InvalidParamsError("You must specify a program before "
                                         "you can retrieve parameters.", "GpuProgramUsage.getParameters");
        }
        
        return mParameters;
    }
    
    /// Load this usage (and ensure program is loaded)
    void _load()
    {
        if (!mProgram.getAs().isLoaded())
            mProgram.getAs().load();
        
        // check type
        if (mProgram.getAs().isLoaded() && mProgram.getAs().getType() != mType)
        {
            string myType = "fragment";
            if (mType == GpuProgramType.GPT_VERTEX_PROGRAM)
            {
                myType = "vertex";
            }
            else if (mType == GpuProgramType.GPT_GEOMETRY_PROGRAM)
            {
                myType = "geometry";
            }
            else if (mType == GpuProgramType.GPT_DOMAIN_PROGRAM)
            {
                myType = "domain";
            }
            else if (mType == GpuProgramType.GPT_HULL_PROGRAM)
            {
                myType = "hull";
            }
            
            string yourType = "fragment";
            if (mProgram.getAs().getType() == GpuProgramType.GPT_VERTEX_PROGRAM)
            {
                yourType = "vertex";
            }
            else if (mProgram.getAs().getType() == GpuProgramType.GPT_GEOMETRY_PROGRAM)
            {
                yourType = "geometry";
            }
            else if (mProgram.getAs().getType() == GpuProgramType.GPT_DOMAIN_PROGRAM)
            {
                yourType = "domain";
            }
            else if (mProgram.getAs().getType() == GpuProgramType.GPT_HULL_PROGRAM)
            {
                yourType = "hull";
            }
            
            throw new InvalidParamsError(
                mProgram.getAs().getName() ~ "is a " ~ yourType ~ " program, but you are assigning it to a " 
                ~ myType ~ " program slot. This is invalid.",
                "GpuProgramUsage.setProgramName");
            
        }
    }
    /// Unload this usage 
    void _unload()
    {
        // TODO?
    }
    
    // Resource Listener
    void unloadingComplete(ref Resource prog)
    {
        mRecreateParams = true;
        
    }
    void loadingComplete(ref Resource prog)
    {
        // Need to re-create parameters
        if (mRecreateParams)
            recreateParameters();
        
    }
    
    size_t calculateSize() //const
    {
        size_t memSize = 0;
        
        memSize += GpuProgramType.sizeof;
        memSize += bool.sizeof;
        
        // Tally up passes
        if(!mProgram.isNull())
            memSize += mProgram.calculateSize();
        if(!mParameters.isNull())
            memSize += mParameters.calculateSize();
        
        return memSize;
    }
}

/** @} */
/** @} */


/** \addtogroup Core
 *  @{
 */
/** \addtogroup Resources
 *  @{
 */
/** Enumerates the types of programs which can run on the GPU. */
enum GpuProgramType
{
    GPT_VERTEX_PROGRAM,
    GPT_FRAGMENT_PROGRAM,
    GPT_GEOMETRY_PROGRAM,
    GPT_DOMAIN_PROGRAM,
    GPT_HULL_PROGRAM,
    GPT_COMPUTE_PROGRAM
}


/** Defines a program which runs on the GPU such as a vertex or fragment program. 
 @remarks
 This class defines the low-level program in assembler code, the sort used to
 directly assemble into machine instructions for the GPU to execute. By nature,
 this means that the assembler source is rendersystem specific, which is why this
 is an abstract class - real instances are created through the RenderSystem. 
 If you wish to use higher level shading languages like HLSL and Cg, you need to 
 use the HighLevelGpuProgram class instead.
 */
class GpuProgram : Resource
{
protected:
    /// Command object - see ParamCommand 
    static class CmdType : ParamCommand
    {
    public:
        override string doGet(Object target)
        {
            GpuProgram t = cast(GpuProgram)(target);
            if (t.getType() == GpuProgramType.GPT_VERTEX_PROGRAM)
            {
                return "vertex_program";
            }
            else if (t.getType() == GpuProgramType.GPT_GEOMETRY_PROGRAM)
            {
                return "geometry_program";
            }
            else if (t.getType() == GpuProgramType.GPT_DOMAIN_PROGRAM)
            {
                return "domain_program";
            }
            else if (t.getType() == GpuProgramType.GPT_HULL_PROGRAM)
            {
                return "hull_program";
            }
            else if (t.getType() == GpuProgramType.GPT_COMPUTE_PROGRAM)
            {
                return "compute_program";
            }
            else
            {
                return "fragment_program";
            }
        }
        void doSet(Object target, string val)
        {
            GpuProgram t = cast(GpuProgram)(target);
            if (val == "vertex_program")
            {
                t.setType(GpuProgramType.GPT_VERTEX_PROGRAM);
            }
            else if (val == "geometry_program")
            {
                t.setType(GpuProgramType.GPT_GEOMETRY_PROGRAM);
            }
            else if (val == "domain_program")
            {
                t.setType(GpuProgramType.GPT_DOMAIN_PROGRAM);
            }
            else if (val == "hull_program")
            {
                t.setType(GpuProgramType.GPT_HULL_PROGRAM);
            }
            else if (val == "compute_program")
            {
                t.setType(GpuProgramType.GPT_COMPUTE_PROGRAM);
            }
            else
            {
                t.setType(GpuProgramType.GPT_FRAGMENT_PROGRAM);
            }
        }
    }
    static class CmdSyntax : ParamCommand
    {
    public:
        override string doGet(Object target)
        {
            GpuProgram t = cast(GpuProgram)(target);
            return t.getSyntaxCode();
        }
        void doSet(Object target, string val)
        {
            GpuProgram t = cast(GpuProgram)(target);
            t.setSyntaxCode(val);
        }
    }
    static class CmdSkeletal : ParamCommand
    {
    public:
        override string doGet(Object target)
        {
            GpuProgram t = cast(GpuProgram)(target);
            return std.conv.to!string(t.isSkeletalAnimationIncluded());
        }
        void doSet(Object target, string val)
        {
            GpuProgram t = cast(GpuProgram)(target);
            t.setSkeletalAnimationIncluded(std.conv.to!bool(val));
        }
    }
    static class CmdMorph : ParamCommand
    {
    public:
        override string doGet(Object target)
        {
            GpuProgram t = cast(GpuProgram)(target);
            return std.conv.to!string(t.isMorphAnimationIncluded());
        }
        void doSet(Object target, string val)
        {
            GpuProgram t = cast(GpuProgram)(target);
            t.setMorphAnimationIncluded(std.conv.to!bool(val));
        }
    }
    static class CmdPose : ParamCommand
    {
    public:
        override string doGet(Object target)
        {
            GpuProgram t = cast(GpuProgram)(target);
            return std.conv.to!string(t.getNumberOfPosesIncluded());
        }
        void doSet(Object target, string val)
        {
            GpuProgram t = cast(GpuProgram)(target);
            t.setPoseAnimationIncluded(std.conv.to!ushort(val));
        }
    }
    static class CmdVTF : ParamCommand
    {
    public:
        override string doGet(Object target)
        {
            GpuProgram t = cast(GpuProgram)(target);
            return std.conv.to!string(t.isVertexTextureFetchRequired());
        }
        void doSet(Object target, string val)
        {
            GpuProgram t = cast(GpuProgram)(target);
            t.setVertexTextureFetchRequired(std.conv.to!bool(val));
        }
    }
    static class CmdManualNamedConstsFile : ParamCommand
    {
    public:
        override string doGet(Object target)
        {
            GpuProgram t = cast(GpuProgram)(target);
            return t.getManualNamedConstantsFile();
        }
        void doSet(Object target, string val)
        {
            GpuProgram t = cast(GpuProgram)(target);
            t.setManualNamedConstantsFile(val);
        }
    }
    static class CmdAdjacency : ParamCommand
    {
    public:
        override string doGet(Object target)
        {
            GpuProgram t = cast(GpuProgram)(target);
            return std.conv.to!string(t.isAdjacencyInfoRequired());
        }
        void doSet(Object target, string val)
        {
            GpuProgram t = cast(GpuProgram)(target);
            t.setAdjacencyInfoRequired(std.conv.to!bool(val));
        }
    }
    // Command object for setting / getting parameters
    static CmdType msTypeCmd;
    static CmdSyntax msSyntaxCmd;
    static CmdSkeletal msSkeletalCmd;
    static CmdMorph msMorphCmd;
    static CmdPose msPoseCmd;
    static CmdVTF msVTFCmd;
    static CmdManualNamedConstsFile msManNamedConstsFileCmd;
    static CmdAdjacency msAdjacencyCmd;
    
    /// The type of the program
    GpuProgramType mType;
    /// The name of the file to load source from (may be blank)
    string mFilename;
    /// The assembler source of the program (may be blank until file loaded)
    string mSource;
    /// Whether we need to load source from file or not
    bool mLoadFromFile;
    /// Syntax code e.g. arbvp1, vs_2_0 etc
    string mSyntaxCode;
    /// Does this (vertex) program include skeletal animation?
    bool mSkeletalAnimation;
    /// Does this (vertex) program include morph animation?
    bool mMorphAnimation;
    /// Does this (vertex) program include pose animation (count of number of poses supported)
    ushort mPoseAnimation;
    /// Does this (vertex) program require support for vertex texture fetch?
    bool mVertexTextureFetch;
    /// Does this (geometry) program require adjacency information?
    bool mNeedsAdjacencyInfo;
    /// The default parameters for use with this object
    GpuProgramParametersPtr mDefaultParams;
    /// Did we encounter a compilation error?
    bool mCompileError;
    /** Record of logical to physical buffer maps. Mandatory for low-level
     programs or high-level programs which set their params the same way. 
     This is a shared pointer because if the program is recompiled and the parameters
     change, this definition will alter, but previous params may reference the old def. */
    //mutable 
    SharedPtr!GpuLogicalBufferStruct mFloatLogicalToPhysical;
    /** Record of logical to physical buffer maps. Mandatory for low-level
     programs or high-level programs which set their params the same way. 
     This is a shared pointer because if the program is recompiled and the parameters
     change, this definition will alter, but previous params may reference the old def.*/
    //mutable 
    SharedPtr!GpuLogicalBufferStruct mDoubleLogicalToPhysical;
    /** Record of logical to physical buffer maps. Mandatory for low-level
     programs or high-level programs which set their params the same way. 
     This is a shared pointer because if the program is recompiled and the parameters
     change, this definition will alter, but previous params may reference the old def.*/
    
    //mutable 
    SharedPtr!GpuLogicalBufferStruct mIntLogicalToPhysical;
    /** Parameter name . ConstantDefinition map, shared instance used by all parameter objects.
     This is a shared pointer because if the program is recompiled and the parameters
     change, this definition will alter, but previous params may reference the old def.
     */
    //mutable 
    SharedPtr!(GpuNamedConstants*) mConstantDefs;
    /// File from which to load named constants manually
    string mManualNamedConstantsFile;
    bool mLoadedManualNamedConstants;
    
    
    /** Internal method for setting up the basic parameter definitions for a subclass. 
     @remarks
     Because stringInterface holds a dictionary of parameters per class, subclasses need to
     call this to ask the base class to add it's parameters to their dictionary as well.
     Can't do this in the constructor because that runs in a non-context.
     @par
     The subclass must have called it's own createParamDictionary before calling this method.
     */
    void setupBaseParamDictionary()
    {
        ParamDictionary dict = getParamDictionary();
        
        dict.addParameter(
            new ParameterDef("type", "'vertex_program', 'geometry_program' or 'fragment_program'",
                         ParameterType.PT_STRING), msTypeCmd);
        dict.addParameter(
            new ParameterDef("syntax", "Syntax code, e.g. vs_1_1", ParameterType.PT_STRING), msSyntaxCmd);
        dict.addParameter(
            new ParameterDef("includes_skeletal_animation", 
                         "Whether this vertex program includes skeletal animation", ParameterType.PT_BOOL), 
            msSkeletalCmd);
        dict.addParameter(
            new ParameterDef("includes_morph_animation", 
                         "Whether this vertex program includes morph animation", ParameterType.PT_BOOL), 
            msMorphCmd);
        dict.addParameter(
            new ParameterDef("includes_pose_animation", 
                         "The number of poses this vertex program supports for pose animation", ParameterType.PT_INT), 
            msPoseCmd);
        dict.addParameter(
            new ParameterDef("uses_vertex_texture_fetch", 
                         "Whether this vertex program requires vertex texture fetch support.", ParameterType.PT_BOOL), 
            msVTFCmd);
        dict.addParameter(
            new ParameterDef("manual_named_constants", 
                         "File containing named parameter mappings for low-level programs.", ParameterType.PT_BOOL), 
            msManNamedConstsFileCmd);
        dict.addParameter(
            new ParameterDef("uses_adjacency_information",
                         "Whether this geometry program requires adjacency information from the input primitives.", ParameterType.PT_BOOL),
            msAdjacencyCmd);
    }
    
    /** Internal method returns whether required capabilities for this program is supported.
     */
    bool isRequiredCapabilitiesSupported()
    {
        auto caps = Root.getSingleton().getRenderSystem().getCapabilities();
        
        // If skeletal animation is being done, we need support for UBYTE4
        if (isSkeletalAnimationIncluded() && 
            !caps.hasCapability(Capabilities.RSC_VERTEX_FORMAT_UBYTE4))
        {
            return false;
        }
        
        // Vertex texture fetch required?
        if (isVertexTextureFetchRequired() && 
            !caps.hasCapability(Capabilities.RSC_VERTEX_TEXTURE_FETCH))
        {
            return false;
        }
        
        return true;
    }
    
    /// @copydoc Resource.loadImpl
    override void loadImpl()
    {
        if (mLoadFromFile)
        {
            // find & load source code
            DataStream stream = 
                ResourceGroupManager.getSingleton().openResource(
                    mFilename, mGroup, true, this);
            mSource = stream.getAsString();
        }
        
        // Call polymorphic load
        try 
        {
            loadFromSource();
            
            if (!mDefaultParams.isNull())
            {
                // Keep a reference to old ones to copy
                GpuProgramParametersPtr savedParams = mDefaultParams;
                // reset params to stop them being referenced in the next create
                mDefaultParams.setNull();
                
                // Create new params
                mDefaultParams = createParameters();
                
                // Copy old (matching) values across
                // Don't use copyConstantsFrom since program may be different
                mDefaultParams.get().copyMatchingNamedConstantsFrom(savedParams.get());
                
            }
        }
        catch (Exception e)
        {
            // will already have been logged
            LogManager.getSingleton().stream()
                << "Gpu program " << mName << " encountered an error "
                    << "during loading and is thus not supported. " << e.msg;
            
            mCompileError = true;
        }
        
    }
    
    /// Create the internal params logical & named mapping structures
    void createParameterMappingStructures(bool recreateIfExists = true)
    {
        createLogicalParameterMappingStructures(recreateIfExists);
        createNamedParameterMappingStructures(recreateIfExists);
    }
    /// Create the internal params logical mapping structures
    void createLogicalParameterMappingStructures(bool recreateIfExists = true)
    {
        if (recreateIfExists || mFloatLogicalToPhysical.isNull())
            mFloatLogicalToPhysical = SharedPtr!GpuLogicalBufferStruct(new GpuLogicalBufferStruct());
        if (recreateIfExists || mIntLogicalToPhysical.isNull())
            mIntLogicalToPhysical = SharedPtr!GpuLogicalBufferStruct(new GpuLogicalBufferStruct());
    }
    /// Create the internal params named mapping structures
    void createNamedParameterMappingStructures(bool recreateIfExists = true)
    {
        if (recreateIfExists || mConstantDefs.isNull())
            mConstantDefs = SharedPtr!(GpuNamedConstants*)(new GpuNamedConstants());
    }
    
public:
    
    static void staticThis()
    {
        msTypeCmd = new CmdType;
        msSyntaxCmd = new CmdSyntax;
        msSkeletalCmd = new CmdSkeletal;
        msMorphCmd = new CmdMorph;
        msPoseCmd = new CmdPose;
        msVTFCmd = new CmdVTF;
        msManNamedConstsFileCmd = new CmdManualNamedConstsFile;
        msAdjacencyCmd = new CmdAdjacency;
        HighLevelGpuProgram.initCmds();
    }
    
    this(ref ResourceManager creator, string name, ResourceHandle handle,
         string group, bool isManual = false, ManualResourceLoader loader = null)
    {
        super(creator, name, handle, group, isManual, loader);
        mType = GpuProgramType.GPT_VERTEX_PROGRAM;
        mLoadFromFile = true;
        mSkeletalAnimation = false;
        mMorphAnimation = false;
        mPoseAnimation = 0;
        mVertexTextureFetch = false;
        mNeedsAdjacencyInfo = false;
        mCompileError = false;
        mLoadedManualNamedConstants = false;
        
        createParameterMappingStructures();
    }
    ~this() {}
    
    /** Sets the filename of the source assembly for this program.
     @remarks
     Setting this will have no effect until you (re)load the program.
     */
    void setSourceFile(string filename)
    {
        mFilename = filename;
        mSource = null;
        mLoadFromFile = true;
        mCompileError = false;
    }
    
    /** Sets the source assembly for this program from an in-memory string.
     @remarks
     Setting this will have no effect until you (re)load the program.
     */
    void setSource(string source)
    {
        mSource = source;
        mFilename = null;
        mLoadFromFile = false;
        mCompileError = false;
    }
    
    /** Gets the syntax code for this program e.g. arbvp1, fp20, vs_1_1 etc */
    string getSyntaxCode(){ return mSyntaxCode; }
    
    /** Sets the syntax code for this program e.g. arbvp1, fp20, vs_1_1 etc */
    void setSyntaxCode(string syntax)
    {
        mSyntaxCode = syntax;
    }
    
    /** Gets the name of the file used as source for this program. */
    string getSourceFile(){ return mFilename; }
    /** Gets the assembler source for this program. */
    string getSource(){ return mSource; }
    /// Set the program type (only valid before load)
    void setType(GpuProgramType t)
    {
        mType = t;
    }
    /// Get the program type
    GpuProgramType getType(){ return mType; }
    
    /** Returns the GpuProgram which should be bound to the pipeline.
     @remarks
     This method is simply to allow some subclasses of GpuProgram to delegate
     the program which is bound to the pipeline to a delegate, if required. */
    GpuProgram _getBindingDelegate() { return this; }
    
    /** Returns whether this program can be supported on the current renderer and hardware. */
    bool isSupported()
    {
        if (mCompileError || !isRequiredCapabilitiesSupported())
            return false;
        
        return GpuProgramManager.getSingleton().isSyntaxSupported(mSyntaxCode);
    }
    
    /** Creates a new parameters object compatible with this program definition. 
     @remarks
     It is recommended that you use this method of creating parameters objects
     rather than going direct to GpuProgramManager, because this method will
     populate any implementation-specific extras (like named parameters) where
     they are appropriate.
     */
    GpuProgramParametersPtr createParameters()
    {
        // Default implementation simply returns standard parameters.
        GpuProgramParametersPtr ret = 
            GpuProgramManager.getSingleton().createParameters();
        
        
        // optionally load manually supplied named constants
        if (!mManualNamedConstantsFile.empty() && !mLoadedManualNamedConstants)
        {
            try 
            {
                GpuNamedConstants namedConstants;
                DataStream stream = 
                    ResourceGroupManager.getSingleton().openResource(
                        mManualNamedConstantsFile, mGroup, true, this);
                namedConstants.load(stream);
                setManualNamedConstants(namedConstants);
            }
            catch(Exception e)
            {
                LogManager.getSingleton().stream() <<
                    "Unable to load manual named constants for GpuProgram " << mName <<
                        ": " << e.msg;
            }
            mLoadedManualNamedConstants = true;
        }
        
        
        // set up named parameters, if any
        if (!mConstantDefs.isNull() && !mConstantDefs.get().map.emptyAA())
        {
            ret.get()._setNamedConstants(mConstantDefs);
        }
        // link shared logical / physical map for low-level use
        ret.get()._setLogicalIndexes(mFloatLogicalToPhysical, mDoubleLogicalToPhysical, mIntLogicalToPhysical);
        
        // Copy in default parameters if present
        if (!mDefaultParams.isNull())
            ret.get().copyConstantsFrom(mDefaultParams.get());
        
        return ret;
    }
    
    /** Sets whether a vertex program includes the required instructions
     to perform skeletal animation. 
     @remarks
     If this is set to true, OGRE will not blend the geometry according to 
     skeletal animation, it will expect the vertex program to do it.
     */
    void setSkeletalAnimationIncluded(bool included) 
    { mSkeletalAnimation = included; }
    
    /** Returns whether a vertex program includes the required instructions
     to perform skeletal animation. 
     @remarks
     If this returns true, OGRE will not blend the geometry according to 
     skeletal animation, it will expect the vertex program to do it.
     */
    bool isSkeletalAnimationIncluded(){ return mSkeletalAnimation; }
    
    /** Sets whether a vertex program includes the required instructions
     to perform morph animation. 
     @remarks
     If this is set to true, OGRE will not blend the geometry according to 
     morph animation, it will expect the vertex program to do it.
     */
    void setMorphAnimationIncluded(bool included) 
    { mMorphAnimation = included; }
    
    /** Sets whether a vertex program includes the required instructions
     to perform pose animation. 
     @remarks
     If this is set to true, OGRE will not blend the geometry according to 
     pose animation, it will expect the vertex program to do it.
     @param poseCount The number of simultaneous poses the program can blend
     */
    void setPoseAnimationIncluded(ushort poseCount) 
    { mPoseAnimation = poseCount; }
    
    /** Returns whether a vertex program includes the required instructions
     to perform morph animation. 
     @remarks
     If this returns true, OGRE will not blend the geometry according to 
     morph animation, it will expect the vertex program to do it.
     */
    bool isMorphAnimationIncluded(){ return mMorphAnimation; }
    
    /** Returns whether a vertex program includes the required instructions
     to perform pose animation. 
     @remarks
     If this returns true, OGRE will not blend the geometry according to 
     pose animation, it will expect the vertex program to do it.
     */
    bool isPoseAnimationIncluded(){ return mPoseAnimation > 0; }
    /** Returns the number of simultaneous poses the vertex program can 
     blend, for use in pose animation.
     */
    ushort getNumberOfPosesIncluded(){ return mPoseAnimation; }
    /** Sets whether this vertex program requires support for vertex 
     texture fetch from the hardware.
     */
    void setVertexTextureFetchRequired(bool r) { mVertexTextureFetch = r; }
    /** Returns whether this vertex program requires support for vertex 
     texture fetch from the hardware.
     */
    bool isVertexTextureFetchRequired(){ return mVertexTextureFetch; }
    
    /** Sets whether this geometry program requires adjacency information
     from the input primitives.
     */
    void setAdjacencyInfoRequired(bool r) { mNeedsAdjacencyInfo = r; }
    /** Returns whether this geometry program requires adjacency information 
     from the input primitives.
     */
    bool isAdjacencyInfoRequired(){ return mNeedsAdjacencyInfo; }
    
    /** Get a reference to the default parameters which are to be used for all
     uses of this program.
     @remarks
     A program can be set up with a list of default parameters, which can save time when 
     using a program many times in a material with roughly the same settings. By 
     retrieving the default parameters and populating it with the most used options, 
     any new parameter objects created from this program afterwards will automatically include
     the default parameters; thus users of the program need only change the parameters
     which are unique to their own usage of the program.
     */
    GpuProgramParametersPtr getDefaultParameters()
    {
        if (mDefaultParams.isNull())
        {
            mDefaultParams = createParameters();
        }
        return mDefaultParams;
    }
    
    /** Returns true if default parameters have been set up.  
     */
    bool hasDefaultParameters(){ return !mDefaultParams.isNull(); }
    
    /** Returns whether a vertex program wants light and material states to be passed
     through fixed pipeline low level API rendering calls (default false, subclasses can override)
     @remarks
     Most vertex programs do not need this material information, however GLSL
     shaders can ref er to this material and lighting state so enable this option
     */
    bool getPassSurfaceAndLightStates(){ return false; }
    
    /** Returns whether a fragment program wants fog state to be passed
     through fixed pipeline low level API rendering calls (default true, subclasses can override)
     @remarks
     On DirectX, shader model 2 and earlier continues to have fixed-function fog
     applied to it, so fog state is still passed (you should disable fog on the
     pass if you want to perform fog in the shader). In OpenGL it is also
     common to be able to access the fixed-function fog state inside the shader. 
     */
    bool getPassFogStates(){ return true; }
    
    /** Returns whether a vertex program wants transform state to be passed
     through fixed pipeline low level API rendering calls
     @remarks
     Most vertex programs do not need fixed-function transform information, however GLSL
     shaders can ref er to this state so enable this option
     */
    bool getPassTransformStates(){ return false; }
    
    /** Returns a string that specifies the language of the gpu programs as specified
     in a material script. ie: asm, cg, hlsl, glsl
     */
    string getLanguage()
    {
        static string language = "asm";
        
        return language;
    }
    
    /** Did this program encounter a compile error when loading?
     */
    bool hasCompileError(){ return mCompileError; }
    
    /** Reset a compile error if it occurred, allowing the load to be retried
     */
    void resetCompileError() { mCompileError = false; }
    
    /** Allows you to manually provide a set of named parameter mappings
     to a program which would not be able to derive named parameters itself.
     @remarks
     You may wish to use this if you have assembler programs that were compiled
     from a high-level source, and want the convenience of still being able
     to use the named parameters from the original high-level source.
     @see setManualNamedConstantsFile
     */
    void setManualNamedConstants(GpuNamedConstants namedConstants)
    {
        createParameterMappingStructures();
        //*(&mConstantDefs.get()) = namedConstants;//TODO SharedPtr.get() pointer assignment, using .set()
        mConstantDefs.copyToPtr(&namedConstants);
        
        mFloatLogicalToPhysical.get().bufferSize = mConstantDefs.get().floatBufferSize;
        mIntLogicalToPhysical.get().bufferSize = mConstantDefs.get().intBufferSize;
        mFloatLogicalToPhysical.get().map.clear();
        mIntLogicalToPhysical.get().map.clear();
        // need to set up logical mappings too for some rendersystems
        foreach (name, def; mConstantDefs.get().map)
        {
            // only consider non-array entries
            if (name.countUntil("[") == -1)
            {
                auto gliu = GpuLogicalIndexUse(def.physicalIndex, def.arraySize * def.elementSize, def.variability);
                if (def.isFloat())
                {
                    mFloatLogicalToPhysical.get().map[def.logicalIndex] = gliu;
                }
                else
                {
                    mIntLogicalToPhysical.get().map[def.logicalIndex] = gliu;
                }
            }
        }
        
        
    }
    
    /// Get a read-only reference to the named constants registered for this program (manually or automatically)
    GpuNamedConstants getNamedConstants(){ return *mConstantDefs.get(); }
    
    /** Specifies the name of a file from which to load named parameters mapping
            for a program which would not be able to derive named parameters itself.
        @remarks
            You may wish to use this if you have assembler programs that were compiled
            from a high-level source, and want the convenience of still being able
            to use the named parameters from the original high-level source. This
            method will make a low-level program search in the resource group of the
            program for the named file from which to load parameter names from. 
            The file must be in the format produced by GpuNamedConstants::save.
        */
    void setManualNamedConstantsFile(string paramDefFile)
    {
        mManualNamedConstantsFile = paramDefFile;
        mLoadedManualNamedConstants = false;
    }
     
     /** Gets the name of a file from which to load named parameters mapping
     for a program which would not be able to derive named parameters itself.
     */
    string getManualNamedConstantsFile(){ return mManualNamedConstantsFile; }
    /** Get the full list of named constants.
     @note
     Only available if this parameters object has named parameters, which means either
     a high-level program which loads them, or a low-level program which has them
     specified manually.
     */
    GpuNamedConstants* getConstantDefinitions(){ return mConstantDefs.get(); }
    
    /// @copydoc Resource.calculateSize
    override size_t calculateSize()
    {
        //TODO GpuPrgram.calculateSize()
        size_t memSize = 0;
        memSize += bool.sizeof * 7;
        memSize += mManualNamedConstantsFile.length * char.sizeof;
        memSize += mFilename.length * char.sizeof;
        memSize += mSource.length * char.sizeof;
        memSize += mSyntaxCode.length * char.sizeof;
        memSize += GpuProgramType.sizeof;
        memSize += ushort.sizeof;
        
        size_t paramsSize = 0;
        if(!mDefaultParams.isNull())
            paramsSize += mDefaultParams.getPointer().calculateSize();
        if(!mFloatLogicalToPhysical.isNull())
            paramsSize += mFloatLogicalToPhysical.getPointer().bufferSize;
        if(!mDoubleLogicalToPhysical.isNull())
            paramsSize += mDoubleLogicalToPhysical.getPointer().bufferSize;
        if(!mIntLogicalToPhysical.isNull())
            paramsSize += mIntLogicalToPhysical.getPointer().bufferSize;
        if(!mConstantDefs.isNull())
            paramsSize += mConstantDefs.calculateSize();
        
        return memSize + paramsSize;
    }
    
    
protected:
    /// method which must be implemented by subclasses, load from mSource
    abstract void loadFromSource() ;
    
}

//alias SharedPtr!GpuProgram GpuProgramPtr;

class GpuProgramManager : ResourceManager
{
    mixin Singleton!GpuProgramManager;
    
public:
    
    /*typedef set<string>.type SyntaxCodes;
     typedef map<string, SharedPtr!GpuSharedParameters>.type SharedParametersMap;
     
     typedef MemoryDataStream Microcode;
     typedef map<string, Microcode>.type MicrocodeMap;*/
    
    alias string[] SyntaxCodes;
    alias SharedPtr!GpuSharedParameters[string] SharedParametersMap;
    
    alias MemoryDataStream Microcode;
    alias Microcode[string] MicrocodeMap;
    
protected:
    
    SharedParametersMap mSharedParametersMap;
    MicrocodeMap mMicrocodeCache;
    bool mSaveMicrocodesToCache;
    bool mCacheDirty;           // When this is true the cache is 'dirty' and should be resaved to disk.
    
    static string addRenderSystemToName( string  name )
    {
        // Use the current render system
        RenderSystem rs = Root.getSingleton().getRenderSystem();
        
        return rs.getName() ~ "_" ~ name;
    }
    
    /// Specialised create method with specific parameters
    //abstract ref Resource createImpl(string name, ResourceHandle handle, 
    //                                 string group, bool isManual, ManualResourceLoader loader,
    //                                 GpuProgramType gptype, string syntaxCode);

    //FIXME Singleton can't be abstract
    override Resource createImpl(string name, ResourceHandle handle, 
                                 string group, bool isManual, ManualResourceLoader loader, 
                                 NameValuePairList createParams)
    { return null; }
    Resource createImpl(string name, ResourceHandle handle, 
                        string group, bool isManual, ManualResourceLoader loader,
                        GpuProgramType gptype, string syntaxCode)
    { return null; }

public:
    this()
    {
        // Loading order
        mLoadOrder = 50.0f;
        // Resource type
        mResourceType = "GpuProgram";
        mSaveMicrocodesToCache = false;
        mCacheDirty = false;
        
        // subclasses should register with resource group manager
    }
    ~this()
    {
        // subclasses should unregister with resource group manager
    }
    
    /** Loads a GPU program from a file of assembly. 
     @remarks
     This method creates a new program of the type specified as the second parameter.
     As with all types of ResourceManager, this class will search for the file in
     all resource locations it has been configured to look in.
     @param name The name of the GpuProgram
     @param groupName The name of the resource group
     @param filename The file to load
     @param gptype The type of program to create
     @param syntaxCode The name of the syntax to be used for this program e.g. arbvp1, vs_1_1
     */
    SharedPtr!GpuProgram load(string name, string groupName, 
                              string filename, GpuProgramType gptype, 
                              string syntaxCode)
    {
        SharedPtr!GpuProgram prg;
        {
            //OGRE_LOCK_AUTO_MUTEX
            synchronized(mLock)
            {
                prg = getByName(name);
                if (prg.isNull())
                {
                    prg = createProgram(name, groupName, filename, gptype, syntaxCode);
                }
            }
            
        }
        prg.get().load();
        return prg;
    }
    
    /** Loads a GPU program from a string of assembly code.
     @remarks
     The assembly code must be compatible with this manager - call the 
     getSupportedSyntax method for details of the supported syntaxes 
     @param name The identifying name to give this program, which can be used to
     retrieve this program later with getByName.
     @param groupName The name of the resource group
     @param code A string of assembly code which will form the program to run
     @param gptype The type of program to create.
     @param syntaxCode The name of the syntax to be used for this program e.g. arbvp1, vs_1_1
     */
    SharedPtr!GpuProgram loadFromstring(string name, string groupName,
                                        string code, GpuProgramType gptype,
                                        string syntaxCode)
    {
        SharedPtr!GpuProgram prg;
        {
            //OGRE_LOCK_AUTO_MUTEX
            synchronized(mLock)
            {
                prg = getByName(name);
                if (prg.isNull())
                {
                    prg = createProgramFromString(name, groupName, code, gptype, syntaxCode);
                }
            }
            
        }
        prg.get().load();
        return prg;
    }
    
    /** Returns the syntaxes that this manager supports. */
    ref SyntaxCodes getSupportedSyntax()
    {
        // Use the current render system
        RenderSystem rs = Root.getSingleton().getRenderSystem();
        
        // Get the supported syntaxed from RenderSystemCapabilities 
        return rs.getCapabilities().getSupportedShaderProfiles();
    }
    
    /** Returns whether a given syntax code (e.g. "ps_1_3", "fp20", "arbvp1") is supported. */
    bool isSyntaxSupported(string syntaxCode)
    {
        // Use the current render system
        RenderSystem rs = Root.getSingleton().getRenderSystem();
        
        // Get the supported syntax from RenderSystemCapabilities 
        return rs.getCapabilities().isShaderProfileSupported(syntaxCode);
    }
    
    /** Creates a new GpuProgramParameters instance which can be used to bind
     parameters to your programs.
     @remarks
     Program parameters can be shared between multiple programs if you wish.
     */
    GpuProgramParametersPtr createParameters()
    {
        return GpuProgramParametersPtr(new GpuProgramParameters());
    }
    
    /** Create a new, unloaded GpuProgram from a file of assembly. 
     @remarks    
     Use this method in preference to the 'load' methods if you wish to define
     a GpuProgram, but not load it yet; useful for saving memory.
     @par
     This method creates a new program of the type specified as the second parameter.
     As with all types of ResourceManager, this class will search for the file in
     all resource locations it has been configured to look in. 
     @param name The name of the program
     @param groupName The name of the resource group
     @param filename The file to load
     @param syntaxCode The name of the syntax to be used for this program e.g. arbvp1, vs_1_1
     @param gptype The type of program to create
     */
    SharedPtr!GpuProgram createProgram(string name, 
                                       string groupName, string filename, 
                                       GpuProgramType gptype, string syntaxCode)
    {
        SharedPtr!GpuProgram prg = create(name, groupName, gptype, syntaxCode);
        // Set all prarmeters (create does not set, just determines factory)
        prg.getAs().setType(gptype);
        prg.getAs().setSyntaxCode(syntaxCode);
        prg.getAs().setSourceFile(filename);
        return prg;
    }
    
    /** Create a GPU program from a string of assembly code.
     @remarks    
     Use this method in preference to the 'load' methods if you wish to define
     a GpuProgram, but not load it yet; useful for saving memory.
     @par
     The assembly code must be compatible with this manager - call the 
     getSupportedSyntax method for details of the supported syntaxes 
     @param name The identifying name to give this program, which can be used to
     retrieve this program later with getByName.
     @param groupName The name of the resource group
     @param code A string of assembly code which will form the program to run
     @param gptype The type of program to create.
     @param syntaxCode The name of the syntax to be used for this program e.g. arbvp1, vs_1_1
     */
    SharedPtr!GpuProgram createProgramFromString(string name, 
                                                 string groupName, string code, 
                                                 GpuProgramType gptype, string syntaxCode)
    {
        SharedPtr!GpuProgram prg = create(name, groupName, gptype, syntaxCode);
        // Set all parameters (create does not set, just determines factory)
        prg.getAs().setType(gptype);
        prg.getAs().setSyntaxCode(syntaxCode);
        prg.getAs().setSource(code);
        return prg;
    }
    
    /** General create method, using specific create parameters
     instead of name / value pairs. 
     */
    SharedPtr!Resource create(string name, string group, 
                              GpuProgramType gptype, string syntaxCode, bool isManual = false, 
                              ManualResourceLoader loader = null)
    {
        // Call creation implementation
        SharedPtr!Resource ret = SharedPtr!Resource(
            createImpl(name, getNextHandle(), group, isManual, loader, gptype, syntaxCode));
        
        addImpl(ret);
        // Tell resource group manager
        ResourceGroupManager.getSingleton()._notifyResourceCreated(ret);
        return ret;
    }
    
    /** Overrides the standard ResourceManager getByName method.
     @param name The name of the program to retrieve
     @param preferHighLevelPrograms If set to true (the default), high level programs will be
     returned in preference to low-level programs.
     */
    SharedPtr!Resource getByName(string name, bool preferHighLevelPrograms = true)
    {
        //SharedPtr!Resource ret;
        if (preferHighLevelPrograms)
        {
            auto ret = HighLevelGpuProgramManager.getSingleton().getByName(name);
            if (!ret.isNull())
                return ret;
        }
        return super.getByName(name);
    }
    
    
    /** Create a new set of shared parameters, which can be used across many 
     GpuProgramParameters objects of different structures.
     @param name The name to give the shared parameters so you can ref er to them
     later.
     */
    SharedPtr!GpuSharedParameters createSharedParameters(string name)
    {
        if ((name in mSharedParametersMap) !is null)
        {
            throw new InvalidParamsError(
                "The shared parameter set '" ~ name ~ "' already exists!", 
                "GpuProgramManager.createSharedParameters");
        }
        auto ret = SharedPtr!GpuSharedParameters(new GpuSharedParameters(name));
        mSharedParametersMap[name] = ret;
        return ret;
    }
    
    /** Retrieve a set of shared parameters, which can be used across many 
     GpuProgramParameters objects of different structures.
     */
    ref SharedPtr!GpuSharedParameters getSharedParameters(string name)
    {
        auto i = name in mSharedParametersMap;
        if (i is null)
        {
            throw new InvalidParamsError(
                "No shared parameter set with name '" ~ name ~ "'!", 
                "GpuProgramManager.createSharedParameters");
        }
        return *i;
    }
    
    /** Get (const) access to the available shared parameter sets. 
     */
    ref SharedParametersMap getAvailableSharedParameters()
    {
        return mSharedParametersMap;
    }
    
    /** Get if the microcode of a shader should be saved to a cache
     */
    bool getSaveMicrocodesToCache()
    {
        return mSaveMicrocodesToCache;
    }
    
    /** Set if the microcode of a shader should be saved to a cache
     */
    void setSaveMicrocodesToCache(bool val )
    {
        mSaveMicrocodesToCache = val;       
    }
    
    /** Returns true if the microcodecache changed during the run.
     */
    bool isCacheDirty()
    {
        return mCacheDirty;     
    }
    
    bool canGetCompiledShaderBuffer()
    {
        // Use the current render system
        RenderSystem rs = Root.getSingleton().getRenderSystem();
        
        // Check if the supported  
        return rs.getCapabilities().hasCapability(Capabilities.RSC_CAN_GET_COMPILED_SHADER_BUFFER);
    }
    /** Check if a microcode is available for a program in the microcode cache.
     @param name The name of the program.
     */
    bool isMicrocodeAvailableInCache( string name )
    {
        return (addRenderSystemToName(name) in mMicrocodeCache) !is null;
    }
    /** Returns a microcode for a program from the microcode cache.
     @param name The name of the program.
     */
    ref Microcode getMicrocodeFromCache( string name )
    {
        return *(addRenderSystemToName(name) in mMicrocodeCache);
    }
    
    /** Creates a microcode to be later added to the cache.
     @param size The size of the microcode in bytes
     */
    Microcode createMicrocode(uint size)
    {   
        //return new Microcode(new MemoryDataStream(size));
        return new Microcode(size);
    }
    
    /** Adds a microcode for a program to the microcode cache.
     @param name The name of the program.
     */
    void addMicrocodeToCache( string name, Microcode microcode )
    {   
        string nameWithRenderSystem = addRenderSystemToName(name);
        auto ptr = nameWithRenderSystem in mMicrocodeCache;
        if ( ptr is null )
        {
            mMicrocodeCache[nameWithRenderSystem] = microcode;
            // if cache is modified, mark it as dirty.
            mCacheDirty = true;
        }
        else
        {
            *ptr = microcode;
        }
    }
    
    void removeMicrocodeFromCache( string name )
    {
        string nameWithRenderSystem = addRenderSystemToName(name);
        auto foundIter = nameWithRenderSystem in mMicrocodeCache;
        
        if (foundIter !is null)
        {
            mMicrocodeCache.remove( name );
            mCacheDirty = true;
        }
    }
    
    /** Saves the microcode cache.lengthk.
     @param stream The destination stream
     */
    void saveMicrocodeCache( DataStream stream )
    {
        if (!mCacheDirty)
            return; 
        
        if (!stream.isWriteable() )
        {
            throw new CannotWriteToFileError(
                "Unable to write to stream " ~ stream.getName(),
                "GpuProgramManager.saveMicrocodeCache");
        }
        
        // write the size of the array
        uint sizeOfArray = cast(uint)mMicrocodeCache.length;
        stream.write(&sizeOfArray, uint.sizeof);
        
        // loop the array and save it
        foreach (nameOfShader, microcodeOfShader; mMicrocodeCache)
        {
            // saves the name of the shader
            {
                uint stringLength = cast(uint)nameOfShader.length;
                stream.write(&stringLength, uint.sizeof);
                stream.write(nameOfShader);//, stringLength);
            }
            // saves the microcode
            {
                uint microcodeLength = cast(uint)microcodeOfShader.size();
                stream.write(&microcodeLength, uint.sizeof);
                stream.write(microcodeOfShader.getPtr(), microcodeLength);
            }
        }
    }
    /** Loads the microcode cache from disk.
     @param stream The source stream
     */
    void loadMicrocodeCache( DataStream stream )
    {
        mMicrocodeCache.clear();
        
        // write the size of the array
        uint sizeOfArray = 0;
        stream.read(&sizeOfArray, uint.sizeof);
        
        // loop the array and load it
        
        for ( uint i = 0 ; i < sizeOfArray ; i++ )
        {
            string nameOfShader;
            // loads the name of the shader
            uint stringLength  = 0;
            stream.read(&stringLength, uint.sizeof);
            nameOfShader.length = stringLength;
            stream.read(&nameOfShader, stringLength);
            
            // loads the microcode
            uint microcodeLength = 0;
            stream.read(&microcodeLength, uint.sizeof);
            
            auto microcodeOfShader = new Microcode(new MemoryDataStream(nameOfShader, microcodeLength));      
            microcodeOfShader.seek(0);
            stream.read(microcodeOfShader.getPtr(), microcodeLength);
            
            mMicrocodeCache[nameOfShader] = microcodeOfShader;
        }
        
        // if cache is not modified, mark it as clean.
        mCacheDirty = false;
        
    }
    
}

/** @} */
/** @} */