module ogre.effects.billboardparticlerenderer;

//import std.container;

import ogre.effects.particle;
import ogre.effects.billboardset;
import ogre.general.generals;
import ogre.exception;
import ogre.strings;
import ogre.rendersystem.renderqueue;
import ogre.scene.camera;
import ogre.materials.material;
import ogre.scene.renderable;
import ogre.scene.node;
import ogre.compat;
import ogre.effects.particlesystemrenderer;
import ogre.effects.billboard;
import ogre.sharedptr;

/** \addtogroup Core
    *  @{
    */
/** \addtogroup Effects
    *  @{
    */

/** Specialisation of ParticleSystemRenderer to render particles using 
        a BillboardSet. 
    @remarks
        This renderer has a few more options than the standard particle system,
        which will be passed to it automatically when the particle system itself
        does not understand them.
    */
class BillboardParticleRenderer : ParticleSystemRenderer
{
    //mixin StringInterfaceTmpl;
protected:
    /// The billboard set that's doing the rendering
    BillboardSet mBillboardSet;
public:
    this()
    {
        if (createParamDictionary("BillboardParticleRenderer"))
        {
            ParamDictionary dict = getParamDictionary();
            dict.addParameter(new ParameterDef("billboard_type", 
                                            "The type of billboard to use. 'point' means a simulated spherical particle, " ~
                                            "'oriented_common' means all particles in the set are oriented around common_direction, " ~
                                            "'oriented_self' means particles are oriented around their own direction, " ~
                                            "'perpendicular_common' means all particles are perpendicular to common_direction, " ~
                                            "and 'perpendicular_self' means particles are perpendicular to their own direction.",
                                            ParameterType.PT_STRING),
                               msBillboardTypeCmd);
            
            dict.addParameter(new ParameterDef("billboard_origin", 
                                            "This setting controls the fine tuning of where a billboard appears in relation to it's position. "~
                                            "Possible value are: 'top_left', 'top_center', 'top_right', 'center_left', 'center', 'center_right', "~
                                            "'bottom_left', 'bottom_center' and 'bottom_right'. Default value is 'center'.",
                                            ParameterType.PT_STRING),
                               msBillboardOriginCmd);
            
            dict.addParameter(new ParameterDef("billboard_rotation_type", 
                                            "This setting controls the billboard rotation type. " ~
                                            "'vertex' means rotate the billboard's vertices around their facing direction." ~
                                            "'texcoord' means rotate the billboard's texture coordinates. Default value is 'texcoord'.",
                                            ParameterType.PT_STRING),
                               msBillboardRotationTypeCmd);
            
            dict.addParameter(new ParameterDef("common_direction", 
                                            "Only useful when billboard_type is oriented_common or perpendicular_common. " ~
                                            "When billboard_type is oriented_common, this parameter sets the common orientation for " ~
                                            "all particles in the set (e.g. raindrops may all be oriented downwards). " ~
                                            "When billboard_type is perpendicular_common, this parameter sets the perpendicular vector for " ~
                                            "all particles in the set (e.g. an aureola around the player and parallel to the ground).",
                                            ParameterType.PT_VECTOR3),
                               msCommonDirectionCmd);

            dict.addParameter(new ParameterDef("common_up_vector",
                                            "Only useful when billboard_type is perpendicular_self or perpendicular_common. This " ~
                                            "parameter sets the common up-vector for all particles in the set (e.g. an aureola around " ~
                                            "the player and parallel to the ground).",
                                            ParameterType.PT_VECTOR3),
                               msCommonUpVectorCmd);
            dict.addParameter(new ParameterDef("point_rendering",
                                            "Set whether or not particles will use point rendering " ~
                                            "rather than manually generated quads. This allows for faster " ~
                                            "rendering of point-oriented particles although introduces some " ~
                                            "limitations too such as requiring a common particle size." ~
                                            "Possible values are 'true' or 'false'.",
                                            ParameterType.PT_BOOL),
                               msPointRenderingCmd);
            dict.addParameter(new ParameterDef("accurate_facing",
                                            "Set whether or not particles will be oriented to the camera " ~
                                            "based on the relative position to the camera rather than just " ~
                                            "the camera direction. This is more accurate but less optimal. " ~
                                            "Cannot be combined with point rendering.",
                                            ParameterType.PT_BOOL),
                               msAccurateFacingCmd);
        }
        
        // Create billboard set
        mBillboardSet = new BillboardSet(/*""*/ null, 0, true);
        // World-relative axes
        mBillboardSet.setBillboardsInWorldSpace(true);
    }


