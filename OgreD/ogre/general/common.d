module ogre.general.common;

import core.sync.mutex;
import std.container;
import std.math;
import std.range;

import ogre.compat;
import ogre.scene.light;
import ogre.rendersystem.renderwindow;

/** \addtogroup Core
*  @{
*/
/** \addtogroup General
*  @{
*/

/** Packages the details of a configuration option.
        @remarks
            Used for RenderSystem::getConfigOptions. If immutable is true, this
            option must be disabled for modifying.
    */
struct ConfigOption
{
    string name;
    string currentValue;
    StringVector possibleValues;
    bool _immutable;
}

//typedef map< String, ConfigOption >::type ConfigOptionMap;
alias ConfigOption[string] ConfigOptionMap;

/** Comparison functions used for the depth/stencil buffer operations and
    others. */


// TODO command line options
//int findCommandLineOpts(int numargs, char** argv, UnaryOptionList& unaryOptList,
//    BinaryOptionList& binOptList)

enum CompareFunction
{
    CMPF_ALWAYS_FAIL,
    CMPF_ALWAYS_PASS,
    CMPF_LESS,
    CMPF_LESS_EQUAL,
    CMPF_EQUAL,
    CMPF_NOT_EQUAL,
    CMPF_GREATER_EQUAL,
    CMPF_GREATER
}

/** High-level filtering options providing shortcuts to settings the
    minification, magnification and mip filters. */
enum TextureFilterOptions
{
    /// Equal to: min=FO_POINT, mag=FO_POINT, mip=FO_NONE
    TFO_NONE,
    /// Equal to: min=FO_LINEAR, mag=FO_LINEAR, mip=FO_POINT
    TFO_BILINEAR,
    /// Equal to: min=FO_LINEAR, mag=FO_LINEAR, mip=FO_LINEAR
    TFO_TRILINEAR,
    /// Equal to: min=FO_ANISOTROPIC, max=FO_ANISOTROPIC, mip=FO_LINEAR
    TFO_ANISOTROPIC
}

enum FilterType
{
    /// The filter used when shrinking a texture
    FT_MIN,
    /// The filter used when magnifying a texture
    FT_MAG,
    /// The filter used when determining the mipmap
    FT_MIP
}

/** Filtering options for textures / mipmaps. */
enum FilterOptions
{
    /// No filtering, used for FILT_MIP to turn off mipmapping
    FO_NONE,
    /// Use the closest pixel
    FO_POINT,
    /// Average of a 2x2 pixel area, denotes bilinear for MIN and MAG, trilinear for MIP
    FO_LINEAR,
    /// Similar to FO_LINEAR, but compensates for the angle of the texture plane
    FO_ANISOTROPIC
}

/** Light shading modes. */
enum ShadeOptions
{
    SO_FLAT,
    SO_GOURAUD,
    SO_PHONG
}

/** Fog modes. */
enum FogMode
{
    /// No fog. Duh.
    FOG_NONE,
    /// Fog density increases  exponentially from the camera (fog = 1/e^(distance * density))
    FOG_EXP,
    /// Fog density increases at the square of FOG_EXP, i.e. even quicker (fog = 1/e^(distance * density)^2)
    FOG_EXP2,
    /// Fog density increases linearly between the start and end distances
    FOG_LINEAR
}

/** Hardware culling modes based on vertex winding.
    This setting applies to how the hardware API culls triangles it is sent. */
enum CullingMode
{
    /// Hardware never culls triangles and renders everything it receives.
    CULL_NONE = 1,
    /// Hardware culls triangles whose vertices are listed clockwise in the view (default).
    CULL_CLOCKWISE = 2,
    /// Hardware culls triangles whose vertices are listed anticlockwise in the view.
    CULL_ANTICLOCKWISE = 3
}

/** Manual culling modes based on vertex normals.
    This setting applies to how the software culls triangles before sending them to the
    hardware API. This culling mode is used by scene managers which choose to implement it -
    normally those which deal with large amounts of fixed world geometry which is often
    planar (software culling movable variable geometry is expensive). */
enum ManualCullingMode
{
    /// No culling so everything is sent to the hardware.
    MANUAL_CULL_NONE = 1,
    /// Cull triangles whose normal is pointing away from the camera (default).
    MANUAL_CULL_BACK = 2,
    /// Cull triangles whose normal is pointing towards the camera.
    MANUAL_CULL_FRONT = 3
}

