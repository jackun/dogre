module ogre.effects.customcompositionpass;
import ogre.effects.compositionpass;
import ogre.effects.compositor;

/** \addtogroup Core
    *  @{
    */
/** \addtogroup Effects
    *  @{
    */
/** Interface for custom composition passes, allowing custom operations (in addition to
    *   the quad, scene and clear operations) in composition passes.
    *   @see CompositorManager::registerCustomCompositionPass
    */
interface CustomCompositionPass
{
public:
    /** Create a custom composition operation.
            @param pass The CompositionPass that triggered the request
            @param instance The compositor instance that this operation will be performed in
            @remarks This call only happens once during creation. The RenderSystemOperation will
            get called each render.
            @remarks The created operation must be instanciated using the OGRE_NEW macro.
        */
    CompositorInstance.RenderSystemOperation createOperation(
        ref CompositorInstance instance,ref CompositionPass pass);
}
/** @} */
/** @} */