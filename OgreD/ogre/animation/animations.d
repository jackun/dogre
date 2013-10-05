module ogre.animation.animations;

import core.sync.mutex;

import std.algorithm;
import std.range;
//import std.container;
import std.exception;
import std.math: fmod;
import std.variant;

import ogre.compat;
import ogre.animation.animable;
import ogre.general.controller;
import ogre.general.log;
import ogre.exception;
import ogre.math.angles;
import ogre.math.vector;
import ogre.math.matrix;
import ogre.math.quaternion;
import ogre.general.common;
import ogre.scene.entity;
import ogre.rendersystem.hardware;
import ogre.math.simplespline;
import ogre.math.rotationalspline;
import ogre.resources.resource;
import ogre.resources.resourcemanager;
import ogre.scene.node;
import ogre.rendersystem.vertex;
import ogre.scene.movableobject;
import ogre.math.maths;
import ogre.resources.mesh;
import ogre.animation.skeletonmanager;
import std.stdio;
import ogre.resources.resourcegroupmanager;
import ogre.animation.skeletonserializer;
import ogre.sharedptr;


/** \addtogroup Core
 *  @{
 */
/** \addtogroup Animation
 *  @{
 */

struct DeltaTransform
{
    Vector3 translate;
    Quaternion rotate;
    Vector3 scale;
    bool isIdentity;
}

/** Records the assignment of a single vertex to a single bone with the corresponding weight.
 @remarks
 This simple struct simply holds a vertex index, bone index and weight representing the
 assignment of a vertex to a bone for skeletal animation. There may be many of these
 per vertex if blended vertex assignments are allowed.
 */
struct VertexBoneAssignment //_s
{
    uint vertexIndex;
    ushort boneIndex;
    Real weight;
}

//alias VertexBoneAssignment_s VertexBoneAssignment;

/** Represents the state of an animation and the weight of its influence. 
 @remarks
 Other classes can hold instances of this class to store the state of any animations
 they are using.
 */
class AnimationState
{
    alias Object.opEquals opEquals;
public:
    
    /// Typedef for an array of float values used as a bone blend mask
    //typedef vector<float>::type BoneBlendMask;
    
    //alias Array!float BoneBlendMask; // Probably overkill
    alias float[] BoneBlendMask;
    
    /** Normal constructor with all params supplied
     @param
     animName The name of this state.
     @param
     parent The parent AnimationStateSet that this state will belong to.
     @param
     timePos The position, in seconds, where this state will begin.
     @param
     length The length, in seconds, of this animation state.
     @param
     weight Weight to apply the animation state with.
     @param
     enabled Whether the animation state is enabled.
     */
    this(string animName, 
         ref AnimationStateSet parent, Real timePos, Real length, Real weight, 
         bool enabled)
    {
        //mBlendMask.clear();
        mAnimationName = animName;
        mParent = parent;
        mTimePos = timePos;
        mLength = length;
        mWeight = weight;
        mEnabled = enabled;
        mLoop = true;
        mParent._notifyDirty();
    }
    /// Constructor to copy from an existing state with new parent
    this(ref AnimationStateSet parent, ref AnimationState rhs)
    {
        //mBlendMask.clear();
        mAnimationName = rhs.mAnimationName;
        mParent = parent;
        mTimePos = rhs.mTimePos;
        mLength = rhs.mLength;
        mWeight = rhs.mWeight;
        mEnabled = rhs.mEnabled;
        mLoop = rhs.mLoop;
        mParent._notifyDirty();
    }
    ~this(){}
    
    /// Gets the name of the animation to which this state applies
    string getAnimationName()
    {
        return mAnimationName;
    }
    /// Gets the time position for this animation
    Real getTimePosition()
    {
        return mTimePos;
    }
    /// Sets the time position for this animation
    void setTimePosition(Real timePos)
    {
        if (timePos != mTimePos)
        {
            mTimePos = timePos;
            if (mLoop)
            {
                // Wrap
                mTimePos = fmod(mTimePos, mLength);
                if(mTimePos < 0)
                    mTimePos += mLength;
            }
            else
            {
                // Clamp
                if(mTimePos < 0)
                    mTimePos = 0;
                else if (mTimePos > mLength)
                    mTimePos = mLength;
            }
            
            if (mEnabled)
                mParent._notifyDirty();
        }
        
    }
    /// Gets the total length of this animation (may be shorter than whole animation)
    Real getLength()
    {
        return mLength;
    }
    /// Sets the total length of this animation (may be shorter than whole animation)
    void setLength(Real len)
    {
        mLength = len;
    }
    /// Gets the weight (influence) of this animation
    Real getWeight()
    {
        return mWeight;
    }
    /// Sets the weight (influence) of this animation
    void setWeight(Real weight)
    {
        mWeight = weight;
        
        if (mEnabled)
            mParent._notifyDirty();
    }
    /** Modifies the time position, adjusting for animation length
     @param offset The amount of time, in seconds, to extend the animation.
     @remarks
     This method loops at the edges if animation looping is enabled.
     */
    void addTime(Real offset)
    {
        setTimePosition(mTimePos + offset);
    }
    
    /// Returns true if the animation has reached the end and is not looping
    bool hasEnded()
    {
        return (mTimePos >= mLength && !mLoop);
    }
    
    /// Returns true if this animation is currently enabled
    bool getEnabled()
    {
        return mEnabled;
    }
    /// Sets whether this animation is enabled
    void setEnabled(bool enabled)
    {
        mEnabled = enabled;
        mParent._notifyAnimationStateEnabled(this, enabled);
    }
    
    /// Equality operator
    bool opEquals(AnimationState rhs)
    {
        if (mAnimationName == rhs.mAnimationName &&
            mEnabled == rhs.mEnabled &&
            mTimePos == rhs.mTimePos &&
            mWeight == rhs.mWeight &&
            mLength == rhs.mLength && 
            mLoop == rhs.mLoop)
        {
            return true;
        }
        else
        {
            return false;
        }
    }
    /// Inequality operator
    //bool operator!=(AnimationState& rhs);
    
    /** Sets whether or not an animation loops at the start and end of
     the animation if the time continues to be altered.
     */
    void setLoop(bool loop) { mLoop = loop; }
    /// Gets whether or not this animation loops            
    bool getLoop(){ return mLoop; }
    
    /** Copies the states from another animation state, preserving the animation name
     (unlike operator=) but copying everything else.
     @param animState Reference to animation state which will use as source.
     */
    void copyStateFrom(AnimationState animState)
    {
        mTimePos = animState.mTimePos;
        mLength = animState.mLength;
        mWeight = animState.mWeight;
        mEnabled = animState.mEnabled;
        mLoop = animState.mLoop;
        mParent._notifyDirty();
    }
    
    /// Get the parent animation state set
    AnimationStateSet getParent(){ return mParent; }
    
    /** @brief Create a new blend mask with the given number of entries
     *
     * In addition to assigning a single weight value to a skeletal animation,
     * it may be desirable to assign animation weights per bone using a 'blend mask'.
     *
     * @param blendMaskSizeHint 
     *   The number of bones of the skeleton owning this AnimationState.
     * @param initialWeight
     *   The value all the blend mask entries will be initialised with (negative to skip initialisation)
     */
    void createBlendMask(size_t blendMaskSizeHint, float initialWeight = 1.0f)
    {
        if(!mBlendMask)
        {
            if(initialWeight >= 0)
            {
                mBlendMask = new BoneBlendMask (blendMaskSizeHint); //MEMCATEGORY_ANIMATION
                mBlendMask[] = initialWeight;
            }
            else
            {
                mBlendMask = new BoneBlendMask (blendMaskSizeHint); //MEMCATEGORY_ANIMATION
            }
        }
    }
    /// Destroy the currently set blend mask
    void destroyBlendMask()
    {
        destroy(mBlendMask);
    }
    /** @brief Set the blend mask data (might be dangerous)
     *
     * @par The size of the array should match the number of entries the
     *      blend mask was created with.
     *
     * @par Stick to the setBlendMaskEntry method if you don't know exactly what you're doing.
     */
    void _setBlendMaskData(float[] blendMaskData)
    {
        assert(mBlendMask, "No BlendMask set!");
        // input 0?
        if(!blendMaskData)
        {
            destroyBlendMask();
            return;
        }
        // dangerous memcpy
        //memcpy(&((*mBlendMask)[0]), blendMaskData, sizeof(float) * mBlendMask.length);
        mBlendMask ~= blendMaskData; //FIXME performance?
        if (mEnabled)
            mParent._notifyDirty();
    }
    /** @brief Set the blend mask
     *
     * @par The size of the array should match the number of entries the
     *      blend mask was created with.
     *
     * @par Stick to the setBlendMaskEntry method if you don't know exactly what you're doing.
     * @todo Probably no use if using std.container.Array.
     */
    void _setBlendMask(BoneBlendMask blendMask)
    {
        if(!mBlendMask)
        {
            createBlendMask(blendMask.length, false);
        }
        _setBlendMaskData(blendMask);
    }
    /// Get the current blend mask (version, may be 0) 
    ref BoneBlendMask getBlendMask(){return mBlendMask;}
    /// Return whether there is currently a valid blend mask set
    bool hasBlendMask(){return mBlendMask && mBlendMask.length > 0;}
    /// Set the weight for the bone identified by the given handle
    void setBlendMaskEntry(size_t boneHandle, float weight)
    {
        assert(mBlendMask && mBlendMask.length > boneHandle);
        mBlendMask[boneHandle] = weight;
        if (mEnabled)
            mParent._notifyDirty();
    }
    /// Get the weight for the bone identified by the given handle
    float getBlendMaskEntry(size_t boneHandle)
    {
        assert(mBlendMask && mBlendMask.length > boneHandle);
        return mBlendMask[boneHandle];
    }
protected:
    /// The blend mask (containing per bone weights)
    BoneBlendMask mBlendMask;
    
    string mAnimationName;
    AnimationStateSet mParent;
    Real mTimePos;
    Real mLength;
    Real mWeight;
    bool mEnabled;
    bool mLoop;
    
}

// A map of animation states
alias AnimationState[string] AnimationStateMap;
//typedef MapIterator<AnimationStateMap> AnimationStateIterator;
//typedef ConstMapIterator<AnimationStateMap> ConstAnimationStateIterator;
// A list of enabled animation states
//typedef list<AnimationState*>::type EnabledAnimationStateList;

alias AnimationState[string] EnabledAnimationStateList;
//alias SList!AnimationState EnabledAnimationStateList;

//typedef ConstVectorIterator<EnabledAnimationStateList> ConstEnabledAnimationStateIterator;

/** Class encapsulating a set of AnimationState objects.
 */
class AnimationStateSet
{
public:
    /// Mutex, public for external locking if needed
    //OGRE_AUTO_MUTEX;
    Mutex mLock;
    /// Create a blank animation state set
    this()
    {
        mDirtyFrameNumber = ulong.max;
        mLock = new Mutex;
    }
    /// Create an animation set by copying the contents of another
    this(AnimationStateSet rhs)
    {
        this();
        // lock rhs
        synchronized(rhs) //.OGRE_AUTO_MUTEX_NAME)
        {
            foreach( name, src; rhs.mAnimationStates)
            {
                mAnimationStates[src.getAnimationName()] = 
                    new AnimationState(this, src);
            }
            
            // Clone enabled animation state list
            auto state = cast(EnabledAnimationStateList)rhs.mEnabledAnimationStates; //fcking shit up
            foreach( name, ref src ; state)
            {
                mEnabledAnimationStates[src.getAnimationName()] = (cast(AnimationState)getAnimationState(src.getAnimationName()));
            }
        }
    }
    
    ~this()
    {
        // Destroy
        removeAllAnimationStates();
    }
    
    /** Create a new AnimationState instance. 
     @param animName The name of the animation
     @param timePos Starting time position
     @param length Length of the animation to play
     @param weight Weight to apply the animation with 
     @param enabled Whether the animation is enabled
     */
    AnimationState createAnimationState(string animName,  
                                        Real timePos, Real length, Real weight = 1.0, bool enabled = false)
    {
        //OGRE_LOCK_AUTO_MUTEX
        synchronized(this)
        {
            auto p = (animName in mAnimationStates); // 'in' returns pointer to state or null
            if (p !is null)
            {
                throw new DuplicateItemError(
                    "State for animation named '" ~ animName ~ "' already exists.", 
                    "AnimationStateSet.createAnimationState");
            }
            
            auto newState = new AnimationState(animName, this, timePos, 
                                               length, weight, enabled);
            mAnimationStates[animName] = newState;
            
            return newState;
        }
    }
    /// Get an animation state by the name of the animation
    ref AnimationState getAnimationState(string name)
    {
        synchronized(this)
        {
            //OGRE_LOCK_AUTO_MUTEX
            
            auto i = name in mAnimationStates;
            if (i is null)
            {
                throw new ItemNotFoundError(
                    "No state found for animation named '" ~ name ~ "'", 
                    "AnimationStateSet.getAnimationState");
            }
            return *i;
        }
    }
    /// Tests if state for the named animation is present
    bool hasAnimationState(string name)
    {
        //OGRE_LOCK_AUTO_MUTEX
        synchronized(this)
        {
            return (name in mAnimationStates) !is null;
        }
    }
    /// Remove animation state with the given name
    void removeAnimationState(string name)
    {
        synchronized(this)
        {
            //OGRE_LOCK_AUTO_MUTEX
            
            auto i = name in mAnimationStates;
            if (i !is null)
            {
                mEnabledAnimationStates.remove(name);
                destroy(*i);
            }
        }
    }
    /// Remove all animation states
    void removeAllAnimationStates()
    {
        synchronized(this)
        {
            //OGRE_LOCK_AUTO_MUTEX
            
            foreach(name, st; mAnimationStates)
            {
                destroy(st);
            }
            mAnimationStates.clear();
            mEnabledAnimationStates.clear();
        }
    }
    
    /// TODO
    /** Get an iterator over all the animation states in this set.
     @note
     The iterator returned from this method is not threadsafe,
     you will need to manually lock the public mutex on this
     class to ensure thread safety if you need it.
     */
    //AnimationStateIterator getAnimationStateIterator();
    /** Get an iterator over all the animation states in this set.
     @note
     The iterator returned from this method is not threadsafe,
     you will need to manually lock the public mutex on this
     class to ensure thread safety if you need it.
     */
    //ConstAnimationStateIterator getAnimationStateIterator();
    ref AnimationStateMap getAnimationStates()
    {
        return mAnimationStates;
    }
    
    /// Copy the state of any matching animation states from this to another
    void copyMatchingState(ref AnimationStateSet target)
    {
        synchronized(this)
        {
            // lock target
            //OGRE_LOCK_MUTEX(target.OGRE_AUTO_MUTEX_NAME)
            // lock source
            //OGRE_LOCK_AUTO_MUTEX
            synchronized(target)
            {
                foreach( name, i; target.mAnimationStates) {
                    auto iother = name in mAnimationStates;
                    if (iother is null) {
                        throw new ItemNotFoundError( "No animation entry found named " ~ name, 
                                                    "AnimationStateSet.copyMatchingState");
                    } else {
                        i.copyStateFrom(*iother);
                    }
                }
                
                // Copy matching enabled animation state list
                target.mEnabledAnimationStates.clear();
                foreach (src ; mEnabledAnimationStates)
                {
                    auto itarget = src.getAnimationName() in target.mAnimationStates;
                    if (itarget !is null)
                    {
                        target.mEnabledAnimationStates[(*itarget).getAnimationName()] = *itarget;
                    }
                }
                
                target.mDirtyFrameNumber = mDirtyFrameNumber;
            }
        }
    }
    /// Set the dirty flag and dirty frame number on this state set
    void _notifyDirty()
    {
        synchronized(this)
        {
            //OGRE_LOCK_AUTO_MUTEX
            ++mDirtyFrameNumber;
        }
    }
    /// Get the latest animation state been altered frame number
    ulong getDirtyFrameNumber(){ return mDirtyFrameNumber; }
    
    /// Internal method respond to enable/disable an animation state
    void _notifyAnimationStateEnabled(ref AnimationState target, bool enabled)
    {
        //OGRE_LOCK_AUTO_MUTEX
        // Remove from enabled animation state list first
        mEnabledAnimationStates.remove(target.getAnimationName());
        
        // Add to enabled animation state list if need
        if (enabled)
        {
            mEnabledAnimationStates[target.getAnimationName()] = target;
        }
        
        // Set the dirty frame number
        _notifyDirty();
    }
    /// Tests if exists enabled animation state in this set
    bool hasEnabledAnimationState(){ return mEnabledAnimationStates.length != 0; }
    /** Get an iterator over all the enabled animation states in this set
     @note
     The iterator returned from this method is not threadsafe,
     you will need to manually lock the public mutex on this
     class to ensure thread safety if you need it.
     */
    //ConstEnabledAnimationStateIterator getEnabledAnimationStateIterator();
    ref EnabledAnimationStateList getEnabledAnimationStates()
    {
        return mEnabledAnimationStates;
    }
    
protected:
    ulong mDirtyFrameNumber;
    AnimationStateMap mAnimationStates;
    EnabledAnimationStateList mEnabledAnimationStates;
    
}

/** ControllerValue wrapper class for AnimationState.
 @remarks
 In Azathoth and earlier, AnimationState was a ControllerValue but this
 actually causes memory problems since Controllers delete their values
 automatically when there are no further references to them, but AnimationState
 is deleted explicitly elsewhere so this causes double-free problems.
 This wrapper acts as a bridge and it is this which is destroyed automatically.
 */
class AnimationStateControllerValue : ControllerValue!Real
{
protected:
    AnimationState mTargetAnimationState;
public:
    /** Constructor, pass in the target animation state. */
    this(ref AnimationState targetAnimationState)
    {
        mTargetAnimationState = targetAnimationState;
    }
    /// Destructor (parent already virtual)
    ~this() {}
    /** ControllerValue implementation. */
    override Real getValue()
    {
        return mTargetAnimationState.getTimePosition() / mTargetAnimationState.getLength();
    }
    
    /** ControllerValue implementation. */
    override void setValue(Real value)
    {
        mTargetAnimationState.setTimePosition(value * mTargetAnimationState.getLength());
    }
    
}


/** A key frame in an animation sequence defined by an AnimationTrack.
 @remarks
 This class can be used as a basis for all kinds of key frames. 
 The unifying principle is that multiple KeyFrames define an 
 animation sequence, with the exact state of the animation being an 
 interpolation between these key frames. 
 */
class KeyFrame// : public AnimationAlloc
{
public:
    
    /** Default constructor, you should not call this but use AnimationTrack.createKeyFrame instead. */
    this(ref /*const*/ AnimationTrack parent, Real time)
    {
        mParentTrack = parent;
        mTime = time;
    }

    this(AnimationTrack parent, Real time)
    {
        mParentTrack = parent;
        mTime = time;
    }
    
    ~this() {}
    
    /** Gets the time of this keyframe in the animation sequence. */
    Real getTime() //
    { return mTime; }
    
    /** Clone a keyframe (internal use only) */
    KeyFrame _clone(ref AnimationTrack newParent) ////fcking shit up
    {
        return new KeyFrame(newParent, mTime);
    }
    
    
protected:
    Real mTime;
    AnimationTrack mParentTrack;
}


/** Specialised KeyFrame which stores any numeric value.
 */
class NumericKeyFrame : KeyFrame
{
public:
    /** Default constructor, you should not call this but use AnimationTrack.createKeyFrame instead. */
    this(ref AnimationTrack parent, Real time)
    {
        super(parent, time);
    }

    this(AnimationTrack parent, Real time)
    {
        super(parent, time);
    }

    ~this() {}
    
    /** Get the value at this keyframe. */
    ref Variant getValue()//
    {
        return mValue;
    }
    /** Set the value at this keyframe.
     @remarks
     All keyframe values must have a consistent type. 
     */
    void setValue(Variant val)
    {
        mValue = val;
    }
    
    /** Clone a keyframe (internal use only) */
    override KeyFrame _clone(ref AnimationTrack newParent)//
    {
        auto newKf = new NumericKeyFrame(newParent, mTime);
        newKf.mValue = mValue;
        return newKf;
    }
protected:
    Variant mValue;
}


/** Specialised KeyFrame which stores a full transform. */
class TransformKeyFrame : KeyFrame
{
public:
    /** Default constructor, you should not call this but use AnimationTrack.createKeyFrame instead. */
    this(AnimationTrack parent, Real time)
    {
        super(parent, time);
        mTranslate = Vector3.ZERO;
        mScale = Vector3.UNIT_SCALE;
        mRotate = Quaternion.IDENTITY;
    }
    
    ~this() {}
    /** Sets the translation associated with this keyframe. 
     @remarks    
     The translation factor affects how much the keyframe translates (moves) it's animable
     object at it's time index.
     @param trans The vector to translate by
     */
    void setTranslate(Vector3 trans)
    {
        mTranslate = trans;
        if (mParentTrack)
            mParentTrack._keyFrameDataChanged();
    }
    
    /** Gets the translation applied by this keyframe. */
    Vector3 getTranslate()
    {
        return mTranslate;
    }
    
    /** Sets the scaling factor applied by this keyframe to the animable
     object at it's time index.
     @param scale The vector to scale by (beware of supplying zero values for any component of this
     vector, it will scale the object to zero dimensions)
     */
    void setScale(Vector3 scale)
    {
        mScale = scale;
        if (mParentTrack)
            mParentTrack._keyFrameDataChanged();
    }
    
