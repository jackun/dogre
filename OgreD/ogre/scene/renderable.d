module ogre.scene.renderable;

//TODO Import these also when someone is importing ogre.scene. Do it?
//For Renderable.Renderable_Impl
public
{
    import ogre.general.common;
    import ogre.materials.gpuprogram;
    import ogre.materials.material;
    import ogre.materials.technique;
    import ogre.math.vector;
    import ogre.exception;
    import ogre.scene.scenemanager;
    import ogre.scene.camera;
    import ogre.scene.userobjectbindings;
    import ogre.rendersystem.rendersystem;
    import ogre.rendersystem.renderoperation;
}

import ogre.math.matrix;
import ogre.compat;
import ogre.sharedptr;

/** Abstract class defining the interface all renderable objects must implement.
 @remarks
 This interface abstracts renderable discrete objects which will be queued in the render pipeline,
 grouped by material. Classes implementing this interface must be based on a single material, a single
 world matrix (or a collection of world matrices which are blended by weights), and must be 
 renderable via a single render operation.
 @par
 Note that deciding whether to put these objects in the rendering pipeline is done from the more specific
 classes e.g. entities. Only once it is decided that the specific class is to be rendered is the abstract version
 created (could be more than one per visible object) and pushed onto the rendering queue.
 @note    
 Use template mixin Renderable_Impl!() and mixin Renderable_Any_Impl!() for default implementations.
 */
interface Renderable
{
    
    /** An internal class that should be used only by a render system for internal use 
     @remarks
     This class was created so a render system can associate internal data to this class.
     The need for this class started when the DX10 render system needed to save state objects.
     */
    class RenderSystemData {}; //So classes can be defined in interfaces ? :P
    
    /** Default implementations. 
     @note Import SceneManager, RenderSystem etc. too in modules where Renderable is used.
     Otherwise error may show that this module is not importing stuff properly 
     instead of the implementer module. (compiler issue?)
     */
    template Renderable_Impl() // override error == derived class also mixin'g
    {
        // Atleast dmd lets us to import stuff like so
        /*private
         {
         //Incomplete list probably
         import ogre.general.common;
         import ogre.gpuprogram;
         import ogre.materials._package;
         import ogre.math.vector;
         import ogre.exception;
         import ogre.rendersystem._package;
         import ogre.scene;
         import ogre.scenemanager;
         }*/
    public:
        
        ~this() //Default, but call RenderableDestroy() if dtor is implemented in implementing class as dtor gets overridden.
        {
            DestroyRenderable();
        }
        
        /** destructor */
        //But if implementing class doesn't explicitly call this, then GC should take care of it anyway, probably.
        void DestroyRenderable()
        {
            if (mRenderSystemData)
            {
                destroy(mRenderSystemData);
                mRenderSystemData = null;
            }
        }
        
        Technique getTechnique()//
        { return getMaterial().getAs().getBestTechnique(0, this); }
        bool preRender(SceneManager sm, RenderSystem rsys) { return true; }
        void postRender(SceneManager sm, RenderSystem rsys) {  }
        ushort getNumWorldTransforms(){ return 1; }
        void setUseIdentityProjection(bool useIdentityProjection)
        { mUseIdentityProjection = useIdentityProjection; }
        bool getUseIdentityProjection()
        { return mUseIdentityProjection; }
        void setUseIdentityView(bool useIdentityView)
        { mUseIdentityView = useIdentityView; }
        bool getUseIdentityView()
        { return mUseIdentityView; }
        bool getCastsShadows()
        { return false; }
        void setCustomParameter(size_t index, Vector4 value) 
        { mCustomParameters[index] = value; }
        void removeCustomParameter(size_t index)
        { mCustomParameters.remove(index); }
        bool hasCustomParameter(size_t index)
        { return (index in mCustomParameters) !is null; }
        Vector4 getCustomParameter(size_t index)
        {
            auto i = index in mCustomParameters;
            if (i !is null)
            {
                return *i;
            }
            else
            {
                throw new ItemNotFoundError(
                    "Parameter at the given index was not found.",
                    "Renderable.getCustomParameter");
            }
        }
        void _updateCustomGpuParameter(
            GpuProgramParameters.AutoConstantEntry constantEntry,
            GpuProgramParameters params)
        {
            auto i = constantEntry.data in mCustomParameters;
            if (i !is null)
            {
                params._writeRawConstant(constantEntry.physicalIndex, *i, 
                                         constantEntry.elementCount);
            }
        }
        void setPolygonModeOverrideable(bool _override)
        { mPolygonModeOverrideable = _override; }
        bool getPolygonModeOverrideable()
        { return mPolygonModeOverrideable; }
        RenderSystemData getRenderSystemData()//
        { return mRenderSystemData; }
        void setRenderSystemData(RenderSystemData val)//
        { mRenderSystemData = val; }
        
        protected {
            alias Vector4[size_t] CustomParameterMap;
            CustomParameterMap mCustomParameters;
            bool mPolygonModeOverrideable = true;
            bool mUseIdentityProjection = false;
            bool mUseIdentityView = false;
            UserObjectBindings mUserObjectBindings;      /// User objects binding.
            RenderSystemData mRenderSystemData;/// This should be used only by a render system for internal use
        }
    }
    