/** Enumerates the wave types usable with the Ogre engine. */
enum WaveformType
{
    /// Standard sine wave which smoothly changes from low to high and back again.
    WFT_SINE,
    /// An angular wave with aant increase / decrease speed with pointed peaks.
    WFT_TRIANGLE,
    /// Half of the time is spent at the min, half at the max with instant transition between.
    WFT_SQUARE,
    /// Gradual steady increase from min to max over the period with an instant return to min at the end.
    WFT_SAWTOOTH,
    /// Gradual steady decrease from max to min over the period, with an instant return to max at the end.
    WFT_INVERSE_SAWTOOTH,
    /// Pulse Width Modulation. Works like WFT_SQUARE, except the high to low transition is controlled by duty cycle.
    /// With a duty cycle of 50% (0.5) will give the same output as WFT_SQUARE.
    WFT_PWM
}

/** The polygon mode to use when rasterising. */
enum PolygonMode
{
    /// Only points are rendered.
    PM_POINTS = 1,
    /// Wiref rame models are rendered.
    PM_WIREFRAME = 2,
    /// Solid polygons are rendered.
    PM_SOLID = 3
}

/** An enumeration of broad shadow techniques */
enum ShadowTechnique
{
    /** No shadows */
    SHADOWTYPE_NONE = 0x00,
    /** Mask for additive shadows (not for direct use, use  SHADOWTYPE_ enum instead)
    */
    SHADOWDETAILTYPE_ADDITIVE = 0x01,
    /** Mask for modulative shadows (not for direct use, use  SHADOWTYPE_ enum instead)
    */
    SHADOWDETAILTYPE_MODULATIVE = 0x02,
    /** Mask for integrated shadows (not for direct use, use SHADOWTYPE_ enum instead)
    */
    SHADOWDETAILTYPE_INTEGRATED = 0x04,
    /** Mask for stencil shadows (not for direct use, use  SHADOWTYPE_ enum instead)
    */
    SHADOWDETAILTYPE_STENCIL = 0x10,
    /** Mask for texture shadows (not for direct use, use  SHADOWTYPE_ enum instead)
    */
    SHADOWDETAILTYPE_TEXTURE = 0x20,

    /** Stencil shadow technique which renders all shadow volumes as
        a modulation after all the non-transparent areas have been
        rendered. This technique is considerably less fillrate intensive
        than the additive stencil shadow approach when there are multiple
        lights, but is not an accurate model.
    */
    SHADOWTYPE_STENCIL_MODULATIVE = 0x12,
    /** Stencil shadow technique which renders each light as a separate
        additive pass to the scene. This technique can be very fillrate
        intensive because it requires at least 2 passes of the entire
        scene, more if there are multiple lights. However, it is a more
        accurate model than the modulative stencil approach and this is
        especially apparent when using coloured lights or bump mapping.
    */
    SHADOWTYPE_STENCIL_ADDITIVE = 0x11,
    /** Texture-based shadow technique which involves a monochrome render-to-texture
        of the shadow caster and a projection of that texture onto the
        shadow receivers as a modulative pass.
    */
    SHADOWTYPE_TEXTURE_MODULATIVE = 0x22,

    /** Texture-based shadow technique which involves a render-to-texture
        of the shadow caster and a projection of that texture onto the
        shadow receivers, built up per light as additive passes.
        This technique can be very fillrate intensive because it requires numLights + 2
        passes of the entire scene. However, it is a more accurate model than the
        modulative approach and this is especially apparent when using coloured lights
        or bump mapping.
    */
    SHADOWTYPE_TEXTURE_ADDITIVE = 0x21,