    /** Gets the scaling factor applied by this keyframe. */
    Vector3 getScale()
    {
        return mScale;
    }
    
    /** Sets the rotation applied by this keyframe.
     @param rot The rotation applied; use Quaternion methods to convert from angle/axis or Matrix3 if
     you don't like using Quaternions directly.
     */
    void setRotation(Quaternion rot)
    {
        mRotate = rot;
        if (mParentTrack)
            mParentTrack._keyFrameDataChanged();
    }
    
    /** Gets the rotation applied by this keyframe. */
    Quaternion getRotation()
    {
        return mRotate;
    }
    
    /** Clone a keyframe (internal use only) */
    override KeyFrame _clone(ref AnimationTrack newParent)
    {
        auto newKf = new TransformKeyFrame(newParent, mTime);
        newKf.mTranslate = mTranslate;
        newKf.mScale = mScale;
        newKf.mRotate = mRotate;
        return newKf;
    }
    
protected:
    Vector3 mTranslate;
    Vector3 mScale;
    Quaternion mRotate;
}



/** Specialised KeyFrame which stores absolute vertex positions for a complete
 buffer, designed to be interpolated with other keys in the same track. 
 */
class VertexMorphKeyFrame : KeyFrame
{
public:
    /** Default constructor, you should not call this but use AnimationTrack.createKeyFrame instead. */
    this(AnimationTrack parent, Real time)
    {
        super(parent, time);
    }
    ~this() {}
    /** Sets the vertex buffer containing the source positions for this keyframe. 
     @remarks    
     We assume that positions are the first 3 float elements in this buffer,
     although we don't necessarily assume they're the only ones in there.
     @param buf Vertex buffer link; will not be modified so can be shared
     read-only data
     */
    void setVertexBuffer(SharedPtr!HardwareVertexBuffer buf)
    {
        mBuffer = buf;
    }
    
    /** Gets the vertex buffer containing positions for this keyframe. */
    SharedPtr!HardwareVertexBuffer getVertexBuffer()//
    {
        return mBuffer;
    }
    
    /** Clone a keyframe (internal use only) */
    override KeyFrame _clone(ref AnimationTrack newParent)//
    {
        auto newKf = new VertexMorphKeyFrame(newParent, mTime);
        newKf.mBuffer = mBuffer;
        return newKf;
    }
    
protected:
    SharedPtr!HardwareVertexBuffer mBuffer;
    
}

/** Specialised KeyFrame which references a Mesh.Pose at a certain influence
 level, which stores offsets for a subset of the vertices 
 in a buffer to provide a blendable pose.
 */
class VertexPoseKeyFrame : KeyFrame
{
public:
    /** Default constructor, you should not call this but use AnimationTrack.createKeyFrame instead. */
    this(AnimationTrack parent, Real time)
    {
        super(parent, time);
    }
    ~this() {}
    
    /** Reference to a pose at a given influence level 
     @remarks
     Each keyframe can ref er to many poses each at a given influence level.
     **/
    struct PoseRef
    {
        /** The linked pose index.
         @remarks
         The Mesh contains all poses for all vertex data in one list, both 
         for the shared vertex data and the dedicated vertex data on submeshes.
         The 'target' on the parent track must match the 'target' on the 
         linked pose.
         */
        ushort poseIndex;
        /** Influence level of the linked pose. 
         1.0 for full influence (full offset), 0.0 for no influence.
         */
        Real influence;
        
        this(ushort p, Real i){ poseIndex = p; influence = i; }
    }
    
    //typedef vector<PoseRef>::type PoseRefList;
    //alias SList!PoseRef PoseRefList;
    alias PoseRef[] PoseRefList;
    
    /** Add a new pose reference. 
     @see PoseRef
     */
    void addPoseReference(ushort poseIndex, Real influence)
    {
        mPoseRefs = (PoseRef(poseIndex, influence)) ~ mPoseRefs;
    }
    /** Update the influence of a pose reference. 
     @see PoseRef
     */
    void updatePoseReference(ushort poseIndex, Real influence)
    {
        foreach(i; mPoseRefs)
        {
            if (i.poseIndex == poseIndex)
            {
                i.influence = influence;
                return;
            }
        }
        // if we got here, we didn't find it
        addPoseReference(poseIndex, influence);
    }
    /** Remove reference to a given pose. 
     @param poseIndex The pose index (not the index of the reference)
     */
    void removePoseReference(ushort poseIndex)
    {
        foreach(i; mPoseRefs)
        {
            if (i.poseIndex == poseIndex)
            {
                mPoseRefs.removeFromArray(i);
                return;
            }
        }
    }
    /** Remove all pose references. */
    void removeAllPoseReferences()
    {
        mPoseRefs.clear();
    }
    
    /** Get areference to the list of pose references. */
    //
    PoseRefList getPoseReferences() //const
    {
        return mPoseRefs;
    }
    
    //typedef VectorIterator<PoseRefList> PoseRefIterator;
    //typedef ConstVectorIterator<PoseRefList> ConstPoseRefIterator;
    
    /** Get an iterator over the pose references. */
    //PoseRefIterator getPoseReferenceIterator();
    
    /** Get aiterator over the pose references. */
    //ConstPoseRefIterator getPoseReferenceIterator();
    ref PoseRefList getPoseRefs()
    {
        return mPoseRefs;
    }

    ref const(PoseRefList) getPoseRefs() const
    {
        return mPoseRefs;
    }

    /** Clone a keyframe (internal use only) */
    override KeyFrame _clone(ref AnimationTrack newParent) //const
    {
        auto newKf = new VertexPoseKeyFrame(newParent, mTime);
        // By-value copy ok
        newKf.mPoseRefs = mPoseRefs;
        return newKf;
    }
    
    void _applyBaseKeyFrame(ref VertexPoseKeyFrame base)
    {
        foreach( myPoseRef; mPoseRefs)
        {
            auto basePoseIt = base.getPoseRefs();
            Real baseInfluence = 0.0f;
            foreach( basePoseRef; basePoseIt)
            {
                if (basePoseRef.poseIndex == myPoseRef.poseIndex)
                {
                    baseInfluence = basePoseRef.influence;
                    break;
                }
            }
            
            myPoseRef.influence -= baseInfluence;
        }
    }
    
protected:
    PoseRefList mPoseRefs;
    
}

/** Time index object used to search keyframe at the given position.
 */
class TimeIndex
{
protected:
    /** The time position (in relation to the whole animation sequence)
     */
    Real mTimePos;
    /** The global keyframe index (in relation to the whole animation sequence)
     that used to convert to local keyframe index, or INVALID_KEY_INDEX which
     means global keyframe index unavailable, and then slight slow method will
     used to search local keyframe index.
     */
    uint mKeyIndex;
    
    /** Indicate it's an invalid global keyframe index.
     */
    static uint INVALID_KEY_INDEX = -1;
    
public:
    /** Construct time index object by the given time position.
     */
    this(Real timePos)
    {
        mTimePos = timePos;
        mKeyIndex = INVALID_KEY_INDEX;
    }
    
    /** Construct time index object by the given time position and
     global keyframe index.
     @note In normally, you don't need to use this constructor directly, use
     Animation._getTimeIndex instead.
     */
    this(Real timePos, uint keyIndex)
    {
        mTimePos = timePos;
        mKeyIndex = keyIndex;
    }
    
    bool hasKeyIndex()
    {
        return mKeyIndex != INVALID_KEY_INDEX;
    }
    
    Real getTimePos()
    {
        return mTimePos;
    }
    
    uint getKeyIndex()
    {
        return mKeyIndex;
    }
}

/** A 'track' in an animation sequence, i.e. a sequence of keyframes which affect a
 certain type of animable object.
 @remarks
 This class is intended as a base for more complete classes which will actually
 animate specific types of object, e.g. a bone in a skeleton to affect
 skeletal animation. An animation will likely include multiple tracks each of which
 can be made up of many KeyFrame instances. Note that the use of tracks allows each animable
 object to have it's own number of keyframes, i.e. you do not have to have the
 maximum number of keyframes for all animable objects just to cope with the most
 animated one.
 @remarks
 Since the most common animable object is a Node, there are options in this class for associating
 the track with a Node which will receive keyframe updates automatically when the 'apply' method
 is called.
 @remarks
 By default rotation is done using shortest-path algorithm.
 It is possible to change this behaviour using
 setUseShortestRotationPath() method.
 */
class AnimationTrack
{
public:
    
    /** Listener allowing you to override certain behaviour of a track, 
     for example to drive animation procedurally.
     */
    interface Listener
    {
    public:
        
        /** Get an interpolated keyframe for this track at the given time.
         @return true if the KeyFrame was populated, false if not.
         */
        //bool getInterpolatedKeyFrame(ref /*const*/ AnimationTrack t,TimeIndex timeIndex, KeyFrame kf);
        //FIXME Ok, no ref then. Do you compile now?
        bool getInterpolatedKeyFrame(AnimationTrack t,TimeIndex timeIndex, KeyFrame kf);
    }
    
    /// Constructor
    this(ref Animation parent, ushort handle)
    {
        mParent = parent; mHandle = handle; mListener = null;
    }
    
    ~this()
    {
        removeAllKeyFrames();
    }
    
    /** Get the handle associated with this track. */
    ushort getHandle(){ return mHandle; }
    
    /** Returns the number of keyframes in this animation. */
    ushort getNumKeyFrames()
    {
        return cast(ushort)mKeyFrames.length;
    }
    
    /** Returns the KeyFrame at the specified index. */
    KeyFrame getKeyFrame(ushort index)
    {
        // If you hit this assert, then the keyframe index is out of bounds
        assert( index < cast(ushort)mKeyFrames.length );
        
        auto r = mKeyFrames[index];
        return r;
    }
    
    /** Gets the 2 KeyFrame objects which are active at the time given, and the blend value between them.
     @remarks
     At any point in time  in an animation, there are either 1 or 2 keyframes which are 'active',
     1 if the time index is exactly on a keyframe, 2 at all other times i.e. the keyframe before
     and the keyframe after.
     @par
     This method returns those keyframes given a time index, and also returns a parametric
     value indicating the value of 't' representing where the time index falls between them.
     E.g. if it returns 0, the time index is exactly on keyFrame1, if it returns 0.5 it is
     half way between keyFrame1 and keyFrame2 etc.
     @param timeIndex The time index.
     @param keyFrame1 Pointer to a KeyFrame pointer which will receive the pointer to the 
     keyframe just before or at this time index.
     @param keyFrame2 Pointer to a KeyFrame pointer which will receive the pointer to the 
     keyframe just after this time index. 
     @param firstKeyIndex Pointer to an ushort which, if supplied, will receive the 
     index of the 'from' keyframe in case the caller needs it.
     @return Parametric value indicating how far along the gap between the 2 keyframes the timeIndex
     value is, e.g. 0.0 for exactly at 1, 0.25 for a quarter etc. By definition the range of this 
     value is:  0.0 <= returnValue < 1.0 .
     */
    Real getKeyFramesAtTime(TimeIndex timeIndex, ref KeyFrame keyFrame1, ref KeyFrame keyFrame2,
                            ushort* firstKeyIndex = null) //const
    {
        // Parametric time
        // t1 = time of previous keyframe
        // t2 = time of next keyframe
        Real t1, t2;
        
        Real timePos = timeIndex.getTimePos();
        KeyFrame i = null; // was iterator
        
        // Find first keyframe after or on current time
        if (timeIndex.hasKeyIndex())
        {
            // Global keyframe index available, map to local keyframe index directly.
            assert(timeIndex.getKeyIndex() < mKeyFrameIndexMap.length);
            i = mKeyFrames[mKeyFrameIndexMap[timeIndex.getKeyIndex()]];
            
            /*version(Debug)
             {
             auto timeKey = KeyFrame (0, timePos);
             if (i != std.lower_bound(mKeyFrames.begin(), mKeyFrames.end(), &timeKey, KeyFrameTimeLess()))
             {
             OGRE_EXCEPT(Exception.ERR_INTERNAL_ERROR,
             "Optimised key frame search failed",
             "AnimationTrack.getKeyFramesAtTime");
             }
             }*/
            
        }
        else
        {
            // Wrap time
            Real totalAnimationLength = mParent.getLength();
            assert(totalAnimationLength > 0.0f, "Invalid animation length!");
            
            if( timePos > totalAnimationLength && totalAnimationLength > 0.0f )
                timePos = fmod( timePos, totalAnimationLength );
            
            // No global keyframe index, need to search with local keyframes.
            auto timeKey = new KeyFrame(null, timePos);
            //FIXME
            //i = std.lower_bound(mKeyFrames.begin(), mKeyFrames.end(), &timeKey, KeyFrameTimeLess());
            foreach( k; mKeyFrames)
            {
                if(k.getTime() < timeKey.getTime()) i = k;
            }
        }
        
        if (i is null)
        {
            // There is no keyframe after this time, wrap back to first
            keyFrame2 = mKeyFrames.front();
            t2 = mParent.getLength() + keyFrame2.getTime();
            
            // Use last keyframe as previous keyframe
            //--i;
            //FIXME --i bypasses mKeyFrameIndexMap right?
            //ptrdiff_t so it can be -1
            ptrdiff_t off = std.algorithm.countUntil(mKeyFrames, i);
            i = mKeyFrames[off - 1];
        }
        else
        {
            keyFrame2 = i;
            t2 = keyFrame2.getTime();
            
            // Find last keyframe before or on current time
            if (i != mKeyFrames[0] && timePos < i.getTime())
            {
                //--i;
                //FIXME --i , correct offset?
                //ptrdiff_t so it can be -1
                ptrdiff_t off = std.algorithm.countUntil(mKeyFrames, i);
                i = mKeyFrames[off - 1];
            }
        }
        
        // Fill index of the first key
        if (firstKeyIndex)
        {
            //*firstKeyIndex = cast(ushort)(std.distance(mKeyFrames.begin(), i));
            *firstKeyIndex = cast(ushort)std.algorithm.countUntil(mKeyFrames, i);
        }
        
        keyFrame1 = i;
        
        t1 = keyFrame1.getTime();
        
        if (t1 == t2)
        {
            // Same KeyFrame (only one)
            return 0.0;
        }
        else
        {
            return (timePos - t1) / (t2 - t1);
        }
    }
    
    /** Creates a new KeyFrame and adds it to this animation at the given time index.
     @remarks
     It is better to create KeyFrames in time order. Creating them out of order can result 
     in expensive reordering processing. Note that a KeyFrame at time index 0.0 is always created
     for you, so you don't need to create this one, just access it using getKeyFrame(0);
     @param timePos The time from which this KeyFrame will apply.
     */
    KeyFrame createKeyFrame(Real timePos)
    {
        KeyFrame kf = createKeyFrameImpl(timePos);
        
        //int i = 0;
        // Insert just before upper bound
        /*foreach(k; mKeyFrames)
         {
         if(k.getTime() > kf.getTime()) 
         break;
         i++;
         }
         mKeyFrames.insertAfter(mKeyFrames[0..i+1], kf);//Range is not inclusive, so +1.*/
        
        try
        {
            size_t i = std.algorithm.countUntil!"a.getTime() > b.getTime()"(mKeyFrames, kf);
            mKeyFrames.insertBeforeIdx(i+1, kf);//TODO Check index
        }
        catch(std.exception.RangeError e)
        {
            mKeyFrames.insert(kf);
        }
        
        
        _keyFrameDataChanged();
        mParent._keyFrameListChanged();
        
        return kf;
    }
    
    /** Removes a KeyFrame by it's index. 
     * @todo linearRemove?
     */
    void removeKeyFrame(ushort index)
    {
        // If you hit this assert, then the keyframe index is out of bounds
        assert( index < cast(ushort)mKeyFrames.length );
        
        destroy(mKeyFrames[index]);
        mKeyFrames.removeFromArrayIdx(index);
        _keyFrameDataChanged();
        mParent._keyFrameListChanged();
    }
    
    /** Removes all the KeyFrames from this track. */
    void removeAllKeyFrames()
    {
        foreach(k; mKeyFrames)
            destroy(k);
        mKeyFrames.clear();
        _keyFrameDataChanged();
        mParent._keyFrameListChanged();
    }
    
    
    /** Gets a KeyFrame object which contains the interpolated transforms at the time index specified.
     @remarks
     The KeyFrame objects held by this class are transformation snapshots at 
     discrete points in time. Normally however, you want to interpolate between these
     keyframes to produce smooth movement, and this method allows you to do this easily.
     In animation terminology this is called 'tweening'. 
     @param timeIndex The time (in relation to the whole animation sequence)
     @param kf Keyframe object to store results
     */
    abstract void getInterpolatedKeyFrame(TimeIndex timeIndex, KeyFrame kf);
    
    /** Applies an animation track to the designated target.
     @param timeIndex The time position in the animation to apply.
     @param weight The influence to give to this track, 1.0 for full influence, less to blend with
     other animations.
     @param scale The scale to apply to translations and scalings, useful for 
     adapting an animation to a different size target.
     */
    void apply(TimeIndex timeIndex, Real weight = 1.0, Real scale = 1.0f) {};
    
    /** Internal method used to tell the track that keyframe data has been 
     changed, which may cause it to rebuild some internal data. */
    void _keyFrameDataChanged(){}
    
    /** Method to determine if this track has any KeyFrames which are
     doing anything useful - can be used to determine if this track
     can be optimised out.
     */
    bool hasNonZeroKeyFrames(){ return true; }
    
    /** Optimise the current track by removing any duplicate keyframes. */
    void optimise() {}
    
    /** Internal method to collect keyframe times, in unique, ordered format. */
    void _collectKeyFrameTimes(ref Real[] keyFrameTimes)
    {
        foreach (k; mKeyFrames)
        {
            Real timePos = k.getTime();
            try
            {
                size_t i = std.algorithm.countUntil!"a > b"(keyFrameTimes, timePos);
                if (keyFrameTimes[i] != timePos)
                {
                    keyFrameTimes.insertBeforeIdx(i+1, timePos); //TODO check index
                }
            }catch(std.exception.RangeError e)
            {
                keyFrameTimes.insert(timePos);
            }
            
        }
    }
    
    /** Internal method to build keyframe time index map to translate global lower
     bound index to local lower bound index. */
    void _buildKeyFrameIndexMap(ref Real[] keyFrameTimes)
    {
        // Pre-allocate memory
        mKeyFrameIndexMap = new KeyFrameIndexMap(keyFrameTimes.length + 1);
        
        size_t i = 0, j = 0;
        while (j <= keyFrameTimes.length)
        {
            mKeyFrameIndexMap[j] = cast(ushort)(i);
            while (i < mKeyFrames.length && mKeyFrames[i].getTime() <= keyFrameTimes[j])
                ++i;
            ++j;
        }
    }
    
    /** Internal method to re-base the keyframes relative to a given keyframe. */
    void _applyBaseKeyFrame(KeyFrame base) {}
    
    /** Set a listener for this track. */
    void setListener(ref Listener l) { mListener = l; }
    
    /** Returns the parent Animation object for this track. */
    Animation getParent() //
    { return mParent; }
protected:
    //typedef vector<KeyFrame*>::type KeyFrameList;
    alias KeyFrame[] KeyFrameList;
    KeyFrameList mKeyFrames;
    Animation mParent;
    ushort mHandle;
    Listener mListener;
    
    /// Map used to translate global keyframe time lower bound index to local lower bound index
    //typedef vector<ushort>::type KeyFrameIndexMap;
    //alias SList!ushort KeyFrameIndexMap;
    alias ushort[] KeyFrameIndexMap;
    KeyFrameIndexMap mKeyFrameIndexMap;
    
    /// Create a keyframe implementation - must be overridden
    KeyFrame createKeyFrameImpl(Real time)
    {
        onNotImplementedError();
        assert(0);
    }
    
    /// Internal method for clone implementation
    void populateClone(AnimationTrack clone) //const
    {
        foreach(k ; mKeyFrames)
        {
            auto clonekf = k._clone(clone);
            clone.mKeyFrames.insert(clonekf);
        }
    }
    
    
    
}

/** Specialised AnimationTrack for dealing with generic animable values.
 */
class NumericAnimationTrack : AnimationTrack
{
public:
    /// Constructor
    this(ref Animation parent, ushort handle)
    {
        super(parent, handle);
    }
    /// Constructor, associates with an AnimableValue
    this(ref Animation parent, ushort handle, 
         /+ref+/ SharedPtr!AnimableValue target)
    {
        super(parent, handle);
        mTargetAnim = target;
    }
    
    /** Creates a new KeyFrame and adds it to this animation at the given time index.
     @remarks
     It is better to create KeyFrames in time order. Creating them out of order can result 
     in expensive reordering processing. Note that a KeyFrame at time index 0.0 is always created
     for you, so you don't need to create this one, just access it using getKeyFrame(0);
     @param timePos The time from which this KeyFrame will apply.
     */
    NumericKeyFrame createNumericKeyFrame(Real timePos)
    {
        return cast(NumericKeyFrame)(createKeyFrame(timePos));
    }
    