    /** Implement default s/getUserAny and s/getUserObjectBindings if parent class (like MovableObject has) doesn't have any.
     */
    template Renderable_Any_Impl()
    {
        void setUserAny(Any anything) 
        { getUserObjectBindings().setUserAny(anything); }
        Any getUserAny()
        { return getUserObjectBindings().getUserAny(); }
        UserObjectBindings getUserObjectBindings() 
        { return mUserObjectBindings; }
    }

    //Uh MovableObject
    template Renderable_Any_Override_Impl()
    {
        override void setUserAny(Any anything) 
        { getUserObjectBindings().setUserAny(anything); }
        override Any getUserAny()
        { return getUserObjectBindings().getUserAny(); }
        override UserObjectBindings getUserObjectBindings() 
        { return mUserObjectBindings; }
    }
    
    /** Retrieves a weak reference to the material this renderable object uses.
     @remarks
     Note that the Renderable also has the option to override the getTechnique method
     to specify a particular Technique to use instead of the best one available.
     */
    SharedPtr!Material getMaterial();// const;
    /** Retrieves a pointer to the Material Technique this renderable object uses.
     @remarks
     This is to allow Renderables to use a chosen Technique if they wish, otherwise
     they will use the best Technique available for the Material they are using.
     */
    Technique getTechnique();// const;
    /** Gets the render operation required to send this object to the frame buffer.
     */
    void getRenderOperation(ref RenderOperation op);
    
    /** Called just prior to the Renderable being rendered. 
     @remarks
     OGRE is a queued renderer, so the actual render commands are executed 
     at a later time than the point at which an object is discovered to be
     visible. This allows ordering & grouping of renders without the discovery
     process having to be aware of it. It also means OGRE uses declarative
     render information rather than immediate mode rendering - this is very useful
     in that certain effects and processes can automatically be applied to 
     a wide range of scenes, but the downside is that special cases are
     more difficult to handle, because there is not the declared state to 
     cope with it. 
     @par
     This method allows a Renderable to do something special at the actual
     point of rendering if it wishes to. When this method is called, all the
     material render state as declared by this Renderable has already been set, 
     all that is left to do is to bind the buffers and perform the render. 
     The Renderable may modify render state itself if it wants to (and restore it in the 
     postRender call) before the automated render happens, or by returning
     'false' from this method can actually suppress the automatic render
     and perform one of its own.
     @return
     true if the automatic render should proceed, false to skip it on 
     the assumption that the Renderable has done it manually.
     */
    bool preRender(SceneManager sm, RenderSystem rsys);
    
    /** Called immediately after the Renderable has been rendered. 
     */
    void postRender(SceneManager sm, RenderSystem rsys);
    
    /** Gets the world transform matrix / matrices for this renderable object.
     @remarks
     If the object has any derived transforms, these are expected to be up to date as long as
     all the SceneNode structures have been updated before this is called.
     @par
     This method will populate transform with 1 matrix if it does not use vertex blending. If it
     does use vertex blending it will fill the passed in pointer with an array of matrices,
     the length being the value returned from getNumWorldTransforms.
     @note
     Internal Ogre never supports non-affine matrix for world transform matrix/matrices,
     the behavior is undefined if returns non-affine matrix here. @see Matrix4.isAffine.
     */
    void getWorldTransforms(ref Matrix4[] xform);//;
    
