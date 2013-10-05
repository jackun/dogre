module ogre.scene.skeletoninstance;

//import std.container;
import std.algorithm;
import ogre.animation.animations;
import ogre.compat;
import ogre.math.quaternion;
import ogre.math.vector;
import ogre.resources.resource;

/** A SkeletonInstance is a single instance of a Skeleton used by a world object.
    @remarks
        The difference between a Skeleton and a SkeletonInstance is that the
        Skeleton is the 'master' version much like Mesh is a 'master' version of
        Entity. Many SkeletonInstance objects can be based on a single Skeleton, 
 and are copies of it when created. Any changes made to this are not
        reflected in the master copy. The exception is animations; these are
        shared on the Skeleton itself and may not be modified here.
    */
class SkeletonInstance : Skeleton
{
public:
    /** Constructor, don't call directly, this will be created automatically
        when you create an Entity based on a skeletally animated Mesh.
        */
    this(SharedPtr!Skeleton masterCopy)
    {
        super();
        mSkeleton = masterCopy;
        mNextTagPointAutoHandle = 0;
    }
    ~this()
    {
        // have to call this here rather than in Resource destructor
        // since calling methods in base destructors causes crash
        // ...and calling it in Skeleton destructor does not unload
        // SkeletonInstance since it has seized to be by then.
        unload();
    }
    
    /** Gets the number of animations on this skeleton. */
    override ushort getNumAnimations()
    {
        return mSkeleton.getAs().getNumAnimations();
    }
    
    /** Gets a single animation by index. */
    override Animation getAnimation(ushort index)
    {
        return mSkeleton.getAs().getAnimation(index);
    }
    /// Internal accessor for animations (returns null if animation does not exist)
    override Animation _getAnimationImpl(string name, 
                                   LinkedSkeletonAnimationSource** linker = null)
    {
        return mSkeleton.getAs()._getAnimationImpl(name, linker);
    }
    
    /** Creates a new Animation object for animating this skeleton. 
        @remarks
            This method updates the reference skeleton, not just this instance!
        @param name The name of this animation
        @param length The length of the animation in seconds
        */
    override ref Animation createAnimation(string name, Real length)
    {
        return mSkeleton.getAs().createAnimation(name, length);
    }

    alias Skeleton.getAnimation getAnimation;

    /** Returns the named Animation object. */
    override Animation getAnimation(string name, 
                              LinkedSkeletonAnimationSource** linker = null)
    {
        return mSkeleton.getAs().getAnimation(name, linker);
    }
    
    /** Removes an Animation from this skeleton. 
        @remarks
            This method updates the reference skeleton, not just this instance!
        */
    override void removeAnimation(string name)
    {
        mSkeleton.getAs().removeAnimation(name);
    }
    
    
    /** Creates a TagPoint ready to be attached to a bone */
    TagPoint createTagPointOnBone(ref Bone bone, 
                                  Quaternion offsetOrientation = Quaternion.IDENTITY, 
                                  Vector3 offsetPosition = Vector3.ZERO)
    {
        TagPoint ret;
        if (!mFreeTagPoints.length) {
            ret = new TagPoint(mNextTagPointAutoHandle++, this);
            mActiveTagPoints.insert(ret);
        } else {
            ret = mFreeTagPoints[0];
            //mActiveTagPoints.splice(mActiveTagPoints.end(), mFreeTagPoints, mFreeTagPoints.begin());
            mActiveTagPoints ~= ret;
            // Initial some members ensure identically behavior, avoiding potential bug.
            ret.setParentEntity(null);
            ret.setChildObject(null);
            ret.setInheritOrientation(true);
            ret.setInheritScale(true);
            ret.setInheritParentEntityOrientation(true);
            ret.setInheritParentEntityScale(true);
        }
        
        ret.setPosition(offsetPosition);
        ret.setOrientation(offsetOrientation);
        ret.setScale(Vector3.UNIT_SCALE);
        ret.setBindingPose();
        bone.addChild(ret);
        
        return ret;
    }
    /** Frees a TagPoint that already attached to a bone */
    void freeTagPoint(ref TagPoint tagPoint)
    {
        //TagPointList.iterator it = std.find(mActiveTagPoints.begin(), mActiveTagPoints.end(), tagPoint);
        //assert(it != mActiveTagPoints.end());
        
        auto it = std.algorithm.find(mActiveTagPoints, tagPoint);
        assert(!it.length);
        
        //if (it != mActiveTagPoints.end())
        if (!it.length)
        {
            if (tagPoint.getParent())
                tagPoint.getParent().removeChild(tagPoint);
            
            //mFreeTagPoints.splice(mFreeTagPoints.end(), mActiveTagPoints, it);
            mFreeTagPoints.insert(it[0]);
        }
    }
    