    /// @copydoc AnimationTrack.getInterpolatedKeyFrame
    override void getInterpolatedKeyFrame(TimeIndex timeIndex, KeyFrame kf) //const
    {
        if (mListener)
        {
            if (mListener.getInterpolatedKeyFrame(this, timeIndex, kf))
                return;
        }
        
        auto kret = cast(NumericKeyFrame)(kf);
        
        // Keyframe pointers
        KeyFrame kBase1, kBase2;
        NumericKeyFrame k1, k2;
        ushort firstKeyIndex;
        
        Real t = this.getKeyFramesAtTime(timeIndex, kBase1, kBase2, &firstKeyIndex);
        k1 = cast(NumericKeyFrame)(kBase1);
        k2 = cast(NumericKeyFrame)(kBase2);
        
        if (t == 0.0)
        {
            // Just use k1
            kret.setValue(k1.getValue());
        }
        else
        {
            // Interpolate by t
            auto diff = k2.getValue() - k1.getValue();
            kret.setValue(k1.getValue() + diff * t);
        }
    }
    
    /// @copydoc AnimationTrack.apply
    override void apply(TimeIndex timeIndex, Real weight = 1.0, Real scale = 1.0f)
    {
        applyToAnimable(mTargetAnim, timeIndex, weight, scale);
    }
    
    /** Applies an animation track to a given animable value.
     @param anim The AnimableValue to which to apply the animation
     @param timeIndex The time position in the animation to apply.
     @param weight The influence to give to this track, 1.0 for full influence, less to blend with
     other animations.
     @param scale The scale to apply to translations and scalings, useful for 
     adapting an animation to a different size target.
     */
    void applyToAnimable(SharedPtr!AnimableValue anim,TimeIndex timeIndex, 
                         Real weight = 1.0, Real scale = 1.0f)
    {
        // Nothing to do if no keyframes or zero weight, scale
        if (mKeyFrames.empty() || !weight || !scale)
            return;
        
        auto kf = new NumericKeyFrame(null, timeIndex.getTimePos());
        getInterpolatedKeyFrame(timeIndex, kf);
        // add to existing. Weights are not relative, but treated as
        // absolute multipliers for the animation
        auto val = kf.getValue() * (weight * scale);//FIXME auto or Variant ?
        
        anim.get().applyDeltaValue(val);
    }
    
    /** Returns a pointer to the associated animable object (if any). */
    ref SharedPtr!AnimableValue getAssociatedAnimable()
    {
        return mTargetAnim;
    }
    
    /** Sets the associated animable object which will be automatically 
     affected by calls to 'apply'. */
    void setAssociatedAnimable(ref SharedPtr!AnimableValue val)
    {
        mTargetAnim = val;
    }
    
    /** Returns the KeyFrame at the specified index. */
    NumericKeyFrame getNumericKeyFrame(ushort index)
    {
        return cast(NumericKeyFrame)(getKeyFrame(index));
    }
    
    /** Clone this track (internal use only) */
    NumericAnimationTrack _clone(ref Animation newParent)
    {
        auto newTrack = newParent.createNumericTrack(mHandle);
        newTrack.mTargetAnim = mTargetAnim;
        populateClone(newTrack);
        return newTrack;
    }
    
    
protected:
    /// Target to animate
    SharedPtr!AnimableValue mTargetAnim;
    
    /// @copydoc AnimationTrack.createKeyFrameImpl
    override KeyFrame createKeyFrameImpl(Real time)
    {
        return new NumericKeyFrame(this, time);
    }
}

/** Specialised AnimationTrack for dealing with node transforms.
 */
class NodeAnimationTrack : AnimationTrack
{
public:
    /// Constructor
    this(ref Animation parent, ushort handle)
    {
        super(parent, handle);
        mTargetNode = null;
        //mSplines = null;
        mSplineBuildNeeded = false;
        mUseShortestRotationPath = true;
    }
    /// Constructor, associates with a Node
    this(ref Animation parent, ushort handle, 
         ref Node targetNode)
    {
        super(parent, handle);
        mTargetNode = (targetNode);
        //mSplines = 0;
        mSplineBuildNeeded = false;
        mUseShortestRotationPath = true;
    }
    /// Destructor
    ~this()
    {
        destroy(mSplines);
    }
    /** Creates a new KeyFrame and adds it to this animation at the given time index.
     @remarks
     It is better to create KeyFrames in time order. Creating them out of order can result 
     in expensive reordering processing. Note that a KeyFrame at time index 0.0 is always created
     for you, so you don't need to create this one, just access it using getKeyFrame(0);
     @param timePos The time from which this KeyFrame will apply.
     */
    TransformKeyFrame createNodeKeyFrame(Real timePos)
    {
        return cast(TransformKeyFrame)(createKeyFrame(timePos));
    }
    /** Returns a pointer to the associated Node object (if any). */
    ref Node getAssociatedNode()
    {
        return mTargetNode;
    }
    
    /** Sets the associated Node object which will be automatically affected by calls to 'apply'. */
    void setAssociatedNode(ref Node node)
    {
        mTargetNode = node;
    }
    
    /** As the 'apply' method but applies to a specified Node instead of associated node. */
    void applyToNode(Node node, TimeIndex timeIndex, Real weight = 1.0, 
                     Real scl = 1.0f)
    {
        // Nothing to do if no keyframes or zero weight or no node
        if (mKeyFrames.empty() || !weight || !node)
            return;
        
        auto kf = new TransformKeyFrame(null, timeIndex.getTimePos());
        getInterpolatedKeyFrame(timeIndex, kf);
        
        // add to existing. Weights are not relative, but treated as absolute multipliers for the animation
        Vector3 translate = kf.getTranslate() * weight * scl;
        node.translate(translate);
        
        // interpolate between no-rotation and full rotation, to point 'weight', so 0 = no rotate, 1 = full
        Quaternion rotate;
        Animation.RotationInterpolationMode rim =
            mParent.getRotationInterpolationMode();
        if (rim == Animation.RotationInterpolationMode.RIM_LINEAR)
        {
            rotate = Quaternion.nlerp(weight, Quaternion.IDENTITY, kf.getRotation(), mUseShortestRotationPath);
        }
        else //if (rim == Animation.RotationInterpolationMode.RIM_SPHERICAL)
        {
            rotate = Quaternion.Slerp(weight, Quaternion.IDENTITY, kf.getRotation(), mUseShortestRotationPath);
        }
        node.rotate(rotate);
        
        Vector3 scale = kf.getScale();
        // Not sure how to modify scale for cumulative anims... leave it alone
        //scale = ((Vector3.UNIT_SCALE - kf.getScale()) * weight) + Vector3.UNIT_SCALE;
        if (scale != Vector3.UNIT_SCALE)
        {
            if (scl != 1.0f)
                scale = Vector3.UNIT_SCALE + (scale - Vector3.UNIT_SCALE) * scl;
            else if (weight != 1.0f)
                scale = Vector3.UNIT_SCALE + (scale - Vector3.UNIT_SCALE) * weight;
        }
        node.scale(scale);
    }
    
    /** Sets the method of rotation calculation */
    void setUseShortestRotationPath(bool useShortestPath)
    {
        mUseShortestRotationPath = useShortestPath;
    }
    
    /** Gets the method of rotation calculation */
    bool getUseShortestRotationPath()
    {
        return mUseShortestRotationPath;
    }
    
    /// @copydoc AnimationTrack.getInterpolatedKeyFrame
    override void getInterpolatedKeyFrame(TimeIndex timeIndex, KeyFrame kf)
    {
        if (mListener)
        {
            if (mListener.getInterpolatedKeyFrame(this, timeIndex, kf))
                return;
        }
        
        auto kret = cast(TransformKeyFrame)(kf);
        
        // Keyframe pointers
        KeyFrame kBase1, kBase2;
        TransformKeyFrame k1, k2;
        ushort firstKeyIndex;
        
        Real t = this.getKeyFramesAtTime(timeIndex, kBase1, kBase2, &firstKeyIndex);
        k1 = cast(TransformKeyFrame)(kBase1);
        k2 = cast(TransformKeyFrame)(kBase2);
        
        if (t == 0.0)
        {
            // Just use k1
            kret.setRotation(k1.getRotation());
            kret.setTranslate(k1.getTranslate());
            kret.setScale(k1.getScale());
        }
        else
        {
            // Interpolate by t
            Animation.InterpolationMode im = mParent.getInterpolationMode();
            Animation.RotationInterpolationMode rim =
                mParent.getRotationInterpolationMode();
            Vector3 base;
            switch(im)
            {
                case Animation.InterpolationMode.IM_LINEAR:
                    // Interpolate linearly
                    // Rotation
                    // Interpolate to nearest rotation if mUseShortestRotationPath set
                    if (rim == Animation.RotationInterpolationMode.RIM_LINEAR)
                    {
                        kret.setRotation( Quaternion.nlerp(t, k1.getRotation(),
                                                           k2.getRotation(), mUseShortestRotationPath) );
                    }
                    else //if (rim == Animation.RotationInterpolationMode.RIM_SPHERICAL)
                    {
                        kret.setRotation( Quaternion.Slerp(t, k1.getRotation(),
                                                           k2.getRotation(), mUseShortestRotationPath) );
                    }
                    
                    // Translation
                    base = k1.getTranslate();
                    kret.setTranslate( base + ((k2.getTranslate() - base) * t) );
                    
                    // Scale
                    base = k1.getScale();
                    kret.setScale( base + ((k2.getScale() - base) * t) );
                    break;
                    
                case Animation.InterpolationMode.IM_SPLINE:
                    // Spline interpolation
                    
                    // Build splines if required
                    if (mSplineBuildNeeded)
                    {
                        buildInterpolationSplines();
                    }
                    
                    // Rotation, take mUseShortestRotationPath into account
                    kret.setRotation( mSplines.rotationSpline.interpolate(firstKeyIndex, t,
                                                                      mUseShortestRotationPath) );
                    
                    // Translation
                    kret.setTranslate( mSplines.positionSpline.interpolate(firstKeyIndex, t) );
                    
                    // Scale
                    kret.setScale( mSplines.scaleSpline.interpolate(firstKeyIndex, t) );
                    
                    break;
                default:
                    break;
            }
            
        }
    }
    
    /// @copydoc AnimationTrack.apply
    override void apply(TimeIndex timeIndex, Real weight = 1.0, Real scale = 1.0f)
    {
        applyToNode(mTargetNode, timeIndex, weight, scale);
    }
    
    /// @copydoc AnimationTrack._keyFrameDataChanged
    override void _keyFrameDataChanged()
    {
        mSplineBuildNeeded = true;
    }
    
    /** Returns the KeyFrame at the specified index. */
    TransformKeyFrame getNodeKeyFrame(ushort index)
    {
        return cast(TransformKeyFrame)(getKeyFrame(index));
    }
    
    
    /** Method to determine if this track has any KeyFrames which are
     doing anything useful - can be used to determine if this track
     can be optimised out.
     */
    override bool hasNonZeroKeyFrames()
    {
        foreach (_kf; mKeyFrames)
        {
            // look for keyframes which have any component which is non-zero
            // Since exporters can be a little inaccurate sometimes we use a
            // tolerance value rather than looking for nothing
            TransformKeyFrame kf = cast(TransformKeyFrame)_kf;
            Vector3 trans = kf.getTranslate();
            Vector3 scale = kf.getScale();
            Vector3 axis;
            Radian angle;
            kf.getRotation().ToAngleAxis(angle, axis);
            Real tolerance = 1e-3f;
            if (!trans.positionEquals(Vector3.ZERO, tolerance) ||
                !scale.positionEquals(Vector3.UNIT_SCALE, tolerance) ||
                !Math.RealEqual(angle.valueRadians(), 0.0f, tolerance))
            {
                return true;
            }
            
        }
        
        return false;
    }
    
    /** Optimise the current track by removing any duplicate keyframes. */
    override void optimise()
    {
        // Eliminate duplicate keyframes from 2nd to penultimate keyframe
        // NB only eliminate middle keys from sequences of 5+ identical keyframes
        // since we need to preserve the boundary keys in place, and we need
        // 2 at each end to preserve tangents for spline interpolation
        Vector3 lasttrans = Vector3.ZERO;
        Vector3 lastscale = Vector3.ZERO;
        Quaternion lastorientation;
        auto quatTolerance = Radian (1e-3f);
        //list<ushort>::type removeList;
        ushort[] removeList;
        ushort k = 0;
        ushort dupKfCount = 0;
        foreach (_kf; mKeyFrames)
        {
            TransformKeyFrame kf = cast(TransformKeyFrame)_kf;
            Vector3 newtrans = kf.getTranslate();
            Vector3 newscale = kf.getScale();
            Quaternion neworientation = kf.getRotation();
            // Ignore first keyframe; now include the last keyframe as we eliminate
            // only k-2 in a group of 5 to ensure we only eliminate middle keys
            if (_kf != mKeyFrames[0] &&
                newtrans.positionEquals(lasttrans) &&
                newscale.positionEquals(lastscale) &&
                neworientation.equals(lastorientation, quatTolerance))
            {
                ++dupKfCount;
                
                // 4 indicates this is the 5th duplicate keyframe
                if (dupKfCount == 4)
                {
                    // remove the 'middle' keyframe
                    removeList.insert(cast(ushort)(k-2));
                    --dupKfCount;
                }
            }
            else
            {
                // reset
                dupKfCount = 0;
                lasttrans = newtrans;
                lastscale = newscale;
                lastorientation = neworientation;
            }
            k++;
        }
        
        // Now remove keyframes, in reverse order to avoid index revocation
        foreach (r; removeList)
        {
            removeKeyFrame(r);
        }
        
    }
    
    /** Clone this track (internal use only) */
    NodeAnimationTrack _clone(ref Animation newParent)
    {
        auto newTrack = newParent.createNodeTrack(mHandle, mTargetNode);
        newTrack.mUseShortestRotationPath = mUseShortestRotationPath;
        populateClone(newTrack);
        return newTrack;
    }
    
    override void _applyBaseKeyFrame(KeyFrame b)
    {
        auto base = cast(TransformKeyFrame)(b); //const
        
        foreach (_kf; mKeyFrames)
        {
            TransformKeyFrame kf = cast(TransformKeyFrame)_kf;
            kf.setTranslate(kf.getTranslate() - base.getTranslate());
            kf.setRotation(base.getRotation().Inverse() * kf.getRotation());
            kf.setScale(kf.getScale() * (Vector3.UNIT_SCALE / base.getScale()));
        }
    }
    
protected:
    /// Specialised keyframe creation
    override KeyFrame createKeyFrameImpl(Real time)
    {
        return new TransformKeyFrame(this, time);
    }
    // Flag indicating we need to rebuild the splines next time
    void buildInterpolationSplines()
    {
        // Allocate splines if not exists
        if (!mSplines)
        {
            mSplines = new Splines; //new_T(Splines, MEMCATEGORY_ANIMATION);
        }
        
        // Cache to register for optimisation
        Splines* splines = mSplines;
        
        // Don't calc automatically, do it on request at the end
        splines.positionSpline.setAutoCalculate(false);
        splines.rotationSpline.setAutoCalculate(false);
        splines.scaleSpline.setAutoCalculate(false);
        
        splines.positionSpline.clear();
        splines.rotationSpline.clear();
        splines.scaleSpline.clear();
        
        foreach (_kf; mKeyFrames)
        {
            TransformKeyFrame kf = cast(TransformKeyFrame)_kf;
            splines.positionSpline.addPoint(kf.getTranslate());
            splines.rotationSpline.addPoint(kf.getRotation());
            splines.scaleSpline.addPoint(kf.getScale());
        }
        
        splines.positionSpline.recalcTangents();
        splines.rotationSpline.recalcTangents();
        splines.scaleSpline.recalcTangents();
        
        
        mSplineBuildNeeded = false;
    }
    
    // Struct for store splines, allocate on demand for better memory footprint
    struct Splines
    {
        SimpleSpline positionSpline;
        SimpleSpline scaleSpline;
        RotationalSpline rotationSpline;
    }
    
    Node mTargetNode;
    // Prebuilt splines, must be mutable since lazy-update inmethod
    /+mutable+/ Splines* mSplines;
    bool mSplineBuildNeeded;
    /// Defines if rotation is done using shortest path
    bool mUseShortestRotationPath ;
}

/** Type of vertex animation.
 Vertex animation comes in 2 types, morph and pose. The reason
 for the 2 types is that we have 2 different potential goals - to encapsulate
 a complete, flowing morph animation with multiple keyframes (a typical animation,
 but implemented by having snapshots of the vertex data at each keyframe), 
 or to represent a single pose change, for example a facial expression. 
 Whilst both could in fact be implemented using the same system, we choose
 to separate them since the requirements and limitations of each are quite
 different.
 @par
 Morph animation is a simple approach where we have a whole series of 
 snapshots of vertex data which must be interpolated, e.g. a running 
 animation implemented as morph targets. Because this is based on simple
 snapshots, it's quite fast to use when animating an entire mesh because 
 it's a simple linear change between keyframes. However, this simplistic 
 approach does not support blending between multiple morph animations. 
 If you need animation blending, you are advised to use skeletal animation
 for full-mesh animation, and pose animation for animation of subsets of 
 meshes or where skeletal animation doesn't fit - for example facial animation.
 For animating in a vertex shader, morph animation is quite simple and 
 just requires the 2 vertex buffers (one the original position buffer) 
 of absolute position data, and an interpolation factor. Each track in 
 a morph animation references a unique set of vertex data.
 @par
 Pose animation is more complex. Like morph animation each track references
 a single unique set of vertex data, but unlike morph animation, each 
 keyframe references 1 or more 'poses', each with an influence level. 
 A pose is a series of offsets to the base vertex data, and may be sparse - ie it
 may not reference every vertex. Because they're offsets, they can be 
 blended - both within a track and between animations. This set of features
 is very well suited to facial animation.
 @par
 For example, let's say you modelled a face (one set of vertex data), and 
 defined a set of poses which represented the various phonetic positions 
 of the face. You could then define an animation called 'SayHello', containing
 a single track which referenced the face vertex data, and which included 
 a series of keyframes, each of which referenced one or more of the facial 
 positions at different influence levels - the combination of which over
 time made the face form the shapes required to say the word 'hello'. Since
 the poses are only stored once, but can be referenced may times in 
 many animations, this is a very powerful way to build up a speech system.
 @par
 The downside of pose animation is that it can be more difficult to set up.
 Also, since it uses more buffers (one for the base data, and one for each
 active pose), if you're animating in hardware using vertex shaders you need
 to keep an eye on how many poses you're blending at once. You define a
 maximum supported number in your vertex program definition, see the 
 includes_pose_animation material script entry. 
 @par
 So, by partitioning the vertex animation approaches into 2, we keep the
 simple morph technique easy to use, whilst still allowing all 
 the powerful techniques to be used. Note that morph animation cannot
 be blended with other types of vertex animation (pose animation or other
 morph animation); pose animation can be blended with other pose animation
 though, and both types can be combined with skeletal animation. Also note
 that all morph animation can be expressed as pose animation, but not vice
 versa.
 */
enum VertexAnimationType
{
    /// No animation
    VAT_NONE = 0,
    /// Morph animation is made up of many interpolated snapshot keyframes
    VAT_MORPH = 1,
    /// Pose animation is made up of a single delta pose keyframe
    VAT_POSE = 2
}

/** Specialised AnimationTrack for dealing with changing vertex position information.
 @see VertexAnimationType
 */
class VertexAnimationTrack : AnimationTrack
{
public:
    /** The target animation mode */
    enum TargetMode
    {
        /// Interpolate vertex positions in software
        TM_SOFTWARE, 
        /** Bind keyframe 1 to position, and keyframe 2 to a texture coordinate
         for interpolation in hardware */
        TM_HARDWARE
    }
    /// Constructor
    this(ref Animation parent, ushort handle, VertexAnimationType animType)
    {
        super(parent, handle);
        mAnimationType = animType;
    }
    /// Constructor, associates with target VertexData and temp buffer (for software)
    this(ref Animation parent, ushort handle, VertexAnimationType animType, 
         ref VertexData targetData, TargetMode target = TargetMode.TM_SOFTWARE)
    {
        super(parent, handle);
        mAnimationType = animType;
        mTargetVertexData = targetData;
        mTargetMode = target;
    }
    
    /** Get the type of vertex animation we're performing. */
    VertexAnimationType getAnimationType(){ return mAnimationType; }
    
    /** Whether the vertex animation (if present) includes normals */
    bool getVertexAnimationIncludesNormals()
    {
        if (mAnimationType == VertexAnimationType.VAT_NONE)
            return false;
        
        if (mAnimationType == VertexAnimationType.VAT_MORPH)
        {
            bool normals = false;
            foreach (_kf; mKeyFrames)
            {
                VertexMorphKeyFrame kf = cast(VertexMorphKeyFrame)_kf;
                bool thisnorm = kf.getVertexBuffer().get().getVertexSize() > 12;
                if (_kf == mKeyFrames[0])
                    normals = thisnorm;
                else
                    // Only support normals if ALL keyframes include them
                    normals = normals && thisnorm;
                
            }
            return normals;
        }
        else 
        {
            // needs to derive from Mesh.PoseList, can't tell here
            return false;
        }
    }
    
    /** Creates a new morph KeyFrame and adds it to this animation at the given time index.
     @remarks
     It is better to create KeyFrames in time order. Creating them out of order can result 
     in expensive reordering processing. Note that a KeyFrame at time index 0.0 is always created
     for you, so you don't need to create this one, just access it using getKeyFrame(0);
     @param timePos The time from which this KeyFrame will apply.
     */
    VertexMorphKeyFrame createVertexMorphKeyFrame(Real timePos)
    {
        if (mAnimationType != VertexAnimationType.VAT_MORPH)
        {
            throw new InvalidParamsError(
                "Morph keyframes can only be created on vertex tracks of type morph.",
                "VertexAnimationTrack.createVertexMorphKeyFrame");
        }
        return cast(VertexMorphKeyFrame)(createKeyFrame(timePos));
    }
    