    /** Returns the number of world transform matrices this renderable requires.
     @remarks
     When a renderable uses vertex blending, it uses multiple world matrices instead of a single
     one. Each vertex sent to the pipeline can reference one or more matrices in this list
     with given weights.
     If a renderable does not use vertex blending this method returns 1, which is the default for 
     simplicity.
     */
    ushort getNumWorldTransforms();
    
    /** Sets whether or not to use an 'identity' projection.
     @remarks
     Usually Renderable objects will use a projection matrix as determined
     by the active camera. However, if they want they can cancel this out
     and use an identity projection, which effectively projects in 2D using
     a {-1, 1} view space. Useful for overlay rendering. Normal renderables
     need not change this. The default is false.
     @see Renderable.getUseIdentityProjection
     */
    void setUseIdentityProjection(bool useIdentityProjection);
    
    /** Returns whether or not to use an 'identity' projection.
     @remarks
     Usually Renderable objects will use a projection matrix as determined
     by the active camera. However, if they want they can cancel this out
     and use an identity projection, which effectively projects in 2D using
     a {-1, 1} view space. Useful for overlay rendering. Normal renderables
     need not change this.
     @see Renderable.setUseIdentityProjection
     */
    bool getUseIdentityProjection();
    
    /** Sets whether or not to use an 'identity' view.
     @remarks
     Usually Renderable objects will use a view matrix as determined
     by the active camera. However, if they want they can cancel this out
     and use an identity matrix, which means all geometry is assumed
     to be relative to camera space already. Useful for overlay rendering. 
     Normal renderables need not change this. The default is false.
     @see Renderable.getUseIdentityView
     */
    void setUseIdentityView(bool useIdentityView);
    
    /** Returns whether or not to use an 'identity' view.
     @remarks
     Usually Renderable objects will use a view matrix as determined
     by the active camera. However, if they want they can cancel this out
     and use an identity matrix, which means all geometry is assumed
     to be relative to camera space already. Useful for overlay rendering. 
     Normal renderables need not change this.
     @see Renderable.setUseIdentityView
     */
    bool getUseIdentityView();
    
    /** Returns the camera-relative squared depth of this renderable.
     @remarks
     Used to sort transparent objects. Squared depth is used rather than
     actual depth to avoid having to perform a square root on the result.
     */
    Real getSquaredViewDepth(Camera cam);
    
    /** Gets a list of lights, ordered relative to how close they are to this renderable.
     @remarks
     Directional lights, which have no position, will always be first on this list.
     */
    LightList getLights();
    
    /** Method which reports whether this renderable would normally cast a
     shadow. 
     @remarks
     Subclasses should override this if they could have been used to 
     generate a shadow.
     */
    bool getCastsShadows();
    
    /** Sets a custom parameter for this Renderable, which may be used to 
     drive calculations for this specific Renderable, like GPU program parameters.
     @remarks
     Calling this method simply associates a numeric index with a 4-dimensional
     value for this specific Renderable. This is most useful if the material
     which this Renderable uses a vertex or fragment program, and has an 
     ACT_CUSTOM parameter entry. This parameter entry can ref er to the
     index you specify as part of this call, thereby mapping a custom
     parameter for this renderable to a program parameter.
     @param index The index with which to associate the value. Note that this
     does not have to start at 0, and can include gaps. It also has no direct
     correlation with a GPU program parameter index - the mapping between the
     two is performed by the ACT_CUSTOM entry, if that is used.
     @param value The value to associate.
     */
    void setCustomParameter(size_t index, Vector4 value);
    
    /** Removes a custom value which is associated with this Renderable at the given index.
     @param index
     @see setCustomParameter for full details.
     */
    void removeCustomParameter(size_t index);
    
    /** Checks whether a custom value is associated with this Renderable at the given index.
     @param index
     @see setCustomParameter for full details.
     */
    bool hasCustomParameter(size_t index);
    
    /** Gets the custom value associated with this Renderable at the given index.
     @param index
     @see setCustomParameter for full details.
     */
    Vector4 getCustomParameter(size_t index);
    
