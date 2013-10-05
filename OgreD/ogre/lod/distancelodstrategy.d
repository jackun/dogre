module ogre.lod.distancelodstrategy;
import ogre.singleton;
import ogre.lod.lodstrategy;
import ogre.scene.movableobject;
import ogre.scene.camera;
import ogre.compat;
import ogre.rendersystem.viewport;
import ogre.math.angles;
import ogre.math.matrix;
import ogre.math.frustum;
import ogre.resources.mesh;
import ogre.materials.material;
import ogre.math.maths;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup LOD
 *  @{
 */

/** Level of detail strategy based on distance from camera. */
class DistanceLodStrategy : LodStrategy
{
    mixin Singleton!DistanceLodStrategy;
protected:
    /// @copydoc LodStrategy::getValueImpl
    override Real getValueImpl(MovableObject movableObject, Camera camera)
    {
        // Get squared depth taking into account bounding radius
        // (d - r) ^ 2 = d^2 - 2dr + r^2, but this requires a lot 
        // more computation (including a sqrt) so we approximate 
        // it with d^2 - r^2, which is good enough for determining 
        // lod.
        Real squaredDepth = movableObject.getParentNode().getSquaredViewDepth(camera) - Math.Sqr(movableObject.getBoundingRadius());
        
        // Check if reference view needs to be taken into account
        if (mReferenceViewEnabled)
        {
            // Reference view only applicable to perspective projection
            assert(camera.getProjectionType() == ProjectionType.PT_PERSPECTIVE, "Camera projection type must be perspective!");
            
            // Get camera viewport
            Viewport viewport = camera.getViewport();
            
            // Get viewport area
            Real viewportArea = cast(Real)(viewport.getActualWidth() * viewport.getActualHeight());
            
            // Get projection matrix (this is done to avoid computation of tan(fov / 2))
           Matrix4 projectionMatrix = camera.getProjectionMatrix();
            
            // Compute bias value (note that this is similar to the method used for PixelCountLodStrategy)
            Real biasValue = viewportArea * projectionMatrix[0][0] * projectionMatrix[1][1];
            
            // Scale squared depth appropriately
            squaredDepth *= (mReferenceViewValue / biasValue);
        }
        
        // Squared depth should never be below 0, so clamp
        squaredDepth = std.algorithm.max(squaredDepth, 0);
        
        // Now adjust it by the camera bias and return the computed value
        return squaredDepth * camera._getLodBiasInverse();
    }
    
public:
    /** Default constructor. */
    this()
    {
        super("Distance");
        mReferenceViewEnabled = false;
        mReferenceViewValue = -1;
    }
    
    /// @copydoc LodStrategy::getBaseValue
    override Real getBaseValue()
    {
        return cast(Real)0;
    }
    
    /// @copydoc LodStrategy::transformBias
    override Real transformBias(Real factor)
    {
        assert(factor > 0.0f, "Bias factor must be > 0!");
        return 1.0f / factor;
    }
    
    /// @copydoc LodStrategy::transformUserValue
    override Real transformUserValue(Real userValue)
    {
        // Square user-supplied distance
        return Math.Sqr(userValue);
    }
    
    /// @copydoc LodStrategy::getIndex
    override ushort getIndex(Real value, ref Mesh.MeshLodUsageList meshLodUsageList)
    {
        // Get index assuming ascending values
        return getIndexAscending(value, meshLodUsageList);
    }
    
    /// @copydoc LodStrategy::getIndex
    override ushort getIndex(Real value, ref Material.LodValueList materialLodValueList)
    {
        // Get index assuming ascending values
        return getIndexAscending(value, materialLodValueList);
    }
    
    /// @copydoc LodStrategy::sort
    override void sort(ref Mesh.MeshLodUsageList meshLodUsageList)
    {
        // Sort ascending
        sortAscending(meshLodUsageList);
    }
    
    /// @copydoc LodStrategy::isSorted
    override bool isSorted(Mesh.LodValueList values)
    {
        // Determine if sorted ascending
        return isSortedAscending(values);
    }
    
    /** Sets the reference view upon which the distances were based.
     @note
     This automatically enables use of the reference view.
     @note
     There is no corresponding get method for these values as
     they are not saved, but used to compute a reference value.
     */
    void setReferenceView(Real viewportWidth, Real viewportHeight, Radian fovY)
    {
        // Determine x FOV based on aspect ratio
        Radian fovX = fovY * (viewportWidth / viewportHeight);
        
        // Determine viewport area
        Real viewportArea = viewportHeight * viewportWidth;
        
        // Compute reference view value based on viewport area and FOVs
        mReferenceViewValue = viewportArea * Math.Tan(fovX * 0.5f) * Math.Tan(fovY * 0.5f);
        
        // Enable use of reference view
        mReferenceViewEnabled = true;
    }
    
    /** Enables to disables use of the reference view.
     @note Do not enable use of the reference view before setting it.
     */
    void setReferenceViewEnabled(bool value)
    {
        // Ensure reference value has been set before being enabled
        if (value)
            assert(mReferenceViewValue != -1, "Reference view must be set before being enabled!");
        
        mReferenceViewEnabled = value;
    }
    
    /** Determine if use of the reference view is enabled */
    bool getReferenceViewEnabled()
    {
        return mReferenceViewEnabled;
    }
    
private:
    bool mReferenceViewEnabled;
    Real mReferenceViewValue;
    
}
/** @} */
/** @} */