    /** Creates the single pose KeyFrame and adds it to this animation.
     */
    VertexPoseKeyFrame createVertexPoseKeyFrame(Real timePos)
    {
        if (mAnimationType != VertexAnimationType.VAT_POSE)
        {
            throw new InvalidParamsError(
                "Pose keyframes can only be created on vertex tracks of type pose.",
                "VertexAnimationTrack.createVertexPoseKeyFrame");
        }
        return cast(VertexPoseKeyFrame)(createKeyFrame(timePos));
    }
    
    /** @copydoc AnimationTrack.getInterpolatedKeyFrame
     */
    override void getInterpolatedKeyFrame(TimeIndex timeIndex, KeyFrame kf)
    {
        // Only relevant for pose animation
        if (mAnimationType == VertexAnimationType.VAT_POSE)
        {
            // Get keyframes
            KeyFrame kf1, kf2;
            Real t = getKeyFramesAtTime(timeIndex, kf1, kf2);
            
            auto vkfOut = cast(VertexPoseKeyFrame)(kf);
            auto vkf1 = cast(VertexPoseKeyFrame)(kf1);
            auto vkf2 = cast(VertexPoseKeyFrame)(kf2);
            
            // For each pose reference in key 1, we need to locate the entry in
            // key 2 and interpolate the influence
            auto poseList1 = vkf1.getPoseReferences();
            auto poseList2 = vkf2.getPoseReferences();
            foreach (p1; poseList1)
            {
                Real startInfluence = p1.influence;
                Real endInfluence = 0;
                // Search for entry in keyframe 2 list (if not there, will be 0)
                foreach (p2; poseList2)
                {
                    if (p1.poseIndex == p2.poseIndex)
                    {
                        endInfluence = p2.influence;
                        break;
                    }
                }
                // Interpolate influence
                Real influence = startInfluence + t*(endInfluence - startInfluence);
                
                vkfOut.addPoseReference(p1.poseIndex, influence);
            }
            // Now deal with any poses in key 2 which are not in key 1
            foreach (p2; poseList2)
            {
                bool found = false;
                foreach (p1; poseList1)
                {
                    if (p1.poseIndex == p2.poseIndex)
                    {
                        found = true;
                        break;
                    }
                }
                if (!found)
                {
                    // Need to apply this pose too, scaled from 0 start
                    Real influence = t * p2.influence;
                    vkfOut.addPoseReference(p2.poseIndex, influence);
                }
            } // key 2 iteration
            
        }
    }
    
    /// @copydoc AnimationTrack.apply
    override void apply(TimeIndex timeIndex, Real weight = 1.0, Real scale = 1.0f)
    {
        applyToVertexData(mTargetVertexData, timeIndex, weight);
    }
    
    /** As the 'apply' method but applies to specified VertexData instead of 
     associated data. */
    void applyToVertexData(ref VertexData data, 
                           ref TimeIndex timeIndex, Real weight = 1.0, 
                           /+ref+/PoseList poseList = PoseList.init)
    {
        // Nothing to do if no keyframes or no vertex data
        if (mKeyFrames.empty() || !data)
            return;
        
        // Get keyframes
        KeyFrame kf1, kf2;
        Real t = getKeyFramesAtTime(timeIndex, kf1, kf2);
        
        if (mAnimationType == VertexAnimationType.VAT_MORPH)
        {
            auto vkf1 = cast(VertexMorphKeyFrame)(kf1);
            auto vkf2 = cast(VertexMorphKeyFrame)(kf2);
            
            if (mTargetMode == TargetMode.TM_HARDWARE)
            {
                // If target mode is hardware, need to bind our 2 keyframe buffers,
                // one to main pos, one to morph target texcoord
                assert(!data.hwAnimationDataList.empty(),
                       "Haven't set up hardware vertex animation elements!");
                
                // no use for TempBlendedBufferInfo here btw
                // NB we assume that position buffer is unshared, except for normals
                // VertexDeclaration.getAutoOrganisedDeclaration should see to that
                auto posElem = data.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_POSITION);
                // Set keyframe1 data as original position
                data.vertexBufferBinding.setBinding(
                    posElem.getSource(), vkf1.getVertexBuffer());
                // Set keyframe2 data as derived
                data.vertexBufferBinding.setBinding(
                    data.hwAnimationDataList[0].targetBufferIndex,
                    vkf2.getVertexBuffer());
                // save T for use later
                data.hwAnimationDataList[0].parametric = t;
                
            }
            else
            {
                // If target mode is software, need to software interpolate each vertex
                
                Mesh.softwareVertexMorph(
                    t, vkf1.getVertexBuffer(), vkf2.getVertexBuffer(), data);
            }
        }
        else
        {
            // Pose
            
            VertexPoseKeyFrame vkf1 = cast(VertexPoseKeyFrame)(kf1);
            VertexPoseKeyFrame vkf2 = cast(VertexPoseKeyFrame)(kf2);
            
            // For each pose reference in key 1, we need to locate the entry in
            // key 2 and interpolate the influence
            auto poseList1 = vkf1.getPoseReferences();
            auto poseList2 = vkf2.getPoseReferences();
            foreach (p1; poseList1)
            {
                Real startInfluence = p1.influence;
                Real endInfluence = 0;
                // Search for entry in keyframe 2 list (if not there, will be 0)
                foreach (p2; poseList2)
                {
                    if (p1.poseIndex == p2.poseIndex)
                    {
                        endInfluence = p2.influence;
                        break;
                    }
                }
                // Interpolate influence
                Real influence = startInfluence + t*(endInfluence - startInfluence);
                // Scale by animation weight
                influence = weight * influence;
                // Get pose
                assert (p1.poseIndex < poseList.length);
                Pose pose = poseList[p1.poseIndex];
                // apply
                applyPoseToVertexData(pose, data, influence);
            }
            // Now deal with any poses in key 2 which are not in key 1
            foreach (p2; poseList2)
            {
                bool found = false;
                foreach (p1; poseList1)
                {
                    if (p1.poseIndex == p2.poseIndex)
                    {
                        found = true;
                        break;
                    }
                }
                if (!found)
                {
                    // Need to apply this pose too, scaled from 0 start
                    Real influence = t * p2.influence;
                    // Scale by animation weight
                    influence = weight * influence;
                    // Get pose
                    assert (p2.poseIndex <= poseList.length);
                    Pose pose = poseList[p2.poseIndex];
                    // apply
                    applyPoseToVertexData(pose, data, influence);
                }
            } // key 2 iteration
        } // morph or pose animation
    }
    
    
    /** Returns the morph KeyFrame at the specified index. */
    VertexMorphKeyFrame getVertexMorphKeyFrame(ushort index)
    {
        if (mAnimationType != VertexAnimationType.VAT_MORPH)
        {
            throw new InvalidParamsError(
                "Morph keyframes can only be created on vertex tracks of type morph.",
                "VertexAnimationTrack.getVertexMorphKeyFrame");
        }
        
        return cast(VertexMorphKeyFrame)(getKeyFrame(index));
    }
    
    /** Returns the pose KeyFrame at the specified index. */
    VertexPoseKeyFrame getVertexPoseKeyFrame(ushort index)
    {
        if (mAnimationType != VertexAnimationType.VAT_POSE)
        {
            throw new InvalidParamsError(
                "Pose keyframes can only be created on vertex tracks of type pose.",
                "VertexAnimationTrack.getVertexPoseKeyFrame");
        }
        
        return cast(VertexPoseKeyFrame)(getKeyFrame(index));
    }
    
    /** Sets the associated VertexData which this track will update. */
    void setAssociatedVertexData(ref VertexData data) { mTargetVertexData = data; }
    /** Gets the associated VertexData which this track will update. */
    ref VertexData getAssociatedVertexData(){ return mTargetVertexData; }
    
    /// Set the target mode
    void setTargetMode(TargetMode m) { mTargetMode = m; }
    /// Get the target mode
    TargetMode getTargetMode(){ return mTargetMode; }
    
    /** Method to determine if this track has any KeyFrames which are
     doing anything useful - can be used to determine if this track
     can be optimised out.
     */
    override bool hasNonZeroKeyFrames()
    {
        if (mAnimationType == VertexAnimationType.VAT_MORPH)
        {
            return !mKeyFrames.empty();
        }
        else
        {
            
            foreach (_kf; mKeyFrames)
            {
                VertexPoseKeyFrame kf = cast(VertexPoseKeyFrame)_kf;
                // look for keyframes which have a pose influence which is non-zero
                auto poseIt = kf.getPoseRefs();
                foreach(poseRef; poseIt)
                {
                    if (poseRef.influence > 0.0f)
                        return true;
                }
                
            }
            
            return false;
        }
    }
    
    /** Optimise the current track by removing any duplicate keyframes. */
    override void optimise()
    {
        // TODO - remove sequences of duplicate pose references?
    }
    
    /** Clone this track (internal use only) */
    VertexAnimationTrack _clone(ref Animation newParent)
    {
        VertexAnimationTrack newTrack = 
            newParent.createVertexTrack(mHandle, mAnimationType);
        newTrack.mTargetMode = mTargetMode;
        populateClone(newTrack);
        return newTrack;
    }
    
    override void _applyBaseKeyFrame(KeyFrame b)
    {
        auto base = cast(VertexPoseKeyFrame)b;
        
        foreach (_kf; mKeyFrames)
        {
            VertexPoseKeyFrame kf = cast(VertexPoseKeyFrame)(_kf);
            kf._applyBaseKeyFrame(base);
        }
    }
    
protected:
    /// Animation type
    VertexAnimationType mAnimationType;
    /// Target to animate
    VertexData mTargetVertexData;
    /// Mode to apply
    TargetMode mTargetMode;
    
    /// @copydoc AnimationTrack.createKeyFrameImpl
    override KeyFrame createKeyFrameImpl(Real time)
    {
        switch(mAnimationType)
        {
            default:
            case VertexAnimationType.VAT_MORPH:
                return new VertexMorphKeyFrame(this, time);
            case VertexAnimationType.VAT_POSE:
                return new VertexPoseKeyFrame(this, time);
        }
    }
    
    /// Utility method for applying pose animation
    void applyPoseToVertexData(ref Pose pose, ref VertexData data, Real influence)
    {
        if (mTargetMode == TargetMode.TM_HARDWARE)
        {
            // Hardware
            // If target mode is hardware, need to bind our pose buffer
            // to a target texcoord
            assert(!data.hwAnimationDataList.empty(),
                   "Haven't set up hardware vertex animation elements!");
            // no use for TempBlendedBufferInfo here btw
            // Set pose target as required
            size_t hwIndex = data.hwAnimDataItemsUsed++;
            // If we try to use too many poses, ignore extras
            if (hwIndex < data.hwAnimationDataList.length)
            {
                auto animData = data.hwAnimationDataList[hwIndex];
                data.vertexBufferBinding.setBinding(
                    animData.targetBufferIndex,
                    pose._getHardwareVertexBuffer(data));
                // save final influence in parametric
                animData.parametric = influence;
                
            }
            
        }
        else
        {
            // Software
            Mesh.softwareVertexPoseBlend(influence, pose.getVertexOffsets(), pose.getNormals(), data);
        }
    }
    
}


/** An animation container interface, which allows generic access to sibling animations.
 @remarks
 Because Animation instances can be held by different kinds of classes, and
 there are sometimes instances when you need to reference other Animation 
 instances within the same container, this class allows generic access to
 named animations within that container, whatever it may be.
 */
//class AnimationContainer
interface AnimationContainer
{
public:
    /** Gets the number of animations in this container. */
    ushort getNumAnimations();
    
    /** Retrieve an animation by index.  */
    Animation getAnimation(ushort index);
    
    /** Retrieve an animation by name. */
    Animation getAnimation(string name);
    
    /** Create a new animation with a given length owned by this container. */
    ref Animation createAnimation(string name, Real length);
    
    /** Returns whether this object contains the named animation. */
    bool hasAnimation(string name);
    
    /** Removes an Animation from this container. */
    void removeAnimation(string name);
    
}
/** An animation sequence. 
 @remarks
 This class defines the interface for a sequence of animation, whether that
 be animation of a mesh, a path along a spline, or possibly more than one
 type of animation in one. An animation is made up of many 'tracks', which are
 the more specific types of animation.
 @par
 You should not create these animations directly. They will be created via a parent
 object which owns the animation, e.g. Skeleton.
 */
class Animation// : public AnimationAlloc
{
    
public:
    /** The types of animation interpolation available. */
    enum InterpolationMode
    {
        /** Values are interpolated along straight lines. */
        IM_LINEAR,
        /** Values are interpolated along a spline, resulting in smoother changes in direction. */
        IM_SPLINE
    }
    
    /** The types of rotational interpolation available. */
    enum RotationInterpolationMode
    {
        /** Values are interpolated linearly. This is faster but does not 
         necessarily give a completely accurate result.
         */
        RIM_LINEAR,
        /** Values are interpolated spherically. This is more accurate but
         has a higher cost.
         */
        RIM_SPHERICAL
    }
    /** You should not use this constructor directly, use the parent object such as Skeleton instead.
     @param name The name of the animation, should be unique within it's parent (e.g. Skeleton)
     @param length The length of the animation in seconds.
     */
    this(string name, Real length)
    {
        mName = name;
        mLength = length;
        mInterpolationMode = msDefaultInterpolationMode;
        mRotationInterpolationMode = msDefaultRotationInterpolationMode;
        mKeyFrameTimesDirty = false;
        mUseBaseKeyFrame = false;
        mBaseKeyFrameTime = 0.0f;
        mBaseKeyFrameAnimationName = "";
        //mContainer = 0;
    }
    ~this()
    {
        destroyAllTracks();
    }
    
    /** Gets the name of this animation. */
    string getName()
    {
        return mName;
    }
    
    /** Gets the total length of the animation. */
    Real getLength()
    {
        return mLength;
    }
    
    /** Sets the length of the animation. 
     @note Changing the length of an animation may invalidate existing AnimationState
     instances which will need to be recreated. 
     */
    void setLength(Real len)
    {
        mLength = len;
    }
    
    /** Creates a NodeAnimationTrack for animating a Node.
     @param handle Handle to give the track, used for accessing the track later. 
     Must be unique within this Animation.
     */
    NodeAnimationTrack createNodeTrack(ushort handle)
    {
        if (hasNodeTrack(handle))
        {
            throw new DuplicateItemError( 
                                         "Node track with the specified handle " ~
                                         std.conv.to!string(handle) ~ " already exists",
                                         "Animation.createNodeTrack");
        }
        
        NodeAnimationTrack ret = new NodeAnimationTrack(this, handle);
        
        mNodeTrackList[handle] = ret;
        return ret;
    }
    
    /** Creates a NumericAnimationTrack for animating any numeric value.
     @param handle Handle to give the track, used for accessing the track later. 
     Must be unique within this Animation.
     */
    NumericAnimationTrack createNumericTrack(ushort handle)
    {
        if (hasNumericTrack(handle))
        {
            throw new DuplicateItemError( 
                                         "Numeric track with the specified handle " ~
                                         std.conv.to!string(handle) ~ " already exists",
                                         "Animation.createNumericTrack");
        }
        
        NumericAnimationTrack ret = new NumericAnimationTrack(this, handle);
        
        mNumericTrackList[handle] = ret;
        return ret;
    }
    
    /** Creates a VertexAnimationTrack for animating vertex position data.
     @param handle Handle to give the track, used for accessing the track later. 
     Must be unique within this Animation, and is used to identify the target. For example
     when applied to a Mesh, the handle must reference the index of the geometry being 
     modified; 0 for the shared geometry, and 1+ for SubMesh geometry with the same index-1.
     @param animType Either morph or pose animation, 
     */
    VertexAnimationTrack createVertexTrack(ushort handle, VertexAnimationType animType)
    {
        if (hasVertexTrack(handle))
        {
            throw new DuplicateItemError( 
                                         "Vertex track with the specified handle " ~
                                         std.conv.to!string(handle) ~ " already exists",
                                         "Animation.createVertexTrack");
        }
        
        VertexAnimationTrack ret = new VertexAnimationTrack(this, handle, animType);
        
        mVertexTrackList[handle] = ret;
        return ret;
    }
    
    /** Creates a new AnimationTrack automatically associated with a Node. 
     @remarks
     This method creates a standard AnimationTrack, but also associates it with a
     target Node which will receive all keyframe effects.
     @param handle Numeric handle to give the track, used for accessing the track later. 
     Must be unique within this Animation.
     @param node A pointer to the Node object which will be affected by this track
     */
    NodeAnimationTrack createNodeTrack(ushort handle, Node node)
    {
        NodeAnimationTrack ret = createNodeTrack(handle);
        
        ret.setAssociatedNode(node);
        
        return ret;
    }
    
    /** Creates a NumericAnimationTrack and associates it with an animable. 
     @param handle Handle to give the track, used for accessing the track later. 
     @param anim Animable object link
     Must be unique within this Animation.
     */
    NumericAnimationTrack createNumericTrack(ushort handle, 
                                             ref SharedPtr!AnimableValue anim)
    {
        NumericAnimationTrack ret = createNumericTrack(handle);
        
        ret.setAssociatedAnimable(anim);
        
        return ret;
    }
    
    /** Creates a VertexAnimationTrack and associates it with VertexData. 
     @param handle Handle to give the track, used for accessing the track later. 
     @param data VertexData object link
     @param animType The animation type 
     Must be unique within this Animation.
     */
    VertexAnimationTrack createVertexTrack(ushort handle, 
                                           ref VertexData data, VertexAnimationType animType)
    {
        VertexAnimationTrack ret = createVertexTrack(handle, animType);
        
        ret.setAssociatedVertexData(data);
        
        return ret;
    }
    
    /** Gets the number of NodeAnimationTrack objects contained in this animation. */
    ushort getNumNodeTracks()
    {
        return cast(ushort)mNodeTrackList.length;
    }
    
    /** Gets a node track by it's handle. */
    NodeAnimationTrack getNodeTrack(ushort handle)
    {
        auto i = handle in mNodeTrackList; // 'in' gives pointer
        
        if (i is null)
        {
            throw new ItemNotFoundError( 
                                        "Cannot find node track with the specified handle " ~
                                        std.conv.to!string(handle),
                                        "Animation.getNodeTrack");
        }
        
        return *i;
    }
    
    /** Does a track exist with the given handle? */
    bool hasNodeTrack(ushort handle)
    {
        return (handle in mNodeTrackList) !is null;
    }
    
    /** Gets the number of NumericAnimationTrack objects contained in this animation. */
    ushort getNumNumericTracks()
    {
        return cast(ushort)mNumericTrackList.length;
    }
    
    /** Gets a numeric track by it's handle. */
    NumericAnimationTrack getNumericTrack(ushort handle)
    {
        auto i = handle in mNumericTrackList; // 'in' gives pointer
        
        if (i is null)
        {
            throw new ItemNotFoundError(
                "Cannot find numeric track with the specified handle " ~
                std.conv.to!string(handle),
                "Animation.getNumericTrack");
        }
        
        return *i;
    }
    
    /** Does a track exist with the given handle? */
    bool hasNumericTrack(ushort handle)
    {
        return (handle in mNumericTrackList) !is null;
    }
    
    /** Gets the number of VertexAnimationTrack objects contained in this animation. */
    ushort getNumVertexTracks()
    {
        return cast(ushort)mVertexTrackList.length;
    }
    
    /** Gets a Vertex track by it's handle. */
    VertexAnimationTrack getVertexTrack(ushort handle)
    {
        auto i = handle in mVertexTrackList;
        
        if (i is null)
        {
            throw new ItemNotFoundError(
                "Cannot find vertex track with the specified handle " ~
                std.conv.to!string(handle),
                "Animation.getVertexTrack");
        }
        
        return *i;
    }
    
    /** Does a track exist with the given handle? */
    bool hasVertexTrack(ushort handle)
    {
        return (handle in mVertexTrackList) !is null;
    }
    
    /** Destroys the node track with the given handle. */
    void destroyNodeTrack(ushort handle)
    {
        auto i = handle in mNodeTrackList;
        
        if (i !is null)
        {
            destroy(*i);
            mNodeTrackList.remove(handle);
            _keyFrameListChanged();
        }
    }
    
    /** Destroys the numeric track with the given handle. */
    void destroyNumericTrack(ushort handle)
    {
        auto i = handle in mNumericTrackList;
        
        if (i !is null)
        {
            destroy(*i);
            mNumericTrackList.remove(handle);
            _keyFrameListChanged();
        }
    }
    
    /** Destroys the Vertex track with the given handle. */
    void destroyVertexTrack(ushort handle)
    {
        auto i = handle in mVertexTrackList;
        
        if (i !is null)
        {
            destroy(*i);
            mVertexTrackList.remove(handle);
            _keyFrameListChanged();
        }
    }
    
    /** Removes and destroys all tracks making up this animation. */
    void destroyAllTracks()
    {
        destroyAllNodeTracks();
        destroyAllNumericTracks();
        destroyAllVertexTracks();
    }
    