    /// @copydoc Skeleton.addLinkedSkeletonAnimationSource
    override void addLinkedSkeletonAnimationSource(string skelName, 
                                                   Real scale = 1.0f)
    {
        mSkeleton.getAs().addLinkedSkeletonAnimationSource(skelName, scale);
    }
    
    /// @copydoc Skeleton.removeAllLinkedSkeletonAnimationSources
    override void removeAllLinkedSkeletonAnimationSources()
    {
        mSkeleton.getAs().removeAllLinkedSkeletonAnimationSources();
    }
    
    /// @copydoc Skeleton.getLinkedSkeletonAnimationSourceIterator
    /*override LinkedSkeletonAnimSourceIterator 
        getLinkedSkeletonAnimationSourceIterator()
    {
        return mSkeleton.getAs().getLinkedSkeletonAnimationSourceIterator();
    }*/
    //TODO Needs override?
    override ref LinkedSkeletonAnimSourceList getLinkedSkeletonAnimSourceList()
    {
        return mSkeleton.getAs().getLinkedSkeletonAnimSourceList();
    }
    
    /// @copydoc Skeleton._initAnimationState
    override void _initAnimationState(ref AnimationStateSet animSet)
    {
        mSkeleton.getAs()._initAnimationState(animSet);
    }
    
    /// @copydoc Skeleton._refreshAnimationState
    override void _refreshAnimationState(ref AnimationStateSet animSet)
    {
        mSkeleton.getAs()._refreshAnimationState(animSet);
    }
    
    /// @copydoc Resource.getName
    override string getName()
    {
        // delegate
        return mSkeleton.getAs().getName();
    }
    
    /// @copydoc Resource.getHandle
    override ResourceHandle getHandle()
    {
        // delegate
        return mSkeleton.getAs().getHandle();
    }
    
    /// @copydoc Resource.getGroup
    override string getGroup()
    {
        // delegate
        return mSkeleton.getAs().getGroup();
    }
    
protected:
    /// Pointer back to master Skeleton
    SharedPtr!Skeleton mSkeleton;
    
    //typedef list<TagPoint*>.type TagPointList;
    alias TagPoint[] TagPointList;
    
    /** Active tag point list.
        @remarks
            This is a linked list of pointers to active tag points
        @par
            This allows very fast insertions and deletions from anywhere in the list to activate / deactivate
            tag points (required for weapon / equip systems etc) as well as reuse of TagPoint instances
            without construction & destruction which avoids memory thrashing.
        */
    TagPointList mActiveTagPoints;
    
    /** Free tag point list.
        @remarks
            This contains a list of the tag points free for use as new instances
            as required by the set. When a TagPoint instance is deactivated, there will be a reference on this
            list. As they get used this list reduces, as they get released back to to the set they get added
            back to the list.
        */
    TagPointList mFreeTagPoints;
    
    /// TagPoint automatic handles
    ushort mNextTagPointAutoHandle;
    
    void cloneBoneAndChildren(Bone source, Bone parent)
    {
        Bone newBone;
        if (source.getName() is null)
        {
            newBone = createBone(source.getHandle());
        }
        else
        {
            newBone = createBone(source.getName(), source.getHandle());
        }
        if (parent is null)
        {
            mRootBones.insert(newBone);
        }
        else
        {
            parent.addChild(newBone);
        }
        newBone.setOrientation(source.getOrientation());
        newBone.setPosition(source.getPosition());
        newBone.setScale(source.getScale());
        
        // Process children
        //Node.ChildNodeIterator it = source.getChildIterator();
        //while (it.hasMoreElements())
        foreach(child; source.getChildren())
        {
            cloneBoneAndChildren(cast(Bone)(child), newBone);
        }
    }
    
    /** Overridden from Skeleton
        */
    override void loadImpl()
    {
        mNextAutoHandle = mSkeleton.getAs()._getNextAutoHandle();
        mNextTagPointAutoHandle = 0;
        //ruct self from master
        mBlendState = mSkeleton.getAs().getBlendMode();
        // Copy bones
        //BoneIterator i = mSkeleton.getAs().getRootBoneIterator();
        //while (i.hasMoreElements())
        foreach(b; mSkeleton.getAs().getRootBones())
        {
            cloneBoneAndChildren(b, null);
            b._update(true, false);
        }
        setBindingPose();
    }
    
    /** Overridden from Skeleton
        */
    override void unloadImpl()
    {
        super.unloadImpl();
        
        // destroy TagPoints
        foreach (tagPoint; mActiveTagPoints)
        {
            // Woohoo! The child object all the same attaching this skeleton instance, but is ok we can just
            // ignore it:
            //   1. The parent node of the tagPoint already deleted by Skeleton.unload(), nothing need to do now
            //   2. And the child object relationship already detached by Entity.~Entity()
            destroy(tagPoint);
        }
        mActiveTagPoints.clear();
        foreach (tagPoint; mFreeTagPoints)
        {
            destroy(tagPoint);
        }
        mFreeTagPoints.clear();
    }
    
}