    /** Texture-based shadow technique which involves a render-to-texture
    of the shadow caster and a projection of that texture on to the shadow
    receivers, with the usage of those shadow textures completely controlled
    by the materials of the receivers.
    This technique is easily the most flexible of all techniques because
    the material author is in complete control over how the shadows are
    combined with regular rendering. It can perform shadows as accurately
    as SHADOWTYPE_TEXTURE_ADDITIVE but more efficiently because it requires
    less passes. However it also requires more expertise to use, and
    in almost all cases, shader capable hardware to really use to the full.
    @note The 'additive' part of this mode means that the colour of
    the rendered shadow texture is by default plain black. It does
    not mean it does the adding on your receivers automatically though, how you
    use that result is up to you.
    */
    SHADOWTYPE_TEXTURE_ADDITIVE_INTEGRATED = 0x25,
    /** Texture-based shadow technique which involves a render-to-texture
        of the shadow caster and a projection of that texture on to the shadow
        receivers, with the usage of those shadow textures completely controlled
        by the materials of the receivers.
        This technique is easily the most flexible of all techniques because
        the material author is in complete control over how the shadows are
        combined with regular rendering. It can perform shadows as accurately
        as SHADOWTYPE_TEXTURE_ADDITIVE but more efficiently because it requires
        less passes. However it also requires more expertise to use, and
        in almost all cases, shader capable hardware to really use to the full.
        @note The 'modulative' part of this mode means that the colour of
        the rendered shadow texture is by default the 'shadow colour'. It does
        not mean it modulates on your receivers automatically though, how you
        use that result is up to you.
    */
    SHADOWTYPE_TEXTURE_MODULATIVE_INTEGRATED = 0x26
}

/** An enumeration describing which material properties should track the vertex colours */
alias uint TrackVertexColour;
enum : TrackVertexColour 
{
    TVC_NONE        = 0x0,
    TVC_AMBIENT     = 0x1,
    TVC_DIFFUSE     = 0x2,
    TVC_SPECULAR    = 0x4,
    TVC_EMISSIVE    = 0x8
}

/** Sort mode for billboard-set and particle-system */
enum SortMode
{
    /** Sort by direction of the camera */
    SM_DIRECTION,
    /** Sort by distance from the camera */
    SM_DISTANCE
}

/** Defines the frame buffer types. */
enum FrameBufferType {
    FBT_COLOUR  = 0x1,
    FBT_DEPTH   = 0x2,
    FBT_STENCIL = 0x4
}

/** Flags for the Instance Manager when calculating ideal number of instances per batch */
enum InstanceManagerFlags
{
    /** Forces an amount of instances per batch low enough so that vertices * numInst < 65535
        since usually improves performance. In HW instanced techniques, this flag is ignored
    */
    IM_USE16BIT     = 0x0001,

    /** The num. of instances is adjusted so that as few pixels as possible are wasted
        in the vertex texture */
    IM_VTFBESTFIT   = 0x0002,

    /** Use a limited number of skeleton animations shared among all instances.
    Update only that limited amount of animations in the vertex texture.*/
    IM_VTFBONEMATRIXLOOKUP = 0x0004,

    IM_USEBONEDUALQUATERNIONS = 0x0008,

    /** Use one weight per vertex when recommended (i.e. VTF). */
    IM_USEONEWEIGHT = 0x0010,

    /** All techniques are forced to one weight per vertex. */
    IM_FORCEONEWEIGHT = 0x0020,

    IM_USEALL       = IM_USE16BIT|IM_VTFBESTFIT|IM_USEONEWEIGHT
}

/// Generic result of clipping
enum ClipResult
{
    /// Nothing was clipped
    CLIPPED_NONE = 0,
    /// Partially clipped
    CLIPPED_SOME = 1,
    /// Everything was clipped away
    CLIPPED_ALL = 2
}

/// Render window creation parameters.
struct RenderWindowDescription
{
    string              name;
    uint                width;
    uint                height;
    bool                useFullScreen;
    NameValuePairList   miscParams;
}

/// Render window creation parameters container.
alias RenderWindowDescription[] RenderWindowDescriptionList;

/// Render window container.
//typedef vector<RenderWindow*>::type RenderWindowList;
alias RenderWindow[] RenderWindowList;


// Some aliases
alias bool[string] UnaryOptionList;
alias string[string] BinaryOptionList;

/// Name / value parameter pair (first = name, second = value)
alias string[string] NameValuePairList;

/// Alias / Texture name pair (first = alias, second = texture name)
alias string[string] AliasTextureNamePairList;

/** A hashed vector(-ish array).

    Using std.container.Array as internal type.
    @todo WIP, broken/missing functionality etc.
*/
struct HashedVector(T)
{
public:
    //alias Array!T VectorImpl;
    alias T[] VectorImpl;

protected:
    VectorImpl mList;
    uint mListHash;
    bool mListHashDirty;