    /** Removes and destroys all tracks making up this animation. */
    void destroyAllNodeTracks()
    {
        foreach (i, t; mNodeTrackList)
        {
            destroy(t);
        }
        mNodeTrackList.clear();
        _keyFrameListChanged();
    }
    /** Removes and destroys all tracks making up this animation. */
    void destroyAllNumericTracks()
    {
        foreach (i, t; mNumericTrackList)
        {
            destroy(t);
        }
        mNumericTrackList.clear();
        _keyFrameListChanged();
    }
    /** Removes and destroys all tracks making up this animation. */
    void destroyAllVertexTracks()
    {
        foreach (i, t; mVertexTrackList)
        {
            destroy(t);
        }
        mVertexTrackList.clear();
        _keyFrameListChanged();
    }
    
    /** Applies an animation given a specific time point and weight.
     @remarks
     Where you have associated animation tracks with objects, you can easily apply
     an animation to those objects by calling this method.
     @param timePos The time position in the animation to apply.
     @param weight The influence to give to this track, 1.0 for full influence, less to blend with
     other animations.
     @param scale The scale to apply to translations and scalings, useful for 
     adapting an animation to a different size target.
     */
    void apply(Real timePos, Real weight = 1.0, Real scale = 1.0f)
    {
        _applyBaseKeyFrame();
        
        // Calculate time index for fast keyframe search
        TimeIndex timeIndex = _getTimeIndex(timePos);
        
        foreach (i, t; mNodeTrackList)
        {
            t.apply(timeIndex, weight, scale);
        }
        
        foreach (i, t; mNumericTrackList)
        {
            t.apply(timeIndex, weight, scale);
        }
        
        foreach (i, t; mVertexTrackList)
        {
            t.apply(timeIndex, weight, scale);
        }
    }
    
    /** Applies all node tracks given a specific time point and weight to the specified node.
     @remarks
     It does not consider the actual node tracks are attached to.
     As such, it resembles the apply method for a given skeleton (see below).
     @param timePos The time position in the animation to apply.
     @param weight The influence to give to this track, 1.0 for full influence, less to blend with
     other animations.
     @param scale The scale to apply to translations and scalings, useful for 
     adapting an animation to a different size target.
     */
    void applyToNode(ref Node node, Real timePos, Real weight = 1.0, Real scale = 1.0f)
    {
        _applyBaseKeyFrame();
        
        // Calculate time index for fast keyframe search
        TimeIndex timeIndex = _getTimeIndex(timePos);
        
        foreach (i, t; mNodeTrackList)
        {
            t.applyToNode(node, timeIndex, weight, scale);
        }
    }
    
    /** Applies all node tracks given a specific time point and weight to a given skeleton.
     @remarks
     Where you have associated animation tracks with Node objects, you can easily apply
     an animation to those nodes by calling this method.
     @param timePos The time position in the animation to apply.
     @param weight The influence to give to this track, 1.0 for full influence, less to blend with
     other animations.
     @param scale The scale to apply to translations and scalings, useful for 
     adapting an animation to a different size target.
     */
    void apply(ref Skeleton skeleton, Real timePos, Real weight = 1.0, Real scale = 1.0f)
    {
        _applyBaseKeyFrame();
        
        // Calculate time index for fast keyframe search
        TimeIndex timeIndex = _getTimeIndex(timePos);
        
        foreach (i, t; mNodeTrackList)
        {
            // get bone to apply to 
            Bone b = skeleton.getBone(i);
            t.applyToNode(b, timeIndex, weight, scale);
        }
    }
    
    /** Applies all node tracks given a specific time point and weight to a given skeleton.
     @remarks
     Where you have associated animation tracks with Node objects, you can easily apply
     an animation to those nodes by calling this method.
     @param timePos The time position in the animation to apply.
     @param weight The influence to give to this track, 1.0 for full influence, less to blend with
     other animations.
     @param blendMask The influence array defining additional per bone weights. These will
     be modulated with the weight factor.
     @param scale The scale to apply to translations and scalings, useful for 
     adapting an animation to a different size target.
     */
    void apply(ref Skeleton skeleton, Real timePos, float weight,
               ref AnimationState.BoneBlendMask blendMask, Real scale)
    {
        _applyBaseKeyFrame();
        
        // Calculate time index for fast keyframe search
        TimeIndex timeIndex = _getTimeIndex(timePos);
        
        
        foreach (i, node; mNodeTrackList)
        {
            // get bone to apply to 
            Bone b = skeleton.getBone(i);
            node.applyToNode(b, timeIndex, blendMask[b.getHandle()] * weight, scale);
        }
    }
    
    /** Applies all vertex tracks given a specific time point and weight to a given entity.
     @remarks
     @param entity The Entity to which this animation should be applied
     @param timePos The time position in the animation to apply.
     @param weight The weight at which the animation should be applied 
     (only affects pose animation)
     @param software Whether to populate the software morph vertex data
     @param hardware Whether to populate the hardware morph vertex data
     */
    void apply(ref Entity entity, Real timePos, Real weight, bool software, 
               bool hardware)
    {
        _applyBaseKeyFrame();
        
        // Calculate time index for fast keyframe search
        TimeIndex timeIndex = _getTimeIndex(timePos);
        
        foreach (handle, track; mVertexTrackList)
        {
            
            VertexData swVertexData;
            VertexData hwVertexData;
            if (handle == 0)
            {
                // shared vertex data
                swVertexData = entity._getSoftwareVertexAnimVertexData();
                hwVertexData = entity._getHardwareVertexAnimVertexData();
                entity._markBuffersUsedForAnimation();
            }
            else
            {
                // sub entity vertex data (-1)
                SubEntity s = entity.getSubEntity(handle - 1);
                // Skip this track if subentity is not visible
                if (!s.isVisible())
                    continue;
                swVertexData = s._getSoftwareVertexAnimVertexData();
                hwVertexData = s._getHardwareVertexAnimVertexData();
                s._markBuffersUsedForAnimation();
            }
            // Apply to both hardware and software, if requested
            if (software)
            {
                track.setTargetMode(VertexAnimationTrack.TargetMode.TM_SOFTWARE);
                track.applyToVertexData(swVertexData, timeIndex, weight, 
                                        entity.getMesh().getAs().getPoseList());
            }
            if (hardware)
            {
                track.setTargetMode(VertexAnimationTrack.TargetMode.TM_HARDWARE);
                track.applyToVertexData(hwVertexData, timeIndex, weight, 
                                        entity.getMesh().getAs().getPoseList());
            }
        }
    }
    
    /** Applies all numeric tracks given a specific time point and weight to the specified animable value.
     @remarks
     It does not applies to actual attached animable values but rather uses all tracks for a single animable value.
     @param timePos The time position in the animation to apply.
     @param weight The influence to give to this track, 1.0 for full influence, less to blend with
     other animations.
     @param scale The scale to apply to translations and scalings, useful for 
     adapting an animation to a different size target.
     */
    void applyToAnimable(SharedPtr!AnimableValue anim, Real timePos, Real weight = 1.0, Real scale = 1.0f)
    {
        _applyBaseKeyFrame();
        
        // Calculate time index for fast keyframe search
        _getTimeIndex(timePos);
        
        foreach (NumericAnimationTrack j; mNumericTrackList)
        {
            //j.applyToAnimable(anim, weight, scale);//TODO applyToAnimable uh?
            j.applyToAnimable(anim, new TimeIndex(weight), scale);//TODO applyToAnimable wtf? c++ passes weight as TimeIndex
        }
    }
    
    /** Applies all vertex tracks given a specific time point and weight to the specified vertex data.
     @remarks
     It does not apply to the actual attached vertex data but rather uses all tracks for a given vertex data.
     @param timePos The time position in the animation to apply.
     @param weight The influence to give to this track, 1.0 for full influence, less to blend with
     other animations.
     */
    void applyToVertexData(ref VertexData data, Real timePos, Real weight = 1.0)
    {
        _applyBaseKeyFrame();
        
        // Calculate time index for fast keyframe search
        TimeIndex timeIndex = _getTimeIndex(timePos);
        
        foreach (i, k; mVertexTrackList)
        {
            k.applyToVertexData(data, timeIndex, weight);
        }
    }
    
    /** Tells the animation how to interpolate between keyframes.
     @remarks
     By default, animations normally interpolate linearly between keyframes. This is
     fast, but when animations include quick changes in direction it can look a little
     unnatural because directions change instantly at keyframes. An alternative is to
     tell the animation to interpolate along a spline, which is more expensive in terms
     of calculation time, but looks smoother because major changes in direction are 
     distributed around the keyframes rather than just at the keyframe.
     @par
     You can also change the default animation behaviour by calling 
     Animation.setDefaultInterpolationMode.
     */
    void setInterpolationMode(InterpolationMode im)
    {
        mInterpolationMode = im;
    }
    
    /** Gets the current interpolation mode of this animation. 
     @remarks
     See setInterpolationMode for more info.
     */
    InterpolationMode getInterpolationMode()
    {
        return mInterpolationMode;
    }
    /** Tells the animation how to interpolate rotations.
     @remarks
     By default, animations interpolate linearly between rotations. This
     is fast but not necessarily completely accurate. If you want more 
     accurate interpolation, use spherical interpolation, but be aware 
     that it will incur a higher cost.
     @par
     You can also change the default rotation behaviour by calling 
     Animation.setDefaultRotationInterpolationMode.
     */
    void setRotationInterpolationMode(RotationInterpolationMode im)
    {
        mRotationInterpolationMode = im;
    }

    /** Gets the current rotation interpolation mode of this animation. 
     @remarks
     See setRotationInterpolationMode for more info.
     */
    RotationInterpolationMode getRotationInterpolationMode()
    {
        return mRotationInterpolationMode;
    }
    
    // Methods for setting the defaults
    /** Sets the default animation interpolation mode. 
     @remarks
     Every animation created after this option is set will have the new interpolation
     mode specified. You can also change the mode per animation by calling the 
     setInterpolationMode method on the instance in question.
     */
    static void setDefaultInterpolationMode(InterpolationMode im)
    {
        msDefaultInterpolationMode = im;
    }
    
    /** Gets the default interpolation mode for all animations. */
    static InterpolationMode getDefaultInterpolationMode()
    {
        return msDefaultInterpolationMode;
    }
    
    /** Sets the default rotation interpolation mode. 
     @remarks
     Every animation created after this option is set will have the new interpolation
     mode specified. You can also change the mode per animation by calling the 
     setInterpolationMode method on the instance in question.
     */
    static void setDefaultRotationInterpolationMode(RotationInterpolationMode im)
    {
        msDefaultRotationInterpolationMode = im;
    }
    
    /** Gets the default rotation interpolation mode for all animations. */
    static RotationInterpolationMode getDefaultRotationInterpolationMode()
    {
        return msDefaultRotationInterpolationMode;
    }
    
    alias NodeAnimationTrack[ushort] NodeTrackList;
    //typedef ConstMapIterator<NodeTrackList> NodeTrackIterator;
    
    alias NumericAnimationTrack[ushort] NumericTrackList;
    //typedef ConstMapIterator<NumericTrackList> NumericTrackIterator;
    
    alias VertexAnimationTrack[ushort] VertexTrackList;
    //typedef ConstMapIterator<VertexTrackList> VertexTrackIterator;
    
    /// Fast access to NON-UPDATEABLE node track list
    ref NodeTrackList _getNodeTrackList()
    {
        return mNodeTrackList;
    }
    
    /// Get non-updateable iterator over node tracks
    //NodeTrackIterator getNodeTrackIterator()
    //{ return NodeTrackIterator(mNodeTrackList.begin(), mNodeTrackList.end()); }

    /// Fast access to NON-UPDATEABLE numeric track list
    ref NumericTrackList _getNumericTrackList()
    {
        return mNumericTrackList;
    }
    
    /// Get non-updateable iterator over node tracks
    //NumericTrackIterator getNumericTrackIterator()
    //{ return NumericTrackIterator(mNumericTrackList.begin(), mNumericTrackList.end()); }
    
    /// Fast access to NON-UPDATEABLE Vertex track list
    ref VertexTrackList _getVertexTrackList()
    {
        return mVertexTrackList;
    }

    /// Try not to modify the list, mkay
    ref NodeTrackList getNodeTracks()
    {
        return mNodeTrackList;
    }

    /// Try not to modify the list, mkay
    ref NumericTrackList getNumericTracks()
    {
        return mNumericTrackList;
    }

    /// Try not to modify the list, mkay
    ref VertexTrackList getVertexTracks()
    {
        return mVertexTrackList;
    }

    /// Get non-updateable iterator over node tracks
    //VertexTrackIterator getVertexTrackIterator()
    //{ return VertexTrackIterator(mVertexTrackList.begin(), mVertexTrackList.end()); }
    
    /** Optimise an animation by removing unnecessary tracks and keyframes.
     @remarks
     When you export an animation, it is possible that certain tracks
     have been keyframed but actually don't include anything useful - the
     keyframes include no transformation. These tracks can be completely
     eliminated from the animation and thus speed up the animation. 
     In addition, if several keyframes in a row have the same value, 
     then they are just adding overhead and can be removed.
     @note
     Since track-less and identity track has difference behavior for
     accumulate animation blending if corresponding track presenting at
     other animation that is non-identity, and in normally this method
     didn't known about the situation of other animation, it can't deciding
     whether or not discards identity tracks. So there have a parameter
     allow you choose what you want, in case you aren't sure how to do that,
     you should use Skeleton.optimiseAllAnimations instead.
     @param
     discardIdentityNodeTracks If true, discard identity node tracks.
     */
    void optimise(bool discardIdentityNodeTracks = true)
    {
        optimiseNodeTracks(discardIdentityNodeTracks);
        optimiseVertexTracks();
    }
    
    /// A list of track handles
    //typedef set<ushort>::type TrackHandleList;
    //alias Array!ushort TrackHandleList;
    alias ushort[] TrackHandleList;
    
    /** Internal method for collecting identity node tracks.
     @remarks
     This method remove non-identity node tracks form the track handle list.
     @param
     tracks A list of track handle of non-identity node tracks, where this
     method will remove non-identity node track handles.
     */
    void _collectIdentityNodeTracks(ref TrackHandleList tracks)
    {
        for (ushort i=0; i < mNodeTrackList.length;)
        {
            auto track = mNodeTrackList[i];
            if (track.hasNonZeroKeyFrames())
            {
                tracks.removeFromArrayIdx(i);
            }
            else
                i++;
        }
    }
    
    /** Internal method for destroy given node tracks.
     */
    void _destroyNodeTracks(TrackHandleList tracks)
    {
        foreach (t; tracks)
        {
            destroyNodeTrack(t);
        }
    }
    
    /** Clone this animation.
     @note
     The pointer returned from this method is the only one recorded, 
     thus it is up to the caller to arrange for the deletion of this
     object.
     */
    Animation clone(string newName)
    {
        Animation newAnim = new Animation(newName, mLength);
        newAnim.mInterpolationMode = mInterpolationMode;
        newAnim.mRotationInterpolationMode = mRotationInterpolationMode;
        
        // Clone all tracks
        foreach (i, t; mNodeTrackList)
        {
            t._clone(newAnim);
        }
        foreach (i, t; mNumericTrackList)
        {
            t._clone(newAnim);
        }
        foreach (i, t; mVertexTrackList)
        {
            t._clone(newAnim);
        }
        
        newAnim._keyFrameListChanged();
        return newAnim;
        
    }
    
    /** Internal method used to tell the animation that keyframe list has been
     changed, which may cause it to rebuild some internal data */
    void _keyFrameListChanged() { mKeyFrameTimesDirty = true; }
    
    /** Internal method used to convert time position to time index object.
     @note
     The time index returns by this function are associated with state of
     the animation object, if the animation object altered (e.g. create/remove
     keyframe or track), all related time index will invalidated.
     @param timePos The time position.
     @return The time index object which contains wrapped time position (in
     relation to the whole animation sequence) and lower bound index of
     global keyframe time list.
     */
    TimeIndex _getTimeIndex(Real timePos)
    {
        // Uncomment following statement for work as previous
        //return timePos;
        
        // Build keyframe time list on demand
        if (mKeyFrameTimesDirty)
        {
            buildKeyFrameTimeList();
        }
        
        // Wrap time
        Real totalAnimationLength = mLength;
        
        if( timePos > totalAnimationLength && totalAnimationLength > 0.0f )
            timePos = fmod( timePos, totalAnimationLength );
        
        // Search for global index
        //KeyFrameTimeList.iterator it =
        //    std.lower_bound(mKeyFrameTimes.begin(), mKeyFrameTimes.end(), timePos);
        auto i = std.algorithm.countUntil!"a > b"(mKeyFrameTimes, timePos);
        
        return new TimeIndex(timePos, cast(uint)i);//FIXME maybe i-1
    }
    
    /** Sets a base keyframe which for the skeletal / pose keyframes 
     in this animation. 
     @remarks
     Skeletal and pose animation keyframes are expressed as deltas from a 
     given base state. By default, that is the binding setup of the skeleton, 
     or the object space mesh positions for pose animation. However, sometimes
     it is useful for animators to create animations with a different starting
     pose, because that's more convenient, and the animation is designed to
     simply be added to the existing animation state and not globally averaged
     with other animations (this is always the case with pose animations, but
     is activated for skeletal animations via ANIMBLEND_CUMULATIVE).
     @par
     In order for this to work, the keyframes need to be 're-based' against
     this new starting state, for example by treating the first keyframe as
     the reference point (and Therefore representing no change). This can 
     be achieved by applying the inverse of this reference keyframe against
     all other keyframes. Since this fundamentally changes the animation, 
     this method just marks the animation as requiring this rebase, which 
     is performed at the next Animation 'apply' call. This is to allow the
     Animation to be re-saved with this flag set, but without having altered
     the keyframes yet, so no data is lost unintentionally. If you wish to
     save the animation after the adjustment has taken place, you can
     (@see _applyBaseKeyFrame)
     @param useBaseKeyFrame Whether a base keyframe should be used
     @param keyframeTime The time corresponding to the base keyframe, if any
     @param baseAnimName Optionally a different base animation (must contain the same tracks)
     */
    void setUseBaseKeyFrame(bool useBaseKeyFrame, Real keyframeTime = 0.0f,string baseAnimName = "")
    {
        if (useBaseKeyFrame != mUseBaseKeyFrame ||
            keyframeTime != mBaseKeyFrameTime ||
            baseAnimName != mBaseKeyFrameAnimationName)
        {
            mUseBaseKeyFrame = useBaseKeyFrame;
            mBaseKeyFrameTime = keyframeTime;
            mBaseKeyFrameAnimationName = baseAnimName;
        }
    }
    /** Whether a base keyframe is being used for this Animation. */
    bool getUseBaseKeyFrame()
    {
        return mUseBaseKeyFrame;
    }
    /** If a base keyframe is being used, the time of that keyframe. */
    Real getBaseKeyFrameTime()
    {
        return mBaseKeyFrameTime;
    }
    /** If a base keyframe is being used, the Animation that provides that keyframe. */
    string getBaseKeyFrameAnimationName()
    {
        return mBaseKeyFrameAnimationName;
    }
    
    /// Internal method to adjust keyframes relative to a base keyframe (@see setUseBaseKeyFrame) */
    void _applyBaseKeyFrame()
    {
        if (mUseBaseKeyFrame)
        {
            Animation baseAnim = this;
            if (mBaseKeyFrameAnimationName !is null && mBaseKeyFrameAnimationName != "" && mContainer)
                baseAnim = mContainer.getAnimation(mBaseKeyFrameAnimationName);
            
            if (baseAnim)
            {
                foreach ( i, track; mNodeTrackList)
                {
                    NodeAnimationTrack baseTrack;
                    if (baseAnim == this)
                        baseTrack = track;
                    else
                        baseTrack = baseAnim.getNodeTrack(track.getHandle());
                    
                    auto kf = new TransformKeyFrame(baseTrack, mBaseKeyFrameTime);
                    baseTrack.getInterpolatedKeyFrame(baseAnim._getTimeIndex(mBaseKeyFrameTime), kf);
                    track._applyBaseKeyFrame(kf);
                }
                
                foreach (i, track; mVertexTrackList)
                {
                    if (track.getAnimationType() == VertexAnimationType.VAT_POSE)
                    {
                        VertexAnimationTrack baseTrack;
                        if (baseAnim == this)
                            baseTrack = track;
                        else
                            baseTrack = baseAnim.getVertexTrack(track.getHandle());
                        
                        auto kf = new VertexPoseKeyFrame(baseTrack, mBaseKeyFrameTime);
                        baseTrack.getInterpolatedKeyFrame(baseAnim._getTimeIndex(mBaseKeyFrameTime), kf);
                        track._applyBaseKeyFrame(kf);
                        
                    }
                }
                
            }
            
            // Re-base has been done, this is a one-way translation
            mUseBaseKeyFrame = false;
        }
        
    }
    
    void _notifyContainer(AnimationContainer c)
    {
        mContainer = c;
    }
    /** Retrieve the container of this animation. */
    ref AnimationContainer getContainer()
    {
        return mContainer;
    }
    
protected:
    /// Node tracks, indexed by handle
    NodeTrackList mNodeTrackList;
    /// Numeric tracks, indexed by handle
    NumericTrackList mNumericTrackList;
    /// Vertex tracks, indexed by handle
    VertexTrackList mVertexTrackList;
    string mName;
    
    Real mLength;
    
    InterpolationMode mInterpolationMode;
    RotationInterpolationMode mRotationInterpolationMode;
    
    static InterpolationMode msDefaultInterpolationMode;
    static RotationInterpolationMode msDefaultRotationInterpolationMode;
    
