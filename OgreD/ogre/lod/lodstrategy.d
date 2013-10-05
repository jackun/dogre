module ogre.lod.lodstrategy;

import ogre.compat;
import ogre.math.angles;
import ogre.resources.mesh;
import ogre.scene.movableobject;
import ogre.scene.camera;
import ogre.materials.material;
import ogre.scene.entity;

/** \addtogroup Core
*  @{
*/
/** \addtogroup LOD
*  @{
*/
/** Strategy for determining level of detail.
@remarks
    Generally, to create a new lod strategy, all of the following will
    need to be implemented: getValueImpl, getBaseValue, transformBias,
    getIndex, sort, and isSorted.
    In addition, transformUserValue may be overridden.
*/
class LodStrategy// : public LodAlloc
{
protected:
    /** Name of this strategy. */
    string mName;

    /** Compute the lod value for a given movable object relative to a given camera. */
    abstract Real getValueImpl(MovableObject movableObject, Camera camera);

public:
    /** Constructor accepting name. */
    this(string name)
    {
        mName = name;
    }

    /** destructor. */
    ~this()
    {
    
    }

    /** Get the value of the first (highest) level of detail. */
    abstract Real getBaseValue();

    /** Transform lod bias so it only needs to be multiplied by the lod value. */
    abstract Real transformBias(Real factor);

    /** Transforum user supplied value to internal value.
    @remarks
        By default, performs no transformation.
    @remarks
        Do not throw exceptions for invalid values here, as the lod strategy
        may be changed such that the values become valid.
    */
    Real transformUserValue(Real userValue)
    {
        // No transformation by default
        return userValue;
    }

    /** Compute the lod value for a given movable object relative to a given camera. */
    Real getValue(MovableObject movableObject, ref Camera camera)
    {
        // Just return implementation with lod camera
        return getValueImpl(movableObject, camera.getLodCamera());
    }

    /** Get the index of the lod usage which applies to a given value. */
    abstract ushort getIndex(Real value, ref Mesh.MeshLodUsageList meshLodUsageList);

    /** Get the index of the lod usage which applies to a given value. */
    abstract ushort getIndex(Real value, ref Material.LodValueList materialLodValueList);

    /** Sort mesh lod usage list from greatest to least detail */
    abstract void sort(ref Mesh.MeshLodUsageList meshLodUsageList);

    /** Determine if the lod values are sorted from greatest detail to least detail. */
    abstract bool isSorted(Mesh.LodValueList values);

    /** Assert that the lod values are sorted from greatest detail to least detail. */
    void assertSorted(Mesh.LodValueList values)
    {
        assert(isSorted(values), "The lod values must be sorted");
    }

    /** Get the name of this strategy. */
   string getName(){ return mName; }

protected:
    /** Implementation of isSorted suitable for ascending values. */
    static bool isSortedAscending(ref Mesh.LodValueList values)
    {
        Real prev = values[0];
        for (int i = 1; i < values.length; i++)
        {
            Real cur = values[i];
            if (cur < prev)
                return false;
            prev = cur;
        }

        return true;
    }
    /** Implementation of isSorted suitable for descending values. */
    static bool isSortedDescending(ref Mesh.LodValueList values)
    {
        Real prev = values[0];
        for (int i = 1; i < values.length; i++)
        {
            Real cur = values[i];
            if (cur > prev)
                return false;
            prev = cur;
        }

        return true;
    }
    
    /*static bool LodUsageSortLess(MeshLodUsage mesh1, ref MeshLodUsage mesh2)
    {
        // sort ascending
        return mesh1.value < mesh2.value;
    }*/

    /** Implementation of sort suitable for ascending values. */
    static void sortAscending(ref Mesh.MeshLodUsageList meshLodUsageList)
    {
        std.algorithm.sort!("a.value < b.value")(meshLodUsageList);
    }
    /** Implementation of sort suitable for descending values. */
    static void sortDescending(ref Mesh.MeshLodUsageList meshLodUsageList)
    {
        std.algorithm.sort!("a.value > b.value")(meshLodUsageList);
    }

    /** Implementation of getIndex suitable for ascending values. */
    static ushort getIndexAscending(Real value, ref Mesh.MeshLodUsageList meshLodUsageList)
    {
        //std.algorithm.countUntil
        ushort index = 0;
        foreach ( i; meshLodUsageList)
        {
            if (i.value > value)
            {
                return index ? cast(ushort)(index - 1) : 0;
            }
            index++;
        }

        // If we fall all the way through, use the highest value
        return cast(ushort)(meshLodUsageList.length - 1);
    }
    /** Implementation of getIndex suitable for descending values. */
    static ushort getIndexDescending(Real value, ref Mesh.MeshLodUsageList meshLodUsageList)
    {
        ushort index = 0;
        foreach (i; meshLodUsageList)
        {
            if (i.value < value)
            {
                return index ? cast(ushort)(index - 1) : 0;
            }
            index++;
        }

        // If we fall all the way through, use the highest value
        return cast(ushort)(meshLodUsageList.length - 1);
    }