    /** Update a custom GpuProgramParametersant which is derived from 
     information only this Renderable knows.
     @remarks
     This method allows a Renderable to map in a custom GPU program parameter
     based on it's own data. This is represented by a GPU auto parameter
     of ACT_CUSTOM, and to allow there to be more than one of these per
     Renderable, the 'data' field on the auto parameter will identify
     which parameter is being updated. The implementation of this method
     must identify the parameter being updated, and call a 'setConstant' 
     method on the passed in GpuProgramParameters object, using the details
     provided in the incoming autoant setting to identify the index
     at which to set the parameter.
     @par
     You do not need to override this method if you're using the standard
     sets of data associated with the Renderable as provided by setCustomParameter
     and getCustomParameter. By default, the implementation will map from the
     value indexed by the 'constantEntry.data' parameter to a value previously
     set by setCustomParameter. But custom Renderables are free to override
     this if they want, in any case.
     @param constantEntry The auto constant entry referring to the parameter
     being updated
     @param params The parameters object which this method should call to 
     set the updated parameters.
     */
    void _updateCustomGpuParameter(
        GpuProgramParameters.AutoConstantEntry constantEntry,
        GpuProgramParameters params);
    
    /** Sets whether this renderable's chosen detail level can be
     overridden (downgraded) by the camera setting. 
     @param override true means that a lower camera detail will override this
     renderables detail level, false means it won't.
     */
    void setPolygonModeOverrideable(bool _override);
    
    /** Gets whether this renderable's chosen detail level can be
     overridden (downgraded) by the camera setting. 
     */
    bool getPolygonModeOverrideable();
    
    /** @deprecated use UserObjectBindings.setUserAny via getUserObjectBindings() instead.
     Sets any kind of user value on this object.
     @remarks
     This method allows you to associate any user value you like with 
     this Renderable. This can be a pointer back to one of your own
     classes for instance.
     */
    void setUserAny(Any anything);
    
    /** @deprecated use UserObjectBindings.getUserAny via getUserObjectBindings() instead.
     Retrieves the custom user value associated with this object.
     */
    Any getUserAny();
    
    /** Return an instance of user objects binding associated with this class.
     You can use it to associate one or more custom objects with this class instance.
     @see UserObjectBindings.setUserAny.
     */
    UserObjectBindings getUserObjectBindings();

    
    /** Visitor object that can be used to iterate over a collection of Renderable
     instances abstractly.
     @remarks
     Different scene objects use Renderable differently; some will have a 
     single Renderable, others will have many. This visitor interface allows
     classes using Renderable to expose a clean way for external code to
     get access to the contained Renderable instance(s) that it will
     eventually add to the render queue.
     @par
     To actually have this method called, you have to call a method on the
     class containing the Renderable instances. One example is 
     MovableObject.visitRenderables.
     */
    interface Visitor
    {
        /** Generic visitor method. 
         @param rend The Renderable instance being visited
         @param lodIndex The LOD index to which this Renderable belongs. Some
         objects support LOD and this will tell you whether the Renderable
         you're looking at is from the top LOD (0) or otherwise
         @param isDebug Whether this is a debug renderable or not.
         @param pAny Optional pointer to some additional data that the class
         calling the visitor may populate if it chooses to.
         */
        void visit(Renderable rend, ushort lodIndex, bool isDebug, 
                   Any pAny = Any());
    }
    
    /** Gets RenderSystem private data
     @remarks
     This should only be used by a RenderSystem
     */
    RenderSystemData getRenderSystemData();//;
    
    /** Sets RenderSystem private data
     @remarks
     This should only be used by a RenderSystem
     */
    void setRenderSystemData(RenderSystemData val);//;
}

//FIXME Heh, workaround for SubEntity super._updateCustomGpuParameter(constantEntry, params);
class RenderableClass : Renderable
{
    mixin Renderable.Renderable_Impl!();
    mixin Renderable.Renderable_Any_Impl;

    SharedPtr!Material getMaterial() { throw new NotImplementedError(); }
    void getRenderOperation(ref RenderOperation op) { throw new NotImplementedError(); }
    void getWorldTransforms(ref Matrix4[] xform) { throw new NotImplementedError(); }
    Real getSquaredViewDepth(Camera cam) { throw new NotImplementedError(); }
    LightList getLights() { throw new NotImplementedError(); }
}
