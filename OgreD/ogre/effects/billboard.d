module ogre.effects.billboard;
import ogre.math.vector;
import ogre.general.colourvalue;
import ogre.math.angles;
import ogre.compat;
import ogre.general.common;
import ogre.effects.billboardset;


//BBSet
import std.conv : to;
import std.algorithm;
import std.array;

import ogre.scene.movableobject;
import ogre.scene.renderable;
import ogre.scene.camera;
import ogre.math.axisalignedbox;
import ogre.materials.material;
import ogre.rendersystem.vertex;
import ogre.rendersystem.hardware;
import ogre.math.quaternion;
import ogre.math.sphere;
import ogre.math.matrix;
import ogre.general.log;
import ogre.scene.scenemanager;
import ogre.general.radixsort;
import ogre.resources.resourcegroupmanager;
import ogre.rendersystem.renderqueue;
import ogre.general.root;
import ogre.materials.materialmanager;
import ogre.math.maths;
import ogre.sharedptr;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Effects
 *  @{
 */

/** A billboard is a primitive which always faces the camera in every frame.
 @remarks
 Billboards can be used for special effects or some other trickery which requires the
 triangles to always facing the camera no matter where it is. Ogre groups billboards into
 sets for efficiency, so you should never create a billboard on it's own (it's ok to have a
 set of one if you need it).
 @par
 Billboards have their geometry generated every frame depending on where the camera is. It is most
 beneficial for all billboards in a set to be identically sized since Ogre can take advantage of this and
 save some calculations - useful when you have sets of hundreds of billboards as is possible with special
 effects. You can deviate from this if you wish (example: a smoke effect would probably have smoke puffs
 expanding as they rise, so each billboard will legitimately have it's own size) but be aware the extra
 overhead this brings and try to avoid it if you can.
 @par
 Billboards are just the mechanism for rendering a range of effects such as particles. It is other classes
 which use billboards to create their individual effects, so the methods here are quite generic.
 @see
 BillboardSet
 */

class Billboard //: public FXAlloc
{
    //friend class BillboardSet;
    //friend class BillboardParticleRenderer;
package:
    @property
    {
        ///For outside module 'friends'
        void _Width(Real w) { mWidth = w; }
        ///For outside module 'friends'
        Real _Width() { return mWidth; }
        ///For outside module 'friends'
        void _Height(Real h) { mHeight = h; }
        ///For outside module 'friends'
        Real _Height() { return mHeight; }
        ///For outside module 'friends'
        bool _OwnDimensions(bool own) { return (mOwnDimensions = own); }
        ///For outside module 'friends'
        bool _OwnDimensions() { return mOwnDimensions; }
    }
protected:
    bool mOwnDimensions;
    bool mUseTexcoordRect;
    ushort mTexcoordIndex;      // index into the BillboardSet array of texture coordinates
    FloatRect mTexcoordRect;    // individual texture coordinates
    Real mWidth;
    Real mHeight;
public:
    // Note the intentional public access to main internal variables used at runtime
    // Forcing access via get/set would be too costly for 000's of billboards
    Vector3 mPosition;
    // Normalised direction vector
    Vector3 mDirection;
    BillboardSet mParentSet;
    ColourValue mColour;
    Radian mRotation;
    
    /** Default constructor.
     */
    this()
    {
        mOwnDimensions = false;
        mUseTexcoordRect = false;
        mTexcoordIndex = 0;
        mPosition = Vector3.ZERO;
        mDirection = Vector3.ZERO;
        mParentSet = null;
        mColour = ColourValue.White;
        mRotation = 0;
    }
    
    /** Default destructor.
     */
    ~this() {}
    
    /** Normal constructor as called by BillboardSet.
     */
    this(Vector3 position, ref BillboardSet owner,ColourValue colour = ColourValue.White)
    {
        mOwnDimensions = false;
        mUseTexcoordRect = false;
        mTexcoordIndex = 0;
        mPosition = position;
        mDirection = Vector3.ZERO;
        mParentSet = owner;
        mColour = colour;
        mRotation = 0;
    }
    
    /** Get the rotation of the billboard.
     @remarks
     This rotation is relative to the center of the billboard.
     */
    Radian getRotation(){ return mRotation; }
    
    /** Set the rotation of the billboard.
     @remarks
     This rotation is relative to the center of the billboard.
     */
    void setRotation(Radian rotation)
    {
        mRotation = rotation;
        if (mRotation != Radian(0))
            mParentSet._notifyBillboardRotated();
    }
    
    /** Set the position of the billboard.
     @remarks
     This position is relative to a point on the quad which is the billboard. Depending on the BillboardSet,
     this may be the center of the quad, the top-left etc. See BillboardSet::setBillboardOrigin for more info.
     */
    void setPosition(Vector3 position)
    {
        mPosition = position;
    }
    
    /** Set the position of the billboard.
     @remarks
     This position is relative to a point on the quad which is the billboard. Depending on the BillboardSet,
     this may be the center of the quad, the top-left etc. See BillboardSet::setBillboardOrigin for more info.
     */
    void setPosition(Real x, Real y, Real z)
    {
        mPosition.x = x;
        mPosition.y = y;
        mPosition.z = z;
    }
    
    /** Get the position of the billboard.
     @remarks
     This position is relative to a point on the quad which is the billboard. Depending on the BillboardSet,
     this may be the center of the quad, the top-left etc. See BillboardSet::setBillboardOrigin for more info.
     */
    Vector3 getPosition()
    {
        return mPosition;
    }
    
    /** Sets the width and height for this billboard.
     @remarks
     Note that it is most efficient for every billboard in a BillboardSet to have the same dimensions. If you
     choose to alter the dimensions of an individual billboard the set will be less efficient. Do not call
     this method unless you really need to have different billboard dimensions within the same set. Otherwise
     just call the BillboardSet::setDefaultDimensions method instead.
     */
    void setDimensions(Real width, Real height)
    {
        mOwnDimensions = true;
        mWidth = width;
        mHeight = height;
        mParentSet._notifyBillboardResized();
    }
    
    /** Resets this Billboard to use the parent BillboardSet's dimensions instead of it's own. */
    void resetDimensions() { mOwnDimensions = false; }
    /** Sets the colour of this billboard.
     @remarks
     Billboards can be tinted based on a base colour. This allows variations in colour irrespective of the
     base colour of the material allowing more varied billboards. The default colour is white.
     The tinting is effected using vertex colours.
     */
    void setColour(ColourValue colour)
    {
        mColour = colour;
    }
    
    /** Gets the colour of this billboard.
     */
    ColourValue getColour()
    {
        return mColour;
    }
    
    /** Returns true if this billboard deviates from the BillboardSet's default dimensions (i.e. if the
     Billboard::setDimensions method has been called for this instance).
     @see
     Billboard::setDimensions
     */
    bool hasOwnDimensions()
    {
        return mOwnDimensions;
    }
    
    /** Retrieves the billboard's personal width, if hasOwnDimensions is true. */
    Real getOwnWidth()
    {
        return mWidth;
    }
    
    /** Retrieves the billboard's personal width, if hasOwnDimensions is true. */
    Real getOwnHeight()
    {
        return mHeight;
    }

    /** Internal method for notifying the billboard of it's owner.
     */
    void _notifyOwner(ref BillboardSet owner)
    {
        mParentSet = owner;
    }
    
    /** Returns true if this billboard use individual texture coordinate rect (i.e. if the 
     Billboard::setTexcoordRect method has been called for this instance), or returns
     false if use texture coordinates defined in the parent BillboardSet's texture
     coordinates array (i.e. if the Billboard::setTexcoordIndex method has been called
     for this instance).
     @see
     Billboard::setTexcoordIndex()
     Billboard::setTexcoordRect()
     */
    bool isUseTexcoordRect(){ return mUseTexcoordRect; }
    
    /** setTexcoordIndex() sets which texture coordinate rect this billboard will use 
     when rendering. The parent billboard set may contain more than one, in which 
     case a billboard can be textured with different pieces of a larger texture 
     sheet very efficiently.
     @see
     BillboardSet::setTextureCoords()
     */
    void setTexcoordIndex(ushort texcoordIndex)
    {
        mTexcoordIndex = texcoordIndex;
        mUseTexcoordRect = false;
    }
    
    /** getTexcoordIndex() returns the previous value set by setTexcoordIndex(). 
     The default value is 0, which is always a valid texture coordinate set.
     @remarks
     This value is useful only when isUseTexcoordRect return false.
     */
    ushort getTexcoordIndex(){ return mTexcoordIndex; }
    
    /** setTexcoordRect() sets the individual texture coordinate rect of this billboard
     will use when rendering. The parent billboard set may contain more than one, in
     which case a billboard can be textured with different pieces of a larger texture
     sheet very efficiently.
     */
    void setTexcoordRect(FloatRect texcoordRect)
    {
        mTexcoordRect = texcoordRect;
        mUseTexcoordRect = true;
    }
    
    /** setTexcoordRect() sets the individual texture coordinate rect of this billboard
     will use when rendering. The parent billboard set may contain more than one, in
     which case a billboard can be textured with different pieces of a larger texture
     sheet very efficiently.
     */
    void setTexcoordRect(Real u0, Real v0, Real u1, Real v1)
    {
        setTexcoordRect(FloatRect(u0, v0, u1, v1));
    }
    
    /** getTexcoordRect() returns the previous value set by setTexcoordRect(). 
     @remarks
     This value is useful only when isUseTexcoordRect return true.
     */
    FloatRect getTexcoordRect(){ return mTexcoordRect; }
}


// Put here because wants to be friends

/** Enum covering what exactly a billboard's position means (center,
 top-left etc).
 @see
 BillboardSet::setBillboardOrigin
 */
enum BillboardOrigin
{
    BBO_TOP_LEFT,
    BBO_TOP_CENTER,
    BBO_TOP_RIGHT,
    BBO_CENTER_LEFT,
    BBO_CENTER,
    BBO_CENTER_RIGHT,
    BBO_BOTTOM_LEFT,
    BBO_BOTTOM_CENTER,
    BBO_BOTTOM_RIGHT
}
/** The rotation type of billboard. */
enum BillboardRotationType
{
    /// Rotate the billboard's vertices around their facing direction
    BBR_VERTEX,
    /// Rotate the billboard's texture coordinates
    BBR_TEXCOORD
}
/** The type of billboard to use. */
enum BillboardType
{
    /// Standard point billboard (default), always faces the camera completely and is always upright
    BBT_POINT,
    /// Billboards are oriented around a shared direction vector (used as Y axis) and only rotate around this to face the camera
    BBT_ORIENTED_COMMON,
    /// Billboards are oriented around their own direction vector (their own Y axis) and only rotate around this to face the camera
    BBT_ORIENTED_SELF,
    /// Billboards are perpendicular to a shared direction vector (used as Z axis, the facing direction) and X, Y axis are determined by a shared up-vertor
    BBT_PERPENDICULAR_COMMON,
    /// Billboards are perpendicular to their own direction vector (their own Z axis, the facing direction) and X, Y axis are determined by a shared up-vertor
    BBT_PERPENDICULAR_SELF
}

/** A collection of billboards (faces which are always facing the given direction) with the same (default) dimensions, material
 and which are fairly close proximity to each other.
 @remarks
 Billboards are rectangles made up of 2 tris which are always facing the given direction. They are typically used
 for special effects like particles. This class collects together a set of billboards with the same (default) dimensions,
 material and relative locality in order to process them more efficiently. The entire set of billboards will be
 culled as a whole (by default, although this can be changed if you want a large set of billboards
 which are spread out and you want them culled individually), individual Billboards have locations which are relative to the set (which itself derives it's
 position from the SceneNode it is attached to since it is a MoveableObject), they will be rendered as a single rendering operation,
 and some calculations will be sped up by the fact that they use the same dimensions so some workings can be reused.
 @par
 A BillboardSet can be created using the SceneManager::createBillboardSet method. They can also be used internally
 by other classes to create effects.
 @note
 Billboard bounds are only automatically calculated when you create them.
 If you modify the position of a billboard you may need to call 
 _updateBounds if the billboard moves outside the original bounds. 
 Similarly, the bounds do no shrink when you remove a billboard, 
 if you want them to call _updateBounds, but note this requires a
 potentially expensive examination of every billboard in the set.
 */
class BillboardSet : MovableObject, Renderable
{
    mixin Renderable.Renderable_Impl;
    mixin Renderable.Renderable_Any_Impl;
    
protected:
    /** Private constructor (instances cannot be created directly).
     */
    this()
    {
        
        mBoundingRadius = 0.0f;
        mOriginType =  BillboardOrigin.BBO_CENTER ;
        mRotationType =  BillboardRotationType.BBR_TEXCOORD ;
        mAllDefaultSize =  true ;
        mAutoExtendPool =  true ;
        mSortingEnabled = false;
        mAccurateFacing = false;
        mAllDefaultRotation = true;
        mWorldSpace = false;
        mVertexData = null;
        mIndexData = null;
        mCullIndividual =  false ;
        mBillboardType = BillboardType.BBT_POINT;
        mCommonDirection = Vector3.UNIT_Z;
        mCommonUpVector = Vector3.UNIT_Y;
        mPointRendering = false;
        mBuffersCreated = false;
        mPoolSize = 0;
        mExternalData = false;
        mAutoUpdate = true;
        mBillboardDataChanged = true;
        
        setDefaultDimensions( 100, 100 );
        setMaterialName( "BaseWhite" );
        mCastShadows = false;
        setTextureStacksAndSlices( 1, 1 );
    }
    
    /// Bounds of all billboards in this set
    AxisAlignedBox mAABB;
    /// Bounding radius
    Real mBoundingRadius;
    
    /// Origin of each billboard
    BillboardOrigin mOriginType;
    /// Rotation type of each billboard
    BillboardRotationType mRotationType;
    
    /// Default width of each billboard
    Real mDefaultWidth;
    /// Default height of each billboard
    Real mDefaultHeight;
    
    /// Name of the material to use
    string mMaterialName;
    /// Pointer to the material to use
    SharedPtr!Material mMaterial;
    
    /// True if no billboards in this set have been resized - greater efficiency.
    bool mAllDefaultSize;
    
    /// Flag indicating whether to autoextend pool
    bool mAutoExtendPool;
    
    /// Flag indicating whether the billboards has to be sorted
    bool mSortingEnabled;
    
    // Use 'true' billboard to cam position facing, rather than camera direcion
    bool mAccurateFacing;
    
    bool mAllDefaultRotation;
    bool mWorldSpace;
    
    //typedef list<Billboard*>::type ActiveBillboardList;
    //typedef list<Billboard*>::type FreeBillboardList;
    //typedef vector<Billboard*>::type BillboardPool;
    
    alias Billboard[] ActiveBillboardList;
    alias Billboard[] FreeBillboardList;
    alias Billboard[] BillboardPool;
    
    /** Active billboard list.
     @remarks
     This is a linked list of pointers to billboards in the billboard pool.
     @par
     This allows very fast insertions and deletions from anywhere in the list to activate / deactivate billboards
     (required for particle systems etc.) as well as reuse of Billboard instances in the pool
     without construction & destruction which avoids memory thrashing.
     */
    ActiveBillboardList mActiveBillboards;
    
    /** Free billboard queue.
     @remarks
     This contains a list of the billboards free for use as new instances
     as required by the set. Billboard instances are preconstructed up to the estimated size in the
     mBillboardPool vector and are referenced on this deque at startup. As they get used this deque
     reduces, as they get released back to to the set they get added back to the deque.
     */
    FreeBillboardList mFreeBillboards;
    
    /** Pool of billboard instances for use and reuse in the active billboard list.
     @remarks
     This vector will be preallocated with the estimated size of the set,and will extend as required.
     */
    BillboardPool mBillboardPool;
    
    /// The vertex position data for all billboards in this set.
    VertexData mVertexData;
    /// Shortcut to main buffer (positions, colours, texture coords)
    SharedPtr!HardwareVertexBuffer mMainBuf;
    /// Locked pointer to buffer
    float* mLockPtr;
    /// Boundary offsets based on origin and camera orientation
    /// Vector3 vLeftOff, vRightOff, vTopOff, vBottomOff;
    /// Final vertex offsets, used where sizes all default to save calcs
    Vector3[4] mVOffset;
    /// Current camera
    Camera mCurrentCamera;
    // Parametric offsets of origin
    Real mLeftOff, mRightOff, mTopOff, mBottomOff;
    // Camera axes in billboard space
    Vector3 mCamX, mCamY;
    // Camera direction in billboard space
    Vector3 mCamDir;
    // Camera orientation in billboard space
    Quaternion mCamQ;
    // Camera position in billboard space
    Vector3 mCamPos;
    
    /// The vertex index data for all billboards in this set (1 set only)
    //unsigned short* mIndexes;
    IndexData mIndexData;
    
    /// Flag indicating whether each billboard should be culled separately (default: false)
    bool mCullIndividual;
    
    //typedef vector< Ogre::FloatRect >::type TextureCoordSets;
    alias FloatRect[] TextureCoordSets;
    TextureCoordSets mTextureCoords; //TODO Make TextureCoordSets just plain array?
    
    /// The type of billboard to render
    BillboardType mBillboardType;
    
    /// Common direction for billboards of type BBT_ORIENTED_COMMON and BBT_PERPENDICULAR_COMMON
    Vector3 mCommonDirection;
    /// Common up-vector for billboards of type BBT_PERPENDICULAR_SELF and BBT_PERPENDICULAR_COMMON
    Vector3 mCommonUpVector;
    
    /// Internal method for culling individual billboards
    bool billboardVisible(ref Camera cam, ref Billboard bill)
    {
        // Return always visible if not culling individually
        if (!mCullIndividual) return true;
        
        // Cull based on sphere (have to transform less)
        Sphere sph;
        Matrix4[] xworld;
        
        getWorldTransforms(xworld);
        
        sph.setCenter(xworld[0].transformAffine(bill.mPosition));
        
        if (bill.mOwnDimensions)
        {
            sph.setRadius(std.algorithm.max(bill.mWidth, bill.mHeight));
        }
        else
        {
            sph.setRadius(std.algorithm.max(mDefaultWidth, mDefaultHeight));
        }
        
        return cam.isVisible(sph, null);
        
    }
    
    // Number of visible billboards (will be == getNumBillboards if mCullIndividual == false)
    ushort mNumVisibleBillboards;
    
    /// Internal method for increasing pool size
    void increasePool(size_t size)
    {
        size_t oldSize = mBillboardPool.length;
        
        // Increase size
        mBillboardPool.length = (size);
        //mBillboardPool.length = size;//TODO std::list.resize
        
        // Create new billboards
        for( size_t i = oldSize; i < size; ++i )
            mBillboardPool.insert(new Billboard());
        
    }
    
    
    //-----------------------------------------------------------------------
    // The internal methods which follow are here to allow maximum flexibility as to 
    //  when various components of the calculation are done. Depending on whether the
    //  billboards are of fixed size and whether they are point or oriented type will
    //  determine how much calculation has to be done per-billboard. NOT a one-size fits all approach.
    //-----------------------------------------------------------------------
    /** Internal method for generating billboard corners. 
     @remarks
     Optional parameter pBill is only present for type BBT_ORIENTED_SELF and BBT_PERPENDICULAR_SELF
     */
    void genBillboardAxes(ref Vector3 pX, ref Vector3 pY,Billboard bb = Billboard.init)
    {
        // If we're using accurate facing, recalculate camera direction per BB
        if (mAccurateFacing && 
            (mBillboardType == BillboardType.BBT_POINT || 
         mBillboardType == BillboardType.BBT_ORIENTED_COMMON ||
         mBillboardType == BillboardType.BBT_ORIENTED_SELF))
        {
            // cam . bb direction
            mCamDir = bb.mPosition - mCamPos;
            mCamDir.normalise();
        }
        
        
        final switch (mBillboardType)
        {
            case BillboardType.BBT_POINT:
                if (mAccurateFacing)
                {
                    // Point billboards will have 'up' based on but not equal to cameras
                    // Use pY temporarily to avoid allocation
                    pY = mCamQ * Vector3.UNIT_Y;
                    pX = mCamDir.crossProduct(pY);
                    pX.normalise();
                    pY = pX.crossProduct(mCamDir); // both normalised already
                }
                else
                {
                    // Get camera axes for X and Y (depth is irrelevant)
                    pX = mCamQ * Vector3.UNIT_X;
                    pY = mCamQ * Vector3.UNIT_Y;
                }
                break;
                
            case BillboardType.BBT_ORIENTED_COMMON:
                // Y-axis is common direction
                // X-axis is cross with camera direction
                pY = mCommonDirection;
                pX = mCamDir.crossProduct(pY);
                pX.normalise();
                break;
                
            case BillboardType.BBT_ORIENTED_SELF:
                // Y-axis is direction
                // X-axis is cross with camera direction
                // Scale direction first
                pY = bb.mDirection;
                pX = mCamDir.crossProduct(pY);
                pX.normalise();
                break;
                
            case BillboardType.BBT_PERPENDICULAR_COMMON:
                // X-axis is up-vector cross common direction
                // Y-axis is common direction cross X-axis
                pX = mCommonUpVector.crossProduct(mCommonDirection);
                pY = mCommonDirection.crossProduct(pX);
                break;
                
            case BillboardType.BBT_PERPENDICULAR_SELF:
                // X-axis is up-vector cross own direction
                // Y-axis is own direction cross X-axis
                pX = mCommonUpVector.crossProduct(bb.mDirection);
                pX.normalise();
                pY = bb.mDirection.crossProduct(pX); // both should be normalised
                break;
        }
        
    }
    
    /** Internal method, generates parametric offsets based on origin.
     */
    void getParametricOffsets(ref Real left, ref Real right, ref Real top, ref Real bottom)
    {
        final switch( mOriginType )
        {
            case BillboardOrigin.BBO_TOP_LEFT:
                left = 0.0f;
                right = 1.0f;
                top = 0.0f;
                bottom = -1.0f;
                break;
                
            case BillboardOrigin.BBO_TOP_CENTER:
                left = -0.5f;
                right = 0.5f;
                top = 0.0f;
                bottom = -1.0f;
                break;
                
            case BillboardOrigin.BBO_TOP_RIGHT:
                left = -1.0f;
                right = 0.0f;
                top = 0.0f;
                bottom = -1.0f;
                break;
                
            case BillboardOrigin.BBO_CENTER_LEFT:
                left = 0.0f;
                right = 1.0f;
                top = 0.5f;
                bottom = -0.5f;
                break;
                
            case BillboardOrigin.BBO_CENTER:
                left = -0.5f;
                right = 0.5f;
                top = 0.5f;
                bottom = -0.5f;
                break;
                
            case BillboardOrigin.BBO_CENTER_RIGHT:
                left = -1.0f;
                right = 0.0f;
                top = 0.5f;
                bottom = -0.5f;
                break;
                
            case BillboardOrigin.BBO_BOTTOM_LEFT:
                left = 0.0f;
                right = 1.0f;
                top = 1.0f;
                bottom = 0.0f;
                break;
                
            case BillboardOrigin.BBO_BOTTOM_CENTER:
                left = -0.5f;
                right = 0.5f;
                top = 1.0f;
                bottom = 0.0f;
                break;
                
            case BillboardOrigin.BBO_BOTTOM_RIGHT:
                left = -1.0f;
                right = 0.0f;
                top = 1.0f;
                bottom = 0.0f;
                break;
        }
    }
    
    /** Internal method for generating vertex data. 
     @param offsets Array of 4 Vector3 offsets
     @param pBillboard Reference to billboard
     */
    void genVertices(Vector3[4] offsets, ref Billboard bb)
    {
        RGBA colour;
        Root.getSingleton().convertColourValue(bb.mColour, colour);
        RGBA* pCol;
        
        // Texcoords
        assert( bb.mUseTexcoordRect || bb.mTexcoordIndex < mTextureCoords.length );
        FloatRect r = bb.mUseTexcoordRect ? bb.mTexcoordRect : mTextureCoords[bb.mTexcoordIndex];
        
        if (mPointRendering)
        {
            // Single vertex per billboard, ignore offsets
            // position
            *mLockPtr++ = bb.mPosition.x;
            *mLockPtr++ = bb.mPosition.y;
            *mLockPtr++ = bb.mPosition.z;
            // Colour
            // Convert float* to RGBA*
            pCol = cast(RGBA*)(cast(void*)(mLockPtr));
            *pCol++ = colour;
            // Update lock pointer
            mLockPtr = cast(float*)(cast(void*)(pCol));
            // No texture coords in point rendering
        }
        else if (mAllDefaultRotation || bb.mRotation == Radian(0))
        {
            // Left-top
            // Positions
            *mLockPtr++ = offsets[0].x + bb.mPosition.x;
            *mLockPtr++ = offsets[0].y + bb.mPosition.y;
            *mLockPtr++ = offsets[0].z + bb.mPosition.z;
            // Colour
            // Convert float* to RGBA*
            pCol = cast(RGBA*)(cast(void*)(mLockPtr));
            *pCol++ = colour;
            // Update lock pointer
            mLockPtr = cast(float*)(cast(void*)(pCol));
            // Texture coords
            *mLockPtr++ = r.left;
            *mLockPtr++ = r.top;
            
            // Right-top
            // Positions
            *mLockPtr++ = offsets[1].x + bb.mPosition.x;
            *mLockPtr++ = offsets[1].y + bb.mPosition.y;
            *mLockPtr++ = offsets[1].z + bb.mPosition.z;
            // Colour
            // Convert float* to RGBA*
            pCol = cast(RGBA*)(cast(void*)(mLockPtr));
            *pCol++ = colour;
            // Update lock pointer
            mLockPtr = cast(float*)(cast(void*)(pCol));
            // Texture coords
            *mLockPtr++ = r.right;
            *mLockPtr++ = r.top;
            
            // Left-bottom
            // Positions
            *mLockPtr++ = offsets[2].x + bb.mPosition.x;
            *mLockPtr++ = offsets[2].y + bb.mPosition.y;
            *mLockPtr++ = offsets[2].z + bb.mPosition.z;
            // Colour
            // Convert float* to RGBA*
            pCol = cast(RGBA*)(cast(void*)(mLockPtr));
            *pCol++ = colour;
            // Update lock pointer
            mLockPtr = cast(float*)(cast(void*)(pCol));
            // Texture coords
            *mLockPtr++ = r.left;
            *mLockPtr++ = r.bottom;
            
            // Right-bottom
            // Positions
            *mLockPtr++ = offsets[3].x + bb.mPosition.x;
            *mLockPtr++ = offsets[3].y + bb.mPosition.y;
            *mLockPtr++ = offsets[3].z + bb.mPosition.z;
            // Colour
            // Convert float* to RGBA*
            pCol = cast(RGBA*)(cast(void*)(mLockPtr));
            *pCol++ = colour;
            // Update lock pointer
            mLockPtr = cast(float*)(cast(void*)(pCol));
            // Texture coords
            *mLockPtr++ = r.right;
            *mLockPtr++ = r.bottom;
        }
        else if (mRotationType == BillboardRotationType.BBR_VERTEX)
        {
            // TODO: Cache axis when billboard type is BBT_POINT or BBT_PERPENDICULAR_COMMON
            Vector3 axis = (offsets[3] - offsets[0]).crossProduct(offsets[2] - offsets[1]).normalisedCopy();
            
            Matrix3 rotation;
            rotation.FromAngleAxis(axis, bb.mRotation);
            
            Vector3 pt;
            
            // Left-top
            // Positions
            pt = rotation * offsets[0];
            *mLockPtr++ = pt.x + bb.mPosition.x;
            *mLockPtr++ = pt.y + bb.mPosition.y;
            *mLockPtr++ = pt.z + bb.mPosition.z;
            // Colour
            // Convert float* to RGBA*
            pCol = cast(RGBA*)(cast(void*)(mLockPtr));
            *pCol++ = colour;
            // Update lock pointer
            mLockPtr = cast(float*)(cast(void*)(pCol));
            // Texture coords
            *mLockPtr++ = r.left;
            *mLockPtr++ = r.top;
            
            // Right-top
            // Positions
            pt = rotation * offsets[1];
            *mLockPtr++ = pt.x + bb.mPosition.x;
            *mLockPtr++ = pt.y + bb.mPosition.y;
            *mLockPtr++ = pt.z + bb.mPosition.z;
            // Colour
            // Convert float* to RGBA*
            pCol = cast(RGBA*)(cast(void*)(mLockPtr));
            *pCol++ = colour;
            // Update lock pointer
            mLockPtr = cast(float*)(cast(void*)(pCol));
            // Texture coords
            *mLockPtr++ = r.right;
            *mLockPtr++ = r.top;
            
            // Left-bottom
            // Positions
            pt = rotation * offsets[2];
            *mLockPtr++ = pt.x + bb.mPosition.x;
            *mLockPtr++ = pt.y + bb.mPosition.y;
            *mLockPtr++ = pt.z + bb.mPosition.z;
            // Colour
            // Convert float* to RGBA*
            pCol = cast(RGBA*)(cast(void*)(mLockPtr));
            *pCol++ = colour;
            // Update lock pointer
            mLockPtr = cast(float*)(cast(void*)(pCol));
            // Texture coords
            *mLockPtr++ = r.left;
            *mLockPtr++ = r.bottom;
            
            // Right-bottom
            // Positions
            pt = rotation * offsets[3];
            *mLockPtr++ = pt.x + bb.mPosition.x;
            *mLockPtr++ = pt.y + bb.mPosition.y;
            *mLockPtr++ = pt.z + bb.mPosition.z;
            // Colour
            // Convert float* to RGBA*
            pCol = cast(RGBA*)(cast(void*)(mLockPtr));
            *pCol++ = colour;
            // Update lock pointer
            mLockPtr = cast(float*)(cast(void*)(pCol));
            // Texture coords
            *mLockPtr++ = r.right;
            *mLockPtr++ = r.bottom;
        }
        else
        {
            Real      cos_rot = Math.Cos(bb.mRotation);
            Real      sin_rot = Math.Sin(bb.mRotation);
            
            float width = (r.right-r.left)/2;
            float height = (r.bottom-r.top)/2;
            float mid_u = r.left+width;
            float mid_v = r.top+height;
            
            float cos_rot_w = cos_rot * width;
            float cos_rot_h = cos_rot * height;
            float sin_rot_w = sin_rot * width;
            float sin_rot_h = sin_rot * height;
            
            // Left-top
            // Positions
            *mLockPtr++ = offsets[0].x + bb.mPosition.x;
            *mLockPtr++ = offsets[0].y + bb.mPosition.y;
            *mLockPtr++ = offsets[0].z + bb.mPosition.z;
            // Colour
            // Convert float* to RGBA*
            pCol = cast(RGBA*)(cast(void*)(mLockPtr));
            *pCol++ = colour;
            // Update lock pointer
            mLockPtr = cast(float*)(cast(void*)(pCol));
            // Texture coords
            *mLockPtr++ = mid_u - cos_rot_w + sin_rot_h;
            *mLockPtr++ = mid_v - sin_rot_w - cos_rot_h;
            
            // Right-top
            // Positions
            *mLockPtr++ = offsets[1].x + bb.mPosition.x;
            *mLockPtr++ = offsets[1].y + bb.mPosition.y;
            *mLockPtr++ = offsets[1].z + bb.mPosition.z;
            // Colour
            // Convert float* to RGBA*
            pCol = cast(RGBA*)(cast(void*)(mLockPtr));
            *pCol++ = colour;
            // Update lock pointer
            mLockPtr = cast(float*)(cast(void*)(pCol));
            // Texture coords
            *mLockPtr++ = mid_u + cos_rot_w + sin_rot_h;
            *mLockPtr++ = mid_v + sin_rot_w - cos_rot_h;
            
            // Left-bottom
            // Positions
            *mLockPtr++ = offsets[2].x + bb.mPosition.x;
            *mLockPtr++ = offsets[2].y + bb.mPosition.y;
            *mLockPtr++ = offsets[2].z + bb.mPosition.z;
            // Colour
            // Convert float* to RGBA*
            pCol = cast(RGBA*)(cast(void*)(mLockPtr));
            *pCol++ = colour;
            // Update lock pointer
            mLockPtr = cast(float*)(cast(void*)(pCol));
            // Texture coords
            *mLockPtr++ = mid_u - cos_rot_w - sin_rot_h;
            *mLockPtr++ = mid_v - sin_rot_w + cos_rot_h;
            
            // Right-bottom
            // Positions
            *mLockPtr++ = offsets[3].x + bb.mPosition.x;
            *mLockPtr++ = offsets[3].y + bb.mPosition.y;
            *mLockPtr++ = offsets[3].z + bb.mPosition.z;
            // Colour
            // Convert float* to RGBA*
            pCol = cast(RGBA*)(cast(void*)(mLockPtr));
            *pCol++ = colour;
            // Update lock pointer
            mLockPtr = cast(float*)(cast(void*)(pCol));
            // Texture coords
            *mLockPtr++ = mid_u + cos_rot_w - sin_rot_h;
            *mLockPtr++ = mid_v + sin_rot_w + cos_rot_h;
        }
        
    }
    
    /** Internal method generates vertex offsets.
     @remarks
     Takes in parametric offsets as generated from getParametericOffsets, width and height values
     and billboard x and y axes as generated from genBillboardAxes. 
     Fills output array of 4 vectors with vector offsets
     from origin for left-top, right-top, left-bottom, right-bottom corners.
     */
    void genVertOffsets(Real inleft, Real inright, Real intop, Real inbottom,
                        Real width, Real height,
                        ref Vector3 x, ref Vector3 y, ref Vector3[4] pDestVec)
    {
        Vector3 vLeftOff, vRightOff, vTopOff, vBottomOff;
        /* Calculate default offsets. Scale the axes by
         parametric offset and dimensions, ready to be added to
         positions.
         */
        
        vLeftOff   = x * ( inleft   * width );
        vRightOff  = x * ( inright  * width );
        vTopOff    = y * ( intop   * height );
        vBottomOff = y * ( inbottom * height );
        
        // Make final offsets to vertex positions
        pDestVec[0] = vLeftOff  + vTopOff;
        pDestVec[1] = vRightOff + vTopOff;
        pDestVec[2] = vLeftOff  + vBottomOff;
        pDestVec[3] = vRightOff + vBottomOff;
        
    }
    
    
    /** Sort by direction functor */
    struct SortByDirectionFunctor
    {
        /// Direction to sort in
        Vector3 sortDir;
        
        this(Vector3 dir)
        {
            sortDir = dir;
        }
        float opCall(ref Billboard bill)
        {
            return sortDir.dotProduct(bill.getPosition());
        }
    }
    
    /** Sort by distance functor */
    struct SortByDistanceFunctor
    {
        /// Position to sort in
        Vector3 sortPos;
        
        this(Vector3 pos)
        {
            sortPos = pos;
        }
        float opCall(ref Billboard bill)
        {
            // Sort descending by squared distance
            return - (sortPos - bill.getPosition()).squaredLength();
        }
    }
    
    //TODO RadixSort is a class and needs a 'new' duh
    static RadixSort!(ActiveBillboardList, Billboard, float) mRadixSorter;
    
    /// Use point rendering?
    bool mPointRendering;
    
    
    
private:
    /// Flag indicating whether the HW buffers have been created.
    bool mBuffersCreated;
    /// The number of billboard in the pool.
    size_t mPoolSize;
    /// Is external billboard data in use?
    bool mExternalData;
    /// Tell if vertex buffer should be update automatically.
    bool mAutoUpdate;
    /// True if the billboard data changed. Will cause vertex buffer update.
    bool mBillboardDataChanged;
    
    /** Internal method creates vertex and index buffers.
     */
    void _createBuffers()
    {
        /* Allocate / reallocate vertex data
         Note that we allocate enough space for ALL the billboards in the pool, but only issue
         rendering operations for the sections relating to the active billboards
         */
        
        /* Alloc positions   ( 1 or 4 verts per billboard, 3 components )
         colours     ( 1 x RGBA per vertex )
         indices     ( 6 per billboard ( 2 tris ) if not point rendering )
         tex. coords ( 2D coords, 1 or 4 per billboard )
         */
        
        // Warn if user requested an invalid setup
        // Do it here so it only appears once
        if (mPointRendering && mBillboardType != BillboardType.BBT_POINT)
        {
            
            LogManager.getSingleton().logMessage("Warning: BillboardSet " ~
                                                 mName ~ " has point rendering enabled but is using a type " ~
                                                 "other than BBT_POINT, this may not give you the results you " ~
                                                 "expect.");
        }
        
        mVertexData = new VertexData();
        if (mPointRendering)
            mVertexData.vertexCount = mPoolSize;
        else
            mVertexData.vertexCount = mPoolSize * 4;
        
        mVertexData.vertexStart = 0;
        
        // Vertex declaration
        VertexDeclaration decl = mVertexData.vertexDeclaration;
        VertexBufferBinding binding = mVertexData.vertexBufferBinding;
        
        size_t offset = 0;
        decl.addElement(0, offset, VertexElementType.VET_FLOAT3, VertexElementSemantic.VES_POSITION);
        offset += VertexElement.getTypeSize(VertexElementType.VET_FLOAT3);
        decl.addElement(0, offset, VertexElementType.VET_COLOUR, VertexElementSemantic.VES_DIFFUSE);
        offset += VertexElement.getTypeSize(VertexElementType.VET_COLOUR);
        // Texture coords irrelevant when enabled point rendering (generated
        // in point sprite mode, and unused in standard point mode)
        if (!mPointRendering)
        {
            decl.addElement(0, offset, VertexElementType.VET_FLOAT2, VertexElementSemantic.VES_TEXTURE_COORDINATES, 0);
        }
        
        mMainBuf =
            HardwareBufferManager.getSingleton().createVertexBuffer(
                decl.getVertexSize(0),
                mVertexData.vertexCount,
                mAutoUpdate ? HardwareBuffer.Usage.HBU_DYNAMIC_WRITE_ONLY_DISCARDABLE : 
                HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY);
        // bind position and diffuses
        binding.setBinding(0, mMainBuf);
        
        if (!mPointRendering)
        {
            mIndexData  = new IndexData();
            mIndexData.indexStart = 0;
            mIndexData.indexCount = mPoolSize * 6;
            
            mIndexData.indexBuffer = HardwareBufferManager.getSingleton().
                createIndexBuffer(HardwareIndexBuffer.IndexType.IT_16BIT,
                                  mIndexData.indexCount,
                                  HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY);
            
            /* Create indexes (will be the same every frame)
             Using indexes because it means 1/3 less vertex transforms (4 instead of 6)

             Billboard layout relative to camera:

             0-----1
             |    /|
             |  /  |
             |/    |
             2-----3
             */
            
            ushort* pIdx = cast(ushort*)(
                mIndexData.indexBuffer.get().lock(0,
                                              mIndexData.indexBuffer.get().getSizeInBytes(),
                                              HardwareBuffer.LockOptions.HBL_DISCARD) );
            
            for(
                size_t idx, idxOff, bboard = 0;
                bboard < mPoolSize;
                ++bboard )
            {
                // Do indexes
                idx    = bboard * 6;
                idxOff = bboard * 4;
                
                pIdx[idx] = cast(ushort)(idxOff); // + 0;, for clarity
                pIdx[idx+1] = cast(ushort)(idxOff + 2);
                pIdx[idx+2] = cast(ushort)(idxOff + 1);
                pIdx[idx+3] = cast(ushort)(idxOff + 1);
                pIdx[idx+4] = cast(ushort)(idxOff + 2);
                pIdx[idx+5] = cast(ushort)(idxOff + 3);
                
            }
            
            mIndexData.indexBuffer.get().unlock();
        }
        mBuffersCreated = true;
    }
    /** Internal method destroys vertex and index buffers.
     */
    void _destroyBuffers()
    {
        if (mVertexData)
        {
            destroy(mVertexData);
            //mVertexData = 0;
        }
        if (mIndexData)
        {
            destroy(mIndexData);
            //mIndexData = 0;
        }
        
        mMainBuf.setNull();
        
        mBuffersCreated = false;
        
    }
    
public:
    
    /** Usual constructor - this is called by the SceneManager.
     @param name
     The name to give the billboard set (must be unique)
     @param poolSize
     The initial size of the billboard pool. Estimate of the number of billboards
     which will be required, and pass it using this parameter. The set will
     preallocate this number to avoid memory fragmentation. The default behaviour
     once this pool has run out is to double it.
     @param externalDataSource
     If @c true, the source of data for drawing the 
     billboards will not be the internal billboard list, but external 
     data. When driving the billboard from external data, you must call
     _notifyCurrentCamera to reorient the billboards, setPoolSize to set
     the maximum billboards you want to use, beginBillboards to 
     start the update, and injectBillboard per billboard, 
     followed by endBillboards.
     @see
     BillboardSet::setAutoextend
     */
    this(string name, uint poolSize = 20, 
         bool externalDataSource = false)
    {
        
        super(name);
        mBoundingRadius = 0.0f;
        mOriginType =  BillboardOrigin.BBO_CENTER ;
        mRotationType =  BillboardRotationType.BBR_TEXCOORD ;
        mAllDefaultSize =  true ;
        mAutoExtendPool =  true ;
        mSortingEnabled = false;
        mAccurateFacing = false;
        mAllDefaultRotation = true;
        mWorldSpace = false;
        //mVertexData = null;
        //mIndexData = null;
        mCullIndividual =  false ;
        mBillboardType = BillboardType.BBT_POINT;
        mCommonDirection = Vector3.UNIT_Z;
        mCommonUpVector = Vector3.UNIT_Y;
        mPointRendering = false;
        mBuffersCreated = false;
        mPoolSize = poolSize;
        mExternalData = externalDataSource;
        mAutoUpdate = true;
        mBillboardDataChanged = true;
        
        setDefaultDimensions( 100, 100 );
        setMaterialName( "BaseWhite" );
        setPoolSize( poolSize );
        mCastShadows = false;
        setTextureStacksAndSlices( 1, 1 );
    }
    
    ~this()
    {
        // Free pool items
        foreach (i; mBillboardPool)
        {
            destroy(i);
        }
        
        // Delete shared buffers
        _destroyBuffers();
    }
    
    /** Creates a new billboard and adds it to this set.
     @remarks
     Behaviour once the billboard pool has been exhausted depends on the
     BillboardSet::setAutoextendPool option.
     @param position
     The position of the new billboard realtive to the certer of the set
     @param colour
     Optional base colour of the billboard.
     @return
     On success, a pointer to a newly created Billboard is
     returned.
     @par
     On failiure (i.e. no more space and can't autoextend),
     @c NULL is returned.
     @see
     BillboardSet::setAutoextend
     */
    Billboard createBillboard(
        Vector3 position,
        ColourValue colour = ColourValue.White )
    {
        if( !mFreeBillboards.length)
        {
            if( mAutoExtendPool )
            {
                setPoolSize( getPoolSize() * 2 );
            }
            else
            {
                return null;
            }
        }
        
        // Get a new billboard
        Billboard newBill = mFreeBillboards[0];
        mFreeBillboards.removeFromArrayIdx(0);
        //mActiveBillboards.splice(mActiveBillboards.end(), mFreeBillboards, mFreeBillboards.begin());
        mActiveBillboards.insert(newBill);
        newBill.setPosition(position);
        newBill.setColour(colour);
        newBill.mDirection = Vector3.ZERO;
        newBill.setRotation(Radian(0));
        newBill.setTexcoordIndex(0);
        newBill.resetDimensions();
        newBill._notifyOwner(this);
        
        // Merge into bounds
        Real adjust = std.algorithm.max(mDefaultWidth, mDefaultHeight);
        auto vecAdjust = Vector3(adjust, adjust, adjust);
        Vector3 newMin = position - vecAdjust;
        Vector3 newMax = position + vecAdjust;
        
        mAABB.merge(newMin);
        mAABB.merge(newMax);
        
        mBoundingRadius = Math.boundingRadiusFromAABB(mAABB);
        
        return newBill;
    }
    
    /** Creates a new billboard and adds it to this set.
     @remarks
     Behaviour once the billboard pool has been exhausted depends on the
     BillboardSet::setAutoextendPool option.
     @param x
     The @c x position of the new billboard relative to the center of the set
     @param y
     The @c y position of the new billboard relative to the center of the set
     @param z
     The @c z position of the new billboard relative to the center of the set
     @param colour
     Optional base colour of the billboard.
     @return
     On success, a pointer to a newly created Billboard is
     returned.
     @par
     On failure (i.e. no more space and can't autoextend),
     @c NULL is returned.
     @see
     BillboardSet::setAutoextend
     */
    Billboard createBillboard(
        Real x, Real y, Real z,
        ColourValue colour = ColourValue.White )
    {
        return createBillboard( Vector3( x, y, z ), colour );
    }
    
    /** Returns the number of active billboards which currently make up this set.
     */
    size_t getNumBillboards()
    {
        return mActiveBillboards.length;
    }
    
    /** Tells the set whether to allow automatic extension of the pool of billboards.
     @remarks
     A BillboardSet stores a pool of pre-constructed billboards which are used as needed when
     a new billboard is requested. This allows applications to create / remove billboards efficiently
     without incurring construction / destruction costs (a must for sets with lots of billboards like
     particle effects). This method allows you to configure the behaviour when a new billboard is requested
     but the billboard pool has been exhausted.
     @par
     The default behaviour is to allow the pool to extend (typically this allocates double the current
     pool of billboards when the pool is expended), equivalent to calling this method with
     autoExtend = true. If you set the parameter to false however, any attempt to create a new billboard
     when the pool has expired will simply fail silently, returning a null pointer.
     @param autoextend
     @c true to double the pool every time it runs out, @c false to fail silently.
     */
    void setAutoextend(bool autoextend)
    {
        mAutoExtendPool = autoextend;
    }
    
    /** Returns true if the billboard pool automatically extends.
     @see
     BillboardSet::setAutoextend
     */
    bool getAutoextend()
    {
        return mAutoExtendPool;
    }
    
    /** Enables sorting for this BillboardSet. (default: off)
     @param sortenable true to sort the billboards according to their distance to the camera
     */
    void setSortingEnabled(bool sortenable)
    {
        mSortingEnabled = sortenable;
    }
    
    /** Returns true if sorting of billboards is enabled based on their distance from the camera
     @see
     BillboardSet::setSortingEnabled
     */
    bool getSortingEnabled()
    {
        return mSortingEnabled;
    }
    
    /** Adjusts the size of the pool of billboards available in this set.
     @remarks
     See the BillboardSet::setAutoextend method for full details of the billboard pool. This method adjusts
     the preallocated size of the pool. If you try to reduce the size of the pool, the set has the option
     of ignoring you if too many billboards are already in use. Bear in mind that calling this method will
     incur significant construction / destruction calls so should be avoided in time-critical code. The same
     goes for auto-extension, try to avoid it by estimating the pool size correctly up-front.
     @param size
     The new size for the pool.
     */
    void setPoolSize(size_t size)
    {
        // If we're driving this from our own data, allocate billboards
        if (!mExternalData)
        {
            // Never shrink below size()
            size_t currSize = mBillboardPool.length;
            if (currSize >= size)
                return;
            
            this.increasePool(size);
            
            for( size_t i = currSize; i < size; ++i )
            {
                // Add new items to the queue
                mFreeBillboards.insert( mBillboardPool[i] );
            }
        }
        
        mPoolSize = size;
        
        _destroyBuffers();
    }
    
    /** Returns the current size of the billboard pool.
     @return
     The current size of the billboard pool.
     @see
     BillboardSet::setAutoextend
     */
    size_t getPoolSize()
    {
        return mBillboardPool.length;
    }
    
    
    /** Empties this set of all billboards.
     */
    void clear()
    {
        // Move actives to free list
        //mFreeBillboards.splice(mFreeBillboards.end(), mActiveBillboards);
        mFreeBillboards.insert(mActiveBillboards);
        mActiveBillboards.clear();
    }
    
    /** Returns a pointer to the billboard at the supplied index.
     @note
     This method requires linear time since the billboard list is a linked list.
     @param index
     The index of the billboard that is requested.
     @return
     On success, a valid pointer to the requested billboard is
     returned.
     @par
     (C++) On failure, @c NULL is returned.
     */
    ref Billboard getBillboard(uint index)
    {
        assert(
            index < mActiveBillboards.length,
            "Billboard index out of bounds." );
        
        return mActiveBillboards[index];
    }
    
    /** Removes the billboard at the supplied index.
     @note
     This method requires linear time since the billboard list is a linked list.
     */
    void removeBillboard(uint index)
    {
        assert(
            index < mActiveBillboards.length,
            "Billboard index out of bounds." );
        
        /* We can't access it directly, so we check wether it's in the first
         or the second half, then we start either from the beginning or the
         end of the list.
         We then remove the billboard form the 'used' list and add it to
         the 'free' list.
         */
        
        //mFreeBillboards.splice(mFreeBillboards.end(), mActiveBillboards, it);
        mFreeBillboards.insert(mActiveBillboards[index]);
        mActiveBillboards.removeFromArrayIdx(index);
    }
    
    /** Removes a billboard from the set.
     @note
     This version is more efficient than removing by index.
     */
    void removeBillboard(ref Billboard pBill)
    {
        auto it = mActiveBillboards.find(pBill);
        assert(
            it.empty,
            "Billboard isn't in the active list." );
        
        //mFreeBillboards.splice(mFreeBillboards.end(), mActiveBillboards, it);
        mFreeBillboards.insert(it[0]);
        mActiveBillboards.removeFromArray(it[0]);
    }
    
    /** Sets the point which acts as the origin point for all billboards in this set.
     @remarks
     This setting controls the fine tuning of where a billboard appears in relation to it's
     position. It could be that a billboard's position represents it's center (e.g. for fireballs),
     it could mean the center of the bottom edge (e.g. a tree which is positioned on the ground),
     the top-left corner (e.g. a cursor).
     @par
     The default setting is BBO_CENTER.
     @param origin
     A member of the BillboardOrigin enum specifying the origin for all the billboards in this set.
     */
    void setBillboardOrigin(BillboardOrigin origin)
    {
        mOriginType = origin;
    }
    
    /** Gets the point which acts as the origin point for all billboards in this set.
     @return
     A member of the BillboardOrigin enum specifying the origin for all the billboards in this set.
     */
    BillboardOrigin getBillboardOrigin()
    {
        return mOriginType;
    }
    
    /** Sets billboard rotation type.
     @remarks
     This setting controls the billboard rotation type, you can deciding rotate the billboard's vertices
     around their facing direction or rotate the billboard's texture coordinates.
     @par
     The default settings is BBR_TEXCOORD.
     @param rotationType
     A member of the BillboardRotationType enum specifying the rotation type for all the billboards in this set.
     */
    void setBillboardRotationType(BillboardRotationType rotationType)
    {
        mRotationType = rotationType;
    }
    
    /** Sets billboard rotation type.
     @return
     A member of the BillboardRotationType enum specifying the rotation type for all the billboards in this set.
     */
    BillboardRotationType getBillboardRotationType()
    {
        return mRotationType;
    }
    
    /** Sets the default dimensions of the billboards in this set.
     @remarks
     All billboards in a set are created with these default dimensions. The set will render most efficiently if
     all the billboards in the set are the default size. It is possible to alter the size of individual
     billboards at the expense of extra calculation. See the Billboard class for more info.
     @param width
     The new default width for the billboards in this set.
     @param height
     The new default height for the billboards in this set.
     */
    void setDefaultDimensions(Real width, Real height)
    {
        mDefaultWidth = width;
        mDefaultHeight = height;
    }
    
    /** See setDefaultDimensions - this sets 1 component individually. */
    void setDefaultWidth(Real width)
    {
        mDefaultWidth = width;
    }
    /** See setDefaultDimensions - this gets 1 component individually. */
    Real getDefaultWidth()
    {
        return mDefaultWidth;
    }
    /** See setDefaultDimensions - this sets 1 component individually. */
    void setDefaultHeight(Real height)
    {
        mDefaultHeight = height;
    }
    /** See setDefaultDimensions - this gets 1 component individually. */
    Real getDefaultHeight()
    {
        return mDefaultHeight;
    }
    
    /** Sets the name of the material to be used for this billboard set.
     @param name
     The new name of the material to use for this set.
     */
    void setMaterialName(string name,string groupName = ResourceGroupManager.AUTODETECT_RESOURCE_GROUP_NAME )
    {
        mMaterialName = name;
        
        mMaterial = MaterialManager.getSingleton().getByName(name, groupName);
        
        if (mMaterial.isNull())
            throw new ItemNotFoundError("Could not find material " ~ name,
                                        "BillboardSet.setMaterialName" );
        
        /* Ensure that the new material was loaded (will not load again if
         already loaded anyway)
         */
        mMaterial.getAs().load();
    }
    /** Sets the name of the material to be used for this billboard set.
     @return The name of the material that is used for this set.
     */
    string getMaterialName()
    {
        return mMaterialName;
    }
    
    /** Overridden from MovableObject
     @see
     MovableObject
     */
    override void _notifyCurrentCamera(Camera cam)
    {
        super._notifyCurrentCamera(cam);
        
        mCurrentCamera = cam;
        
        // Calculate camera orientation and position
        mCamQ = mCurrentCamera.getDerivedOrientation();
        mCamPos = mCurrentCamera.getDerivedPosition();
        if (!mWorldSpace)
        {
            // Default behaviour is that billboards are in local node space
            // so orientation of camera (in world space) must be reverse-transformed
            // into node space
            mCamQ = mParentNode._getDerivedOrientation().UnitInverse() * mCamQ;
            mCamPos = mParentNode._getDerivedOrientation().UnitInverse() *
                (mCamPos - mParentNode._getDerivedPosition()) / mParentNode._getDerivedScale();
        }
        
        // Camera direction points down -Z
        mCamDir = mCamQ * Vector3.NEGATIVE_UNIT_Z;
    }
    
    /** Begin injection of billboard data; applicable when 
     constructing the BillboardSet for external data use.
     @param numBillboards If you know the number of billboards you will be 
     issuing, state it here to make the update more efficient.
     */
    void beginBillboards(size_t numBillboards = 0)
    {
        /* Generate the vertices for all the billboards relative to the camera
         Also take the opportunity to update the vertex colours
         May as well do it here to save on loops elsewhere
         */
        
        /* NOTE: most engines generate world coordinates for the billboards
         directly, taking the world axes of the camera as offsets to the
         center points. I take a different approach, reverse-transforming
         the camera world axes into local billboard space.
         Why?
         Well, it's actually more efficient this way, because I only have to
         reverse-transform using the billboardset world matrix (inverse)
         once, from then on it's simple additions (assuming identically
         sized billboards). If I transformed every billboard center by it's
         world transform, that's a matrix multiplication per billboard
         instead.
         I leave the final transform to the render pipeline since that can
         use hardware TnL if it is available.
         */
        
        // create vertex and index buffers if they haven't already been
        if(!mBuffersCreated)
            _createBuffers();
        
        // Only calculate vertex offets et al if we're not point rendering
        if (!mPointRendering)
        {
            
            // Get offsets for origin type
            getParametricOffsets(mLeftOff, mRightOff, mTopOff, mBottomOff);
            
            // Generate axes etc up-front if not oriented per-billboard
            if (mBillboardType != BillboardType.BBT_ORIENTED_SELF &&
                mBillboardType != BillboardType.BBT_PERPENDICULAR_SELF && 
                !(mAccurateFacing && mBillboardType != BillboardType.BBT_PERPENDICULAR_COMMON))
            {
                genBillboardAxes(mCamX, mCamY);
                
                /* If all billboards are the same size we can precalculate the
                 offsets and just use '+' instead of '*' for each billboard,
                 and it should be faster.
                 */
                genVertOffsets(mLeftOff, mRightOff, mTopOff, mBottomOff,
                               mDefaultWidth, mDefaultHeight, mCamX, mCamY, mVOffset);
                
            }
        }
        
        // Init num visible
        mNumVisibleBillboards = 0;
        
        // Lock the buffer
        if (numBillboards) // optimal lock
        {
            // clamp to max
            numBillboards = std.algorithm.min(mPoolSize, numBillboards);
            
            size_t billboardSize;
            if (mPointRendering)
            {
                // just one vertex per billboard (this also excludes texcoords)
                billboardSize = mMainBuf.get().getVertexSize();
            }
            else
            {
                // 4 corners
                billboardSize = mMainBuf.get().getVertexSize() * 4;
            }
            assert (numBillboards * billboardSize <= mMainBuf.get().getSizeInBytes());
            
            mLockPtr = cast(float*)(
                mMainBuf.get().lock(0, numBillboards * billboardSize, 
                                mMainBuf.get().getUsage() & HardwareBuffer.Usage.HBU_DYNAMIC ?
                                HardwareBuffer.LockOptions.HBL_DISCARD : HardwareBuffer.LockOptions.HBL_NORMAL) );
        }
        else // lock the entire thing
            mLockPtr = cast(float*)(
                mMainBuf.get().lock(mMainBuf.get().getUsage() & HardwareBuffer.Usage.HBU_DYNAMIC ?
                          HardwareBuffer.LockOptions.HBL_DISCARD : HardwareBuffer.LockOptions.HBL_NORMAL) );
        
    }
    
    /** Define a billboard. */
    void injectBillboard(Billboard bb)
    {
        // Don't accept injections beyond pool size
        if (mNumVisibleBillboards == mPoolSize) return;
        
        // Skip if not visible (NB always true if not bounds checking individual billboards)
        if (!billboardVisible(mCurrentCamera, bb)) return;
        
        if (!mPointRendering &&
            (mBillboardType == BillboardType.BBT_ORIENTED_SELF ||
         mBillboardType == BillboardType.BBT_PERPENDICULAR_SELF ||
         (mAccurateFacing && mBillboardType != BillboardType.BBT_PERPENDICULAR_COMMON)))
        {
            // Have to generate axes & offsets per billboard
            genBillboardAxes(mCamX, mCamY, bb);
        }
        
        // If they're all the same size or we're point rendering
        if( mAllDefaultSize || mPointRendering)
        {
            /* No per-billboard checking, just blast through.
             Saves us an if clause every billboard which may
             make a difference.
             */
            
            if (!mPointRendering &&
                (mBillboardType == BillboardType.BBT_ORIENTED_SELF ||
             mBillboardType == BillboardType.BBT_PERPENDICULAR_SELF ||
             (mAccurateFacing && mBillboardType != BillboardType.BBT_PERPENDICULAR_COMMON)))
            {
                genVertOffsets(mLeftOff, mRightOff, mTopOff, mBottomOff,
                               mDefaultWidth, mDefaultHeight, mCamX, mCamY, mVOffset);
            }
            genVertices(mVOffset, bb);
        }
        else // not all default size and not point rendering
        {
            Vector3[4] vOwnOffset;
            // If it has own dimensions, or self-oriented, gen offsets
            if (mBillboardType == BillboardType.BBT_ORIENTED_SELF ||
                mBillboardType == BillboardType.BBT_PERPENDICULAR_SELF ||
                bb.mOwnDimensions ||
                (mAccurateFacing && mBillboardType != BillboardType.BBT_PERPENDICULAR_COMMON))
            {
                // Generate using own dimensions
                genVertOffsets(mLeftOff, mRightOff, mTopOff, mBottomOff,
                               bb.mWidth, bb.mHeight, mCamX, mCamY, vOwnOffset);
                // Create vertex data
                genVertices(vOwnOffset, bb);
            }
            else // Use default dimension, already computed before the loop, for faster creation
            {
                genVertices(mVOffset, bb);
            }
        }
        // Increment visibles
        mNumVisibleBillboards++;
    }
    
    /** Finish defining billboards. */
    void endBillboards()
    {
        mMainBuf.get().unlock();
    }
    
    /** Set the bounds of the BillboardSet.
     @remarks
     You may need to call this if you're injecting billboards manually, 
     and you're relying on the BillboardSet to determine culling.
     */
    void setBounds(AxisAlignedBox box, Real radius)
    {
        mAABB = box;
        mBoundingRadius = radius;
    }
    
    
    /** Overridden from MovableObject
     @see
     MovableObject
     */
    override AxisAlignedBox getBoundingBox()
    {
        return mAABB;
    }
    
    /** Overridden from MovableObject
     @see
     MovableObject
     */
    override Real getBoundingRadius()
    {
        return mBoundingRadius;
    }
    
    /** Overridden from MovableObject
     @see
     MovableObject
     */
    override void _updateRenderQueue(RenderQueue queue)
    {
        // If we're driving this from our own data, update geometry if need to.
        if (!mExternalData && (mAutoUpdate || mBillboardDataChanged || !mBuffersCreated))
        {
            if (mSortingEnabled)
            {
                _sortBillboards(mCurrentCamera);
            }
            
            beginBillboards(mActiveBillboards.length);
            
            //foreach(it; mActiveBillboards)
            foreach(i; 0..mActiveBillboards.length)
            {
                injectBillboard(mActiveBillboards[i]); //TODO Check if ref'ed
            }
            endBillboards();
            mBillboardDataChanged = false;
        }
        
        //only set the render queue group if it has been explicitly set.
        if (mRenderQueuePrioritySet)
        {
            assert(mRenderQueueIDSet == true);
            queue.addRenderable(this, mRenderQueueID, mRenderQueuePriority);
        }
        else if( mRenderQueueIDSet )
        {
            queue.addRenderable(this, mRenderQueueID);
        } else {
            queue.addRenderable(this);
        }
        
    }
    
    /** Overridden from MovableObject
     @see
     MovableObject
     */
    override SharedPtr!Material getMaterial()
    {
        return mMaterial;
    }
    
    /** Sets the name of the material to be used for this billboard set.
     @param material
     The new material to use for this set.
     */
    void setMaterial(SharedPtr!Material material )
    {
        mMaterial = material;
        
        if (mMaterial.isNull())
        {
            LogManager.getSingleton().logMessage("Can't assign material to BillboardSet of " ~ getName() ~ 
                                                 " because this Material does not exist. Have you forgotten" ~
                                                 "to define it in a .material script?");
            
            mMaterial = MaterialManager.getSingleton().getByName("BaseWhite");
            
            if (mMaterial.isNull())
            {
                throw new InternalError("Can't assign default material to BillboardSet " ~ getName() ~ 
                                        ". Did you forget to call MaterialManager.initialise()?",
                                        "BillboardSet.setMaterial");
            }
        }
        
        mMaterialName = mMaterial.getAs().getName();
        
        // Ensure new material loaded (will not load again if already loaded)
        mMaterial.getAs().load();
    }
    
    /** Overridden from MovableObject
     @see
     MovableObject
     */
    void getRenderOperation(ref RenderOperation op)
    {
        op.vertexData = mVertexData;
        op.vertexData.vertexStart = 0;
        
        if (mPointRendering)
        {
            op.operationType = RenderOperation.OperationType.OT_POINT_LIST;
            op.useIndexes = false;
            op.useGlobalInstancingVertexBufferIsAvailable = false;
            op.indexData = null;
            op.vertexData.vertexCount = mNumVisibleBillboards;
        }
        else
        {
            op.operationType = RenderOperation.OperationType.OT_TRIANGLE_LIST;
            op.useIndexes = true;
            
            op.vertexData.vertexCount = mNumVisibleBillboards * 4;
            
            op.indexData = mIndexData;
            op.indexData.indexCount = mNumVisibleBillboards * 6;
            op.indexData.indexStart = 0;
        }
    }
    
    /** Overridden from MovableObject
     @see
     MovableObject
     */
    void getWorldTransforms(ref Matrix4[] xform)
    {
        if (mWorldSpace)
        {
            //TODO make a mutable copy
            xform.insertOrReplace(cast(Matrix4)Matrix4.IDENTITY);
        }
        else
        {
            xform.insertOrReplace(_getParentNodeFullTransform());
        }
    }
    
    /** Internal callback used by Billboards to notify their parent that they have been resized.
     */
    void _notifyBillboardResized()
    {
        mAllDefaultSize = false;
    }
    
    /** Internal callback used by Billboards to notify their parent that they have been rotated.
     */
    void _notifyBillboardRotated()
    {
        mAllDefaultRotation = false;
    }
    
    /** Returns whether or not billboards in this are tested individually for culling. */
    bool getCullIndividually()
    {
        return mCullIndividual;
    }
    /** Sets whether culling tests billboards in this individually as well as in a group.
     @remarks
     Billboard sets are always culled as a whole group, based on a bounding box which 
     encloses all billboards in the set. For fairly localised sets, this is enough. However, you
     can optionally tell the set to also cull individual billboards in the set, i.e. to test
     each individual billboard before rendering. The default is not to do this.
     @par
     This is useful when you have a large, fairly distributed set of billboards, like maybe 
     trees on a landscape. You probably still want to group them into more than one
     set (maybe one set per section of landscape), which will be culled coarsely, but you also
     want to cull the billboards individually because they are spread out. Whilst you could have
     lots of single-tree sets which are culled separately, this would be inefficient to render
     because each tree would be issued as it's own rendering operation.
     @par
     By calling this method with a parameter of true, you can have large billboard sets which 
     are spaced out and so get the benefit of batch rendering and coarse culling, but also have
     fine-grained culling so unnecessary rendering is avoided.
     @param cullIndividual If true, each billboard is tested before being sent to the pipeline as well 
     as the whole set having to pass the coarse group bounding test.
     */
    void setCullIndividually(bool cullIndividual)
    {
        mCullIndividual = cullIndividual;
    }
    
    /** Sets the type of billboard to render.
     @remarks
     The default sort of billboard (BBT_POINT), always has both x and y axes parallel to 
     the camera's local axes. This is fine for 'point' style billboards (e.g. flares,
     smoke, anything which is symmetrical about a central point) but does not look good for
     billboards which have an orientation (e.g. an elongated raindrop). In this case, the
     oriented billboards are more suitable (BBT_ORIENTED_COMMON or BBT_ORIENTED_SELF) since
     they retain an independent Y axis and only the X axis is generated, perpendicular to both
     the local Y and the camera Z.
     @par
     In some case you might want the billboard has fixed Z axis and doesn't need to face to
     camera (e.g. an aureola around the player and parallel to the ground). You can use
     BBT_PERPENDICULAR_SELF which the billboard plane perpendicular to the billboard own
     direction. Or BBT_PERPENDICULAR_COMMON which the billboard plane perpendicular to the
     common direction.
     @note
     BBT_PERPENDICULAR_SELF and BBT_PERPENDICULAR_COMMON can't guarantee counterclockwise, you might
     use double-side material (<b>cull_hardware node</b>) to ensure no billboard are culled.
     @param bbt The type of billboard to render
     */
    void setBillboardType(BillboardType bbt)
    {
        mBillboardType = bbt;
    }
    
    /** Returns the billboard type in use. */
    BillboardType getBillboardType()
    {
        return mBillboardType;
    }
    
    /** Use this to specify the common direction given to billboards of type BBT_ORIENTED_COMMON or BBT_PERPENDICULAR_COMMON.
     @remarks
     Use BBT_ORIENTED_COMMON when you want oriented billboards but you know they are always going to 
     be oriented the same way (e.g. rain in calm weather). It is faster for the system to calculate
     the billboard vertices if they have a common direction.
     @par
     The common direction also use in BBT_PERPENDICULAR_COMMON, in this case the common direction
     treat as Z axis, and an additional common up-vector was use to determine billboard X and Y
     axis.
     @see setCommonUpVector
     @param vec The direction for all billboards.
     @note
     The direction are use as is, never normalised in internal, user are supposed to normalise it himself.
     */
    void setCommonDirection(Vector3 vec)
    {
        mCommonDirection = vec;
    }
    
    /** Gets the common direction for all billboards (BBT_ORIENTED_COMMON) */
    Vector3 getCommonDirection()
    {
        return mCommonDirection;
    }
    
    /** Use this to specify the common up-vector given to billboards of type BBT_PERPENDICULAR_SELF or BBT_PERPENDICULAR_COMMON.
     @remarks
     Use BBT_PERPENDICULAR_SELF or BBT_PERPENDICULAR_COMMON when you want oriented billboards
     perpendicular to specify direction vector (or, Z axis), and doesn't face to camera.
     In this case, we need an additional up-vector to determine the billboard X and Y axis.
     The generated billboard plane and X-axis guarantee perpendicular to specify direction.
     @see setCommonDirection
     @par
     The specify direction is billboard own direction when billboard type is BBT_PERPENDICULAR_SELF,
     and it's shared common direction when billboard type is BBT_PERPENDICULAR_COMMON.
     @param vec The up-vector for all billboards.
     @note
     The up-vector are use as is, never normalised in internal, user are supposed to normalise it himself.
     */
    void setCommonUpVector(Vector3 vec)
    {
        mCommonUpVector = vec;
    }
    
    /** Gets the common up-vector for all billboards (BBT_PERPENDICULAR_SELF and BBT_PERPENDICULAR_COMMON) */
    Vector3 getCommonUpVector()
    {
        return mCommonUpVector;
    }
    
    /** Sets whether or not billboards should use an 'accurate' facing model
     based on the vector from each billboard to the camera, rather than 
     an optimised version using just the camera direction.
     @remarks
     By default, the axes for all billboards are calculated using the 
     camera's view direction, not the vector from the camera position to
     the billboard. The former is faster, and most of the time the difference
     is not noticeable. However for some purposes (e.g. very large, static
     billboards) the changing billboard orientation when rotating the camera
     can be off putting, Therefore you can enable this option to use a
     more expensive, but more accurate version.
     @param acc True to use the slower but more accurate model. Default is false.
     */
    void setUseAccurateFacing(bool acc) { mAccurateFacing = acc; }
    /** Gets whether or not billboards use an 'accurate' facing model
     based on the vector from each billboard to the camera, rather than 
     an optimised version using just the camera direction.
     */
    bool getUseAccurateFacing(){ return mAccurateFacing; }
    
    /** Overridden from MovableObject */
    override string getMovableType()
    {
        return BillboardSetFactory.FACTORY_TYPE_NAME;
    }
    
    /** Overridden, see Renderable */
    Real getSquaredViewDepth(Camera cam)
    {
        assert(mParentNode);
        return mParentNode.getSquaredViewDepth(cam);
    }
    
    /** Update the bounds of the billboardset */
    void _updateBounds()
    {
        if (mActiveBillboards.empty())
        {
            // No billboards, null bbox
            mAABB.setNull();
            mBoundingRadius = 0.0f;
        }
        else
        {
            Real maxSqLen = -1.0f;
            
            auto min = Vector3(Math.POS_INFINITY, Math.POS_INFINITY, Math.POS_INFINITY);
            auto max = Vector3(Math.NEG_INFINITY, Math.NEG_INFINITY, Math.NEG_INFINITY);
            
            Matrix4 invWorld;
            if (mWorldSpace && getParentSceneNode())
                invWorld = getParentSceneNode()._getFullTransform().inverse();
            
            foreach (i; mActiveBillboards)
            {
                Vector3 pos = i.getPosition();
                // transform from world space to local space
                if (mWorldSpace && getParentSceneNode())
                    pos = invWorld * pos;
                min.makeFloor(pos);
                max.makeCeil(pos);
                
                maxSqLen = std.algorithm.max(maxSqLen, pos.squaredLength());
            }
            // Adjust for billboard size
            Real adjust = std.algorithm.max(mDefaultWidth, mDefaultHeight);
            auto vecAdjust = Vector3(adjust, adjust, adjust);
            min -= vecAdjust;
            max += vecAdjust;
            
            mAABB.setExtents(min, max);
            mBoundingRadius = Math.Sqrt(maxSqLen);
            
        }
        
        if (mParentNode)
            mParentNode.needUpdate();
        
    }
    
    /** @copydoc Renderable::getLights */
    LightList getLights()
    {
        // It's actually quite unlikely that this will be called,
        // because most billboards are unlit, but here we go anyway
        return queryLights();
    }
    
    /// @copydoc MovableObject::visitRenderables
    override void visitRenderables(Renderable.Visitor visitor, 
                                   bool debugRenderables = false)
    {
        // only one renderable
        visitor.visit(this, 0, false, Any());
    }
    
    /** Sort the billboard set. Only called when enabled via setSortingEnabled */
    void _sortBillboards( ref Camera cam)
    {
        final switch (_getSortMode())
        {
            case SortMode.SM_DIRECTION:
                auto s = SortByDirectionFunctor(-mCamDir); //TODO _sortBillboards: can't pass temporary?
                mRadixSorter.sort(mActiveBillboards, s);
                break;
            case SortMode.SM_DISTANCE:
                auto s = SortByDistanceFunctor(mCamPos);
                mRadixSorter.sort(mActiveBillboards, s);
                break;
        }
    }
    
    /** Gets the sort mode of this billboard set */
    SortMode _getSortMode()
    {
        // Need to sort by distance if we're using accurate facing, or perpendicular billboard type.
        if (mAccurateFacing ||
            mBillboardType == BillboardType.BBT_PERPENDICULAR_SELF ||
            mBillboardType == BillboardType.BBT_PERPENDICULAR_COMMON)
        {
            return SortMode.SM_DISTANCE;
        }
        else
        {
            return SortMode.SM_DIRECTION;
        }
    }
    
    /** Sets whether billboards should be treated as being in world space. 
     @remarks
     This is most useful when you are driving the billboard set from 
     an external data source.
     */
    void setBillboardsInWorldSpace(bool ws) { mWorldSpace = ws; }
    
    /** BillboardSet can use custom texture coordinates for various billboards. 
     This is useful for selecting one of many particle images out of a tiled 
     texture sheet, or doing flipbook animation within a single texture.
     @par
     The generic functionality is setTextureCoords(), which will copy the 
     texture coordinate rects you supply into internal storage for the 
     billboard set. If your texture sheet is a square grid, you can also 
     use setTextureStacksAndSlices() for more convenience, which willruct 
     the set of texture coordinates for you.
     @par
     When a Billboard is created, it can be assigned a texture coordinate 
     set from within the sets you specify (that set can also be re-specified 
     later). When drawn, the billboard will use those texture coordinates, 
     rather than the full 0-1 range.

     @param coords is a vector of texture coordinates (in UV space) to choose 
     from for each billboard created in the set.
     @param numCoords is how many such coordinate rectangles there are to 
     choose from.
     @remarks
     Set 'coords' to 0 and/or 'numCoords' to 0 to reset the texture coord 
     rects to the initial set of a single rectangle spanning 0 through 1 in 
     both U and V (i e, the entire texture).
     @see
     BillboardSet::setTextureStacksAndSlices()
     Billboard::setTexcoordIndex()
     */
    void setTextureCoords( FloatRect[] coords, ushort numCoords )
    {
        if( !numCoords || !coords ) {
            setTextureStacksAndSlices( 1, 1 );
            return;
        }
        
        mTextureCoords.clear();
        mTextureCoords.insert(coords);
    }
    
    /** setTextureStacksAndSlices() will generate texture coordinate rects as if the 
     texture for the billboard set contained 'stacks' rows of 'slices' 
     images each, all equal size. Thus, if the texture size is 512x512 
     and 'stacks' is 4 and 'slices' is 8, each sub-rectangle of the texture 
     would be 128 texels tall and 64 texels wide.
     @remarks
     This function is short-hand for creating a regular set and calling 
     setTextureCoords() yourself. The numbering used for Billboard::setTexcoordIndex() 
     counts first across, then down, so top-left is 0, the one to the right 
     of that is 1, and the lower-right is stacks*slices-1.
     @see
     BillboardSet::setTextureCoords()
     */
    void setTextureStacksAndSlices( ubyte stacks, ubyte slices )
    {
        if( stacks == 0 ) stacks = 1;
        if( slices == 0 ) slices = 1;
        //  clear out any previous allocation (as vectors may not shrink)
        //TextureCoordSets().swap( mTextureCoords );
        mTextureCoords.clear();//TODO .swap() has other side-effects?
        
        //  make room
        //mTextureCoords.length = stacks * slices;
        mTextureCoords.length = (stacks * slices);
        //uint coordIndex = 0;
        
        //  spread the U and V coordinates across the rects
        for( uint v = 0; v < stacks; ++v ) {
            //  cast(float)X / X is guaranteed to be == 1.0f for X up to 8 million, so
            //  our range of 1..256 is quite enough to guarantee perfect coverage.
            float top = cast(float)v / cast(float)stacks;
            float bottom = (cast(float)v + 1) / cast(float)stacks;
            for( uint u = 0; u < slices; ++u ) {
                FloatRect r; // = mTextureCoords[coordIndex];
                r.left = cast(float)u / cast(float)slices;
                r.bottom = bottom;
                r.right = (cast(float)u + 1) / cast(float)slices;
                r.top = top;
                mTextureCoords.insert(r);
                //++coordIndex;
            }
        }
        assert( /*coordIndex*/ mTextureCoords.length == stacks * slices );
    }
    
    /** getTextureCoords() returns the current texture coordinate rects in 
     effect. By default, there is only one texture coordinate rect in the 
     set, spanning the entire texture from 0 through 1 in each direction.
     @see
     BillboardSet::setTextureCoords()
     */
    //FloatRect[] 
    ref TextureCoordSets getTextureCoords()//( ref ushort oNumCoords )
    {
        //oNumCoords = mTextureCoords.length;
        return mTextureCoords;
    }
    
    /** Set whether or not the BillboardSet will use point rendering
     rather than manually generated quads.
     @remarks
     By default a billboardset is rendered by generating geometry for a
     textured quad in memory, taking into account the size and 
     orientation settings, and uploading it to the video card. 
     The alternative is to use hardware point rendering, which means that
     only one position needs to be sent per billboard rather than 4 and
     the hardware sorts out how this is rendered based on the render
     state.
     @par
     Using point rendering is faster than generating quads manually, but
     is more restrictive. The following restrictions apply:
     \li Only the BBT_POINT type is supported
     \li Size and appearance of each billboard is controlled by the 
     material (Pass::setPointSize, Pass::setPointSizeAttenuation, 
     Pass::setPointSpritesEnabled)
     \li Per-billboard size is not supported (stems from the above)
     \li Per-billboard rotation is not supported, this can only be 
     controlled through texture unit rotation
     \li Only BBO_CENTER origin is supported
     \li Per-billboard texture coordinates are not supported

     @par
     You will almost certainly want to enable in your material pass
     both point attenuation and point sprites if you use this option. 
     @param enabled True to enable point rendering, false otherwise
     */
    void setPointRenderingEnabled(bool enabled)
    {
        // Override point rendering if not supported
        if (enabled && !Root.getSingleton().getRenderSystem().getCapabilities().hasCapability(Capabilities.RSC_POINT_SPRITES))
        {
            enabled = false;
        }
        
        if (enabled != mPointRendering)
        {
            mPointRendering = enabled;
            // Different buffer structure (1 or 4 verts per billboard)
            _destroyBuffers();
        }
    }
    
    /** Returns whether point rendering is enabled. */
    bool isPointRenderingEnabled()
    { return mPointRendering; }
    
    /// Override to return specific type flag
    override uint getTypeFlags()
    {
        return SceneManager.FX_TYPE_MASK;
    }
    
    /** Set the auto update state of this billboard set.
     @remarks
     This methods controls the updating policy of the vertex buffer.
     By default auto update is true so the vertex buffer is being update every time this billboard set
     is about to be rendered. This behavior best fit when the billboards of this set changes frequently.
     When using static or semi-static billboards, it is recommended to set auto update to false.
     In that case one should call notifyBillboardDataChanged method to reflect changes made to the
     billboards data.
     */
    void setAutoUpdate(bool autoUpdate)
    {
        // Case auto update buffers changed we have to destroy the current buffers
        // since their usage will be different.
        if (autoUpdate != mAutoUpdate)
        {
            mAutoUpdate = autoUpdate;
            _destroyBuffers();
        }
    }
    
    /** Return the auto update state of this billboard set.*/
    bool getAutoUpdate(){ return mAutoUpdate; }
    
    /** When billboard set is not auto updating its GPU buffer, the user is responsible to inform it
     about any billboard changes in order to reflect them at the rendering stage.
     Calling this method will cause GPU buffers update in the next render queue update.
     */
    void notifyBillboardDataChanged() { mBillboardDataChanged = true; }
    
}

/** Factory object for creating BillboardSet instances */
class BillboardSetFactory : MovableObjectFactory
{
protected:
    override MovableObject createInstanceImpl(string name, NameValuePairList params)
    {
        // may have parameters
        bool externalData = false;
        uint poolSize = 0;
        
        if (!params.emptyAA)
        {
            auto ni = "poolSize" in params;
            if (ni !is null)
            {
                poolSize = std.conv.to!uint(*ni);
            }
            ni = "externalData" in params;
            if (ni !is null)
            {
                externalData = std.conv.to!bool(*ni);
            }
            
        }
        
        if (poolSize > 0)
        {
            return new BillboardSet(name, poolSize, externalData);
        }
        else
        {
            return new BillboardSet(name);
        }
        
    }
public:
    this() {}
    ~this() {}
    
    immutable static string FACTORY_TYPE_NAME = "BillboardSet";
    
    override string getType()
    {
        return FACTORY_TYPE_NAME;
    }
    override void destroyInstance( ref MovableObject obj)
    {
        destroy(obj);
    }
    
}


/** @} */
/** @} */