    /** Implementation of getIndex suitable for ascending values. */
    static ushort getIndexAscending(Real value, ref Material.LodValueList materialLodValueList)
    {
        //std.algorithm.countUntil
        ushort index = 0;
        foreach (i; materialLodValueList)
        {
            if (i > value)
            {
                return index ? cast(ushort)(index - 1) : 0;
            }
            index++;
        }

        // If we fall all the way through, use the highest value
        return cast(ushort)(materialLodValueList.length - 1);
    }
    /** Implementation of getIndex suitable for descending values. */
    static ushort getIndexDescending(Real value, ref Material.LodValueList materialLodValueList)
    {
        ushort index = 0;
        foreach (i; materialLodValueList)
        {
            if (i < value)
            {
                return index ? cast(ushort)(index - 1) : 0;
            }
            index++;
        }

        // If we fall all the way through, use the highest value
        return cast(ushort)(materialLodValueList.length - 1);
    }

}

/// Struct containing information about a lod change event for movable objects.
struct MovableObjectLodChangedEvent
{
    /// The movable object whose level of detail has changed.
    MovableObject movableObject;
    
    /// The camera with respect to which the level of detail has changed.
    Camera camera;
}

/// Struct containing information about a mesh lod change event for entities.
struct EntityMeshLodChangedEvent
{
    /// The entity whose level of detail has changed.
    Entity entity;
    
    /// The camera with respect to which the level of detail has changed.
    Camera camera;
    
    /// Lod value as determined by lod strategy.
    Real lodValue;
    
    /// Previous level of detail index.
    ushort previousLodIndex;
    
    /// New level of detail index.
    ushort newLodIndex;
}

/// Struct containing information about a material lod change event for entities.
struct EntityMaterialLodChangedEvent
{
    /// The sub-entity whose material's level of detail has changed.
    SubEntity subEntity;
    
    /// The camera with respect to which the level of detail has changed.
    Camera camera;
    
    /// Lod value as determined by lod strategy.
    Real lodValue;
    
    /// Previous level of detail index.
    ushort previousLodIndex;
    
    /// New level of detail index.
    ushort newLodIndex;
}


/** A interface class defining a listener which can be used to receive
        notifications of lod events.
        @remarks
            A 'listener' is an interface designed to be called back when
            particular events are called. This class defines the
            interface relating to lod events. In order to receive
            notifications of lod events, you should create a subclass of
            LodListener and override the methods for which you would like
            to customise the resulting processing. You should then call
            SceneManager::addLodListener passing an instance of this class.
            There is no limit to the number of lod listeners you can register,
            allowing you to register multiple listeners for different purposes.

            For some uses, it may be advantageous to also subclass
            RenderQueueListener as this interface makes available information
            regarding render queue invocations.

            It is important not to modify the scene graph during rendering, so,
            for each event, there are two methods, a prequeue method and a
            postqueue method.  The prequeue method is invoked during rendering,
            and as such should not perform any changes, but if the event is
            relevant, it may return true indicating the postqueue method should
            also be called.  The postqueue method is invoked at an appropriate
            time after rendering and scene changes may be safely made there.
    */
interface LodListener
{
    /**
        Called before a movable object's lod has changed.
        @remarks
            Do not change the Ogre state from this method, 
            instead return true and perform changes in 
            postqueueMovableObjectLodChanged.
        @return
            True to indicate the event should be queued and
            postqueueMovableObjectLodChanged called after
            rendering is complete.
        */
    bool prequeueMovableObjectLodChanged(MovableObjectLodChangedEvent evt);
    
    /**
        Called after a movable object's lod has changed.
        @remarks
            May be called even if not requested from prequeueMovableObjectLodChanged
            as only one event queue is maintained per SceneManger instance.
        */
    void postqueueMovableObjectLodChanged(MovableObjectLodChangedEvent evt);
    
    /**
        Called before an entity's mesh lod has changed.
        @remarks
            Do not change the Ogre state from this method, 
            instead return true and perform changes in 
            postqueueEntityMeshLodChanged.

            It is possible to change the event notification 
            and even alter the newLodIndex field (possibly to 
            prevent the lod from changing, or to skip an 
            index).
        @return
            True to indicate the event should be queued and
            postqueueEntityMeshLodChanged called after
            rendering is complete.
        */
    bool prequeueEntityMeshLodChanged(ref EntityMeshLodChangedEvent evt);
    
    /**
        Called after an entity's mesh lod has changed.
        @remarks
            May be called even if not requested from prequeueEntityMeshLodChanged
            as only one event queue is maintained per SceneManger instance.
        */
    void postqueueEntityMeshLodChanged(EntityMeshLodChangedEvent evt);
    
    /**
        Called before an entity's material lod has changed.
        @remarks
            Do not change the Ogre state from this method, 
            instead return true and perform changes in 
            postqueueMaterialLodChanged.

            It is possible to change the event notification 
            and even alter the newLodIndex field (possibly to 
            prevent the lod from changing, or to skip an 
            index).
        @return
            True to indicate the event should be queued and
            postqueueMaterialLodChanged called after
            rendering is complete.
        */
    bool prequeueEntityMaterialLodChanged(ref EntityMaterialLodChangedEvent evt);
    
    /**
        Called after an entity's material lod has changed.
        @remarks
            May be called even if not requested from prequeueEntityMaterialLodChanged
            as only one event queue is maintained per SceneManger instance.
        */
    void postqueueEntityMaterialLodChanged(EntityMaterialLodChangedEvent evt);
    
}
/** @} */
/** @} */