    /// Global keyframe time list used to search global keyframe index.
    //typedef vector<Real>::type KeyFrameTimeList;
    alias Real[] KeyFrameTimeList;
    KeyFrameTimeList mKeyFrameTimes;
    /// Dirty flag indicate that keyframe time list need to rebuild
    bool mKeyFrameTimesDirty;
    
    bool mUseBaseKeyFrame;
    Real mBaseKeyFrameTime;
    string mBaseKeyFrameAnimationName;
    AnimationContainer mContainer;
    
    void optimiseNodeTracks(bool discardIdentityTracks)
    {
        // Iterate over the node tracks and identify those with no useful keyframes
        ushort[] tracksToDestroy;
        
        foreach (i, track; mNodeTrackList)
        {
            if (discardIdentityTracks && !track.hasNonZeroKeyFrames())
            {
                // mark the entire track for destruction
                tracksToDestroy.insert(i);
            }
            else
            {
                track.optimise();
            }
            
        }
        
        // Now destroy the tracks we marked for death
        foreach(h; tracksToDestroy)
        {
            destroyNodeTrack(h);
        }
    }
    
    void optimiseVertexTracks()
    {
        // Iterate over the node tracks and identify those with no useful keyframes
        ushort[] tracksToDestroy;
        foreach (i, track; mVertexTrackList)
        {
            if (!track.hasNonZeroKeyFrames())
            {
                // mark the entire track for destruction
                tracksToDestroy.insert(i);
            }
            else
            {
                track.optimise();
            }
            
        }
        
        // Now destroy the tracks we marked for death
        foreach(h; tracksToDestroy)
        {
            destroyVertexTrack(h);
        }
        
    }
    
    /// Internal method to build global keyframe time list
    void buildKeyFrameTimeList()
    {
        // Clear old keyframe times
        mKeyFrameTimes.clear();
        
        // Collect all keyframe times from each track
        foreach (i, t; mNodeTrackList)
        {
            t._collectKeyFrameTimes(mKeyFrameTimes);
        }
        foreach (j, t; mNumericTrackList)
        {
            t._collectKeyFrameTimes(mKeyFrameTimes);
        }
        foreach (k, t; mVertexTrackList)
        {
            t._collectKeyFrameTimes(mKeyFrameTimes);
        }
        
        // Build global index to local index map for each track
        foreach (i, t; mNodeTrackList)
        {
            t._buildKeyFrameIndexMap(mKeyFrameTimes);
        }
        foreach (j, t; mNumericTrackList)
        {
            t._buildKeyFrameIndexMap(mKeyFrameTimes);
        }
        foreach (k, t; mVertexTrackList)
        {
            t._buildKeyFrameIndexMap(mKeyFrameTimes);
        }
        
        // Reset dirty flag
        mKeyFrameTimesDirty = false;
    }
}

/** A pose is a linked set of vertex offsets applying to one set of vertex
 data. 
 @remarks
 The target index referred to by the pose has a meaning set by the user
 of this class; but for example when used by Mesh it ref ers to either the
 Mesh shared geometry (0) or a SubMesh dedicated geometry (1+).
 Pose instances can be referred to by keyframes in VertexAnimationTrack in
 order to animate based on blending poses together.
 */
class Pose// : public AnimationAlloc
{
public:
    /** Constructor
     @param target The target vertexdata index (0 for shared, 1+ for 
     dedicated at the submesh index + 1)
     @param name Optional name
     */
    this(ushort target,string name = "")
    {
        mTarget = target;
        mName = name;
    }
    ~this() {}
    /// Return the name of the pose (may be blank)
    string getName(){ return mName; }
    /// Return the target geometry index of the pose
    ushort getTarget(){ return mTarget; }

    /// A collection of vertex offsets based on the vertex index
    //typedef map<size_t, Vector3>::type VertexOffsetMap;
    //alias SortedMap!(size_t, Vector3) VertexOffsetMap;
    alias Vector3[size_t] VertexOffsetMap;

    /// An iterator over the vertex offsets
    //typedef MapIterator<VertexOffsetMap> VertexOffsetIterator;
    /// An iterator over the vertex offsets
    //typedef ConstMapIterator<VertexOffsetMap> ConstVertexOffsetIterator;

    /// A collection of normals based on the vertex index
    //typedef map<size_t, Vector3>::type NormalsMap;
    //alias SortedMap!(size_t, Vector3) NormalsMap;
    //alias OrderedMap!(size_t, Vector3) NormalsMap;
    alias Vector3[size_t] NormalsMap;

    /// An iterator over the vertex offsets
    //typedef MapIterator<NormalsMap> NormalsIterator;
    /// An iterator over the vertex offsets
    //typedef ConstMapIterator<NormalsMap> ConstNormalsIterator;
    /// Return whether the pose vertices include normals
    bool getIncludesNormals(){ return !mNormalsMap.emptyAA(); }
    
    /** Adds an offset to a vertex for this pose. 
     @param index The vertex index
     @param offset The position offset for this pose
     */
    void addVertex(size_t index, ref Vector3 offset)
    {
        if (!mNormalsMap.emptyAA())
            throw new InvalidParamsError(
                "Inconsistent calls to addVertex, must include normals always or never",
                "Pose.addVertex");
        
        if(offset.squaredLength() < 1e-6f)
        {
            return;
        }
        
        mVertexOffsetMap[index] = offset;
        mBuffer.setNull();
    }
    
    /** Adds an offset to a vertex and a new normal for this pose. 
     @param index The vertex index
     @param offset The position offset for this pose
     */
    void addVertex(size_t index, ref Vector3 offset, ref Vector3 normal)
    {
        if (!mVertexOffsetMap.emptyAA() && mNormalsMap.emptyAA())
            throw new InvalidParamsError(
                "Inconsistent calls to addVertex, must include normals always or never",
                "Pose.addVertex");
        
        if(offset.squaredLength() < 1e-6f && normal.squaredLength() < 1e-6f)
        {
            return;
        }
        
        mVertexOffsetMap[index] = offset;
        mNormalsMap[index] = normal;
        mBuffer.setNull();
    }
    
    /** Remove a vertex offset. */
    void removeVertex(size_t index)
    {
        auto i = index in mVertexOffsetMap;
        if (i !is null)
        {
            mVertexOffsetMap.remove(index);
            mBuffer.setNull();
        }
        auto j = index in mNormalsMap;
        if (j !is null)
        {
            mNormalsMap.remove(index);
        }
    }
    
    /** Clear all vertices. */
    void clearVertices()
    {
        mVertexOffsetMap.clear();
        mNormalsMap.clear();
        mBuffer.setNull();
    }
    
    /** Gets an iterator over all the vertex offsets. */
    //ConstVertexOffsetIterator getVertexOffsetIterator();
    /** Gets an iterator over all the vertex offsets. */
    //VertexOffsetIterator getVertexOffsetIterator();
    /** Gets areference to the vertex offsets. */
    ref VertexOffsetMap getVertexOffsets(){ return mVertexOffsetMap; }
    
    /** Gets an iterator over all the vertex offsets. */
    //ConstNormalsIterator getNormalsIterator();
    /** Gets an iterator over all the vertex offsets. */
    //NormalsIterator getNormalsIterator();
    /** Gets areference to the vertex offsets. */
    ref NormalsMap getNormals(){ return mNormalsMap; }
    
    /** Get a hardware vertex buffer version of the vertex offsets. */
    SharedPtr!HardwareVertexBuffer _getHardwareVertexBuffer(VertexData origData)
    {
        size_t numVertices = origData.vertexCount;
        
        if (mBuffer.isNull())
        {
            // Create buffer
            size_t vertexSize = VertexElement.getTypeSize(VertexElementType.VET_FLOAT3);
            bool normals = getIncludesNormals();
            if (normals)
                vertexSize += VertexElement.getTypeSize(VertexElementType.VET_FLOAT3);
            
            mBuffer = HardwareBufferManager.getSingleton().createVertexBuffer(
                vertexSize, numVertices, HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY);
            
            float* pFloat = cast(float*)(mBuffer.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
            // initialise - these will be the values used where no pose vertex is included
            memset(pFloat, 0, mBuffer.get().getSizeInBytes()); 
            if (normals)
            {
                // zeroes are fine for positions (deltas), but for normals we need the original
                // mesh normals, since delta normals don't work (re-normalisation would
                // always result in a blended normal even with full pose applied)
                VertexElement origNormElem = 
                    origData.vertexDeclaration.findElementBySemantic(VertexElementSemantic.VES_NORMAL, 0);
                assert(origNormElem);
                
                SharedPtr!HardwareVertexBuffer origBuffer = 
                    origData.vertexBufferBinding.getBuffer(origNormElem.getSource());
                float* pDst = pFloat + 3;
                void* pSrcBase = origBuffer.get().lock(HardwareBuffer.LockOptions.HBL_READ_ONLY);
                float* pSrc;
                origNormElem.baseVertexPointerToElement(pSrcBase, &pSrc);
                for (size_t v = 0; v < numVertices; ++v)
                {
                    memcpy(pDst, pSrc, float.sizeof*3);
                    
                    pDst += 6;
                    pSrc = cast(float*)((cast(ubyte*)pSrc) + origBuffer.get().getVertexSize());
                }
                origBuffer.get().unlock();
                
                
            }
            // Set each vertex
            //VertexOffsetMap.const_iterator v = mVertexOffsetMap.begin();
            //NormalsMap.const_iterator n = mNormalsMap.begin();
            
            size_t numFloatsPerVertex = normals ? 6: 3;
            size_t n = 0;
            //while(v != mVertexOffsetMap.end())
            foreach(k, v; mVertexOffsetMap)//TODO mVertexOffsetMap sorting / ordering
            {
                // Remember, vertex maps are *sparse* so may have missing entries
                // This is why we skip
                float* pDst = pFloat + (numFloatsPerVertex * k);
                *pDst++ = v.x;
                *pDst++ = v.y;
                *pDst++ = v.z;
                //++v;
                if (normals)
                {
                    *pDst++ = v.x;
                    *pDst++ = v.y;
                    *pDst++ = v.z;
                }
                
            }
            mBuffer.get().unlock();
        }
        return mBuffer;
    }
    
    /** Clone this pose and create another one configured exactly the same
     way (only really useful for cloning holders of this class).
     */
    Pose clone()
    {
        auto newPose = new Pose(mTarget, mName);
        newPose.mVertexOffsetMap = mVertexOffsetMap;
        newPose.mNormalsMap = mNormalsMap;
        // Allow buffer to recreate itself, contents may change anyway
        return newPose;
    }
protected:
    /// Target geometry index
    ushort mTarget;
    /// Optional name
    string mName;
    /// Primary storage, sparse vertex use
    VertexOffsetMap mVertexOffsetMap;
    /// Primary storage, sparse vertex use
    NormalsMap mNormalsMap;
    /// Derived hardware buffer, covers all vertices
    //mutable 
    SharedPtr!HardwareVertexBuffer mBuffer;
}
//typedef vector<Pose*>::type PoseList;
alias Pose[] PoseList;


/** A bone in a skeleton.
 @remarks
 See Skeleton for more information about the principles behind skeletal animation.
 This class is a node in the joint hierarchy. Mesh vertices also have assignments
 to bones to define how they move in relation to the skeleton.
 */
class Bone : Node
{
public:
    /** Constructor, not to be used directly (use Bone::createChild or Skeleton::createBone) */
    this(ushort handle, Skeleton creator)
    {
        super();
        mHandle = handle;
        mManuallyControlled = false;
        mCreator = creator;
    }
    
    /** Constructor, not to be used directly (use Bone::createChild or Skeleton::createBone) */
    this(string name, ushort handle, Skeleton creator)
    {
        super(name);
        mHandle = handle;
        mManuallyControlled = false;
        mCreator = creator;
    }
    
    ~this(){}
    
    
    /** Creates a new Bone as a child of this bone.
     @remarks
     This method creates a new bone which will inherit the transforms of this
     bone, with the handle specified.
     @param 
     handle The numeric handle to give the new bone; must be unique within the Skeleton.
     @param
     translate Initial translation offset of child relative to parent
     @param
     rotate Initial rotation relative to parent
     */
    Bone createChild(ushort handle, 
                     Vector3 translate = Vector3.ZERO, Quaternion rotate = Quaternion.IDENTITY)
    {
        Bone retBone = mCreator.createBone(handle);
        retBone.translate(translate);
        retBone.rotate(rotate);
        this.addChild(retBone);
        return retBone;
    }
    
    
    /** Gets the numeric handle for this bone (unique within the skeleton). */
    ushort getHandle()
    {
        return mHandle;
    }
    
    /** Sets the current position / orientation to be the 'binding pose' ie the layout in which 
     bones were originally bound to a mesh.
     */
    void setBindingPose()
    {
        setInitialState();
        
        // Save inverse derived position/scale/orientation, used for calculate offset transform later
        mBindDerivedInversePosition = - _getDerivedPosition();
        mBindDerivedInverseScale = Vector3.UNIT_SCALE / _getDerivedScale();
        mBindDerivedInverseOrientation = _getDerivedOrientation().Inverse();
    }
    
    /** Resets the position and orientation of this Bone to the original binding position.
     @remarks
     Bones are bound to the mesh in a binding pose. They are then modified from this
     position during animation. This method returns the bone to it's original position and
     orientation.
     */
    void reset()
    {
        resetToInitialState();
    }
    
    /** Sets whether or not this bone is manually controlled. 
     @remarks
     Manually controlled bones can be altered by the application at runtime, 
     and their positions will not be reset by the animation routines. Note 
     that you should also make sure that there are no AnimationTrack objects
     ref erencing this bone, or if there are, you should disable them using
     pAnimation.destroyTrack(pBone.getHandle());
     @par
     You can also use AnimationState::setBlendMask to mask out animation from 
     chosen tracks if you want to prevent application of a scripted animation 
     to a bone without altering the Animation definition.
     */
    void setManuallyControlled(bool manuallyControlled)
    {
        mManuallyControlled = manuallyControlled;
        mCreator._notifyManualBoneStateChange(this);
    }
    
    /** Getter for mManuallyControlled Flag */
    bool isManuallyControlled()
    {
        return mManuallyControlled;
    }
    
    
    /** Gets the transform which takes bone space to current from the binding pose. 
     @remarks
     Internal use only.
     */
    void _getOffsetTransform(ref Matrix4 m)
    {
        // Combine scale with binding pose inverse scale,
        // NB just combine as equivalent axes, no shearing
        Vector3 locScale = _getDerivedScale() * mBindDerivedInverseScale;
        
        // Combine orientation with binding pose inverse orientation
        Quaternion locRotate = _getDerivedOrientation() * mBindDerivedInverseOrientation;
        
        // Combine position with binding pose inverse position,
        // Note that translation is relative to scale & rotation,
        // so first reverse transform original derived position to
        // binding pose bone space, and then transform to current
        // derived bone space.
        Vector3 locTranslate = _getDerivedPosition() + locRotate * (locScale * mBindDerivedInversePosition);
        
        m.makeTransform(locTranslate, locScale, locRotate);
    }
    
    /** Gets the inverted binding pose scale. */
    ref Vector3 _getBindingPoseInverseScale(){ return mBindDerivedInverseScale; }
    /** Gets the inverted binding pose position. */
    ref Vector3 _getBindingPoseInversePosition(){ return mBindDerivedInversePosition; }
    /** Gets the inverted binding pose orientation. */
    ref Quaternion _getBindingPoseInverseOrientation(){ return mBindDerivedInverseOrientation; }
    
    /// @see Node::needUpdate
    override void needUpdate(bool forceParentUpdate = false)
    {
        super.needUpdate(forceParentUpdate);
        
        if (isManuallyControlled())
        {
            // Dirty the skeleton if manually controlled so animation can be updated
            mCreator._notifyManualBonesDirty();
        }
        
    }
    
    
protected:
    /// The numeric handle of this bone
    ushort mHandle;
    
    /** Bones set as manuallyControlled are not reseted in Skeleton::reset() */
    bool mManuallyControlled;
    
    /** See Node. */
    override Node createChildImpl()
    {
        return mCreator.createBone();
    }
    /** See Node. */
    override Node createChildImpl(string name)
    {
        return mCreator.createBone(name);
    }
    
    /// Pointer back to creator, for child creation (not smart ptr so child does not preserve parent)
    //Skeleton* mCreator;
    Skeleton mCreator;//TODO Reference or pointer?
    
    /// The inversed derived scale of the bone in the binding pose
    Vector3 mBindDerivedInverseScale;
    /// The inversed derived orientation of the bone in the binding pose
    Quaternion mBindDerivedInverseOrientation;
    /// The inversed derived position of the bone in the binding pose
    Vector3 mBindDerivedInversePosition;
}

/** A tagged point on a skeleton, which can be used to attach entities to on specific
 other entities.
 @remarks
 A Skeleton, like a Mesh, is shared between Entity objects and simply updated as required
 when it comes to rendering. However there are times when you want to attach another object
 to an animated entity, and make sure that attachment follows the parent entity's animation
 (for example, a character holding a gun in his / her hand). This class simply identifies
 attachment points on a skeleton which can be used to attach child objects. 
 @par
 The child objects themselves are not physically attached to this class; as it's name suggests
 this class just 'tags' the area. The actual child objects are attached to the Entity using the
 skeleton which has this tag point. Use the Entity::attachMovableObjectToBone method to attach
 the objects, which creates a new TagPoint on demand.
 */
class TagPoint : Bone
{
    
public:
    this(ushort handle, Skeleton creator)
    {
        super(handle, creator);
        mParentEntity = null;
        mChildObject = null;
        mInheritParentEntityOrientation = true;
        mInheritParentEntityScale = true;
    }
    
    ~this() {}
    
    ref Entity getParentEntity()
    {
        return mParentEntity;
    }
    
    ref MovableObject getChildObject()
    {
        return mChildObject;
    }
    
    void setParentEntity(Entity pEntity)
    {
        mParentEntity = pEntity;
    }
    
    void setChildObject(MovableObject pObject)
    {
        mChildObject = pObject;
    }
    
    /** Tells the TagPoint whether it should inherit orientation from it's parent entity.
     @param inherit If true, this TagPoint's orientation will be affected by
     its parent entity's orientation. If false, it will not be affected.
     */
    void setInheritParentEntityOrientation(bool inherit)
    {
        mInheritParentEntityOrientation = inherit;
        needUpdate();
    }
    
    /** Returns true if this TagPoint is affected by orientation applied to the parent entity. 
     */
    bool getInheritParentEntityOrientation()
    {
        return mInheritParentEntityOrientation;
    }
    
    /** Tells the TagPoint whether it should inherit scaling factors from it's parent entity.
     @param inherit If true, this TagPoint's scaling factors will be affected by
     its parent entity's scaling factors. If false, it will not be affected.
     */
    void setInheritParentEntityScale(bool inherit)
    {
        mInheritParentEntityScale = inherit;
        needUpdate();
    }
    
    /** Returns true if this TagPoint is affected by scaling factors applied to the parent entity. 
     */
    bool getInheritParentEntityScale()
    {
        return mInheritParentEntityScale;
    }
    
    /** Gets the transform of parent entity. */
    Matrix4 getParentEntityTransform()
    {
        
        return mParentEntity._getParentNodeFullTransform();
    }
    
    /** Gets the transform of this node just for the skeleton (not entity) */
    ref Matrix4 _getFullLocalTransform()
    {
        return mFullLocalTransform;
    }
    
    /** @copydoc Node::needUpdate */
    override void needUpdate(bool forceParentUpdate = false)
    {
        super.needUpdate(forceParentUpdate);
        
        // We need to tell parent entities node
        if (mParentEntity)
        {
            Node n = mParentEntity.getParentNode();
            if (n)
            {
                n.needUpdate();
            }
            
        }
        
    }
    