    ~this()
    {
        // mBillboardSet is never actually attached to a node, we just passthrough
        // based on the particle system's attachment. So manually notify that it's
        // no longer attached.
        mBillboardSet._notifyAttached(null);
        destroy(mBillboardSet);
    }
    
    /** Command object for billboard type (see ParamCommand).*/
    static class CmdBillboardType : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            BillboardType t = (cast(BillboardParticleRenderer)target).getBillboardType();
            final switch(t)
            {
                case BillboardType.BBT_POINT:
                    return "point";
                    break;
                case BillboardType.BBT_ORIENTED_COMMON:
                    return "oriented_common";
                    break;
                case BillboardType.BBT_ORIENTED_SELF:
                    return "oriented_self";
                    break;
                case BillboardType.BBT_PERPENDICULAR_COMMON:
                    return "perpendicular_common";
                case BillboardType.BBT_PERPENDICULAR_SELF:
                    return "perpendicular_self";
            }
            // Compiler nicety
            return "";
        }
        void doSet(Object target,string val)
        {
            BillboardType t;
            if (val == "point")
            {
                t = BillboardType.BBT_POINT;
            }
            else if (val == "oriented_common")
            {
                t = BillboardType.BBT_ORIENTED_COMMON;
            }
            else if (val == "oriented_self")
            {
                t = BillboardType.BBT_ORIENTED_SELF;
            }
            else if (val == "perpendicular_common")
            {
                t = BillboardType.BBT_PERPENDICULAR_COMMON;
            }
            else if (val == "perpendicular_self")
            {
                t = BillboardType.BBT_PERPENDICULAR_SELF;
            }
            else
            {
                throw new InvalidParamsError(
                            "Invalid billboard_type '" ~ val ~ "'", 
                            "ParticleSystem.CmdBillboardType.doSet");
            }
            
            (cast(BillboardParticleRenderer)target).setBillboardType(t);
        }
    }
    /** Command object for billboard origin (see ParamCommand).*/
    static class CmdBillboardOrigin : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            BillboardOrigin o = (cast(BillboardParticleRenderer)target).getBillboardOrigin();
            final switch (o)
            {
                case BillboardOrigin.BBO_TOP_LEFT:
                    return "top_left";
                case BillboardOrigin.BBO_TOP_CENTER:
                    return "top_center";
                case BillboardOrigin.BBO_TOP_RIGHT:
                    return "top_right";
                case BillboardOrigin.BBO_CENTER_LEFT:
                    return "center_left";
                case BillboardOrigin.BBO_CENTER:
                    return "center";
                case BillboardOrigin.BBO_CENTER_RIGHT:
                    return "center_right";
                case BillboardOrigin.BBO_BOTTOM_LEFT:
                    return "bottom_left";
                case BillboardOrigin.BBO_BOTTOM_CENTER:
                    return "bottom_center";
                case BillboardOrigin.BBO_BOTTOM_RIGHT:
                    return "bottom_right";
            }
            // Compiler nicety
            return null;
        }

        void doSet(Object target,string val)
        {
            BillboardOrigin o;
            if (val == "top_left")
                o = BillboardOrigin.BBO_TOP_LEFT;
            else if (val =="top_center")
                o = BillboardOrigin.BBO_TOP_CENTER;
            else if (val =="top_right")
                o = BillboardOrigin.BBO_TOP_RIGHT;
            else if (val =="center_left")
                o = BillboardOrigin.BBO_CENTER_LEFT;
            else if (val =="center")
                o = BillboardOrigin.BBO_CENTER;
            else if (val =="center_right")
                o = BillboardOrigin.BBO_CENTER_RIGHT;
            else if (val =="bottom_left")
                o = BillboardOrigin.BBO_BOTTOM_LEFT;
            else if (val =="bottom_center")
                o = BillboardOrigin.BBO_BOTTOM_CENTER;
            else if (val =="bottom_right")
                o = BillboardOrigin.BBO_BOTTOM_RIGHT;
            else
            {
                throw new InvalidParamsError(
                            "Invalid billboard_origin '" ~ val ~ "'", 
                            "ParticleSystem.CmdBillboardOrigin.doSet");
            }
            
            (cast(BillboardParticleRenderer)target).setBillboardOrigin(o);
        }
    }
    /** Command object for billboard rotation type (see ParamCommand).*/
    static class CmdBillboardRotationType : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            BillboardRotationType r = (cast(BillboardParticleRenderer)target).getBillboardRotationType();
            final switch(r)
            {
                case BillboardRotationType.BBR_VERTEX:
                    return "vertex";
                case BillboardRotationType.BBR_TEXCOORD:
                    return "texcoord";
            }
            // Compiler nicety
            return null;
        }
        void doSet(Object target,string val)
        {
            BillboardRotationType r;
            if (val == "vertex")
                r = BillboardRotationType.BBR_VERTEX;
            else if (val == "texcoord")
                r = BillboardRotationType.BBR_TEXCOORD;
            else
            {
                throw new InvalidParamsError(
                            "Invalid billboard_rotation_type '" ~ val ~ "'", 
                            "ParticleSystem.CmdBillboardRotationType.doSet");
            }
            
            (cast(BillboardParticleRenderer)target).setBillboardRotationType(r);
        }
    }
    /** Command object for common direction (see ParamCommand).*/
    static class CmdCommonDirection : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string( (cast(BillboardParticleRenderer)target).getCommonDirection() );
        }
        void doSet(Object target,string val)
        {
            (cast(BillboardParticleRenderer)target).setCommonDirection(
                StringConverter.parseVector3(val));
        }
    }
    /** Command object for common up-vector (see ParamCommand).*/
    static class CmdCommonUpVector : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(BillboardParticleRenderer)target).getCommonUpVector() );
        }
        void doSet(Object target,string val)
        {
            (cast(BillboardParticleRenderer)target).setCommonUpVector(
                StringConverter.parseVector3(val));
        }
    }
    /** Command object for point rendering (see ParamCommand).*/
    static class CmdPointRendering : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(BillboardParticleRenderer)target).isPointRenderingEnabled() );
        }
        void doSet(Object target,string val)
        {
            (cast(BillboardParticleRenderer)target).setPointRenderingEnabled(
                std.conv.to!bool(val));
        }
    }
    /** Command object for accurate facing(see ParamCommand).*/
    static class CmdAccurateFacing : ParamCommand
    {
    public:
        string doGet(Object target)
        {
            return std.conv.to!string(
                (cast(BillboardParticleRenderer)target).getUseAccurateFacing() );
        }
        void doSet(Object target,string val)
        {
            (cast(BillboardParticleRenderer)target).setUseAccurateFacing(
                std.conv.to!bool(val));
        }
    }

    /** Sets the type of billboard to render.
        @remarks
            The default sort of billboard (BBT_POINT), always has both x and y axes parallel to 
            the camera's local axes. This is fine for 'point' style billboards (e.g. flares,
            smoke, anything which is symmetrical about a central point) but does not look good for
            billboards which have an orientation (e.g. an elongated raindrop). In this case, the
            oriented billboards are more suitable (BBT_ORIENTED_COMMON or BBT_ORIENTED_SELF) since they retain an independent Y axis
            and only the X axis is generated, perpendicular to both the local Y and the camera Z.
        @param bbt The type of billboard to render
        */
    void setBillboardType(BillboardType bbt)
    {
        mBillboardSet.setBillboardType(bbt);
    }
    
    /** Returns the billboard type in use. */
    BillboardType getBillboardType()
    {
        return mBillboardSet.getBillboardType();
    }
    
    /// @copydoc BillboardSet::setUseAccurateFacing
    void setUseAccurateFacing(bool acc)
    {
        mBillboardSet.setUseAccurateFacing(acc);
    }
    /// @copydoc BillboardSet::getUseAccurateFacing
    bool getUseAccurateFacing()
    {
        return mBillboardSet.getUseAccurateFacing();
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
    void setBillboardOrigin(BillboardOrigin origin) { mBillboardSet.setBillboardOrigin(origin); }
    
    /** Gets the point which acts as the origin point for all billboards in this set.
        @return
            A member of the BillboardOrigin enum specifying the origin for all the billboards in this set.
        */
    BillboardOrigin getBillboardOrigin(){ return mBillboardSet.getBillboardOrigin(); }
    
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
        mBillboardSet.setBillboardRotationType(rotationType);
    }
    
    /** Sets billboard rotation type.
        @return
            A member of the BillboardRotationType enum specifying the rotation type for all the billboards in this set.
        */
    BillboardRotationType getBillboardRotationType()
    {
        return mBillboardSet.getBillboardRotationType();
    }
    
    /** Use this to specify the common direction given to billboards of type BBT_ORIENTED_COMMON.
        @remarks
            Use BBT_ORIENTED_COMMON when you want oriented billboards but you know they are always going to 
            be oriented the same way (e.g. rain in calm weather). It is faster for the system to calculate
            the billboard vertices if they have a common direction.
        @param vec The direction for all billboards.
        */
    void setCommonDirection(Vector3 vec)
    {
        mBillboardSet.setCommonDirection(vec);
    }
    
    /** Gets the common direction for all billboards (BBT_ORIENTED_COMMON) */
   Vector3 getCommonDirection()
    {
        return mBillboardSet.getCommonDirection();
    }
    
    /** Use this to specify the common up-vector given to billboards of type BBT_PERPENDICULAR_SELF.
        @remarks
            Use BBT_PERPENDICULAR_SELF when you want oriented billboards perpendicular to their own
            direction vector and doesn't face to camera. In this case, we need an additional vector
            to determine the billboard X, Y axis. The generated X axis perpendicular to both the own
            direction and up-vector, the Y axis will coplanar with both own direction and up-vector,
            and perpendicular to own direction.
        @param vec The up-vector for all billboards.
        */
    void setCommonUpVector(Vector3 vec)
    {
        mBillboardSet.setCommonUpVector(vec);
    }
    
    /** Gets the common up-vector for all billboards (BBT_PERPENDICULAR_SELF) */
   Vector3 getCommonUpVector()
    {
        return mBillboardSet.getCommonUpVector();
    }
    
    /// @copydoc BillboardSet::setPointRenderingEnabled
    void setPointRenderingEnabled(bool enabled)
    {
        mBillboardSet.setPointRenderingEnabled(enabled);
    }
    
    /// @copydoc BillboardSet::isPointRenderingEnabled
    bool isPointRenderingEnabled()
    {
        return mBillboardSet.isPointRenderingEnabled();
    }
    
    
    
    /// @copydoc ParticleSystemRenderer::getType
    override string getType()
    {
        return rendererTypeName;
    }
    /// @copydoc ParticleSystemRenderer::_updateRenderQueue
    override void _updateRenderQueue(RenderQueue queue, 
                            Particle[] currentParticles, bool cullIndividually)
    {
        mBillboardSet.setCullIndividually(cullIndividually);
        
        // Update billboard set geometry
        mBillboardSet.beginBillboards(currentParticles.length);
        Billboard bb;
        foreach (p; currentParticles)
        {
            bb.mPosition = p.position;
            if (mBillboardSet.getBillboardType() == BillboardType.BBT_ORIENTED_SELF ||
                mBillboardSet.getBillboardType() == BillboardType.BBT_PERPENDICULAR_SELF)
            {
                // Normalise direction vector
                bb.mDirection = p.direction;
                bb.mDirection.normalise();
            }
            bb.mColour = p.colour;
            bb.mRotation = p.rotation;
            // Assign and compare at the same time
            if ((bb._OwnDimensions = p.mOwnDimensions) == true)
            {
                bb._Width = p.mWidth;
                bb._Height = p.mHeight;
            }
            mBillboardSet.injectBillboard(bb);
            
        }
        
        mBillboardSet.endBillboards();
        
        // Update the queue
        mBillboardSet._updateRenderQueue(queue);
    }

    /// @copydoc ParticleSystemRenderer::visitRenderables
    override void visitRenderables(Renderable.Visitor visitor, 
                          bool debugRenderables = false)
    {
        mBillboardSet.visitRenderables(visitor, debugRenderables);
    }

    /// @copydoc ParticleSystemRenderer::_setMaterial
    override void _setMaterial(SharedPtr!Material mat)
    {
        mBillboardSet.setMaterialName(mat.get().getName(), mat.get().getGroup());
    }

    /// @copydoc ParticleSystemRenderer::_notifyCurrentCamera
    override void _notifyCurrentCamera(Camera cam)
    {
        mBillboardSet._notifyCurrentCamera(cam);
    }
    /// @copydoc ParticleSystemRenderer::_notifyParticleRotated
    override void _notifyParticleRotated()
    {
        mBillboardSet._notifyBillboardRotated();
    }
    /// @copydoc ParticleSystemRenderer::_notifyParticleResized
    override void _notifyParticleResized()
    {
        mBillboardSet._notifyBillboardResized();
    }
    /// @copydoc ParticleSystemRenderer::_notifyParticleQuota
    override void _notifyParticleQuota(size_t quota)
    {
        mBillboardSet.setPoolSize(quota);
    }
    /// @copydoc ParticleSystemRenderer::_notifyAttached
    override void _notifyAttached(Node parent, bool isTagPoint = false)
    {
        mBillboardSet._notifyAttached(parent, isTagPoint);
    }
    /// @copydoc ParticleSystemRenderer::_notifyDefaultDimensions
    override void _notifyDefaultDimensions(Real width, Real height)
    {
        mBillboardSet.setDefaultDimensions(width, height);
    }
    /// @copydoc ParticleSystemRenderer::setRenderQueueGroup
    override void setRenderQueueGroup(ubyte queueID)
    {
        assert(queueID <= RenderQueueGroupID.RENDER_QUEUE_MAX, "Render queue out of range!");
        mBillboardSet.setRenderQueueGroup(queueID);
    }
    /// @copydoc MovableObject::setRenderQueueGroupAndPriority
    override void setRenderQueueGroupAndPriority(ubyte queueID, ushort priority)
    {
        assert(queueID <= RenderQueueGroupID.RENDER_QUEUE_MAX, "Render queue out of range!");
        mBillboardSet.setRenderQueueGroupAndPriority(queueID, priority);
    }
    /// @copydoc ParticleSystemRenderer::setKeepParticlesInLocalSpace
    override void setKeepParticlesInLocalSpace(bool keepLocal)
    {
        mBillboardSet.setBillboardsInWorldSpace(!keepLocal);
    }
    /// @copydoc ParticleSystemRenderer::_getSortMode
    override SortMode _getSortMode()
    {
        return mBillboardSet._getSortMode();
    }
    
    /// Access BillboardSet in use
    ref BillboardSet getBillboardSet(){ return mBillboardSet; }
    