    void addToHash(T newPtr)
    {
        mListHash = FastHash(cast(ubyte*)&newPtr, T.sizeof, mListHash);
    }
    void recalcHash()
    {
        mListHash = 0;
        foreach (T i; mList)
            addToHash(i);
        mListHashDirty = false;
    }

public:

    @property size_t length()
    {
        return mList.length;
    }

    @property void length(size_t l)
    {
        mList.length = l;
    }

    void dirtyHash()
    {
        mListHashDirty = true;
    }
    bool isHashDirty()
    {
        return mListHashDirty;
    }

    size_t size(){ return mList.length; }

    bool empty(){ return mList.empty(); }

    //this(/+const+/ Array!T t)
    this(/+const+/ T[] t)
    {
        mList = t;
        mListHash = 0;
        mListHashDirty = (t.length > 0);
    }

    this(/+const+/ HashedVector!T rhs)
    {
        mList = rhs.mList.dup;//swap?
        mListHash = rhs.mListHash;
        mListHashDirty = rhs.mListHashDirty;
    }

    ~this() {}

    HashedVector!T opAssign(/+const+/ HashedVector!T rhs)
    {
        mList = rhs.mList.dup;//swap?
        mListHash = rhs.mListHash;
        mListHashDirty = rhs.mListHashDirty;
        return this;
    }

    T opIndex(size_t n)
    {
        return mList[n];
    }

    void opIndexAssign(T value, size_t i)
    {
        dirtyHash();
        mList[i] = value;
    }

    /*auto linearRemove(VectorImpl.Range r)
    {
        return mList.linearRemove(r);
    }*/

    auto opSlice()
    {
        return mList[];
    }

    size_t opDollar()
    {
        return mList.length;
    }

    auto opSlice(size_t a, size_t b)
    {
        return mList[a .. b];
    }
    
    /*void opSliceAssign(T value)
    {
        mList.opSliceAssign(value);
    }*/
    
    void opSliceAssign(T value, size_t i, size_t j)
    {
        mList[i .. j] = value;
    }
    
    void opSliceUnary(string op)()
    if(op == "++" || op == "--")
    {
        mList.opSliceUnary!op();
    }
    
    void opSliceUnary(string op)(size_t i, size_t j)
    if(op == "++" || op == "--")
    {
        mList.opSliceUnary!op(i, j);
    }
    
    void opSliceOpAssign(string op)(T value)
    {
        mList.opSliceOpAssign!op(value);
    }
    
    void opSliceOpAssign(string op)(T value, size_t i, size_t j)
    {
        mList.opSliceOpAssign!op(value, i, j);
    }

    T front()
    {
        // we have to assume that hash needs recalculating on non-const
        dirtyHash();
        return mList.front();
    }
    //T front(){ return mList.front(); }
    T back()
    {
        // we have to assume that hash needs recalculating on non-const
        dirtyHash();
        return mList.back();
    }
    //T back(){ return mList.back(); }

    void push_back(T t)
    {
        mList ~= t;
        // Quick progressive hash add
        if (!isHashDirty())
            addToHash(t);
    }
    void pop_back()
    {
        mList.popBack();
        dirtyHash();
    }
    void swap(ref HashedVector!T rhs)
    {
        std.algorithm.swap(mList, rhs.mList);
        dirtyHash();
    }
    void insert(size_t pos, T t)
    {
        bool recalc = (pos != mList.length);
        //mList.insertAfter(mList[], pos), t);
        //mList.insertAfter(mList[pos..pos+1], t);
        mList.insertBeforeIdx(pos, t);
        if (recalc)
            dirtyHash();
        else
            addToHash(t);
    }

    /*void insert(T t) const
    {
        mList.insert(t);
    }*/

    void insert(T t)
    {
        mList.insert(t);
        if (!isHashDirty())
            addToHash(t);
    }

    /*void reserve(size_t elements)
    {
        mList.reserve(elements);
    }*/

    /*void insert(iterator pos, size_type n,T& x)
    {
        mList.insert(pos, n, x);
        dirtyHash();
    }*/
    void erase(size_t pos)
    {
        //mList.linearRemove(mList[pos..pos+1]);
        mList.removeFromArrayIdx(pos);
        dirtyHash();
    }

