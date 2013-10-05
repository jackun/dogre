module ogre.effects.compositorlogic;
import ogre.effects.compositor;
/** \addtogroup Core
    *  @{
    */
/** \addtogroup Effects
    *  @{
    */
/** Interface for compositor logics, which can be automatically binded to compositors,
    *   allowing per-compositor logic (such as attaching a relevant listener) to happen
    *   automatically.
    *   @remarks All methods have empty implementations to not force an implementer into
    *       extending all of them.
    */
interface CompositorLogic
{
public:
    /** Called when a compositor instance has been created.
            @remarks
            This happens after its setup was finished, so the chain is also accessible.
            This is an ideal method to automatically attach a compositor listener.
        */
    void compositorInstanceCreated(ref CompositorInstance newInstance);// {}
    
    /** Called when a compositor instance has been destroyed
            @remarks
            The chain that contained the compositor is still alive during this call.
        */
    void compositorInstanceDestroyed(ref CompositorInstance destroyedInstance);// {}
}
/** @} */
/** @} */