protected:

    static CmdBillboardType    msBillboardTypeCmd;
    static CmdBillboardOrigin  msBillboardOriginCmd;
    static CmdBillboardRotationType msBillboardRotationTypeCmd;
    static CmdCommonDirection  msCommonDirectionCmd;
    static CmdCommonUpVector   msCommonUpVectorCmd;
    static CmdPointRendering   msPointRenderingCmd;
    static CmdAccurateFacing   msAccurateFacingCmd;

    static this()
    {
        msBillboardTypeCmd = new CmdBillboardType;
        msBillboardOriginCmd = new CmdBillboardOrigin;
        msBillboardRotationTypeCmd = new CmdBillboardRotationType;
        msCommonDirectionCmd = new CmdCommonDirection;
        msCommonUpVectorCmd = new CmdCommonUpVector;
        msPointRenderingCmd = new CmdPointRendering;
        msAccurateFacingCmd = new CmdAccurateFacing;
    }

    static string rendererTypeName = "billboard";
}

/** Factory class for BillboardParticleRenderer */
class BillboardParticleRendererFactory : ParticleSystemRendererFactory
{
public:
    /// @copydoc FactoryObj::getType
    override string getType()
    {
        return BillboardParticleRenderer.rendererTypeName;
    }
    /// @copydoc FactoryObj::createInstance
    override ParticleSystemRenderer createInstance(string name )
    {
        return new BillboardParticleRenderer();
    }
    /// @copydoc FactoryObj::destroyInstance
    override void destroyInstance(ref ParticleSystemRenderer ptr)
    {
        destroy(ptr);
    }
}
/** @} */
/** @} */