    void clear()
    {
        mList.clear();
        mListHash = 0;
        mListHashDirty = false;
    }

    /*void resize(size_t n, ref T t = T())
    {
        bool recalc = false;
        if (n != size())
            recalc = true;

        mList.resize(n, t);
        if (recalc)
            dirtyHash();
    }*/

    bool opEquals(HashedVector!T b)
    { return mListHash == b.mListHash; }

    bool opLessThan(HashedVector!T b)
    { return mListHash < b.mListHash; }

    //Array!T getArray()
    T[] getArray()
    {
        return mList;
    }

    /// Get the hash value
    uint getHash()
    {
        if (isHashDirty())
            recalcHash();

        return mListHash;
    }
public:

}

/** Template class describing a simple pool of items.
 * @todo C++ behaviour, but is there really any difference if front or back :P
*/
class Pool(T)
{
protected:
    //Array!T mItems;
    T[] mItems;
    //OGRE_AUTO_MUTEX
    Mutex mLock;
public:
    this() { mLock = new Mutex;}
    ~this() {}

    /** Get the next item from the pool.
    @return pair indicating whether there was a free item, and the item if so
    */
    pair!(bool, T) removeItem()
    {
        //OGRE_LOCK_AUTO_MUTEX
        synchronized(this)
        {
            pair!(bool, T) ret;
            if (mItems.empty())
            {
                ret.first = false;
            }
            else
            {
                ret.first = true;
                ret.second = mItems.back();
                mItems.popBack();
            }
            return ret;
        }
    }

    /** Add a new item to the pool.
    */
    void addItem(T i)
    {
        //OGRE_LOCK_AUTO_MUTEX
        synchronized(mLock)
        {
            mItems.insert(i);
        }
    }
    /// Clear the pool
    void clear()
    {
        //OGRE_LOCK_AUTO_MUTEX
        synchronized(mLock)
        {
            mItems.clear();
        }
    }
    
    invariant()
    {
        assert(mLock !is null);
    }
}

struct TRect(T)
{
    T left, top, right, bottom;
    //TRect() : left(0), top(0), right(0), bottom(0) {}
    this( T l, T t, T r, T b )
    {
        left = l; top = t; right = r; bottom = b;
    }

    this( TRect /+&+/ o )
    {
        left = o.left;
        top = o.top;
        right = o.right;
        bottom = o.bottom;
    }

    TRect opAssign( TRect /+&+/ o )
    {
        left = o.left;
        top = o.top;
        right = o.right;
        bottom = o.bottom;
        return this;
    }

    T width()
    {
        return right - left;
    }

    T height()
    {
        return bottom - top;
    }

    bool isNull()
    {
        return width() == 0 || height() == 0;
    }

    void setNull()
    {
        left = right = top = bottom = 0;
    }

    TRect merge(/+ref+/TRect rhs)
    {
        if (isNull())
        {
            this = rhs; //TODO opAssign copies values instead assigns?
        }
        else if (!rhs.isNull())
        {
            left = cast(T)std.math.fmin(left, rhs.left);
            right = cast(T)std.math.fmax(right, rhs.right);
            top = cast(T)std.math.fmin(top, rhs.top);
            bottom = cast(T)std.math.fmax(bottom, rhs.bottom);
        }
        return this;
    }

    TRect intersect(/+ref+/TRect rhs)
    {
        TRect ret;
        if (isNull() || rhs.isNull())
        {
            // empty
            return ret;
        }
        else
        {
            ret.left = cast(T)std.math.fmax(left, rhs.left);
            ret.right = cast(T)std.math.fmin(right, rhs.right);
            ret.top = cast(T)std.math.fmax(top, rhs.top);
            ret.bottom = cast(T)std.math.fmin(bottom, rhs.bottom);
        }

        if (ret.left > ret.right || ret.top > ret.bottom)
        {
            // no intersection, return empty
            ret.left = ret.top = ret.right = ret.bottom = 0;
        }
        return ret;
    }

    string toString()
    {
        return "TRect(l:" ~ std.conv.to!string(left) ~ ", t:"
            ~ std.conv.to!string(top) ~ ", r:"
            ~ std.conv.to!string(right) ~ ", b:"
            ~ std.conv.to!string(bottom) ~ ")";
    }

}

