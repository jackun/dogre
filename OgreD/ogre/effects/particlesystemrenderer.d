module ogre.effects.particlesystemrenderer;

//import std.container;
import ogre.compat;
import ogre.effects.particle;
import ogre.general.generals;
import ogre.materials.material;
import ogre.rendersystem.renderqueue;
import ogre.scene.camera;
import ogre.scene.node;
import ogre.scene.renderable;
import ogre.sharedptr;

/** \addtogroup Core
    *  @{
    */
/** \addtogroup Effects
    *  @{
    */
/** Abstract class defining the interface required to be implemented
        by classes which provide rendering capability to ParticleSystem instances.
    */
//interface
class ParticleSystemRenderer : StringInterface //, public FXAlloc
{
    mixin StringInterfaceTmpl;

public:
    /// Constructor
    //this() {}
    /// Destructor
    //~this() {}
    
    /** Gets the type of this renderer - must be implemented by subclasses */
   string getType();
    
    /** Delegated to by ParticleSystem::_updateRenderQueue
        @remarks
            The subclass must update the render queue using whichever Renderable
            instance(s) it wishes.
        */
    void _updateRenderQueue(RenderQueue queue, 
                            Particle[] currentParticles, bool cullIndividually);
    
    /** Sets the material this renderer must use; called by ParticleSystem. */
    abstract void _setMaterial(SharedPtr!Material mat);
    /** Delegated to by ParticleSystem::_notifyCurrentCamera */
    abstract void _notifyCurrentCamera(Camera cam);
    /** Delegated to by ParticleSystem::_notifyAttached */
    abstract void _notifyAttached(Node parent, bool isTagPoint = false);
    /** Optional callback notified when particles are rotated */
    void _notifyParticleRotated() {}
    /** Optional callback notified when particles are resized individually */
    void _notifyParticleResized() {}
    /** Tells the renderer that the particle quota has changed */
    abstract void _notifyParticleQuota(size_t quota);
    /** Tells the renderer that the particle default size has changed */
    abstract void _notifyDefaultDimensions(Real width, Real height);
    /** Optional callback notified when particle emitted */
    void _notifyParticleEmitted(ref Particle particle) {}
    /** Optional callback notified when particle expired */
    void _notifyParticleExpired(ref Particle particle) {}
    /** Optional callback notified when particles moved */
    void _notifyParticleMoved(ref Particle[] currentParticles) {}
    /** Optional callback notified when particles cleared */
    void _notifyParticleCleared(ref Particle[] currentParticles) {}
    /** Create a new ParticleVisualData instance for attachment to a particle.
        @remarks
            If this renderer needs additional data in each particle, then this should
            be held in an instance of a subclass of ParticleVisualData, and this method
            should be overridden to return a new instance of it. The default
            behaviour is to return null.
        */
    ParticleVisualData _createVisualData() { return null; }
    /** Destroy a ParticleVisualData instance.
        @remarks
            If this renderer needs additional data in each particle, then this should
            be held in an instance of a subclass of ParticleVisualData, and this method
            should be overridden to destroy an instance of it. The default
            behaviour is to do nothing.
        */
    void _destroyVisualData(ref ParticleVisualData vis) { assert (vis is null); }
    
    /** Sets which render queue group this renderer should target with it's
            output.
        */
    abstract void setRenderQueueGroup(ubyte queueID);
    /** Sets which render queue group and priority this renderer should target with it's
            output.
        */
    abstract void setRenderQueueGroupAndPriority(ubyte queueID, ushort priority);
    
    /** Setting carried over from ParticleSystem.
        */
    abstract void setKeepParticlesInLocalSpace(bool keepLocal);
    
    /** Gets the desired particles sort mode of this renderer */
    abstract SortMode _getSortMode();
    
    /** Required method to allow the renderer to communicate the Renderables
            it will be using to render the system to a visitor.
        @see MovableObject::visitRenderables
        */
    abstract void visitRenderables(Renderable.Visitor visitor, 
                                  bool debugRenderables = false);
}

/** Abstract class definition of a factory object for ParticleSystemRenderer. */
class ParticleSystemRendererFactory : FactoryObj!ParticleSystemRenderer //, public FXAlloc
{
public:
    // No methods, must just override all methods inherited from FactoryObj
}
/** @} */
/** @} */