    /** Overridden from Node in order to include parent Entity transform. */
    override void updateFromParentImpl()//
    {
        // Call superclass
        super.updateFromParentImpl();
        
        // Save transform for local skeleton
        mFullLocalTransform.makeTransform(
            mDerivedPosition,
            mDerivedScale,
            mDerivedOrientation);
        
        // Include Entity transform
        if (mParentEntity)
        {
            Node entityParentNode = mParentEntity.getParentNode();
            if (entityParentNode)
            {
                // Note: orientation/scale inherits from parent node already take care with
                // Bone::_updateFromParent, don't do that with parent entity transform.
                
                // Combine orientation with that of parent entity
                Quaternion parentOrientation = entityParentNode._getDerivedOrientation();
                if (mInheritParentEntityOrientation)
                {
                    mDerivedOrientation = parentOrientation * mDerivedOrientation;
                }
                
                // Incorporate parent entity scale
                Vector3 parentScale = entityParentNode._getDerivedScale();
                if (mInheritParentEntityScale)
                {
                    mDerivedScale *= parentScale;
                }
                
                // Change position vector based on parent entity's orientation & scale
                mDerivedPosition = parentOrientation * (parentScale * mDerivedPosition);
                
                // Add altered position vector to parent entity
                mDerivedPosition += entityParentNode._getDerivedPosition();
            }
        }
        
        if (mChildObject)
        {
            mChildObject._notifyMoved();
        }
    }
    /** @copydoc Renderable::getLights */
    LightList getLights()
    {
        return mParentEntity.queryLights();
    }
    
    
    
private:
    Entity mParentEntity;
    MovableObject mChildObject;
    //mutable 
    Matrix4 mFullLocalTransform;
    bool mInheritParentEntityOrientation;
    bool mInheritParentEntityScale;
}


/**  */
enum SkeletonAnimationBlendMode {
    /// Animations are applied by calculating a weighted average of all animations
    ANIMBLEND_AVERAGE = 0,
    /// Animations are applied by calculating a weighted cumulative total
    ANIMBLEND_CUMULATIVE = 1
}

static uint OGRE_MAX_NUM_BONES = 256;

//struct LinkedSkeletonAnimationSource;

/** A collection of Bone objects used to animate a skinned mesh.
 @remarks
 Skeletal animation works by having a collection of 'bones' which are 
 actually just joints with a position and orientation, arranged in a tree structure.
 For example, the wrist joint is a child of the elbow joint, which in turn is a
 child of the shoulder joint. Rotating the shoulder automatically moves the elbow
 and wrist as well due to this hierarchy.
 @par
 So how does this animate a mesh? Well every vertex in a mesh is assigned to one or more
 bones which affects it's position when the bone is moved. If a vertex is assigned to 
 more than one bone, then weights must be assigned to determine how much each bone affects
 the vertex (actually a weight of 1.0 is used for single bone assignments). 
 Weighted vertex assignments are especially useful around the joints themselves
 to avoid 'pinching' of the mesh in this region. 
 @par
 Therefore by moving the skeleton using preset animations, we can animate the mesh. The
 advantage of using skeletal animation is that you store less animation data, especially
 as vertex counts increase. In addition, you are able to blend multiple animations together
 (e.g. walking and looking around, running and shooting) and provide smooth transitions
 between animations without incurring as much of an overhead as would be involved if you
 did this on the core vertex data.
 @par
 Skeleton definitions are loaded from datafiles, namely the .skeleton file format. They
 are loaded on demand, especially when referenced by a Mesh.
 */
class Skeleton : Resource, AnimationContainer
{
    //friend class SkeletonInstance;
protected:
    /// Internal constructor for use by SkeletonInstance only
    this(){}
    
public:
    /** Constructor, don't call directly, use SkeletonManager.
     @remarks
     On creation, a Skeleton has a no bones, you should create them and link
     them together appropriately. 
     */
    this(ResourceManager creator,string name, ResourceHandle handle,
         string group, bool isManual = false, ManualResourceLoader loader = null)
    {
        super(creator, name, handle, group, isManual, loader);
        mBlendState = SkeletonAnimationBlendMode.ANIMBLEND_AVERAGE;
        mNextAutoHandle = 0;
        // set animation blending to weighted, not cumulative
        if (createParamDictionary("Skeleton"))
        {
            // no custom params
        }
    }
    
    ~this()
    {
        // have to call this here reather than in Resource destructor
        // since calling virtual methods in base destructors causes crash
        unload(); 
    }
    
    
    /** Creates a brand new Bone owned by this Skeleton. 
     @remarks
     This method creates an unattached new Bone for this skeleton.
     Unless this is to be a root bone (there may be more than one of 
     these), you must attach it to another Bone in the skeleton using addChild for it to be any use.
     For this reason you will likely be better off creating child bones using the
     Bone::createChild method instead, once you have created the root bone. 
     @par
     Note that this method automatically generates a handle for the bone, which you
     can retrieve using Bone::getHandle. If you wish the new Bone to have a specific
     handle, use the alternate form of this method which takes a handle as a parameter,
     although you should note the restrictions.
     */
    Bone createBone()
    {
        // use autohandle
        return createBone(mNextAutoHandle++);
    }
    
    /** Creates a brand new Bone owned by this Skeleton. 
     @remarks
     This method creates an unattached new Bone for this skeleton and assigns it a 
     specific handle. Unless this is to be a root bone (there may be more than one of 
     these), you must attach it to another Bone in the skeleton using addChild for it to be any use. 
     For this reason you will likely be better off creating child bones using the
     Bone::createChild method instead, once you have created a root bone. 
     @param handle The handle to give to this new bone - must be unique within this skeleton. 
     You should also ensure that all bone handles are eventually contiguous (this is to simplify
     their compilation into an indexed array of transformation matrices). For this reason
     it is advised that you use the simpler createBone method which automatically assigns a
     sequential handle starting from 0.
     */
    Bone createBone(ushort handle)
    {
        if (handle >= OGRE_MAX_NUM_BONES)
        {
            throw new InvalidParamsError( "Exceeded the maximum number of bones per skeleton.",
                                         "Skeleton.createBone");
        }
        // Check handle not used
        if (handle < mBoneList.length && mBoneList[handle] !is null)
        {
            throw new DuplicateItemError(
                "A bone with the handle " ~ std.conv.to!string(handle) ~ " already exists",
                "Skeleton.createBone" );
        }
        Bone ret = new Bone(handle, this);
        assert((ret.getName() in mBoneListByName) is null);
        if (mBoneList.length <= handle)
        {
            mBoneList.length = (handle+1);
        }
        mBoneList[handle] = ret;
        mBoneListByName[ret.getName()] = ret;
        return ret;
        
    }
    
    /** Creates a brand new Bone owned by this Skeleton. 
     @remarks
     This method creates an unattached new Bone for this skeleton and assigns it a 
     specific name.Unless this is to be a root bone (there may be more than one of 
     these), you must attach it to another Bone in the skeleton using addChild for it to be any use.
     For this reason you will likely be better off creating child bones using the
     Bone::createChild method instead, once you have created the root bone. 
     @param name The name to give to this new bone - must be unique within this skeleton. 
     Note that the way OGRE looks up bones is via a numeric handle, so if you name a
     Bone this way it will be given an automatic sequential handle. The name is just
     for your convenience, although it is recommended that you only use the handle to 
     retrieve the bone in performance-critical code.
     */
    Bone createBone(string name)
    {
        return createBone(name, mNextAutoHandle++);
    }
    
    /** Creates a brand new Bone owned by this Skeleton. 
     @remarks
     This method creates an unattached new Bone for this skeleton and assigns it a 
     specific name and handle. Unless this is to be a root bone (there may be more than one of 
     these), you must attach it to another Bone in the skeleton using addChild for it to be any use.
     For this reason you will likely be better off creating child bones using the
     Bone::createChild method instead, once you have created the root bone. 
     @param name The name to give to this new bone - must be unique within this skeleton. 
     @param handle The handle to give to this new bone - must be unique within this skeleton. 
     */
    Bone createBone(string name, ushort handle)
    {
        if (handle >= OGRE_MAX_NUM_BONES)
        {
            throw new InvalidParamsError("Exceeded the maximum number of bones per skeleton.",
                                         "Skeleton.createBone");
        }
        // Check handle not used
        if (handle < mBoneList.length && (mBoneList[handle] !is null))
        {
            throw new DuplicateItemError(
                "A bone with the handle " ~ std.conv.to!string(handle) ~ " already exists",
                "Skeleton.createBone" );
        }
        // Check name not used
        if ((name in mBoneListByName) !is null)
        {
            throw new DuplicateItemError(
                "A bone with the name " ~ name ~ " already exists",
                "Skeleton.createBone" );
        }
        Bone ret = new Bone(name, handle, this);
        if (mBoneList.length <= handle)
        {
            mBoneList.length = (handle+1);
        }
        mBoneList[handle] = ret;
        mBoneListByName[name] = ret;
        return ret;
    }
    
    /** Returns the number of bones in this skeleton. */
    ushort getNumBones()
    {
        return cast(ushort)mBoneList.length;
    }
    
    /** Gets the root bone of the skeleton: deprecated in favour of getRootBoneIterator. 
     @remarks
     The system derives the root bone the first time you ask for it. The root bone is the
     only bone in the skeleton which has no parent. The system locates it by taking the
     first bone in the list and going up the bone tree until there are no more parents,
     and saves this top bone as the root. If you are building the skeleton manually using
     createBone then you must ensure there is only one bone which is not a child of 
     another bone, otherwise your skeleton will not work properly. If you use createBone
     only once, and then use Bone::createChild from then on, then inherently the first
     bone you create will by default be the root.
     */
    ref Bone getRootBone()
    {
        if (mRootBones.empty())
        {
            deriveRootBone();
        }
        
        return mRootBones[0];
    }
    
    //typedef vector<Bone *>::type BoneList;
    //typedef VectorIterator<BoneList> BoneIterator;
    alias Bone[] BoneList;
    
    /// Get an iterator over the root bones in the skeleton, ie those with no parents
    //BoneIterator getRootBoneIterator();
    /// Get an iterator over all the bones in the skeleton
    //BoneIterator getBoneIterator();

    ref BoneList getRootBones()
    {
        return mRootBones;
    }
    
    /** Gets a bone by it's handle. */
    ref Bone getBone(ushort handle)
    {
        assert(handle < mBoneList.length , "Index out of bounds");
        return mBoneList[handle];
    }
    
    /** Gets a bone by it's name. */
    ref Bone getBone(string name)
    {
        auto i = name in mBoneListByName;
        
        if (i is null)
        {
            throw new ItemNotFoundError( "Bone named '" ~ name ~ "' not found.", 
                                        "Skeleton.getBone");
        }
        
        return *i;
        
    }
    
    /** Returns whether this skeleton contains the named bone. */
    bool hasBone(string name)
    {   
        return (name in mBoneListByName) !is null;
    }
    
    /** Sets the current position / orientation to be the 'binding pose' i.e. the layout in which 
     bones were originally bound to a mesh.
     */
    void setBindingPose()
    {
        // Update the derived transforms
        _updateTransforms();
        
        foreach (i; mBoneList)
        {            
            i.setBindingPose();
        }
    }
    
    /** Resets the position and orientation of all bones in this skeleton to their original binding position.
     @remarks
     A skeleton is bound to a mesh in a binding pose. Bone positions are then modified from this
     position during animation. This method returns all the bones to their original position and
     orientation.
     @param resetManualBones If set to true, causes the state of manual bones to be reset
     too, which is normally not done to allow the manual state to persist even 
     when keyframe animation is applied.
     */
    void reset(bool resetManualBones = false)
    {
        foreach (i; mBoneList)
        {
            if(!i.isManuallyControlled() || resetManualBones)
                i.reset();
        }
    }
    
    /** Creates a new Animation object for animating this skeleton. 
     @param name The name of this animation
     @param length The length of the animation in seconds
     */
    ref Animation createAnimation(string name, Real length)
    {
        // Check name not used
        if ((name in mAnimationsList) !is null)
        {
            throw new DuplicateItemError(
                "An animation with the name " ~ name ~ " already exists",
                "Skeleton.createAnimation");
        }
        
        Animation ret = new Animation(name, length);
        ret._notifyContainer(this);
        
        // Add to list
        mAnimationsList[name] = ret;
        
        return mAnimationsList[name]; //ret;
        
    }
    
    /** Returns the named Animation object. 
     @remarks
     Will pick up animations in linked skeletons 
     (@see addLinkedSkeletonAnimationSource). 
     @param name The name of the animation
     @param linker Optional pointer to a pointer to the linked skeleton animation
     where this is coming from.
     */
    Animation getAnimation(string name, 
                           LinkedSkeletonAnimationSource** linker)
    {
        Animation ret = _getAnimationImpl(name, linker);
        if (!ret)
        {
            throw new ItemNotFoundError("No animation entry found named " ~ name, 
                                        "Skeleton.getAnimation");
        }
        
        return ret;
    }
    
    /** Returns the named Animation object.
     @remarks
     Will pick up animations in linked skeletons 
     (@see addLinkedSkeletonAnimationSource). 
     @param name The name of the animation
     */
    Animation getAnimation(string name)
    {
        return getAnimation(name, null);
    }
    
    /// Internal accessor for animations (returns null if animation does not exist)
    Animation _getAnimationImpl(string name, 
                                LinkedSkeletonAnimationSource** linker = null)
    {
        Animation ret;
        auto i = name in mAnimationsList;
        
        if (i is null)
        {
            foreach (it; mLinkedSkeletonAnimSourceList)
            {
                if (!it.pSkeleton.isNull())
                {
                    ret = it.pSkeleton.getAs()._getAnimationImpl(name);
                    if (ret && linker)
                    {
                        *linker = &(it);
                    }
                    
                }
            }
            
        }
        else
        {
            if (linker)
                *linker = null;
            ret = *i;
        }
        
        return ret;
        
    }
    
    
    /** Returns whether this skeleton contains the named animation. */
    bool hasAnimation(string name)
    {
        return _getAnimationImpl(name) !is null;
    }
    
    /** Removes an Animation from this skeleton. */
    void removeAnimation(string name)
    {
        auto i = name in mAnimationsList;
        
        if (i is null)
        {
            throw new ItemNotFoundError("No animation entry found named " ~ name, 
                                        "Skeleton.getAnimation");
        }
        
        destroy(*i);
        
        mAnimationsList.remove(name);
        
    }
    
    /** Changes the state of the skeleton to reflect the application of the passed in collection of animations.
     @remarks
     Animating a skeleton involves both interpolating between keyframes of a specific animation,
     and blending between the animations themselves. Calling this method sets the state of
     the skeleton so that it reflects the combination of all the passed in animations, at the
     time index specified for each, using the weights specified. Note that the weights between 
     animations do not have to sum to 1.0, because some animations may affect only subsets
     of the skeleton. If the weights exceed 1.0 for the same area of the skeleton, the 
     movement will just be exaggerated.
     */
    void setAnimationState(AnimationStateSet animSet)
    {
        /* 
         Algorithm:
         1. Reset all bone positions
         2. Iterate per AnimationState, if enabled get Animation and call Animation::apply
         */
        
        // Reset bones
        reset();
        
        Real weightFactor = 1.0f;
        if (mBlendState == SkeletonAnimationBlendMode.ANIMBLEND_AVERAGE)
        {
            // Derive total weights so we can rebalance if > 1.0f
            Real totalWeights = 0.0f;
            //ConstEnabledAnimationStateIterator stateIt = 
            //    animSet.getEnabledAnimationStateIterator();
            auto stateIt = animSet.getEnabledAnimationStates();
            foreach (animState; stateIt)
            {
                //AnimationState* animState = stateIt.getNext();
                // Make sure we have an anim to match implementation
                LinkedSkeletonAnimationSource* linked = null;
                if (_getAnimationImpl(animState.getAnimationName(), &linked))
                {
                    totalWeights += animState.getWeight();
                }
            }
            
            // Allow < 1.0f, allows fade out of all anims if required 
            if (totalWeights > 1.0f)
            {
                weightFactor = 1.0f / totalWeights;
            }
        }
        
        // Per enabled animation state
        //ConstEnabledAnimationStateIterator stateIt = 
        //    animSet.getEnabledAnimationStateIterator();
        auto stateIt = animSet.getEnabledAnimationStates();
        //while (stateIt.hasMoreElements())
        foreach(animState; stateIt)
        {
            //AnimationState* animState = stateIt.getNext();
            LinkedSkeletonAnimationSource* linked = null;
            Animation anim = _getAnimationImpl(animState.getAnimationName(), &linked);
            // tolerate state entries for animations we're not aware of
            if (anim)
            {
                if(animState.hasBlendMask())
                {
                    anim.apply(this, animState.getTimePosition(), animState.getWeight() * weightFactor,
                               animState.getBlendMask(), linked ? linked.scale : 1.0f);
                }
                else
                {
                    anim.apply(this, animState.getTimePosition(), 
                               animState.getWeight() * weightFactor, linked ? linked.scale : 1.0f);
                }
            }
        }
        
        
    }
    
    
    /** Initialise an animation set suitable for use with this skeleton. 
     @remarks
     Only recommended for use inside the engine, not by applications.
     */
    void _initAnimationState(ref AnimationStateSet animSet)
    {
        animSet.removeAllAnimationStates();
        
        foreach (k, anim; mAnimationsList)
        {
            // Create animation at time index 0, default params mean this has weight 1 and is disabled
            string animName = anim.getName();
            animSet.createAnimationState(animName, 0.0, anim.getLength());
        }
        
        // Also iterate over linked animation
        foreach (li; mLinkedSkeletonAnimSourceList)
        {
            if (!li.pSkeleton.isNull())
            {
                li.pSkeleton.getAs()._refreshAnimationState(animSet);
            }
        }
        
    }
    
    /** Refresh an animation set suitable for use with this skeleton. 
     @remarks
     Only recommended for use inside the engine, not by applications.
     */
    void _refreshAnimationState(ref AnimationStateSet animSet)
    {
        // Merge in any new animations
        foreach (k,anim; mAnimationsList)
        {
            // Create animation at time index 0, default params mean this has weight 1 and is disabled
            string animName = anim.getName();
            if (!animSet.hasAnimationState(animName))
            {
                animSet.createAnimationState(animName, 0.0, anim.getLength());
            }
            else
            {
                // Update length incase changed
                AnimationState animState = animSet.getAnimationState(animName);
                animState.setLength(anim.getLength());
                animState.setTimePosition(std.algorithm.min(anim.getLength(), animState.getTimePosition()));
            }
        }
        // Also iterate over linked animation
        foreach (li; mLinkedSkeletonAnimSourceList)
        {
            if (!li.pSkeleton.isNull())
            {
                li.pSkeleton.getAs()._refreshAnimationState(animSet);
            }
        }
    }
    
    /** Populates the passed in array with the bone matrices based on the current position.
     @remarks
     Internal use only. The array pointed to by the passed in pointer must
     be at least as large as the number of bones.
     Assumes animation has already been updated.
     */
    void _getBoneMatrices(ref Matrix4[] pMatrices)
    {
        // Update derived transforms
        _updateTransforms();
        
        /*
         Calculating the bone matrices
         -----------------------------
         Now that we have the derived scaling factors, orientations & positions in the
         Bone nodes, we have to compute the Matrix4 to apply to the vertices of a mesh.
         Because any modification of a vertex has to be relative to the bone, we must
         first reverse transform by the Bone's original derived position/orientation/scale,
         then transform by the new derived position/orientation/scale.
         Also note we combine scale as equivalent axes, no shearing.
         */
        
        foreach (pBone; mBoneList)
        {
            Matrix4 mat;
            pBone._getOffsetTransform(mat);
            pMatrices ~= mat;
        }
        
    }
    
    /** Gets the number of animations on this skeleton. */
    ushort getNumAnimations()
    {
        return cast(ushort)mAnimationsList.length;
    }
    
    /** Gets a single animation by index. 
     @remarks
     Will NOT pick up animations in linked skeletons 
     (@see addLinkedSkeletonAnimationSource).
     @todo Assoc. array is unordered!
     */
    Animation getAnimation(ushort index)
    {
        // If you hit this assert, then the index is out of bounds.
        assert( index < mAnimationsList.length );
        //FIXME get from mAnimationsList by index
        return mAnimationsList[mAnimationsList.keysAA[index]];
    }
    
    
    /** Gets the animation blending mode which this skeleton will use. */
    SkeletonAnimationBlendMode getBlendMode()
    {
        return mBlendState;
    }
    /** Sets the animation blending mode this skeleton will use. */
    void setBlendMode(SkeletonAnimationBlendMode state)
    {
        mBlendState = state;
    }
    
    /// Updates all the derived transforms in the skeleton
    void _updateTransforms()
    {
        foreach (i; mRootBones)
        {
            i._update(true, false);
        }
        mManualBonesDirty = false;
    }
    
    /** Optimise all of this skeleton's animations.
     @see Animation::optimise
     @param
     preservingIdentityNodeTracks If true, don't destroy identity node tracks.
     */
    void optimiseAllAnimations(bool preservingIdentityNodeTracks = false)
    {
        if (!preservingIdentityNodeTracks)
        {
            Animation.TrackHandleList tracksToDestroy;
            
            // Assume all node tracks are identity
            ushort numBones = getNumBones();
            for (ushort h = 0; h < numBones; ++h)
            {
                tracksToDestroy.insert(h);
            }
            
            // Collect identity node tracks for all animations
            foreach (k, a; mAnimationsList)
            {
                a._collectIdentityNodeTracks(tracksToDestroy);
            }
            
            // Destroy identity node tracks
            foreach (k,a; mAnimationsList)
            {
                a._destroyNodeTracks(tracksToDestroy);
            }
        }
        
        foreach (k,a; mAnimationsList)
        {
            // Don't discard identity node tracks here
            a.optimise(false);
        }
    }
    
    /** Allows you to use the animations from another Skeleton object to animate
     this skeleton.
     @remarks
     If you have skeletons of identical structure (that means identically
     named bones with identical handles, and with the same hierarchy), but
     slightly different proportions or binding poses, you can re-use animations
     from one in the other. Because animations are actually stored as
     changes to bones from their bind positions, it's possible to use the
     same animation data for different skeletons, provided the skeletal
     structure matches and the 'deltas' stored in the keyframes apply
     equally well to the other skeletons bind position (so they must be
     roughly similar, but don't have to be identical). You can use the 
     'scale' option to adjust the translation and scale keyframes where
     there are large differences in size between the skeletons.
     @note
     This method takes a skeleton name, rather than a more specific 
     animation name, for two reasons; firstly it allows some validation 
     of compatibility of skeletal structure, and secondly skeletons are
     the unit of loading. Linking a skeleton to another in this way means
     that the linkee will be prevented from being destroyed until the 
     linker is destroyed.

     You cannot set up cyclic relationships, e.g. SkeletonA uses SkeletonB's
     animations, and SkeletonB uses SkeletonA's animations. This is because
     it would set up a circular dependency which would prevent proper 
     unloading - make one of the skeletons the 'master' in this case.
     @param skelName Name of the skeleton to link animations from. This 
     skeleton will be loaded immediately if this skeleton is already 
     loaded, otherwise it will be loaded when this skeleton is.
     @param scale A scale factor to apply to translation and scaling elements
     of the keyframes in the other skeleton when applying the animations
     to this one. Compensates for skeleton size differences.
     */
    void addLinkedSkeletonAnimationSource(string skelName, 
                                          Real scale = 1.0f)
    {
        // Check not already linked
        foreach (i; mLinkedSkeletonAnimSourceList)
        {
            if (skelName == i.skeletonName)
                return; // don't bother
        }
        
        if (isLoaded())
        {
            // Load immediately
            SharedPtr!Skeleton skelPtr = SkeletonManager.getSingleton().load(skelName, mGroup);
            mLinkedSkeletonAnimSourceList.insert(
                LinkedSkeletonAnimationSource(skelName, scale, skelPtr));
            
        }
        else
        {
            // Load later
            mLinkedSkeletonAnimSourceList.insert(
                LinkedSkeletonAnimationSource(skelName, scale));
        }
        
    }
    /// Remove all links to other skeletons for the purposes of sharing animation
    void removeAllLinkedSkeletonAnimationSources()
    {
        mLinkedSkeletonAnimSourceList.clear();
    }
    