/** Structure used to define a box in a 3-D integer space.
    Note that the left, top, and front edges are included but the right,
    bottom and back ones are not.
 */
class Box //D structs can't inherit
{
    size_t left, top, right = 1, bottom = 1, front, back = 1;

    this(){}

    //TODO 
    this( Box box )
    {
        left=box.left; top=box.top;
        right=box.right; bottom=box.bottom;
        front=box.front; back=box.back;
        assert(right >= left && bottom >= top && back >= front);
    }

    /** Define a box from left, top, right and bottom coordinates
        This box will have depth one (front=0 and back=1).
        @param  l   x value of left edge
        @param  t   y value of top edge
        @param  r   x value of right edge
        @param  b   y value of bottom edge
        @note Note that the left, top, and front edges are included
            but the right, bottom and back ones are not.
    */
    this( size_t l, size_t t, size_t r, size_t b )
    {
        left=l; top=t;
        right=r; bottom=b;
        front=0; back=1;
        assert(right >= left && bottom >= top && back >= front);
    }
    /** Define a box from left, top, front, right, bottom and back
        coordinates.
        @param  l   x value of left edge
        @param  t   y value of top edge
        @param  ff  z value of front edge
        @param  r   x value of right edge
        @param  b   y value of bottom edge
        @param  bb  z value of back edge
        @note Note that the left, top, and front edges are included
            but the right, bottom and back ones are not.
    */
    this( size_t l, size_t t, size_t ff, size_t r, size_t b, size_t bb )
    {
        left=l; top=t;
        right=r; bottom=b;
        front=ff; back=bb;
        assert(right >= left && bottom >= top && back >= front);
    }

    /// Return true if the other box is a part of this one
    bool contains(Box def)
    {
        return (def.left >= left && def.top >= top && def.front >= front &&
            def.right <= right && def.bottom <= bottom && def.back <= back);
    }

    /// Get the width of this box
    size_t getWidth() const { return right-left; }
    /// Get the height of this box
    size_t getHeight() const { return bottom-top; }
    /// Get the depth of this box
    size_t getDepth() const { return back-front; }
}

alias HashedVector!Light LightList;
//alias Array!Light LightList;

/** Structure used to define a rectangle in a 2-D floating point space.
*/
alias TRect!float FloatRect;

/** Structure used to define a rectangle in a 2-D floating point space,
subject to double / single floating point settings.
*/
alias TRect!Real RealRect;

/** Structure used to define a rectangle in a 2-D integer space.
*/
alias TRect!long Rect; //TODO C++ long is D's int?

/** General hash function, derived from here
    http://www.azillionmonkeys.com/qed/hash.html
    Original by Paul Hsieh

    Pass ubyte[].ptr as pointer.
*/
//uint FastHash (char * data, int len, uint hashSoFar)
uint FastHash (ubyte* cdata, size_t len, uint hashSoFar)
{
    uint hash;
    uint tmp;
    int rem;
    ubyte* data = cast(ubyte*)cdata;

    version(BigEndian)
    {
        uint OGRE_GET16BITS(ubyte* d)
        {
            return  (*(cast(ushort *) (d)));
        }
    }
    else
    {
        // Cast to uint16 in little endian means first byte is least significant
        // replicate that here
        uint OGRE_GET16BITS(ubyte* d)
        {
            return (*(cast(ubyte *) (d)) + (*(cast(ubyte *) (d+1))<<8));
        }
    }


    if (hashSoFar)
        hash = hashSoFar;
    else
        hash = cast(uint)len;

    if (len <= 0 || data is null) return 0;

    rem = len & 3;
    len >>= 2;

    /* Main loop */
    for (;len > 0; len--) {
        hash  += OGRE_GET16BITS (data);
        tmp    = (OGRE_GET16BITS (data+2) << 11) ^ hash;
        hash   = (hash << 16) ^ tmp;
        data  += 2*ushort.sizeof;
        hash  += hash >> 11;
    }

    /* Handle end cases */
    switch (rem) {
    case 3: hash += OGRE_GET16BITS (data);
        hash ^= hash << 16;
        hash ^= data[ushort.sizeof] << 18;
        hash += hash >> 11;
        break;
    case 2: hash += OGRE_GET16BITS (data);
        hash ^= hash << 11;
        hash += hash >> 17;
        break;
    case 1: hash += *data;
        hash ^= hash << 10;
        hash += hash >> 1;
    default:
        break;
    }

    /* Force "avalanching" of final 127 bits */
    hash ^= hash << 3;
    hash += hash >> 5;
    hash ^= hash << 4;
    hash += hash >> 17;
    hash ^= hash << 25;
    hash += hash >> 6;

    return hash;
}


