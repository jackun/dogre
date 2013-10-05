module ogre.lod.pixelcountlodstrategy;
import ogre.lod.lodstrategy;
import ogre.singleton;
import ogre.scene.movableobject;
import ogre.scene.camera;
import ogre.rendersystem.viewport;
import ogre.math.maths;
import ogre.math.frustum;
import ogre.compat;
import ogre.math.matrix;
import ogre.resources.mesh;
import ogre.materials.material;

/** \addtogroup Core
    *  @{
    */
/** \addtogroup LOD
    *  @{
    */
/** Level of detail strategy based on pixel count approximation from bounding sphere projection. */
class PixelCountLodStrategy : LodStrategy
{
    mixin Singleton!PixelCountLodStrategy;
protected:
    /// @copydoc LodStrategy::getValueImpl
    override Real getValueImpl(MovableObject movableObject, Camera camera)
    {
        // Get viewport
       Viewport viewport = camera.getViewport();
        
        // Get viewport area
        Real viewportArea = cast(Real)(viewport.getActualWidth() * viewport.getActualHeight());
        
        // Get area of unprojected circle with object bounding radius
        Real boundingArea = Math.PI * Math.Sqr(movableObject.getBoundingRadius());
        
        // Base computation on projection type
        final switch (camera.getProjectionType())
        {
            case ProjectionType.PT_PERSPECTIVE:
            {
                // Get camera distance
                Real distanceSquared = movableObject.getParentNode().getSquaredViewDepth(camera);
                
                // Check for 0 distance
                if (distanceSquared <= Real.epsilon)
                    return getBaseValue();
                
                // Get projection matrix (this is done to avoid computation of tan(fov / 2))
               Matrix4 projectionMatrix = camera.getProjectionMatrix();
                
                // Estimate pixel count
                return (boundingArea * viewportArea * projectionMatrix[0][0] * projectionMatrix[1][1]) / distanceSquared;
            }
            case ProjectionType.PT_ORTHOGRAPHIC:
            {
                // Compute orthographic area
                Real orthoArea = camera.getOrthoWindowHeight() * camera.getOrthoWindowWidth();
                
                // Check for 0 orthographic area
                if (orthoArea <= Real.epsilon)
                    return getBaseValue();
                
                // Estimate pixel count
                return (boundingArea * viewportArea) / orthoArea;
            }
        }
    }
    
public:
    /** Default constructor. */
    this()
    {
        super("PixelCount");
    }
    
    /// @copydoc LodStrategy::getBaseValue
    override Real getBaseValue()
    {
        // Use the maximum possible value as base
        return Real.max;
    }
    
    /// @copydoc LodStrategy::transformBias
    override Real transformBias(Real factor)
    {
        // No transformation required for pixel count strategy
        return factor;
    }
    
    /// @copydoc LodStrategy::getIndex
    override ushort getIndex(Real value, ref Mesh.MeshLodUsageList meshLodUsageList)
    {
        // Values are descending
        return getIndexDescending(value, meshLodUsageList);
    }
    
    /// @copydoc LodStrategy::getIndex
    override ushort getIndex(Real value, ref Material.LodValueList materialLodValueList)
    {
        // Values are descending
        return getIndexDescending(value, materialLodValueList);
    }
    
    /// @copydoc LodStrategy::sort
    override void sort(ref Mesh.MeshLodUsageList meshLodUsageList)
    {
        // Sort descending
        sortDescending(meshLodUsageList);
    }
    
    /// @copydoc LodStrategy::isSorted
    override bool isSorted(Mesh.LodValueList values)
    {
        // Check if values are sorted descending
        return isSortedDescending(values);
    }
       
}
/** @} */
/** @} */