    //typedef vector<LinkedSkeletonAnimationSource>::type 
    //    LinkedSkeletonAnimSourceList;
    //typedef ConstVectorIterator<LinkedSkeletonAnimSourceList> 
    //    LinkedSkeletonAnimSourceIterator;
    
    alias LinkedSkeletonAnimationSource[] LinkedSkeletonAnimSourceList;
    
    /// Get an iterator over the linked skeletons used as animation sources
    //LinkedSkeletonAnimSourceIterator 
    //    getLinkedSkeletonAnimationSourceIterator();

    ref LinkedSkeletonAnimSourceList getLinkedSkeletonAnimSourceList()
    {
        return mLinkedSkeletonAnimSourceList;
    }

    /// Internal method for marking the manual bones as dirty
    void _notifyManualBonesDirty()
    {
        mManualBonesDirty = true;
    }
    /// Internal method for notifying that a bone is manual
    void _notifyManualBoneStateChange(ref Bone bone)
    {
        if (bone.isManuallyControlled())
            mManualBones.insert(bone);
        else
            mManualBones.removeFromArray(bone);
    }
    
    /// Have manual bones been modified since the skeleton was last updated?
    bool getManualBonesDirty(){ return mManualBonesDirty; }
    /// Are there any manually controlled bones?
    bool hasManualBones(){ return !mManualBones.empty(); }
    
    /// Map to translate bone handle from one skeleton to another skeleton.
    //typedef vector<ushort>::type BoneHandleMap;
    alias ushort[] BoneHandleMap;
    
    /** Merge animations from another Skeleton object into this skeleton.
     @remarks
     This function allow merge two structures compatible skeletons. The
     'compatible' here means identically bones will have same hierarchy,
     but skeletons are not necessary to have same number of bones (if
     number bones of source skeleton's more than this skeleton, they will
     copied as is, except that duplicate names are unallowed; and in the
     case of bones missing in source skeleton, nothing happen for those
     bones).
     @par
     There are also unnecessary to have same binding poses, this function
     will adjust keyframes of the source skeleton to match this skeleton
     automatically.
     @par
     It's useful for exporting skeleton animations separately. i.e. export
     mesh and 'master' skeleton at the same time, and then other animations
     will export separately (even if used completely difference binding
     pose), finally, merge separately exported animations into 'master'
     skeleton.
     @param
     source Pointer to source skeleton. It'll keep unmodified.
     @param
     boneHandleMap A map to translate identically bone's handle from source
     skeleton to this skeleton. If mapped bone handle doesn't exists in this
     skeleton, it'll created. You can populate bone handle map manually, or
     use predefined functions build bone handle map for you. (@see 
     _buildMapBoneByHandle, _buildMapBoneByName)
     @param
     animations A list name of animations to merge, if empty, all animations
     of source skeleton are used to merge. Note that the animation names
     must not presented in this skeleton, and will NOT pick up animations
     in linked skeletons (@see addLinkedSkeletonAnimationSource).
     */
    void _mergeSkeletonAnimations(Skeleton src,
                                  ref BoneHandleMap boneHandleMap,
                                  ref StringVector animations /+= StringVector+/)
    {
        ushort numSrcBones = src.getNumBones();
        ushort numDstBones = this.getNumBones();
        
        if (boneHandleMap.length != numSrcBones)
        {
            throw new InvalidParamsError(
                "Number of bones in the bone handle map must equal to "
                "number of bones in the source skeleton.",
                "Skeleton._mergeSkeletonAnimations");
        }
        
        bool existsMissingBone = false;
        
        // Check source skeleton structures compatible with ourself (that means
        // identically bones with identical handles, and with same hierarchy, but
        // not necessary to have same number of bones and bone names).
        for (ushort handle = 0; handle < numSrcBones; ++handle)
        {
            Bone srcBone = src.getBone(handle);
            ushort dstHandle = boneHandleMap[handle];
            
            // Does it exists in target skeleton?
            if (dstHandle < numDstBones)
            {
                Bone destBone = this.getBone(dstHandle);
                
                // Check both bones have identical parent, or both are root bone.
                Bone srcParent = cast(Bone)(srcBone.getParent());
                Bone destParent = cast(Bone)(destBone.getParent());
                if ((srcParent || destParent) &&
                    (!srcParent || !destParent ||
                 boneHandleMap[srcParent.getHandle()] != destParent.getHandle()))
                {
                    throw new InvalidParamsError(
                        "Source skeleton incompatible with this skeleton: "
                        "difference hierarchy between bone '" ~ srcBone.getName() ~
                        "' and '" ~ destBone.getName() ~ "'.",
                        "Skeleton._mergeSkeletonAnimations");
                }
            }
            else
            {
                existsMissingBone = true;
            }
        }
        
        // Clone bones if need
        if (existsMissingBone)
        {
            // Create missing bones
            for (ushort handle = 0; handle < numSrcBones; ++handle)
            {
                Bone srcBone = src.getBone(handle);
                ushort dstHandle = boneHandleMap[handle];
                
                // The bone is missing in target skeleton?
                if (dstHandle >= numDstBones)
                {
                    Bone dstBone = this.createBone(srcBone.getName(), dstHandle);
                    // Sets initial transform
                    dstBone.setPosition(srcBone.getInitialPosition());
                    dstBone.setOrientation(srcBone.getInitialOrientation());
                    dstBone.setScale(srcBone.getInitialScale());
                    dstBone.setInitialState();
                }
            }
            
            // Link new bones to parent
            for (ushort handle = 0; handle < numSrcBones; ++handle)
            {
                Bone srcBone = src.getBone(handle);
                ushort dstHandle = boneHandleMap[handle];
                
                // Is new bone?
                if (dstHandle >= numDstBones)
                {
                    Bone srcParent = cast(Bone)(srcBone.getParent());
                    if (srcParent)
                    {
                        Bone destParent = this.getBone(boneHandleMap[srcParent.getHandle()]);
                        Bone dstBone = this.getBone(dstHandle);
                        destParent.addChild(dstBone);
                    }
                }
            }
            
            // Derive root bones in case it was changed
            this.deriveRootBone();
            
            // Reset binding pose for new bones
            this.reset(true);
            this.setBindingPose();
        }
        
        //
        // We need to adapt animations from source to target skeleton, but since source
        // and target skeleton bones bind transform might difference, so we need to alter
        // keyframes in source to suit to target skeleton.
        //
        // For any given animation time, formula:
        //
        //      LocalTransform = BindTransform * KeyFrame;
        //      DerivedTransform = ParentDerivedTransform * LocalTransform
        //
        // And all derived transforms should be keep identically after adapt to
        // target skeleton, Then:
        //
        //      DestDerivedTransform == SrcDerivedTransform
        //      DestParentDerivedTransform == SrcParentDerivedTransform
        // ==>
        //      DestLocalTransform = SrcLocalTransform
        // ==>
        //      DestBindTransform * DestKeyFrame = SrcBindTransform * SrcKeyFrame
        // ==>
        //      DestKeyFrame = inverse(DestBindTransform) * SrcBindTransform * SrcKeyFrame
        //
        // We define (inverse(DestBindTransform) * SrcBindTransform) as 'delta-transform' here.
        //
        
        // Calculate delta-transforms for all source bones.
        //vector<DeltaTransform>::type deltaTransforms(numSrcBones);
        DeltaTransform[] deltaTransforms;//(numSrcBones);
        foreach (ushort handle; 0..numSrcBones)
        {
            Bone srcBone = src.getBone(handle);
            DeltaTransform deltaTransform = deltaTransforms[handle];
            ushort dstHandle = boneHandleMap[handle];
            
            if (dstHandle < numDstBones)
            {
                // Common bone, calculate delta-transform
                
                Bone dstBone = this.getBone(dstHandle);
                
                deltaTransform.translate = srcBone.getInitialPosition() - dstBone.getInitialPosition();
                deltaTransform.rotate = dstBone.getInitialOrientation().Inverse() * srcBone.getInitialOrientation();
                deltaTransform.scale = srcBone.getInitialScale() / dstBone.getInitialScale();
                
                // Check whether or not delta-transform is identity
                Real tolerance = 1e-3f;
                Vector3 axis;
                Radian angle;
                deltaTransform.rotate.ToAngleAxis(angle, axis);
                deltaTransform.isIdentity =
                    deltaTransform.translate.positionEquals(Vector3.ZERO, tolerance) &&
                        deltaTransform.scale.positionEquals(Vector3.UNIT_SCALE, tolerance) &&
                        Math.RealEqual(angle.valueRadians(), 0.0f, tolerance);
            }
            else
            {
                // New bone, the delta-transform is identity
                
                deltaTransform.translate = Vector3.ZERO;
                deltaTransform.rotate = Quaternion.IDENTITY;
                deltaTransform.scale = Vector3.UNIT_SCALE;
                deltaTransform.isIdentity = true;
            }
        }
        
        // Now copy animations
        
        ushort numAnimations;
        if (animations.empty())
            numAnimations = src.getNumAnimations();
        else
            numAnimations = cast(ushort)(animations.length);
        for (ushort i = 0; i < numAnimations; ++i)
        {
            Animation srcAnimation;
            if (animations.empty())
            {
                // Get animation of source skeleton by the given index
                srcAnimation = src.getAnimation(i);
            }
            else
            {
                // Get animation of source skeleton by the given name
                LinkedSkeletonAnimationSource* linker;
                srcAnimation = src._getAnimationImpl(animations[i], &linker);
                if (!srcAnimation || linker)
                {
                    throw new ItemNotFoundError(
                        "No animation entry found named " ~ animations[i],
                        "Skeleton._mergeSkeletonAnimations");
                }
            }
            
            // Create target animation
            Animation dstAnimation = this.createAnimation(srcAnimation.getName(), srcAnimation.getLength());
            
            // Copy interpolation modes
            dstAnimation.setInterpolationMode(srcAnimation.getInterpolationMode());
            dstAnimation.setRotationInterpolationMode(srcAnimation.getRotationInterpolationMode());
            
            // Copy track for each bone
            foreach (ushort handle; 0..numSrcBones)
            {
                DeltaTransform deltaTransform = deltaTransforms[handle];
                ushort dstHandle = boneHandleMap[handle];
                
                if (srcAnimation.hasNodeTrack(handle))
                {
                    // Clone track from source animation
                    
                    NodeAnimationTrack srcTrack = srcAnimation.getNodeTrack(handle);
                    NodeAnimationTrack dstTrack = dstAnimation.createNodeTrack(dstHandle, this.getBone(dstHandle));
                    dstTrack.setUseShortestRotationPath(srcTrack.getUseShortestRotationPath());
                    
                    ushort numKeyFrames = srcTrack.getNumKeyFrames();
                    for (ushort k = 0; k < numKeyFrames; ++k)
                    {
                        TransformKeyFrame srcKeyFrame = srcTrack.getNodeKeyFrame(k);
                        TransformKeyFrame dstKeyFrame = dstTrack.createNodeKeyFrame(srcKeyFrame.getTime());
                        
                        // Adjust keyframes to match target binding pose
                        if (deltaTransform.isIdentity)
                        {
                            dstKeyFrame.setTranslate(srcKeyFrame.getTranslate());
                            dstKeyFrame.setRotation(srcKeyFrame.getRotation());
                            dstKeyFrame.setScale(srcKeyFrame.getScale());
                        }
                        else
                        {
                            dstKeyFrame.setTranslate(deltaTransform.translate + srcKeyFrame.getTranslate());
                            dstKeyFrame.setRotation(deltaTransform.rotate * srcKeyFrame.getRotation());
                            dstKeyFrame.setScale(deltaTransform.scale * srcKeyFrame.getScale());
                        }
                    }
                }
                else if (!deltaTransform.isIdentity)
                {
                    // Create 'static' track for this bone
                    
                    NodeAnimationTrack dstTrack = dstAnimation.createNodeTrack(dstHandle, this.getBone(dstHandle));
                    TransformKeyFrame dstKeyFrame;
                    
                    dstKeyFrame = dstTrack.createNodeKeyFrame(0);
                    dstKeyFrame.setTranslate(deltaTransform.translate);
                    dstKeyFrame.setRotation(deltaTransform.rotate);
                    dstKeyFrame.setScale(deltaTransform.scale);
                    
                    dstKeyFrame = dstTrack.createNodeKeyFrame(dstAnimation.getLength());
                    dstKeyFrame.setTranslate(deltaTransform.translate);
                    dstKeyFrame.setRotation(deltaTransform.rotate);
                    dstKeyFrame.setScale(deltaTransform.scale);
                }
            }
        }
    }
    /** Build the bone handle map to use with Skeleton::_mergeSkeletonAnimations.
     @remarks
     Identically bones are determine by handle.
     */
    void _buildMapBoneByHandle(Skeleton source,
                               ref BoneHandleMap boneHandleMap)
    {
        ushort numSrcBones = source.getNumBones();
        //boneHandleMap.resize(numSrcBones);
        
        foreach (ushort handle; 0..numSrcBones)
        {
            boneHandleMap[handle] = handle;
        }
    }
    
    /** Build the bone handle map to use with Skeleton::_mergeSkeletonAnimations.
     @remarks
     Identically bones are determine by name.
     */
    void _buildMapBoneByName(Skeleton src,
                             ref BoneHandleMap boneHandleMap)
    {
        ushort numSrcBones = src.getNumBones();
        //boneHandleMap.resize(numSrcBones);
        
        ushort newBoneHandle = this.getNumBones();
        foreach (ushort handle;0..numSrcBones)
        {
            Bone srcBone = src.getBone(handle);
            auto i = srcBone.getName() in this.mBoneListByName;
            if (i is null)
                boneHandleMap[handle] = newBoneHandle++;
            else
                boneHandleMap[handle] = (*i).getHandle();
        }
    }


    /// For SkeletonInstance, because it is in a separate file, 
    /// so no friendly access to protected members.
    ushort _getNextAutoHandle()
    {
        return mNextAutoHandle;
    }
        
protected:
    SkeletonAnimationBlendMode mBlendState = SkeletonAnimationBlendMode.ANIMBLEND_AVERAGE;
    /// Storage of bones, indexed by bone handle
    BoneList mBoneList;
    /// Lookup by bone name
    //typedef map<string, ref Bone>::type BoneListByName;
    alias Bone[string] BoneListByName;
    BoneListByName mBoneListByName;
    
    
    /// Pointer to root bones (can now have multiple roots)
    //mutable 
    BoneList mRootBones;
    /// Bone automatic handles
    ushort mNextAutoHandle;
    //typedef set<ref Bone>::type BoneSet;
    alias Bone[] BoneSet;
    /// Manual bones
    BoneSet mManualBones;
    /// Manual bones dirty?
    bool mManualBonesDirty;
    
    
    /// Storage of animations, lookup by name
    //typedef map<string, ref Animation>::type AnimationList;
    alias Animation[string] AnimationList;
    AnimationList mAnimationsList;
    
    /// List of references to other skeletons to use animations from 
    //mutable 
    LinkedSkeletonAnimSourceList mLinkedSkeletonAnimSourceList;
    
    /** Internal method which parses the bones to derive the root bone. 
     @remarks
     Must bebecause called in getRootBone but mRootBone is mutable
     since lazy-updated.
     */
    void deriveRootBone()
    {
        // Start at the first bone and work up
        if (mBoneList.empty())
        {
            throw new InvalidParamsError("Cannot derive root bone as this "
                                         "skeleton has no bones!", "Skeleton.deriveRootBone");
        }
        
        mRootBones.clear();
        
        foreach (currentBone; mBoneList)
        {
            if (currentBone.getParent() is null)
            {
                // This is a root
                mRootBones.insert(currentBone);
            }
        }
    }
    
    /// Debugging method
    void _dumpContents(string filename)
    {
        File of;
        
        Quaternion q;
        Radian angle;
        Vector3 axis;
        of.open(filename, "w");
        
        of.writefln("-= Debug output of skeleton %s =-\n", mName);
        of.writefln("== Bones ==");
        of.writefln("Number of bones: %d", mBoneList.length);
        
        foreach (bone; mBoneList)
        {
            
            of.writefln("-- Bone %d --", bone.getHandle());
            of.writefln("Position: %d", bone.getPosition());
            q = bone.getOrientation();
            of.writef("Rotation: %s", q); //should call toString()
            q.ToAngleAxis(angle, axis);
            of.writefln(" = %f radians around axis %s \n",  angle.valueRadians(), axis);
        }
        
        of.writeln("== Animations ==");
        of.writefln("Number of animations: %d", mAnimationsList.length);
        
        foreach (k, anim; mAnimationsList)
        {
            
            of.writefln("-- Animation '%s' (length %d) --", anim.getName(), anim.getLength());
            of.writefln("Number of tracks: %d", anim.getNumNodeTracks());
            
            foreach (ushort ti; 0..anim.getNumNodeTracks())
            {
                NodeAnimationTrack track = anim.getNodeTrack(ti);
                of.writefln("  -- AnimationTrack %d --", ti);
                of.writefln("  Affects bone: %d", (cast(Bone)track.getAssociatedNode()).getHandle() );
                of.writefln("  Number of keyframes: %d", track.getNumKeyFrames() );
                
                foreach (ushort ki; 0..track.getNumKeyFrames())
                {
                    TransformKeyFrame key = track.getNodeKeyFrame(ki);
                    of.writefln("    -- KeyFrame %d --", ki);
                    of.writefln("    Time index: %d", key.getTime() );
                    of.writefln("    Translation: %s", key.getTranslate() );
                    q = key.getRotation();
                    of.writef("    Rotation: %s", q);
                    q.ToAngleAxis(angle, axis);
                    of.writefln(" = %f radians around axis %s", angle.valueRadians(), axis);
                }
                
            }
            
        }
        
    }
    
    /** @copydoc Resource::loadImpl
     */
    override void loadImpl()
    {
        SkeletonSerializer serializer = new SkeletonSerializer;
        LogManager.getSingleton().stream()
            << "Skeleton: Loading " << mName;
        
        auto stream = ResourceGroupManager.getSingleton().openResource(
            mName, mGroup, true, this);
        
        serializer.importSkeleton(stream, this);
        
        // Load any linked skeletons
        foreach (ref i; mLinkedSkeletonAnimSourceList)
        {
            i.pSkeleton = SkeletonManager.getSingleton().load(
                i.skeletonName, mGroup);
        }
        
        
    }
    
    /** @copydoc Resource::unloadImpl
     */
    override void unloadImpl()
    {
        // destroy bones
        foreach (i; mBoneList)
        {
            destroy(i);
        }
        mBoneList.clear();
        mBoneListByName.clear();
        mRootBones.clear();
        mManualBones.clear();
        mManualBonesDirty = false;
        
        // Destroy animations
        foreach (k,v; mAnimationsList)
        {
            destroy(v);
        }
        mAnimationsList.clear();
        
        // Remove all linked skeletons
        mLinkedSkeletonAnimSourceList.clear();
    }
    
public:
    /// @copydoc Resource::calculateSize
    override size_t calculateSize() //const
    {
        size_t memSize = 0;
        memSize += SkeletonAnimationBlendMode.sizeof;
        memSize += mBoneList.length * Bone.sizeof;
        memSize += mRootBones.length * Bone.sizeof;
        memSize += mBoneListByName.length * (string.sizeof + Bone.sizeof);
        memSize += mAnimationsList.length * (string.sizeof + Animation.sizeof);
        memSize += mManualBones.length * Bone*.sizeof;
        memSize += mLinkedSkeletonAnimSourceList.length * LinkedSkeletonAnimationSource.sizeof;
        memSize += bool.sizeof;
        
        return memSize;
    }
    
}

//alias SharedPtr!Skeleton SkeletonPtr;

/// Link to another skeleton to share animations
struct LinkedSkeletonAnimationSource
{
    string skeletonName;
    SharedPtr!Skeleton pSkeleton;
    Real scale;
    this(string skelName, Real scl)
    {
        skeletonName = skelName;
        scale = scl;
    }
    this(string skelName, Real scl, 
         ref SharedPtr!Skeleton skelPtr)
    
    {
        skeletonName = skelName;
        pSkeleton = skelPtr;
        scale = scl;
    }
}

/** @} */
/** @} */


unittest
{
    auto set   = new AnimationStateSet();
    auto state = new AnimationState("myName", set, 0f, 10f, 0.5f, true);
    state.addTime(1.24f);
    state.getTimePosition();
}