/// Utility class to generate a sequentially numbered series of names
class NameGenerator
{
protected:
    string mPrefix;
    ulong mNext;

    /**
     * @todo Not sure if synchronized is enough or use Mutex.
     */
    /*OGRE_AUTO_MUTEX lock;
private:
    this()
    {
        lock = new OGRE_AUTO_MUTEX;
    }*/
public:
    this(NameGenerator rhs)
    {
        //this();
        mPrefix = rhs.mPrefix;
        mNext = rhs.mNext;
    }

    this(string prefix)
    {
        //this();
        mPrefix = prefix;
        mNext = 1;
    }

    /**
     * @todo should probably add 'synchronized' as function statement or whatever, but 'shared is not callable'
     * */
    /// Generate a new name
    string generate()
    {
        //OGRE_LOCK_AUTO_MUTEX
        //lock.lock();
        //scope(exit) lock.unlock();
        synchronized (this) 
        {
            return mPrefix ~ std.conv.to!string(mNext++);
        }
    }

    /// Reset the internal counter
    void reset()
    {
        synchronized (this)
        {
            mNext = 1;
        }
    }

    /// Manually set the internal counter (use caution)
    void setNext(ulong val)
    {
        synchronized (this)
        {
            mNext = val;
        }
    }

    /// Get the internal counter
    ulong getNext()//
    {
        // lock even on get because 64-bit may not be atomic read
        synchronized (this)
        {
            return mNext;
        }
    }
}

unittest
{
    //import std.stdio;

    //import core.thread;
    //import core.time;

    struct Stest { ubyte a,b,c,d,e;}

    Stest s0; //s0.b = [1,2,3,4,5];
    Stest s1; //s1.b = [6,7,8,9,10];
    s0.a=1; s0.b=2; s0.c=3; s0.d=4; s0.e=5;
    s1.a=6; s1.b=7; s1.c=8; s1.d=9; s1.e=10;

    TRect!float r;
    TRect!float r2 = TRect!float(1f,1f,5f,5f);

    UnaryOptionList opl;
    opl["Fullscreen"] = true;
    NameValuePairList nvpl;
    nvpl["abc"] = "def";

    auto pool = new Pool!Stest;
    pool.addItem(s0);
    auto ret1 = pool.removeItem();
    //writeln(ret1.first, ",", ret1.second);
    auto ret2 = pool.removeItem();
    //writeln(ret2.first, ",",ret2.second);

    HashedVector!Stest hv;
    hv.push_back(s0);
    hv.push_back(s1);
    assert(hv.getHash() == 0x6aef3527);

    ubyte[] d = [1,2,3,4,5,6,7,8,9,10];
    ubyte[] d1 = [1,2,3,4,5];
    ubyte[] d2 = [6,7,8,9,10];

    uint hash = FastHash(d.ptr, d.length, 0);
    assert(hash == 0xb9480e5);

    hash = FastHash(d1.ptr, d1.length, 0);
    hash = FastHash(d2.ptr, d2.length, hash);
    assert(hash == 0x6aef3527); //IMO should be same as d's hash

    
    /*NameGenerator ng = new NameGenerator("Ogre/");
    ng.reset();
    void write()
    {
        int l = 10;
        while(l>0){
            writeln(ng.generate(), Thread.getThis().name());
            l--;
            Thread.getThis().sleep(dur!("msecs")(1));
        }
    }
    //Freshen my memory: output can be unsorted with this test, just not duplicates/skipped values
    Thread t0 = new Thread(&write);
    t0.name = "/t0";
    Thread t1 = new Thread(&write);
    t1.name = "/t1";

    t0.start();
    t1.start();*/
    
}

/** @} */
/** @} */