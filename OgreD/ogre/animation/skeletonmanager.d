module ogre.animation.skeletonmanager;
import ogre.singleton;
import ogre.resources.resourcemanager;
import ogre.animation.animations;
import ogre.resources.resource;
import ogre.general.common;
import ogre.resources.resourcegroupmanager;

/** \addtogroup Core
    *  @{
    */
/** \addtogroup Animation
    *  @{
    */
/** Handles the management of skeleton resources.
 @remarks
     This class deals with the runtime management of
     skeleton data; like other resource managers it handles
     the creation of resources (in this case skeleton data),
     working within a fixed memory budget.
 */
final class SkeletonManager: ResourceManager
{
    mixin Singleton!SkeletonManager;
public:
    /// Constructor
    this()
    {
        mLoadOrder = 300.0f;
        mResourceType = "Skeleton";
        
        ResourceGroupManager.getSingleton()._registerResourceManager(mResourceType, this);
    }
    ~this()
    {
        ResourceGroupManager.getSingleton()._unregisterResourceManager(mResourceType);
    }

protected:
    
    /// @copydoc ResourceManager::createImpl
    override Resource createImpl(string name, ResourceHandle handle, 
                                 string group, bool isManual, ManualResourceLoader loader, 
                                 NameValuePairList createParams)
    {
        return new Skeleton(this, name, handle, group, isManual, loader);
    }
}

/** @} */
/** @} */

