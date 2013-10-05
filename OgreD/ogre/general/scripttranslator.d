module ogre.general.scripttranslator;
import std.traits;
import std.conv;
import std.string;
import std.array;
alias std.string.indexOf indexOf;

import ogre.compat;
import ogre.general.scriptcompiler;
import ogre.materials.blendmode;
import ogre.general.common;
import ogre.rendersystem.rendersystem;
import ogre.materials.gpuprogram;
import ogre.materials.material;
import ogre.materials.materialmanager;
import ogre.lod.lodstrategy;
import ogre.lod.distancelodstrategy;
import ogre.lod.lodstrategymanager;
import ogre.materials.technique;
import ogre.scene.light;
import ogre.materials.pass;
import ogre.image.pixelformat;
import ogre.general.root;
import ogre.resources.texture;
import ogre.image.images;
import ogre.materials.textureunitstate;
import ogre.materials.externaltexturesourcemanager;
import ogre.math.matrix;
import ogre.effects.particlesystem;
import ogre.effects.particleemitter;
import ogre.effects.particleaffector;
import ogre.effects.compositor;
import ogre.effects.compositiontechnique;
import ogre.effects.compositiontargetpass;
import ogre.effects.compositionpass;
import ogre.general.colourvalue;
import ogre.strings;
import ogre.math.angles;
import ogre.resources.highlevelgpuprogram;
import ogre.effects.particlesystemmanager;
import ogre.effects.compositormanager;

/** \addtogroup Core
    *  @{
    */
/** \addtogroup General
    *  @{
    */    
GpuProgramType translateIDToGpuProgramType(uint id)
{
    switch (id)
    {
        case ID_VERTEX_PROGRAM:
        default:
            return GpuProgramType.GPT_VERTEX_PROGRAM;
        case ID_GEOMETRY_PROGRAM:
            return GpuProgramType.GPT_GEOMETRY_PROGRAM;
        case ID_FRAGMENT_PROGRAM:
            return GpuProgramType.GPT_FRAGMENT_PROGRAM;
        case ID_TESSELATION_HULL_PROGRAM:
            return GpuProgramType.GPT_HULL_PROGRAM;
        case ID_TESSELATION_DOMAIN_PROGRAM:
            return GpuProgramType.GPT_DOMAIN_PROGRAM;
        case ID_COMPUTE_PROGRAM:
            return GpuProgramType.GPT_COMPUTE_PROGRAM;
    }
}

/** This class translates script AST (abstract syntax tree) into
     *  Ogre resources. It defines a common interface for subclasses
     *  which perform the actual translation.
     */

class ScriptTranslator //: ScriptTranslatorAlloc
{
public:
    /**
         * This function translates the given node into Ogre resource(s).
         * @param compiler The compiler invoking this translator
         * @param node The current AST node to be translated
         */
    abstract void translate(ScriptCompiler compiler, /*const*/ AbstractNodePtr node);
protected:
    // needs destructor
    ~this() {}

    /// Retrieves a new translator from the factories and uses it to process the give node
    void processNode(ScriptCompiler compiler, /*const*/ AbstractNodePtr node)
    {
        if(node.type != ANT_OBJECT)
            return;

        // Abstract objects are completely skipped
        if((cast(ObjectAbstractNode)node.get())._abstract)
            return;

        // Retrieve the translator to use
        ScriptTranslator translator =
            ScriptCompilerManager.getSingleton().getTranslator(node);

        if(translator)
            translator.translate(compiler, node);
        else
            compiler.addError(ScriptCompiler.CE_UNEXPECTEDTOKEN, node.file, node.line,
                              "token \"" ~ (cast(ObjectAbstractNode)node.get()).cls ~ "\" is not recognized");
    }

    /// Retrieves the node iterator at the given index
    static AbstractNodePtr getNodeAt(/*const*/ AbstractNodeList nodes, size_t index)
    {
        if(index < nodes.length)
            return nodes[index];
        return AbstractNodePtr();
    }
    
    /// Converts the node to a boolean and returns true if successful
    static bool getBoolean(/*const*/ AbstractNodePtr node, ref bool result)
    {
        if(node.isNull() || node.type != ANT_ATOM)
            return false;
        AtomAbstractNode atom = cast(AtomAbstractNode)node.get();
        if(atom.id != 1 && atom.id != 2)
            return false;

        result = (atom.id == 1);
        return true;
    }

    /// Converts the node to a string and returns true if successful
    static bool getString(/*const*/ AbstractNodePtr node, ref string result)
    {
        if(node.isNull() || node.type != ANT_ATOM)
            return false;
        AtomAbstractNode atom = cast(AtomAbstractNode)node.get();
        result = atom.value;
        return true;
    }

    //XXX Merging different get*s into a template
    /// Converts the node to a value type and returns true if successful
    static bool get(T)(/*const*/ AbstractNodePtr node, ref T result)
        if(is(T == Real) || is(T == float) || is(T == double) || is(T == int) ||
        is(T == uint) || is(T == long) || is(T == ulong) || is(T == size_t))
    {
        if(node.isNull() || node.type != ANT_ATOM)
            return false;

        AtomAbstractNode atom = cast(AtomAbstractNode)node.get();
        try
        {
            result = to!T(atom.value);
        }
        catch(ConvException e)
            return false;

        return true;
    }

    /// Converts the range of nodes to a ColourValue and returns true if successful
    /// @param tokens Slice of tokens to parse
    static bool getColour(AbstractNodeList tokens, ref ColourValue result, int maxEntries = 4)
    {
        size_t n = 0;
        while(n < tokens.length && n < maxEntries)
        {
            float v = 0;
            if(get!float(tokens[n], v))
            {
                switch(n)
                {
                    case 0:
                        result.r = v;
                        break;
                    case 1:
                        result.g = v;
                        break;
                    case 2:
                        result.b = v;
                        break;
                    case 3:
                        result.a = v;
                        break;
                    default:
                        break;
                }
            }
            else
            {
                return false;
            }
            ++n;
        }
        // return error if we found less than rgb before end, unless constrained
        return (n >= 3 || n == maxEntries);
    }

    /// Converts the node to a SceneBlendFactor enum and returns true if successful
    static bool getSceneBlendFactor(/*const*/ AbstractNodePtr node, ref SceneBlendFactor sbf)
    {
        if(node.isNull() || node.type != ANT_ATOM)
            return false;
        AtomAbstractNode atom = cast(AtomAbstractNode)node.get();
        switch(atom.id)
        {
            case ID_ONE:
                sbf = SceneBlendFactor.SBF_ONE;
                break;
            case ID_ZERO:
                sbf = SceneBlendFactor.SBF_ZERO;
                break;
            case ID_DEST_COLOUR:
                sbf = SceneBlendFactor.SBF_DEST_COLOUR;
                break;
            case ID_DEST_ALPHA:
                sbf = SceneBlendFactor.SBF_DEST_ALPHA;
                break;
            case ID_SRC_ALPHA:
                sbf = SceneBlendFactor.SBF_SOURCE_ALPHA;
                break;
            case ID_SRC_COLOUR:
                sbf = SceneBlendFactor.SBF_SOURCE_COLOUR;
                break;
            case ID_ONE_MINUS_DEST_COLOUR:
                sbf = SceneBlendFactor.SBF_ONE_MINUS_DEST_COLOUR;
                break;
            case ID_ONE_MINUS_SRC_COLOUR:
                sbf = SceneBlendFactor.SBF_ONE_MINUS_SOURCE_COLOUR;
                break;
            case ID_ONE_MINUS_DEST_ALPHA:
                sbf = SceneBlendFactor.SBF_ONE_MINUS_DEST_ALPHA;
                break;
            case ID_ONE_MINUS_SRC_ALPHA:
                sbf = SceneBlendFactor.SBF_ONE_MINUS_SOURCE_ALPHA;
                break;
            default:
                return false;
        }
        return true;
    }

    /// Converts the node to a CompareFunction enum and returns true if successful
    static bool getCompareFunction(/*const*/ AbstractNodePtr node, ref CompareFunction func)
    {
        if(node.isNull() || node.type != ANT_ATOM)
            return false;
        AtomAbstractNode atom = cast(AtomAbstractNode)node.get();
        switch(atom.id)
        {
            case ID_ALWAYS_FAIL:
                func = CompareFunction.CMPF_ALWAYS_FAIL;
                break;
            case ID_ALWAYS_PASS:
                func = CompareFunction.CMPF_ALWAYS_PASS;
                break;
            case ID_LESS:
                func = CompareFunction.CMPF_LESS;
                break;
            case ID_LESS_EQUAL:
                func = CompareFunction.CMPF_LESS_EQUAL;
                break;
            case ID_EQUAL:
                func = CompareFunction.CMPF_EQUAL;
                break;
            case ID_NOT_EQUAL:
                func = CompareFunction.CMPF_NOT_EQUAL;
                break;
            case ID_GREATER_EQUAL:
                func = CompareFunction.CMPF_GREATER_EQUAL;
                break;
            case ID_GREATER:
                func = CompareFunction.CMPF_GREATER;
                break;
            default:
                return false;
        }
        return true;
    }

    /** Converts the range of nodes to a Matrix4 and returns true if successful
     @param tokens Slice of tokens to parse */
    static bool getMatrix4(AbstractNodeList tokens, ref Matrix4 m)
    {
        size_t n = 0;
        while(n < tokens.length && n < 16)
        {
            if(n < tokens.length)
            {
                Real r = 0;
                if(get(tokens[n], r))
                    m[n/4, n%4] = r;
                else
                    return false;
            }
            else
            {
                return false;
            }
            ++n;
        }
        return true;
    }

    /// Converts the range of nodes to an array of ints and returns true if successful
    static bool get(A:V[], V)(AbstractNodeList tokens, ref A vals, int count) //TODO Templating could be wrong
        if(/*isArray!A &&*/ (is(V == Real) || is(V == float) || is(V == int)))
    {
        bool success = true;
        size_t n = 0;
        while(n < count)
        {
            if(n < tokens.length)
            {
                V v;
                if(get(tokens[n], v))
                    vals ~= v;
                else
                    break;
            }
            else
                vals ~= 0;
            ++n;
        }

        if(n < count)
            success = false;

        return success;
    }

    /// Converts the node to a StencilOperation enum and returns true if successful
    static bool getStencilOp(/*const*/ AbstractNodePtr node, ref StencilOperation op)
    {
        if(node.isNull() || node.type != ANT_ATOM)
            return false;
        AtomAbstractNode atom = cast(AtomAbstractNode)node.get();
        switch(atom.id)
        {
            case ID_KEEP:
                op = StencilOperation.SOP_KEEP;
                break;
            case ID_ZERO:
                op = StencilOperation.SOP_ZERO;
                break;
            case ID_REPLACE:
                op = StencilOperation.SOP_REPLACE;
                break;
            case ID_INCREMENT:
                op = StencilOperation.SOP_INCREMENT;
                break;
            case ID_DECREMENT:
                op = StencilOperation.SOP_DECREMENT;
                break;
            case ID_INCREMENT_WRAP:
                op = StencilOperation.SOP_INCREMENT_WRAP;
                break;
            case ID_DECREMENT_WRAP:
                op = StencilOperation.SOP_DECREMENT_WRAP;
                break;
            case ID_INVERT:
                op = StencilOperation.SOP_INVERT;
                break;
            default:
                return false;
        }
        return true;
    }

    /// Converts the node to a GpuConstantType enum and returns true if successful
    static bool getConstantType(AbstractNodePtr token, ref GpuConstantType op)
    {

        string val;
        getString(token, val);
        if(val.indexOf("float") != -1)
        {
            int count = 1;
            if (val.length == 6)
                count = to!int(val[5..$].strip());
            else if (val.length > 6)
                return false;

            if (count > 4 || count == 0)
                return false;

            op = cast(GpuConstantType)(GpuConstantType.GCT_FLOAT1 + count - 1);
        }
        else if(val.indexOf("double") != -1)
        {
            int count = 1;
            if (val.length == 6)
                count = to!int(val[5..$].strip());
            else if (val.length > 6)
                return false;
            
            if (count > 4 || count == 0)
                return false;
            
            op = cast(GpuConstantType)(GpuConstantType.GCT_DOUBLE1 + count - 1);
        }
        else if(val.indexOf("int") != -1)
        {
            int count = 1;
            if (val.length == 4)
                count = to!int(val[3..$].strip());
            else if (val.length > 4)
                return false;

            if (count > 4 || count == 0)
                return false;

            op = cast(GpuConstantType)(GpuConstantType.GCT_INT1 + count - 1);
        }
        else if(val.indexOf("matrix") != -1)
        {
            int count1, count2;

            if (val.length == 9)
            {
                count1 = to!int(val[6..7]);
                count2 = to!int(val[8..9]);
            }
            else
                return false;

            if (count1 > 4 || count1 < 2 || count2 > 4 || count2 < 2)
                return false;

            switch(count1)
            {
                case 2:
                    op = cast(GpuConstantType)(GpuConstantType.GCT_MATRIX_2X2 + count2 - 2);
                    break;
                case 3:
                    op = cast(GpuConstantType)(GpuConstantType.GCT_MATRIX_3X2 + count2 - 2);
                    break;
                case 4:
                    op = cast(GpuConstantType)(GpuConstantType.GCT_MATRIX_4X2 + count2 - 2);
                    break;
                default:
                    break;
            }

        }

        return true;
    }

}

/** The ScriptTranslatorManager manages the lifetime and access to
     *  script translators. You register these managers with the
     *  ScriptCompilerManager tied to specific object types.
     *  Each manager may manage multiple types.
     */
interface ScriptTranslatorManager //: ScriptTranslatorAlloc
{
    /// Returns the number of translators being managed
    size_t getNumTranslators();// const;
    /// Returns a manager for the given object abstract node, or null if it is not supported
    ScriptTranslator getTranslator(/*const*/ AbstractNodePtr);
}

/**************************************************************************
     * Material compilation section
     *************************************************************************/
class MaterialTranslator : ScriptTranslator
{
protected:
    Material mMaterial;
    AliasTextureNamePairList mTextureAliases;
public:
    this() {}
    
    override void translate(ScriptCompiler compiler, /*const*/ AbstractNodePtr node)
    {
        ObjectAbstractNode obj = cast(ObjectAbstractNode)node.get();
        if(obj.name.empty())
            compiler.addError(ScriptCompiler.CE_OBJECTNAMEEXPECTED, obj.file, obj.line);
        
        // Create a material with the given name
        auto evt = new CreateMaterialScriptCompilerEvent(node.file, obj.name, compiler.getResourceGroup());
        bool processed = compiler._fireEvent(evt, cast(void*)&mMaterial);
        
        if(!processed)
        {
            mMaterial = cast(Material)(MaterialManager.getSingleton().create(obj.name, compiler.getResourceGroup()).get());
        }
        else
        {
            if(!mMaterial)
                compiler.addError(ScriptCompiler.CE_OBJECTALLOCATIONERROR, obj.file, obj.line, 
                                  "failed to find or create material \"" ~ obj.name ~ "\"");
        }
        
        mMaterial.removeAllTechniques();
        obj.context = Any(mMaterial);
        mMaterial._notifyOrigin(obj.file);
        
        foreach(i; obj.children)
        {
            if(i.type == ANT_PROPERTY)
            {
                PropertyAbstractNode prop = cast(PropertyAbstractNode)i.get();
                switch(prop.id)
                {
                    case ID_LOD_VALUES:
                    {
                        Material.LodValueList lods;
                        foreach(j; prop.values)
                        {
                            Real v = 0;
                            if(get(j, v))
                                lods ~= v;
                            else
                                compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line,
                                                  "lod_values expects only numbers as arguments");
                        }
                        mMaterial.setLodLevels(lods);
                    }
                        break;
                    case ID_LOD_DISTANCES:
                    {
                        // Set strategy to distance strategy
                        LodStrategy strategy = DistanceLodStrategy.getSingleton();
                        mMaterial.setLodStrategy(strategy);
                        
                        // Read in lod distances
                        Material.LodValueList lods;
                        foreach(j; prop.values)
                        {
                            Real v = 0;
                            if(get(j, v))
                                lods ~= v;
                            else
                                compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line,
                                                  "lod_values expects only numbers as arguments");
                        }
                        mMaterial.setLodLevels(lods);
                    }
                        break;
                    case ID_LOD_STRATEGY:
                        if (prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if (prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "lod_strategy only supports 1 argument");
                        }
                        else
                        {
                            string strategyName;
                            bool result = getString(prop.values.front, strategyName);
                            if (result)
                            {
                                LodStrategy strategy = LodStrategyManager.getSingleton().getStrategy(strategyName);
                                
                                result = (strategy !is null);
                                
                                if (result)
                                    mMaterial.setLodStrategy(strategy);
                            }
                            
                            if (!result)
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "lod_strategy argument must be a valid lod strategy");
                            }
                        }
                        break;
                    case ID_RECEIVE_SHADOWS:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "receive_shadows only supports 1 argument");
                        }
                        else
                        {
                            bool val = true;
                            if(getBoolean(prop.values.front, val))
                                mMaterial.setReceiveShadows(val);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "receive_shadows argument must be \"true\", \"false\", \"yes\", \"no\", \"on\", or \"off\"");
                        }
                        break;
                    case ID_TRANSPARENCY_CASTS_SHADOWS:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "transparency_casts_shadows only supports 1 argument");
                        }
                        else
                        {
                            bool val = true;
                            if(getBoolean(prop.values.front, val))
                                mMaterial.setTransparencyCastsShadows(val);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "transparency_casts_shadows argument must be \"true\", \"false\", \"yes\", \"no\", \"on\", or \"off\"");
                        }
                        break;
                    case ID_SET_TEXTURE_ALIAS:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 3)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "set_texture_alias only supports 2 arguments");
                        }
                        else
                        {
                            AbstractNodePtr i0 = prop.values[0], i1 = prop.values[1];
                            string name, value;
                            if(getString(i0, name) && getString(i1, value))
                                mTextureAliases[name] = value;
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "set_texture_alias must have 2 string argument");
                        }
                        break;
                    default:
                        compiler.addError(ScriptCompiler.CE_UNEXPECTEDTOKEN, prop.file, prop.line, 
                                          "token \"" ~ prop.name ~ "\" is not recognized");
                }
            }
            else if(i.type == ANT_OBJECT)
            {
                processNode(compiler, i);
            }
        }
        
        // Apply the texture aliases
        if(compiler.getListener())
        {
            auto locEvt = new PreApplyTextureAliasesScriptCompilerEvent(mMaterial, mTextureAliases);
            compiler._fireEvent(locEvt, null);
        }
        mMaterial.applyTextureAliases(mTextureAliases);
        mTextureAliases.clear();//TODO Needs clear?
    }
}

class TechniqueTranslator : ScriptTranslator
{
protected:
    Technique mTechnique;
public:
    this() {}
    override void translate(ScriptCompiler compiler, /*const*/ AbstractNodePtr node)
    {
        ObjectAbstractNode obj = cast(ObjectAbstractNode)node.get();
        
        // Create the technique from the material
        Material material = obj.parent.context.get!Material;
        mTechnique = material.createTechnique();
        obj.context = Any(mTechnique);
        
        // Get the name of the technique
        if(!obj.name.empty())
            mTechnique.setName(obj.name);
        
        // Set the properties for the material
        foreach(i; obj.children)
        {
            if(i.type == ANT_PROPERTY)
            {
                PropertyAbstractNode prop = cast(PropertyAbstractNode)i.get();
                switch(prop.id)
                {
                    case ID_SCHEME:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "scheme only supports 1 argument");
                        }
                        else
                        {
                            AbstractNodePtr i0 = prop.values[0];
                            string scheme;
                            if(getString(i0, scheme))
                                mTechnique.setSchemeName(scheme);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "scheme must have 1 string argument");
                        }
                        break;
                    case ID_LOD_INDEX:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "lod_index only supports 1 argument");
                        }
                        else
                        {
                            AbstractNodePtr i0 = prop.values[0];
                            uint v = 0;
                            if(get(i0, v))
                                mTechnique.setLodIndex(cast(ushort)v);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "lod_index cannot accept argument \"" ~ i0.getValue() ~ "\"");
                        }
                        break;
                    case ID_SHADOW_CASTER_MATERIAL:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "shadow_caster_material only accepts 1 argument");
                        }
                        else
                        {
                            AbstractNodePtr i0 = prop.values[0];
                            string matName;
                            if(getString(i0, matName))
                            {
                                auto evt = new ProcessResourceNameScriptCompilerEvent(ProcessResourceNameScriptCompilerEvent.MATERIAL, matName);
                                compiler._fireEvent(evt, null);
                                mTechnique.setShadowCasterMaterial(evt.mName); // Use the processed name
                            }
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "shadow_caster_material cannot accept argument \"" ~ i0.getValue() ~ "\"");
                        }
                        break;
                    case ID_SHADOW_RECEIVER_MATERIAL:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "shadow_receiver_material only accepts 1 argument");
                        }
                        else
                        {
                            AbstractNodePtr i0 = prop.values[0];
                            string matName;
                            if(getString(i0, matName))
                            {
                                auto evt = new ProcessResourceNameScriptCompilerEvent(ProcessResourceNameScriptCompilerEvent.MATERIAL, matName);
                                compiler._fireEvent(evt, null);
                                mTechnique.setShadowReceiverMaterial(evt.mName);
                            }
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "shadow_receiver_material_name cannot accept argument \"" ~ i0.getValue() ~ "\"");
                        }
                        break;
                    case ID_GPU_VENDOR_RULE:
                        if(prop.values.length < 2)
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line,
                                              "gpu_vendor_rule must have 2 arguments");
                        }
                        else if(prop.values.length > 2)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "gpu_vendor_rule must have 2 arguments");
                        }
                        else
                        {
                            AbstractNodePtr i0 = prop.values[0], i1 = prop.values[1];
                            
                            Technique.GPUVendorRule rule;
                            if (i0.type == ANT_ATOM)
                            {
                                AtomAbstractNode atom0 = cast(AtomAbstractNode)i0.get();
                                if (atom0.id == ID_INCLUDE)
                                {
                                    rule.includeOrExclude = Technique.INCLUDE;
                                }
                                else if (atom0.id == ID_EXCLUDE)
                                {
                                    rule.includeOrExclude = Technique.EXCLUDE;
                                }
                                else
                                {
                                    compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                      "gpu_vendor_rule cannot accept \"" ~ i0.getValue() ~ "\" as first argument");
                                }
                                
                                string vendor;
                                if(!getString(i1, vendor))
                                    compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                      "gpu_vendor_rule cannot accept \"" ~ i1.getValue() ~ "\" as second argument");
                                
                                rule.vendor = RenderSystemCapabilities.vendorFromString(vendor);
                                
                                if (rule.vendor != GPUVendor.GPU_UNKNOWN)
                                {
                                    mTechnique.addGPUVendorRule(rule);
                                }
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "gpu_vendor_rule cannot accept \"" ~ i0.getValue() ~ "\" as first argument");
                            }
                            
                        }
                        break;
                    case ID_GPU_DEVICE_RULE:
                        if(prop.values.length < 2)
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line,
                                              "gpu_device_rule must have at least 2 arguments");
                        }
                        else if(prop.values.length > 3)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "gpu_device_rule must have at most 3 arguments");
                        }
                        else
                        {
                            AbstractNodePtr i0 = prop.values[0], i1 = prop.values[1];
                            
                            Technique.GPUDeviceNameRule rule;
                            if (i0.type == ANT_ATOM)
                            {
                                AtomAbstractNode atom0 = cast(AtomAbstractNode)i0.get();
                                if (atom0.id == ID_INCLUDE)
                                {
                                    rule.includeOrExclude = Technique.INCLUDE;
                                }
                                else if (atom0.id == ID_EXCLUDE)
                                {
                                    rule.includeOrExclude = Technique.EXCLUDE;
                                }
                                else
                                {
                                    compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                      "gpu_device_rule cannot accept \"" ~ i0.getValue() ~ "\" as first argument");
                                }
                                
                                if(!getString(i1, rule.devicePattern))
                                    compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                      "gpu_device_rule cannot accept \"" ~ i1.getValue() ~ "\" as second argument");
                                
                                if (prop.values.length == 3)
                                {
                                    AbstractNodePtr i2 = prop.values[2];
                                    if (!getBoolean(i2, rule.caseSensitive))
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          "gpu_device_rule third argument must be \"true\", \"false\", \"yes\", \"no\", \"on\", or \"off\"");
                                }
                                
                                mTechnique.addGPUDeviceNameRule(rule);
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "gpu_device_rule cannot accept \"" ~ i0.getValue() ~ "\" as first argument");
                            }
                            
                        }
                        break;
                    default:
                        compiler.addError(ScriptCompiler.CE_UNEXPECTEDTOKEN, prop.file, prop.line, 
                                          "token \"" ~ prop.name ~ "\" is not recognized");
                }
            }
            else if(i.type == ANT_OBJECT)
            {
                processNode(compiler, i);
            }
        }
    }
}

class PassTranslator : ScriptTranslator
{
protected:
    Pass mPass;
public:
    this(){}
    override void translate(ScriptCompiler compiler, /*const*/ AbstractNodePtr node)
    {
        ObjectAbstractNode obj = cast(ObjectAbstractNode)(node.get());
        
        Technique technique = obj.parent.context.get!Technique;
        mPass = technique.createPass();
        obj.context = Any(mPass);
        
        // Get the name of the technique
        if(!obj.name.empty())
            mPass.setName(obj.name);
        
        // Set the properties for the material
        foreach(i; obj.children)
        {
            if(i.type == ANT_PROPERTY)
            {
                PropertyAbstractNode prop = cast(PropertyAbstractNode)(i.get());
                switch(prop.id)
                {
                    case ID_AMBIENT:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 4)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                               "ambient must have at most 4 parameters");
                        }
                        else
                        {
                            if(prop.values.front.type == ANT_ATOM && 
                               (cast(AtomAbstractNode)prop.values.front.get()).id == ID_VERTEXCOLOUR)
                            {
                                mPass.setVertexColourTracking(mPass.getVertexColourTracking() | TVC_AMBIENT);
                            }
                            else
                            {
                                ColourValue val = ColourValue.White;
                                if(getColour(prop.values, val))
                                    mPass.setAmbient(val);
                                else
                                    compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                      "ambient requires 3 or 4 colour arguments, or a \"vertexcolour\" directive");
                            }
                        }
                        break;
                    case ID_DIFFUSE:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 4)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                               "diffuse must have at most 4 arguments");
                        }
                        else
                        {
                            if(prop.values.front.type == ANT_ATOM && 
                               (cast(AtomAbstractNode)prop.values.front.get()).id == ID_VERTEXCOLOUR)
                            {
                                mPass.setVertexColourTracking(mPass.getVertexColourTracking() | TVC_DIFFUSE);
                            }
                            else
                            {
                                ColourValue val = ColourValue.White;
                                if(getColour(prop.values, val))
                                    mPass.setDiffuse(val);
                                else
                                    compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                       "diffuse requires 3 or 4 colour arguments, or a \"vertexcolour\" directive");
                            }
                        }
                        break;
                    case ID_SPECULAR:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 5)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                               "specular must have at most 5 arguments");
                        }
                        else
                        {
                            if(prop.values.front.type == ANT_ATOM && 
                               (cast(AtomAbstractNode)prop.values.front.get()).id == ID_VERTEXCOLOUR)
                            {
                                mPass.setVertexColourTracking(mPass.getVertexColourTracking() | TVC_SPECULAR);
                                
                                if(prop.values.length >= 2)
                                {
                                    Real val = 0;
                                    if(get(prop.values.back, val))
                                        mPass.setShininess(val);
                                    else
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          "specular does not support \"" ~ prop.values.back().getValue() ~ "\" as its second argument");
                                }
                            }
                            else
                            {
                                if(prop.values.length < 4)
                                {
                                    compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line,
                                                      "specular expects at least 4 arguments");
                                }
                                else
                                {
                                    AbstractNodePtr i0 = prop.values[0], i1 = prop.values[1], i2 = prop.values[2];
                                    ColourValue val = ColourValue(0.0f, 0.0f, 0.0f, 1.0f);
                                    if(get!float(i0, val.r) && get!float(i1, val.g) && get!float(i2, val.b))
                                    {
                                        if(prop.values.length == 4)
                                        {
                                            mPass.setSpecular(val);
                                            
                                            AbstractNodePtr i3 = prop.values[3];
                                            Real shininess = 0.0f;
                                            if(get(i3, shininess))
                                                mPass.setShininess(shininess);
                                            else
                                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                                  "specular fourth argument must be a valid number for shininess attribute");
                                        }
                                        else
                                        {
                                            AbstractNodePtr i3 = prop.values[3];
                                            if(!get!float(i3, val.a))
                                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                                  "specular fourth argument must be a valid color component value");
                                            else
                                                mPass.setSpecular(val);
                                            
                                            AbstractNodePtr i4 = prop.values[4];
                                            Real shininess = 0.0f;
                                            if(get(i4, shininess))
                                                mPass.setShininess(shininess);
                                            else
                                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                                  "specular fourth argument must be a valid number for shininess attribute"); 
                                        }
                                    }
                                    else
                                    {
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          "specular must have first 3 arguments be a valid colour");
                                    }   
                                }
                                
                            }
                        }
                        break;
                    case ID_EMISSIVE:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 4)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "emissive must have at most 4 arguments");
                        }
                        else
                        {
                            if(prop.values.front.type == ANT_ATOM && 
                               (cast(AtomAbstractNode)prop.values.front.get()).id == ID_VERTEXCOLOUR)
                            {
                                mPass.setVertexColourTracking(mPass.getVertexColourTracking() | TVC_EMISSIVE);
                            }
                            else
                            {
                                ColourValue val = ColourValue(0.0f, 0.0f, 0.0f, 1.0f);
                                if(getColour(prop.values, val))
                                    mPass.setSelfIllumination(val);
                                else
                                    compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                      "emissive requires 3 or 4 colour arguments, or a \"vertexcolour\" directive");
                            }
                        }
                        break;
                    case ID_SCENE_BLEND:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 2)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "scene_blend supports at most 2 arguments");
                        }
                        else if(prop.values.length == 1)
                        {
                            if(prop.values.front.type == ANT_ATOM)
                            {
                                AtomAbstractNode atom = cast(AtomAbstractNode)prop.values.front.get();
                                switch(atom.id)
                                {
                                    case ID_ADD:
                                        mPass.setSceneBlending(SceneBlendType.SBT_ADD);
                                        break;
                                    case ID_MODULATE:
                                        mPass.setSceneBlending(SceneBlendType.SBT_MODULATE);
                                        break;
                                    case ID_COLOUR_BLEND:
                                        mPass.setSceneBlending(SceneBlendType.SBT_TRANSPARENT_COLOUR);
                                        break;
                                    case ID_ALPHA_BLEND:
                                        mPass.setSceneBlending(SceneBlendType.SBT_TRANSPARENT_ALPHA);
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          "scene_blend does not support \"" ~ prop.values.front.getValue() ~ "\" for argument 1");
                                }
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "scene_blend does not support \"" ~ prop.values.front.getValue() ~ "\" for argument 1");
                            }
                        }
                        else
                        {
                            AbstractNodePtr i0 = prop.values[0], i1 = prop.values[1];
                            SceneBlendFactor sbf0, sbf1;
                            if(getSceneBlendFactor(i0, sbf0) && getSceneBlendFactor(i1, sbf1))
                            {
                                mPass.setSceneBlending(sbf0, sbf1);
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "scene_blend does not support \"" ~ i0.getValue() ~ "\" and \"" ~ i1.getValue() ~ "\" as arguments");
                            }               
                        }
                        break;
                    case ID_SEPARATE_SCENE_BLEND:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length == 3)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "separate_scene_blend must have 2 or 4 arguments");
                        }
                        else if(prop.values.length > 4)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "separate_scene_blend must have 2 or 4 arguments");
                        }
                        else if(prop.values.length == 2)
                        {
                            AbstractNodePtr i0 = prop.values[0], i1 = prop.values[1];
                            if(i0.type == ANT_ATOM && i1.type == ANT_ATOM)
                            {
                                AtomAbstractNode atom0 = cast(AtomAbstractNode)i0.get(), atom1 = cast(AtomAbstractNode)i1.get();
                                SceneBlendType sbt0, sbt1;
                                switch(atom0.id)
                                {
                                    case ID_ADD:
                                        sbt0 = SceneBlendType.SBT_ADD;
                                        break;
                                    case ID_MODULATE:
                                        sbt0 = SceneBlendType.SBT_MODULATE;
                                        break;
                                    case ID_COLOUR_BLEND:
                                        sbt0 = SceneBlendType.SBT_TRANSPARENT_COLOUR;
                                        break;
                                    case ID_ALPHA_BLEND:
                                        sbt0 = SceneBlendType.SBT_TRANSPARENT_ALPHA;
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          "separate_scene_blend does not support \"" ~ atom0.value ~ "\" as argument 1");
                                        return;
                                }
                                
                                switch(atom1.id)
                                {
                                    case ID_ADD:
                                        sbt1 = SceneBlendType.SBT_ADD;
                                        break;
                                    case ID_MODULATE:
                                        sbt1 = SceneBlendType.SBT_MODULATE;
                                        break;
                                    case ID_COLOUR_BLEND:
                                        sbt1 = SceneBlendType.SBT_TRANSPARENT_COLOUR;
                                        break;
                                    case ID_ALPHA_BLEND:
                                        sbt1 = SceneBlendType.SBT_TRANSPARENT_ALPHA;
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          "separate_scene_blend does not support \"" ~ atom1.value ~ "\" as argument 2");
                                        return;
                                }
                                
                                mPass.setSeparateSceneBlending(sbt0, sbt1);
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "separate_scene_blend does not support \"" ~ i0.getValue() ~ "\" as argument 1");
                            }
                        }
                        else
                        {
                            AbstractNodePtr i0 = prop.values[0], i1 = prop.values[1],
                                i2 = prop.values[2], i3 = prop.values[3];
                            if(i0.type == ANT_ATOM && i1.type == ANT_ATOM && i2.type == ANT_ATOM && i3.type == ANT_ATOM)
                            {
                                SceneBlendFactor sbf0, sbf1, sbf2, sbf3;
                                if(getSceneBlendFactor(i0, sbf0) && getSceneBlendFactor(i1, sbf1) && getSceneBlendFactor(i2, sbf2) && 
                                   getSceneBlendFactor(i3, sbf3))
                                {
                                    mPass.setSeparateSceneBlending(sbf0, sbf1, sbf2, sbf3);
                                }
                                else
                                {
                                    compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                      "one of the arguments to separate_scene_blend is not a valid scene blend factor directive");
                                }
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "one of the arguments to separate_scene_blend is not a valid scene blend factor directive");
                            }
                        }
                        break;
                    case ID_SCENE_BLEND_OP:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "scene_blend_op must have 1 argument");
                        }
                        else
                        {
                            if(prop.values.front.type == ANT_ATOM)
                            {
                                AtomAbstractNode atom = cast(AtomAbstractNode)(prop.values.front.get());
                                switch(atom.id)
                                {
                                    case ID_ADD:
                                        mPass.setSceneBlendingOperation(SceneBlendOperation.SBO_ADD);
                                        break;
                                    case ID_SUBTRACT:
                                        mPass.setSceneBlendingOperation(SceneBlendOperation.SBO_SUBTRACT);
                                        break;
                                    case ID_REVERSE_SUBTRACT:
                                        mPass.setSceneBlendingOperation(SceneBlendOperation.SBO_REVERSE_SUBTRACT);
                                        break;
                                    case ID_MIN:
                                        mPass.setSceneBlendingOperation(SceneBlendOperation.SBO_MIN);
                                        break;
                                    case ID_MAX:
                                        mPass.setSceneBlendingOperation(SceneBlendOperation.SBO_MAX);
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          atom.value ~ ": unrecognized argument");
                                }
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front.getValue() ~ ": unrecognized argument");
                            }
                        }
                        break;
                    case ID_SEPARATE_SCENE_BLEND_OP:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length != 2)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "separate_scene_blend_op must have 2 arguments");
                        }
                        else
                        {
                            AbstractNodePtr i0 = prop.values[0], i1 = prop.values[1];
                            if(i0.type == ANT_ATOM && i1.type == ANT_ATOM)
                            {
                                AtomAbstractNode atom0 = cast(AtomAbstractNode)(i0.get()),
                                    atom1 = cast(AtomAbstractNode)(i1.get());
                                SceneBlendOperation op = SceneBlendOperation.SBO_ADD, alphaOp = SceneBlendOperation.SBO_ADD;
                                switch(atom0.id)
                                {
                                    case ID_ADD:
                                        op = SceneBlendOperation.SBO_ADD;
                                        break;
                                    case ID_SUBTRACT:
                                        op = SceneBlendOperation.SBO_SUBTRACT;
                                        break;
                                    case ID_REVERSE_SUBTRACT:
                                        op = SceneBlendOperation.SBO_REVERSE_SUBTRACT;
                                        break;
                                    case ID_MIN:
                                        op = SceneBlendOperation.SBO_MIN;
                                        break;
                                    case ID_MAX:
                                        op = SceneBlendOperation.SBO_MAX;
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          atom0.value ~ ": unrecognized first argument");
                                }
                                
                                switch(atom1.id)
                                {
                                    case ID_ADD:
                                        alphaOp = SceneBlendOperation.SBO_ADD;
                                        break;
                                    case ID_SUBTRACT:
                                        alphaOp = SceneBlendOperation.SBO_SUBTRACT;
                                        break;
                                    case ID_REVERSE_SUBTRACT:
                                        alphaOp = SceneBlendOperation.SBO_REVERSE_SUBTRACT;
                                        break;
                                    case ID_MIN:
                                        alphaOp = SceneBlendOperation.SBO_MIN;
                                        break;
                                    case ID_MAX:
                                        alphaOp = SceneBlendOperation.SBO_MAX;
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          atom1.value ~ ": unrecognized second argument");
                                }
                                
                                mPass.setSeparateSceneBlendingOperation(op, alphaOp);
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front.getValue() ~ ": unrecognized argument");
                            }
                        }
                        break;
                    case ID_DEPTH_CHECK:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "depth_check must have 1 argument");
                        }
                        else
                        {
                            bool val = true;
                            if(getBoolean(prop.values.front, val))
                                mPass.setDepthCheckEnabled(val);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "depth_check third argument must be \"true\", \"false\", \"yes\", \"no\", \"on\", or \"off\"");
                        }
                        break;
                    case ID_DEPTH_WRITE:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "depth_write must have 1 argument");
                        }
                        else
                        {
                            bool val = true;
                            if(getBoolean(prop.values.front, val))
                                mPass.setDepthWriteEnabled(val);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "depth_write third argument must be \"true\", \"false\", \"yes\", \"no\", \"on\", or \"off\"");
                        }
                        break;
                    case ID_DEPTH_BIAS:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 2)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "depth_bias must have at most 2 arguments");
                        }
                        else
                        {
                            AbstractNodePtr i0 = prop.values[0], i1 = getNodeAt(prop.values, 1);
                            float val0, val1 = 0.0f;
                            if(get!float(i0, val0))
                            {
                                if(!i1.isNull())
                                    get!float(i1, val1);
                                mPass.setDepthBias(val0, val1);
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "depth_bias does not support \"" ~ i0.getValue() ~ "\" for argument 1");
                            }
                        }
                        break;
                    case ID_DEPTH_FUNC:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "depth_func must have 1 argument");
                        }
                        else
                        {
                            CompareFunction func;
                            if(getCompareFunction(prop.values.front, func))
                                mPass.setDepthFunction(func);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front.getValue() ~ " is not a valid CompareFunction");
                        }
                        break;
                    case ID_ITERATION_DEPTH_BIAS:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "iteration_depth_bias must have 1 argument");
                        }
                        else
                        {
                            float val = 0.0f;
                            if(get!float(prop.values.front, val))
                                mPass.setIterationDepthBias(val);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front.getValue() ~ " is not a valid float value");
                        }
                        break;
                    case ID_ALPHA_REJECTION:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 2)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "alpha_rejection must have at most 2 arguments");
                        }
                        else
                        {
                            AbstractNodePtr i0 = prop.values[0], i1 = getNodeAt(prop.values, 1);
                            CompareFunction func;
                            if(getCompareFunction(i0, func))
                            {
                                if(!i1.isNull())
                                {
                                    uint val = 0;
                                    if(get(i1, val))
                                        mPass.setAlphaRejectSettings(func, cast(ubyte)val);
                                    else
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          i1.getValue() ~ " is not a valid integer");
                                }
                                else
                                    mPass.setAlphaRejectFunction(func);
                            }
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  i0.getValue() ~ " is not a valid CompareFunction");
                        }
                        break;
                    case ID_ALPHA_TO_COVERAGE:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "alpha_to_coverage must have 1 argument");
                        }
                        else
                        {
                            bool val = true;
                            if(getBoolean(prop.values.front, val))
                                mPass.setAlphaToCoverageEnabled(val);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "alpha_to_coverage argument must be \"true\", \"false\", \"yes\", \"no\", \"on\", or \"off\"");
                        }
                        break;
                    case ID_LIGHT_SCISSOR:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "light_scissor must have only 1 argument");
                        }
                        else
                        {
                            bool val = false;
                            if(getBoolean(prop.values.front, val))
                                mPass.setLightScissoringEnabled(val);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front.getValue() ~ " is not a valid boolean");
                        }
                        break;
                    case ID_LIGHT_CLIP_PLANES:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "light_clip_planes must have at most 1 argument");
                        }
                        else
                        {
                            bool val = false;
                            if(getBoolean(prop.values.front, val))
                                mPass.setLightClipPlanesEnabled(val);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front.getValue() ~ " is not a valid boolean");
                        }
                        break;
                    case ID_TRANSPARENT_SORTING:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "transparent_sorting must have at most 1 argument");
                        }
                        else
                        {
                            bool val = true;
                            if(getBoolean(prop.values.front, val)) 
                            {
                                mPass.setTransparentSortingEnabled(val);
                                mPass.setTransparentSortingForced(false);
                            } 
                            else 
                            {
                                string val2;
                                if (getString(prop.values.front, val2) && val2=="force") 
                                {
                                    mPass.setTransparentSortingEnabled(true);
                                    mPass.setTransparentSortingForced(true);
                                }
                                else 
                                {
                                    compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                      prop.values.front.getValue() ~ " must be boolean or force");
                                }
                            }    
                        }
                        break;
                    case ID_ILLUMINATION_STAGE:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "illumination_stage must have at most 1 argument");
                        }
                        else
                        {
                            if(prop.values.front.type == ANT_ATOM)
                            {
                                AtomAbstractNode atom = cast(AtomAbstractNode)prop.values.front.get();
                                switch(atom.id)
                                {
                                    case ID_AMBIENT:
                                        mPass.setIlluminationStage(IlluminationStage.IS_AMBIENT);
                                        break;
                                    case ID_PER_LIGHT:
                                        mPass.setIlluminationStage(IlluminationStage.IS_PER_LIGHT);
                                        break;
                                    case ID_DECAL:
                                        mPass.setIlluminationStage(IlluminationStage.IS_DECAL);
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          prop.values.front.getValue() ~ " is not a valid IlluminationStage");
                                }
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front.getValue() ~ " is not a valid IlluminationStage");
                            }
                        }
                        break;
                    case ID_CULL_HARDWARE:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "cull_hardware must have at most 1 argument");
                        }
                        else
                        {
                            if(prop.values.front.type == ANT_ATOM)
                            {
                                AtomAbstractNode atom = cast(AtomAbstractNode)prop.values.front.get();
                                switch(atom.id)
                                {
                                    case ID_CLOCKWISE:
                                        mPass.setCullingMode(CullingMode.CULL_CLOCKWISE);
                                        break;
                                    case ID_ANTICLOCKWISE:
                                        mPass.setCullingMode(CullingMode.CULL_ANTICLOCKWISE);
                                        break;
                                    case ID_NONE:
                                        mPass.setCullingMode(CullingMode.CULL_NONE);
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          prop.values.front.getValue() ~ " is not a valid CullingMode");
                                }
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front.getValue() ~ " is not a valid CullingMode");
                            }
                        }
                        break;
                    case ID_CULL_SOFTWARE:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "cull_software must have at most 1 argument");
                        }
                        else
                        {
                            if(prop.values.front.type == ANT_ATOM)
                            {
                                AtomAbstractNode atom = cast(AtomAbstractNode)prop.values.front.get();
                                switch(atom.id)
                                {
                                    case ID_FRONT:
                                        mPass.setManualCullingMode(ManualCullingMode.MANUAL_CULL_FRONT);
                                        break;
                                    case ID_BACK:
                                        mPass.setManualCullingMode(ManualCullingMode.MANUAL_CULL_BACK);
                                        break;
                                    case ID_NONE:
                                        mPass.setManualCullingMode(ManualCullingMode.MANUAL_CULL_NONE);
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          prop.values.front.getValue() ~ " is not a valid ManualCullingMode");
                                }
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front.getValue() ~ " is not a valid ManualCullingMode");
                            }
                        }
                        break;
                    case ID_NORMALISE_NORMALS:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "normalise_normals must have at most 1 argument");
                        }
                        else
                        {
                            bool val = false;
                            if(getBoolean(prop.values.front, val))
                                mPass.setNormaliseNormals(val);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front.getValue() ~ " is not a valid boolean");
                        }
                        break;
                    case ID_LIGHTING:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "lighting must have at most 1 argument");
                        }
                        else
                        {
                            bool val = false;
                            if(getBoolean(prop.values.front, val))
                                mPass.setLightingEnabled(val);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front.getValue() ~ " is not a valid boolean");
                        }
                        break;
                    case ID_SHADING:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "shading must have at most 1 argument");
                        }
                        else
                        {
                            if(prop.values.front.type == ANT_ATOM)
                            {
                                AtomAbstractNode atom = cast(AtomAbstractNode)prop.values.front.get();
                                switch(atom.id)
                                {
                                    case ID_FLAT:
                                        mPass.setShadingMode(ShadeOptions.SO_FLAT);
                                        break;
                                    case ID_GOURAUD:
                                        mPass.setShadingMode(ShadeOptions.SO_GOURAUD);
                                        break;
                                    case ID_PHONG:
                                        mPass.setShadingMode(ShadeOptions.SO_PHONG);
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          prop.values.front.getValue() ~ " is not a valid shading mode (flat, gouraud, or phong)");
                                }
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front.getValue() ~ " is not a valid shading mode (flat, gouraud, or phong)");
                            }
                        }
                        break;
                    case ID_POLYGON_MODE:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "polygon_mode must have at most 1 argument");
                        }
                        else
                        {
                            if(prop.values.front.type == ANT_ATOM)
                            {
                                AtomAbstractNode atom = cast(AtomAbstractNode)prop.values.front.get();
                                switch(atom.id)
                                {
                                    case ID_SOLID:
                                        mPass.setPolygonMode(PolygonMode.PM_SOLID);
                                        break;
                                    case ID_POINTS:
                                        mPass.setPolygonMode(PolygonMode.PM_POINTS);
                                        break;
                                    case ID_WIREFRAME:
                                        mPass.setPolygonMode(PolygonMode.PM_WIREFRAME);
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          prop.values.front.getValue() ~ " is not a valid polygon mode (solid, points, or wireframe)");
                                }
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front.getValue() ~ " is not a valid polygon mode (solid, points, or wireframe)");
                            }
                        }
                        break;
                    case ID_POLYGON_MODE_OVERRIDEABLE:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "polygon_mode_overrideable must have at most 1 argument");
                        }
                        else
                        {
                            bool val = false;
                            if(getBoolean(prop.values.front, val))
                                mPass.setPolygonModeOverrideable(val);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front.getValue() ~ " is not a valid boolean");
                        }
                        break;
                    case ID_FOG_OVERRIDE:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 8)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "fog_override must have at most 8 arguments");
                        }
                        else
                        {
                            AbstractNodePtr i1 = getNodeAt(prop.values, 1), i2 = getNodeAt(prop.values, 2);
                            bool val = false;
                            if(getBoolean(prop.values.front, val))
                            {
                                FogMode mode = FogMode.FOG_NONE;
                                ColourValue clr = ColourValue.White;
                                Real dens = 0.001, start = 0.0f, end = 1.0f;
                                
                                if(!i1.isNull())
                                {
                                    if(i1.type == ANT_ATOM)
                                    {
                                        AtomAbstractNode atom = cast(AtomAbstractNode)i1.get();
                                        switch(atom.id)
                                        {
                                            case ID_NONE:
                                                mode = FogMode.FOG_NONE;
                                                break;
                                            case ID_LINEAR:
                                                mode = FogMode.FOG_LINEAR;
                                                break;
                                            case ID_EXP:
                                                mode = FogMode.FOG_EXP;
                                                break;
                                            case ID_EXP2:
                                                mode = FogMode.FOG_EXP2;
                                                break;
                                            default:
                                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                                  i1.getValue() ~ " is not a valid FogMode");
                                                break;
                                        }
                                    }
                                    else
                                    {
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          i1.getValue() ~ " is not a valid FogMode");
                                        break;
                                    }
                                }
                                
                                if(!i2.isNull())
                                {
                                    if(!getColour(prop.values[2..5], clr, 3))
                                    {
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          i2.getValue() ~ " is not a valid colour");
                                        break;
                                    }
                                    
                                    i2 = getNodeAt(prop.values, 5);
                                } 
                                
                                if(!i2.isNull())
                                {
                                    if(!get(i2, dens))
                                    {
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          i2.getValue() ~ " is not a valid number");
                                        break;
                                    }
                                    i2 = getNodeAt(prop.values, 6);
                                }
                                
                                if(!i2.isNull())
                                {
                                    if(!get(i2, start))
                                    {
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                           i2.getValue() ~ " is not a valid number");
                                        return;
                                    }
                                    i2 = getNodeAt(prop.values, 7);
                                }
                                
                                if(!i2.isNull())
                                {
                                    if(!get(i2, end))
                                    {
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                           i2.getValue() ~ " is not a valid number");
                                        return;
                                    }
                                    i2 = getNodeAt(prop.values, 8);
                                }
                                
                                mPass.setFog(val, mode, clr, dens, start, end);
                            }
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                   prop.values.front.getValue() ~ " is not a valid boolean");
                        }
                        break;
                    case ID_COLOUR_WRITE:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                               "colour_write must have at most 1 argument");
                        }
                        else
                        {
                            bool val = false;
                            if(getBoolean(prop.values.front, val))
                                mPass.setColourWriteEnabled(val);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front.getValue() ~ " is not a valid boolean");
                        }
                        break;
                    case ID_MAX_LIGHTS:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "max_lights must have at most 1 argument");
                        }
                        else
                        {
                            uint val = 0;
                            if(get(prop.values.front, val))
                                mPass.setMaxSimultaneousLights(cast(ushort)val);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front.getValue() ~ " is not a valid integer");
                        }
                        break;
                    case ID_START_LIGHT:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "start_light must have at most 1 argument");
                        }
                        else
                        {
                            uint val = 0;
                            if(get(prop.values.front, val))
                                mPass.setStartLight(cast(ushort)val);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front.getValue() ~ " is not a valid integer");
                        }
                        break;
                    case ID_LIGHT_MASK:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else
                        {
                            uint val = 0;
                            if(get(prop.values.front, val))
                                mPass.setLightMask(cast(ushort)val);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front.getValue() ~ " is not a valid integer");
                        }
                        break;
                    case ID_ITERATION:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else
                        {
                        AbstractNodePtr i0 = prop.values[0];
                            if(i0.type == ANT_ATOM)
                            {
                                AtomAbstractNode atom = cast(AtomAbstractNode)i0.get();
                                if(atom.id == ID_ONCE)
                                {
                                    mPass.setIteratePerLight(false);
                                }
                                else if(atom.id == ID_ONCE_PER_LIGHT)
                                {
                                    AbstractNodePtr i1 = getNodeAt(prop.values, 1);
                                    if(!i1.isNull() && i1.type == ANT_ATOM)
                                    {
                                        atom = cast(AtomAbstractNode)i1.get();
                                        switch(atom.id)
                                        {
                                            case ID_POINT:
                                                mPass.setIteratePerLight(true);
                                                break;
                                            case ID_DIRECTIONAL:
                                                mPass.setIteratePerLight(true, true, Light.LightTypes.LT_DIRECTIONAL);
                                                break;
                                            case ID_SPOT:
                                                mPass.setIteratePerLight(true, true, Light.LightTypes.LT_SPOTLIGHT);
                                                break;
                                            default:
                                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                                  prop.values.front.getValue() ~ " is not a valid light type (point, directional, or spot)");
                                        }
                                    }
                                    else
                                    {
                                        mPass.setIteratePerLight(true, false);
                                    }
                                    
                                }
                                else if(StringUtil.isNumber(atom.value))
                                {
                                    mPass.setPassIterationCount(to!int(atom.value));
                                    
                                    AbstractNodePtr i1 = getNodeAt(prop.values, 1);
                                    if(!i1.isNull() && i1.type == ANT_ATOM)
                                    {
                                        atom = cast(AtomAbstractNode)i1.get();
                                        if(atom.id == ID_PER_LIGHT)
                                        {
                                            AbstractNodePtr i2 = getNodeAt(prop.values, 2);
                                            if(!i2.isNull() && i2.type == ANT_ATOM)
                                            {
                                                atom = cast(AtomAbstractNode)i2.get();
                                                switch(atom.id)
                                                {
                                                    case ID_POINT:
                                                        mPass.setIteratePerLight(true);
                                                        break;
                                                    case ID_DIRECTIONAL:
                                                        mPass.setIteratePerLight(true, true, Light.LightTypes.LT_DIRECTIONAL);
                                                        break;
                                                    case ID_SPOT:
                                                        mPass.setIteratePerLight(true, true, Light.LightTypes.LT_SPOTLIGHT);
                                                        break;
                                                    default:
                                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                                          i2.getValue() ~ " is not a valid light type (point, directional, or spot)");
                                                }
                                            }
                                            else
                                            {
                                                mPass.setIteratePerLight(true, false);
                                            }
                                        }
                                        else if(ID_PER_N_LIGHTS)
                                        {
                                            AbstractNodePtr i2 = getNodeAt(prop.values, 2);
                                            if(!i2.isNull() && i2.type == ANT_ATOM)
                                            {
                                                atom = cast(AtomAbstractNode)i2.get();
                                                if(isDigits(atom.value))
                                                {
                                                    mPass.setLightCountPerIteration(to!ushort(atom.value));
                                                    
                                                    AbstractNodePtr i3 = getNodeAt(prop.values, 3);
                                                    if(!i3.isNull() && i3.type == ANT_ATOM)
                                                    {
                                                        atom = cast(AtomAbstractNode)i3.get();
                                                        switch(atom.id)
                                                        {
                                                            case ID_POINT:
                                                                mPass.setIteratePerLight(true);
                                                                break;
                                                            case ID_DIRECTIONAL:
                                                                mPass.setIteratePerLight(true, true, Light.LightTypes.LT_DIRECTIONAL);
                                                                break;
                                                            case ID_SPOT:
                                                                mPass.setIteratePerLight(true, true, Light.LightTypes.LT_SPOTLIGHT);
                                                                break;
                                                            default:
                                                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                                                  i3.getValue() ~ " is not a valid light type (point, directional, or spot)");
                                                        }
                                                    }
                                                    else
                                                    {
                                                        mPass.setIteratePerLight(true, false);
                                                    }
                                                }
                                                else
                                                {
                                                    compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line,
                                                                      i2.getValue() ~ " is not a valid number");
                                                }
                                            }
                                            else
                                            {
                                                compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line,
                                                                  prop.values.front.getValue() ~ " is not a valid number");
                                            }
                                        }
                                    }
                                }
                                else
                                {
                                    compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                                }
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                            }
                        }
                        break;
                    case ID_POINT_SIZE:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "point_size must have at most 1 argument");
                        }
                        else
                        {
                            Real val = 0.0f;
                            if(get(prop.values.front, val))
                                mPass.setPointSize(val);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front.getValue() ~ " is not a valid number");
                        }
                        break;
                    case ID_POINT_SPRITES:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "point_sprites must have at most 1 argument");
                        }
                        else
                        {
                            bool val = false;
                            if(getBoolean(prop.values.front, val))
                                mPass.setPointSpritesEnabled(val);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front.getValue() ~ " is not a valid boolean");
                        }
                        break;
                    case ID_POINT_SIZE_ATTENUATION:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 4)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "point_size_attenuation must have at most 4 arguments");
                        }
                        else
                        {
                            bool val = false;
                            if(getBoolean(prop.values.front, val))
                            {
                                if(val)
                                {
                                    AbstractNodePtr i1 = getNodeAt(prop.values, 1), 
                                        i2 = getNodeAt(prop.values, 2), 
                                        i3 = getNodeAt(prop.values, 3);
                                    
                                    if (prop.values.length > 1)
                                    {
                                        
                                        Real constant = 0.0f, linear = 1.0f, quadratic = 0.0f;
                                        
                                        if(!i1.isNull() && i1.type == ANT_ATOM)
                                        {
                                            AtomAbstractNode atom = cast(AtomAbstractNode)i1.get();
                                            if(StringUtil.isNumber(atom.value))
                                                constant = to!Real(atom.value);
                                            else
                                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                                        }
                                        else
                                        {
                                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                              i1.getValue() ~ " is not a valid number");
                                        }
                                        
                                        if(!i2.isNull() && i2.type == ANT_ATOM)
                                        {
                                            AtomAbstractNode atom = cast(AtomAbstractNode)i2.get();
                                            if(StringUtil.isNumber(atom.value))
                                                linear = to!Real(atom.value);
                                            else
                                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                                        }
                                        else
                                        {
                                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                              i2.getValue() ~ " is not a valid number");
                                        }
                                        
                                        if(!i3.isNull() && i3.type == ANT_ATOM)
                                        {
                                            AtomAbstractNode atom = cast(AtomAbstractNode)i3.get();
                                            if(StringUtil.isNumber(atom.value))
                                                quadratic = to!Real(atom.value);
                                            else
                                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                                        }
                                        else
                                        {
                                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                              i3.getValue() ~ " is not a valid number");
                                        }
                                        
                                        mPass.setPointAttenuation(true, constant, linear, quadratic);
                                    }
                                    else
                                    {
                                        mPass.setPointAttenuation(true);
                                    }
                                }
                                else
                                {
                                    mPass.setPointAttenuation(false);
                                }
                            }
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front.getValue() ~ " is not a valid boolean");
                        }
                        break;
                    case ID_POINT_SIZE_MIN:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "point_size_min must have at most 1 argument");
                        }
                        else
                        {
                            Real val = 0.0f;
                            if(get(prop.values.front, val))
                                mPass.setPointMinSize(val);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front.getValue() ~ " is not a valid number");
                        }
                        break;
                    case ID_POINT_SIZE_MAX:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "point_size_max must have at most 1 argument");
                        }
                        else
                        {
                            Real val = 0.0f;
                            if(get(prop.values.front, val))
                                mPass.setPointMaxSize(val);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front.getValue() ~ " is not a valid number");
                        }
                        break;
                    default:
                        compiler.addError(ScriptCompiler.CE_UNEXPECTEDTOKEN, prop.file, prop.line, 
                                          "token \"" ~ prop.name ~ "\" is not recognized");
                }
            }
            else if(i.type == ANT_OBJECT)
            {
                ObjectAbstractNode child = cast(ObjectAbstractNode)(i.get());
                switch(child.id)
                {
                    case ID_FRAGMENT_PROGRAM_REF:
                        translateFragmentProgramRef(compiler, child);
                        break;
                    case ID_VERTEX_PROGRAM_REF:
                        translateVertexProgramRef(compiler, child);
                        break;
                    case ID_GEOMETRY_PROGRAM_REF:
                        translateGeometryProgramRef(compiler, child);
                        break;
                    case ID_TESSELATION_HULL_PROGRAM_REF:
                        translateTesselationHullProgramRef(compiler, child);
                        break;
                    case ID_TESSELATION_DOMAIN_PROGRAM_REF:
                        translateTesselationDomainProgramRef(compiler, child);
                        break;
                    case ID_COMPUTE_PROGRAM_REF:
                        translateComputeProgramRef(compiler, child);
                        break;
                    case ID_SHADOW_CASTER_VERTEX_PROGRAM_REF:
                        translateShadowCasterVertexProgramRef(compiler, child);
                        break;
                    case ID_SHADOW_CASTER_FRAGMENT_PROGRAM_REF:
                        translateShadowCasterFragmentProgramRef(compiler, child);
                        break;
                    case ID_SHADOW_RECEIVER_VERTEX_PROGRAM_REF:
                        translateShadowReceiverVertexProgramRef(compiler, child);
                        break;
                    case ID_SHADOW_RECEIVER_FRAGMENT_PROGRAM_REF:
                        translateShadowReceiverFragmentProgramRef(compiler, child);
                        break;
                    default:
                        processNode(compiler, i);
                }
            }
        }
    }
protected:
    void translateVertexProgramRef(ScriptCompiler compiler, ObjectAbstractNode node)
    {
        if(node.name.empty())
        {
            compiler.addError(ScriptCompiler.CE_OBJECTNAMEEXPECTED, node.file, node.line);
            return;
        }
        
        auto evt = new ProcessResourceNameScriptCompilerEvent(ProcessResourceNameScriptCompilerEvent.GPU_PROGRAM, node.name);
        compiler._fireEvent(evt, null);
        
        if (GpuProgramManager.getSingleton().getByName(evt.mName).isNull())
        {
            compiler.addError(ScriptCompiler.CE_REFERENCETOANONEXISTINGOBJECT, node.file, node.line);
            return;
        }
        
        Pass pass = node.parent.context.get!Pass;
        pass.setVertexProgram(evt.mName);
        if(pass.getVertexProgram().isSupported())
        {
            GpuProgramParametersPtr params = pass.getVertexProgramParameters();
            GpuProgramTranslator.translateProgramParameters(compiler, params, node);
        }
    }
    
    void translateGeometryProgramRef(ScriptCompiler compiler, ObjectAbstractNode node)
    {
        if(node.name.empty())
        {
            compiler.addError(ScriptCompiler.CE_OBJECTNAMEEXPECTED, node.file, node.line);
            return;
        }
        
        auto evt = new ProcessResourceNameScriptCompilerEvent(ProcessResourceNameScriptCompilerEvent.GPU_PROGRAM, node.name);
        compiler._fireEvent(evt, null);
        
        if (GpuProgramManager.getSingleton().getByName(evt.mName).isNull())
        {
            compiler.addError(ScriptCompiler.CE_REFERENCETOANONEXISTINGOBJECT, node.file, node.line);
            return;
        }
        
        Pass pass = node.parent.context.get!Pass;
        pass.setGeometryProgram(evt.mName);
        if(pass.getGeometryProgram().isSupported())
        {
            GpuProgramParametersPtr params = pass.getGeometryProgramParameters();
            GpuProgramTranslator.translateProgramParameters(compiler, params, node);
        }
    }
    
    void translateFragmentProgramRef(ScriptCompiler compiler, ObjectAbstractNode node)
    {
        if(node.name.empty())
        {
            compiler.addError(ScriptCompiler.CE_OBJECTNAMEEXPECTED, node.file, node.line);
            return;
        }
        
        auto evt = new ProcessResourceNameScriptCompilerEvent(ProcessResourceNameScriptCompilerEvent.GPU_PROGRAM, node.name);
        compiler._fireEvent(evt, null);
        
        if (GpuProgramManager.getSingleton().getByName(evt.mName).isNull())
        {
            compiler.addError(ScriptCompiler.CE_REFERENCETOANONEXISTINGOBJECT, node.file, node.line);
            return;
        }
        
        Pass pass = node.parent.context.get!Pass;
        pass.setFragmentProgram(evt.mName);
        if(pass.getFragmentProgram().isSupported())
        {
            GpuProgramParametersPtr params = pass.getFragmentProgramParameters();
            GpuProgramTranslator.translateProgramParameters(compiler, params, node);
        }
    }
    
    void translateTesselationHullProgramRef(ScriptCompiler compiler, ObjectAbstractNode node)
    {
        if(node.name.empty())
        {
            compiler.addError(ScriptCompiler.CE_OBJECTNAMEEXPECTED, node.file, node.line);
            return;
        }
        
        auto evt = new ProcessResourceNameScriptCompilerEvent(ProcessResourceNameScriptCompilerEvent.GPU_PROGRAM, node.name);
        compiler._fireEvent(evt, null);
        
        if (GpuProgramManager.getSingleton().getByName(evt.mName).isNull())
        {
            compiler.addError(ScriptCompiler.CE_REFERENCETOANONEXISTINGOBJECT, node.file, node.line);
            return;
        }
        
        Pass pass = node.parent.context.get!Pass;
        pass.setTesselationHullProgram(evt.mName);
        if(pass.getTesselationHullProgram().isSupported())
        {
            GpuProgramParametersPtr params = pass.getTesselationHullProgramParameters();
            GpuProgramTranslator.translateProgramParameters(compiler, params, node);
        }
    }
    
    void translateTesselationDomainProgramRef(ScriptCompiler compiler, ObjectAbstractNode node)
    {
        if(node.name.empty())
        {
            compiler.addError(ScriptCompiler.CE_OBJECTNAMEEXPECTED, node.file, node.line);
            return;
        }
        
        auto evt = new ProcessResourceNameScriptCompilerEvent(ProcessResourceNameScriptCompilerEvent.GPU_PROGRAM, node.name);
        compiler._fireEvent(evt, null);
        
        if (GpuProgramManager.getSingleton().getByName(evt.mName).isNull())
        {
            compiler.addError(ScriptCompiler.CE_REFERENCETOANONEXISTINGOBJECT, node.file, node.line);
            return;
        }
        
        Pass pass = node.parent.context.get!Pass;
        pass.setTesselationDomainProgram(evt.mName);
        if(pass.getTesselationDomainProgram().isSupported())
        {
            GpuProgramParametersPtr params = pass.getTesselationDomainProgramParameters();
            GpuProgramTranslator.translateProgramParameters(compiler, params, node);
        }
    }
    
    void translateComputeProgramRef(ScriptCompiler compiler, ObjectAbstractNode node)
    {
        if(node.name.empty())
        {
            compiler.addError(ScriptCompiler.CE_OBJECTNAMEEXPECTED, node.file, node.line);
            return;
        }
        
        auto evt = new ProcessResourceNameScriptCompilerEvent(ProcessResourceNameScriptCompilerEvent.GPU_PROGRAM, node.name);
        compiler._fireEvent(evt, null);
        
        if (GpuProgramManager.getSingleton().getByName(evt.mName).isNull())
        {
            compiler.addError(ScriptCompiler.CE_REFERENCETOANONEXISTINGOBJECT, node.file, node.line);
            return;
        }
        
        Pass pass = node.parent.context.get!Pass;
        pass.setComputeProgram(evt.mName);
        if(pass.getComputeProgram().isSupported())
        {
            GpuProgramParametersPtr params = pass.getComputeProgramParameters();
            GpuProgramTranslator.translateProgramParameters(compiler, params, node);
        }
    }
    
    void translateShadowCasterVertexProgramRef(ScriptCompiler compiler, ObjectAbstractNode node)
    {
        if(node.name.empty())
        {
            compiler.addError(ScriptCompiler.CE_OBJECTNAMEEXPECTED, node.file, node.line);
            return;
        }
        
        auto evt = new ProcessResourceNameScriptCompilerEvent(ProcessResourceNameScriptCompilerEvent.GPU_PROGRAM, node.name);
        compiler._fireEvent(evt, null);
        
        if (GpuProgramManager.getSingleton().getByName(evt.mName).isNull())
        {
            compiler.addError(ScriptCompiler.CE_REFERENCETOANONEXISTINGOBJECT, node.file, node.line);
            return;
        }
        
        Pass pass = node.parent.context.get!Pass;
        pass.setShadowCasterVertexProgram(evt.mName);
        if(pass.getShadowCasterVertexProgram().isSupported())
        {
            GpuProgramParametersPtr params = pass.getShadowCasterVertexProgramParameters();
            GpuProgramTranslator.translateProgramParameters(compiler, params, node);
        }
    }
    
    void translateShadowCasterFragmentProgramRef(ScriptCompiler compiler, ObjectAbstractNode node)
    {
        if(node.name.empty())
        {
            compiler.addError(ScriptCompiler.CE_OBJECTNAMEEXPECTED, node.file, node.line);
            return;
        }
        
        auto evt = new ProcessResourceNameScriptCompilerEvent(ProcessResourceNameScriptCompilerEvent.GPU_PROGRAM, node.name);
        compiler._fireEvent(evt, null);
        
        if (GpuProgramManager.getSingleton().getByName(evt.mName).isNull())
        {
            compiler.addError(ScriptCompiler.CE_REFERENCETOANONEXISTINGOBJECT, node.file, node.line);
            return;
        }
        
        Pass pass = node.parent.context.get!Pass;
        pass.setShadowCasterFragmentProgram(evt.mName);
        if(pass.getShadowCasterFragmentProgram().isSupported())
        {
            GpuProgramParametersPtr params = pass.getShadowCasterFragmentProgramParameters();
            GpuProgramTranslator.translateProgramParameters(compiler, params, node);
        }
    }
    
    void translateShadowReceiverVertexProgramRef(ScriptCompiler compiler, ObjectAbstractNode node)
    {
        if(node.name.empty())
        {
            compiler.addError(ScriptCompiler.CE_OBJECTNAMEEXPECTED, node.file, node.line);
            return;
        }
        
        auto evt = new ProcessResourceNameScriptCompilerEvent(ProcessResourceNameScriptCompilerEvent.GPU_PROGRAM, node.name);
        compiler._fireEvent(evt, null);
        
        if (GpuProgramManager.getSingleton().getByName(evt.mName).isNull())
        {
            compiler.addError(ScriptCompiler.CE_REFERENCETOANONEXISTINGOBJECT, node.file, node.line);
            return;
        }
        
        Pass pass = node.parent.context.get!Pass;
        pass.setShadowReceiverVertexProgram(evt.mName);
        if(pass.getShadowReceiverVertexProgram().isSupported())
        {
            GpuProgramParametersPtr params = pass.getShadowReceiverVertexProgramParameters();
            GpuProgramTranslator.translateProgramParameters(compiler, params, node);
        }
    }
    
    void translateShadowReceiverFragmentProgramRef(ScriptCompiler compiler, ObjectAbstractNode node)
    {
        if(node.name.empty())
        {
            compiler.addError(ScriptCompiler.CE_OBJECTNAMEEXPECTED, node.file, node.line);
            return;
        }
        
        auto evt = new ProcessResourceNameScriptCompilerEvent(ProcessResourceNameScriptCompilerEvent.GPU_PROGRAM, node.name);
        compiler._fireEvent(evt, null);
        
        if (GpuProgramManager.getSingleton().getByName(evt.mName).isNull())
        {
            compiler.addError(ScriptCompiler.CE_REFERENCETOANONEXISTINGOBJECT, node.file, node.line);
            return;
        }
        
        Pass pass = node.parent.context.get!Pass;
        pass.setShadowReceiverFragmentProgram(evt.mName);
        if(pass.getShadowReceiverFragmentProgram().isSupported())
        {
            GpuProgramParametersPtr params = pass.getShadowReceiverFragmentProgramParameters();
            GpuProgramTranslator.translateProgramParameters(compiler, params, node);
        }
    }
    
}

class TextureUnitTranslator : ScriptTranslator
{
protected:
    TextureUnitState mUnit;
public:
    this() {}
    override void translate(ScriptCompiler compiler, /*const*/ AbstractNodePtr node)
    {
        ObjectAbstractNode obj = cast(ObjectAbstractNode)(node.get());
        Pass pass = obj.parent.context.get!Pass;
        mUnit = pass.createTextureUnitState();
        obj.context = Any(mUnit);
        
        // Get the name of the technique
        if(!obj.name.empty())
            mUnit.setName(obj.name);
        
        // Set the properties for the material
        foreach(i; obj.children)
        {
            if(i.type == ANT_PROPERTY)
            {
                PropertyAbstractNode prop = cast(PropertyAbstractNode)(i.get());
                switch(prop.id)
                {
                    case ID_TEXTURE_ALIAS:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                               "texture_alias must have at most 1 argument");
                        }
                        else
                        {
                            string val;
                            if(getString(prop.values.front, val))
                                mUnit.setTextureNameAlias(val);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                   prop.values.front().getValue() ~ " is not a valid texture alias");
                        }
                        break;
                    case ID_TEXTURE:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 5)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                               "texture must have at most 5 arguments");
                        }
                        else
                        {
                            size_t j;
                            string val;
                            if(getString(prop.values[j], val))
                            {
                                TextureType texType = TextureType.TEX_TYPE_2D;
                                bool isAlpha = false;
                                bool sRGBRead = false;
                                PixelFormat format = PixelFormat.PF_UNKNOWN;
                                int mipmaps = TextureMipmap.MIP_DEFAULT;
                                
                                ++j;
                                for(;j < prop.values.length; j++)
                                {
                                    if(prop.values[j].type == ANT_ATOM)
                                    {
                                        AtomAbstractNode atom = cast(AtomAbstractNode)prop.values[j].get();
                                        switch(atom.id)
                                        {
                                            case ID_1D:
                                            // fallback to 2d texture if 1d is not supported
                                            {
                                                // Use the current render system
                                                RenderSystem rs = Root.getSingleton().getRenderSystem();
                                                
                                                if (rs.getCapabilities().hasCapability(Capabilities.RSC_TEXTURE_1D))
                                                {
                                                    texType = TextureType.TEX_TYPE_1D;
                                                    break;
                                                }
                                            }
                                            case ID_2D:
                                                texType = TextureType.TEX_TYPE_2D;
                                                break;
                                            case ID_3D:
                                                texType = TextureType.TEX_TYPE_3D;
                                                break;
                                            case ID_CUBIC:
                                                texType = TextureType.TEX_TYPE_CUBE_MAP;
                                                break;
                                            case ID_2DARRAY:
                                                texType = TextureType.TEX_TYPE_2D_ARRAY;
                                                break;
                                            case ID_UNLIMITED:
                                                mipmaps = TextureMipmap.MIP_UNLIMITED;
                                                break;
                                            case ID_ALPHA:
                                                isAlpha = true;
                                                break;
                                            case ID_GAMMA:
                                                sRGBRead = true;
                                                break;
                                            default:
                                                if(StringUtil.isNumber(atom.value))
                                                    mipmaps = to!int(atom.value);
                                                else
                                                    format = PixelUtil.getFormatFromName(atom.value, true);
                                        }
                                    }
                                    else
                                    {
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          prop.values[j].getValue() ~ " is not a supported argument to the texture property");
                                    }
                                }
                                
                                auto evt = new ProcessResourceNameScriptCompilerEvent(ProcessResourceNameScriptCompilerEvent.TEXTURE, val);
                                compiler._fireEvent(evt, null);
                                
                                mUnit.setTextureName(evt.mName, texType);
                                mUnit.setDesiredFormat(format);
                                mUnit.setIsAlpha(isAlpha);
                                mUnit.setNumMipmaps(mipmaps);
                                mUnit.setHardwareGammaEnabled(sRGBRead);
                            }
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values[j].getValue() ~ " is not a valid texture name");
                        }
                        break;
                    case ID_ANIM_TEXTURE:
                        if(prop.values.length < 3)
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else
                        {
                            AbstractNodePtr i1 = getNodeAt(prop.values, 1);
                            if(i1.type == ANT_ATOM && StringUtil.isNumber((cast(AtomAbstractNode)i1.get()).value))
                            {
                                // Short form
                                AbstractNodePtr i0 = getNodeAt(prop.values, 0), i2 = getNodeAt(prop.values, 2);
                                if(i0.type == ANT_ATOM && i1.type == ANT_ATOM)
                                {
                                    string val0;
                                    uint val1;
                                    Real val2;
                                    if(getString(i0, val0) && get(i1, val1) && get(i2, val2))
                                    {
                                        auto evt = new ProcessResourceNameScriptCompilerEvent(ProcessResourceNameScriptCompilerEvent.TEXTURE, val0);
                                        compiler._fireEvent(evt, null);
                                        
                                        mUnit.setAnimatedTextureName(evt.mName, val1, val2);
                                    }
                                    else
                                    {
                                        compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line,
                                                          "anim_texture short form requires a texture name, number of frames, and animation duration");
                                    }
                                }
                                else
                                {
                                    compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                      "anim_texture short form requires a texture name, number of frames, and animation duration");
                                }
                            }
                            else
                            {
                                // Long form has n number of frames
                                Real duration = 0;
                                AbstractNodePtr _in = getNodeAt(prop.values, prop.values.length - 1);
                                if(get(_in, duration))
                                {
                                    //string[] names = new string[prop.values.length - 1];
                                    auto names = appender!string();
                                    //int n = 0;
                                    
                                    size_t j;
                                    while(j < cast(long)prop.values.length - 1) //TODO unsigned vs signed math
                                    {
                                        if(prop.values[j].type == ANT_ATOM)
                                        {
                                            string name = (cast(AtomAbstractNode)prop.values[j].get()).value;
                                            // Run the name through the listener
                                            if(compiler.getListener())
                                            {
                                                auto evt = new ProcessResourceNameScriptCompilerEvent(ProcessResourceNameScriptCompilerEvent.TEXTURE, name);
                                                compiler._fireEvent(evt, null);
                                                names.put(evt.mName);
                                            }
                                            else
                                            {
                                                names.put(name);
                                            }
                                        }
                                        else
                                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                              prop.values[j].getValue() ~ " is not supported as a texture name");
                                        ++j;
                                    }
                                    
                                    mUnit.setAnimatedTextureName(names.data, names.data.length, duration);
                                }
                                else
                                {
                                    compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line,
                                                      _in.getValue() ~ " is not supported for the duration argument");
                                }
                            }
                        }
                        break;
                    case ID_CUBIC_TEXTURE:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length == 2)
                        {
                            AbstractNodePtr i0 = getNodeAt(prop.values, 0),
                                i1 = getNodeAt(prop.values, 1);
                            if(i0.type == ANT_ATOM && i1.type == ANT_ATOM)
                            {   
                                AtomAbstractNode atom0 = cast(AtomAbstractNode)i0.get(), atom1 = cast(AtomAbstractNode)i1.get();
                                
                                auto evt = new ProcessResourceNameScriptCompilerEvent(ProcessResourceNameScriptCompilerEvent.TEXTURE, atom0.value);
                                compiler._fireEvent(evt, null);
                                
                                mUnit.setCubicTextureName(evt.mName, atom1.id == ID_COMBINED_UVW);
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                            }
                        }
                        else if(prop.values.length == 7)
                        {
                            AbstractNodePtr i0 = prop.values[0],
                                    i1 = prop.values[1],
                                    i2 = prop.values[2],
                                    i3 = prop.values[3],
                                    i4 = prop.values[4],
                                    i5 = prop.values[5],
                                    i6 = prop.values[6];
                            if(i0.type == ANT_ATOM && i1.type == ANT_ATOM && i2.type == ANT_ATOM && i3.type == ANT_ATOM &&
                               i4.type == ANT_ATOM && i5.type == ANT_ATOM && i6.type == ANT_ATOM)
                            {
                                AtomAbstractNode atom0 = cast(AtomAbstractNode)i0.get(), atom1 = cast(AtomAbstractNode)i1.get(),
                                        atom2 = cast(AtomAbstractNode)i2.get(), atom3 = cast(AtomAbstractNode)i3.get(),
                                        atom4 = cast(AtomAbstractNode)i4.get(), atom5 = cast(AtomAbstractNode)i5.get(),
                                        atom6 = cast(AtomAbstractNode)i6.get();
                                string[6] names;
                                names[0] = atom0.value;
                                names[1] = atom1.value;
                                names[2] = atom2.value;
                                names[3] = atom3.value;
                                names[4] = atom4.value;
                                names[5] = atom5.value;
                                
                                if(compiler.getListener())
                                {
                                    // Run each name through the listener
                                    for(int j = 0; j < 6; ++j)
                                    {
                                        auto evt = new ProcessResourceNameScriptCompilerEvent(ProcessResourceNameScriptCompilerEvent.TEXTURE, names[j]);
                                        compiler._fireEvent(evt, null);
                                        names[j] = evt.mName;
                                    }
                                }
                                
                                mUnit.setCubicTextureName(names, atom6.id == ID_COMBINED_UVW);
                            }
                            
                        }
                        else
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "cubic_texture must have at most 7 arguments");
                        }
                        break;
                    case ID_TEX_COORD_SET:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "tex_coord_set must have at most 1 argument");
                        }
                        else
                        {
                            uint val = 0;
                            if(get(prop.values.front(), val))
                                mUnit.setTextureCoordSet(val);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front().getValue() ~ " is not supported as an integer argument");
                        }
                        break;
                    case ID_TEX_ADDRESS_MODE:
                    {
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else
                        {
                            AbstractNodePtr i0 = getNodeAt(prop.values, 0), 
                                i1 = getNodeAt(prop.values, 1), 
                                i2 = getNodeAt(prop.values, 2);
                            TextureUnitState.UVWAddressingMode mode;
                            mode.u = mode.v = mode.w = TextureUnitState.TAM_WRAP;
                            
                            if(!i0.isNull() && i0.type == ANT_ATOM)
                            {
                                AtomAbstractNode atom = cast(AtomAbstractNode)i0.get();
                                switch(atom.id)
                                {
                                    case ID_WRAP:
                                        mode.u = TextureUnitState.TAM_WRAP;
                                        break;
                                    case ID_CLAMP:
                                        mode.u = TextureUnitState.TAM_CLAMP;
                                        break;
                                    case ID_MIRROR:
                                        mode.u = TextureUnitState.TAM_MIRROR;
                                        break;
                                    case ID_BORDER:
                                        mode.u = TextureUnitState.TAM_BORDER;
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          i0.getValue() ~ " not supported as first argument (must be \"wrap\", \"clamp\", \"mirror\", or \"border\")");
                                }
                            }
                            mode.v = mode.u;
                            mode.w = mode.u;
                            
                            if(!i1.isNull() && i1.type == ANT_ATOM)
                            {
                                AtomAbstractNode atom = cast(AtomAbstractNode)i1.get();
                                switch(atom.id)
                                {
                                    case ID_WRAP:
                                        mode.v = TextureUnitState.TAM_WRAP;
                                        break;
                                    case ID_CLAMP:
                                        mode.v = TextureUnitState.TAM_CLAMP;
                                        break;
                                    case ID_MIRROR:
                                        mode.v = TextureUnitState.TAM_MIRROR;
                                        break;
                                    case ID_BORDER:
                                        mode.v = TextureUnitState.TAM_BORDER;
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          i0.getValue() ~ " not supported as second argument (must be \"wrap\", \"clamp\", \"mirror\", or \"border\")");
                                }
                            }
                            
                            if(!i2.isNull() && i2.type == ANT_ATOM)
                            {
                                AtomAbstractNode atom = cast(AtomAbstractNode)i2.get();
                                switch(atom.id)
                                {
                                    case ID_WRAP:
                                        mode.w = TextureUnitState.TAM_WRAP;
                                        break;
                                    case ID_CLAMP:
                                        mode.w = TextureUnitState.TAM_CLAMP;
                                        break;
                                    case ID_MIRROR:
                                        mode.w = TextureUnitState.TAM_MIRROR;
                                        break;
                                    case ID_BORDER:
                                        mode.w = TextureUnitState.TAM_BORDER;
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          i0.getValue() ~ " not supported as third argument (must be \"wrap\", \"clamp\", \"mirror\", or \"border\")");
                                }
                            }
                            
                            mUnit.setTextureAddressingMode(mode);
                        }
                    }
                        break;
                    case ID_TEX_BORDER_COLOUR:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line);
                        }
                        else
                        {
                            ColourValue val;
                            if(getColour(prop.values, val))
                                mUnit.setTextureBorderColour(val);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "tex_border_colour only accepts a colour argument");
                        }
                        break;
                    case ID_FILTERING:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length == 1)
                        {
                            if(prop.values.front().type == ANT_ATOM)
                            {
                                AtomAbstractNode atom = cast(AtomAbstractNode)prop.values.front().get();
                                switch(atom.id)
                                {
                                    case ID_NONE:
                                        mUnit.setTextureFiltering(TextureFilterOptions.TFO_NONE);
                                        break;
                                    case ID_BILINEAR:
                                        mUnit.setTextureFiltering(TextureFilterOptions.TFO_BILINEAR);
                                        break;
                                    case ID_TRILINEAR:
                                        mUnit.setTextureFiltering(TextureFilterOptions.TFO_TRILINEAR);
                                        break;
                                    case ID_ANISOTROPIC:
                                        mUnit.setTextureFiltering(TextureFilterOptions.TFO_ANISOTROPIC);
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          prop.values.front().getValue() ~ " not supported as first argument (must be \"none\", \"bilinear\", \"trilinear\", or \"anisotropic\")");
                                }
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front().getValue() ~ " not supported as first argument (must be \"none\", \"bilinear\", \"trilinear\", or \"anisotropic\")");
                            }
                        }
                        else if(prop.values.length == 3)
                        {
                            AbstractNodePtr i0 = prop.values[0],
                                    i1 = prop.values[1],
                                    i2 = prop.values[2];
                            if(i0.type == ANT_ATOM &&
                               i1.type == ANT_ATOM &&
                               i2.type == ANT_ATOM)
                            {
                                AtomAbstractNode atom0 = cast(AtomAbstractNode)i0.get(),
                                        atom1 = cast(AtomAbstractNode)i1.get(),
                                        atom2 = cast(AtomAbstractNode)i2.get();
                                FilterOptions tmin = FilterOptions.FO_NONE, tmax = FilterOptions.FO_NONE, tmip = FilterOptions.FO_NONE;
                                switch(atom0.id)
                                {
                                    case ID_NONE:
                                        tmin = FilterOptions.FO_NONE;
                                        break;
                                    case ID_POINT:
                                        tmin = FilterOptions.FO_POINT;
                                        break;
                                    case ID_LINEAR:
                                        tmin = FilterOptions.FO_LINEAR;
                                        break;
                                    case ID_ANISOTROPIC:
                                        tmin = FilterOptions.FO_ANISOTROPIC;
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          i0.getValue() ~ " not supported as first argument (must be \"none\", \"point\", \"linear\", or \"anisotropic\")");
                                }
                                
                                switch(atom1.id)
                                {
                                    case ID_NONE:
                                        tmax = FilterOptions.FO_NONE;
                                        break;
                                    case ID_POINT:
                                        tmax = FilterOptions.FO_POINT;
                                        break;
                                    case ID_LINEAR:
                                        tmax = FilterOptions.FO_LINEAR;
                                        break;
                                    case ID_ANISOTROPIC:
                                        tmax = FilterOptions.FO_ANISOTROPIC;
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          i0.getValue() ~ " not supported as second argument (must be \"none\", \"point\", \"linear\", or \"anisotropic\")");
                                }
                                
                                switch(atom2.id)
                                {
                                    case ID_NONE:
                                        tmip = FilterOptions.FO_NONE;
                                        break;
                                    case ID_POINT:
                                        tmip = FilterOptions.FO_POINT;
                                        break;
                                    case ID_LINEAR:
                                        tmip = FilterOptions.FO_LINEAR;
                                        break;
                                    case ID_ANISOTROPIC:
                                        tmip = FilterOptions.FO_ANISOTROPIC;
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          i0.getValue() ~ " not supported as third argument (must be \"none\", \"point\", \"linear\", or \"anisotropic\")");
                                }
                                
                                mUnit.setTextureFiltering(tmin, tmax, tmip);
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                            }
                        }
                        else
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "filtering must have either 1 or 3 arguments");
                        }
                        break;
                    case ID_CMPTEST:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "compare_test must have at most 1 argument");
                        }
                        else
                        {
                            if(prop.values.front().type == ANT_ATOM)
                            {
                                AtomAbstractNode atom = cast(AtomAbstractNode)prop.values.front().get();
                                bool enabled = false;
                                switch(atom.id)
                                {
                                    case ID_ON:
                                        enabled=true;
                                        break;
                                    case ID_OFF:
                                        enabled=false;
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          prop.values.front().getValue() ~ " is not a valid parameter");
                                }
                                mUnit.setTextureCompareEnabled(enabled);
                            }
                        }
                        break;
                    case ID_CMPFUNC:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "compare_func must have at most 1 argument");
                        }
                        else
                        {
                            if(prop.values.front().type == ANT_ATOM)
                            {
                                AtomAbstractNode atom = cast(AtomAbstractNode)prop.values.front().get();
                                CompareFunction func = CompareFunction.CMPF_GREATER_EQUAL;
                                switch(atom.id)
                                {
                                    case ID_ALWAYS_FAIL:
                                        func = CompareFunction.CMPF_ALWAYS_FAIL;
                                        break;
                                    case ID_ALWAYS_PASS:
                                        func = CompareFunction.CMPF_ALWAYS_PASS;
                                        break;
                                    case ID_LESS:
                                        func = CompareFunction.CMPF_LESS;
                                        break;
                                    case ID_LESS_EQUAL:
                                        func = CompareFunction.CMPF_LESS_EQUAL;
                                        break;
                                    case ID_EQUAL:
                                        func = CompareFunction.CMPF_EQUAL;
                                        break;
                                    case ID_NOT_EQUAL:
                                        func = CompareFunction.CMPF_NOT_EQUAL;
                                        break;
                                    case ID_GREATER_EQUAL:
                                        func = CompareFunction.CMPF_GREATER_EQUAL;
                                        break;
                                    case ID_GREATER:
                                        func = CompareFunction.CMPF_GREATER;
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          prop.values.front().getValue() ~ "is not a valid parameter");
                                }
                                
                                mUnit.setTextureCompareFunction(func);
                            }
                        }
                        break;
                    case ID_MAX_ANISOTROPY:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "max_anisotropy must have at most 1 argument");
                        }
                        else
                        {
                            uint val = 0;
                            if(get(prop.values.front(), val))
                                mUnit.setTextureAnisotropy(val);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front().getValue() ~ " is not a valid integer argument");
                        }
                        break;
                    case ID_MIPMAP_BIAS:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "mipmap_bias must have at most 1 argument");
                        }
                        else
                        {
                            Real val = 0.0f;
                            if(get(prop.values.front(), val))
                                mUnit.setTextureMipmapBias(val);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front().getValue() ~ " is not a valid number argument");
                        }
                        break;
                    case ID_COLOUR_OP:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "colour_op must have at most 1 argument");
                        }
                        else
                        {
                            if(prop.values.front().type == ANT_ATOM)
                            {
                                AtomAbstractNode atom = cast(AtomAbstractNode)prop.values.front().get();
                                switch(atom.id)
                                {
                                    case ID_REPLACE:
                                        mUnit.setColourOperation(LayerBlendOperation.LBO_REPLACE);
                                        break;
                                    case ID_ADD:
                                        mUnit.setColourOperation(LayerBlendOperation.LBO_ADD);
                                        break;
                                    case ID_MODULATE:
                                        mUnit.setColourOperation(LayerBlendOperation.LBO_MODULATE);
                                        break;
                                    case ID_ALPHA_BLEND:
                                        mUnit.setColourOperation(LayerBlendOperation.LBO_ALPHA_BLEND);
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          prop.values.front().getValue() ~ " is not a valid argument (must be \"replace\", \"add\", \"modulate\", or \"alpha_blend\")");
                                }
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front().getValue() ~ " is not a valid argument (must be \"replace\", \"add\", \"modulate\", or \"alpha_blend\")");
                            }
                        }
                        break;
                    case ID_COLOUR_OP_EX:
                        if(prop.values.length < 3)
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line,
                                              "colour_op_ex must have at least 3 arguments");
                        }
                        else if(prop.values.length > 10)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "colour_op_ex must have at most 10 arguments");
                        }
                        else
                        {
                            AbstractNodePtr i0 = getNodeAt(prop.values, 0),
                                    i1 = getNodeAt(prop.values, 1),
                                    i2 = getNodeAt(prop.values, 2);
                            if(i0.type == ANT_ATOM && i1.type == ANT_ATOM && i2.type == ANT_ATOM)
                            {
                                AtomAbstractNode atom0 = cast(AtomAbstractNode)i0.get(),
                                        atom1 = cast(AtomAbstractNode)i1.get(),
                                        atom2 = cast(AtomAbstractNode)i2.get();
                                LayerBlendOperationEx op = LayerBlendOperationEx.LBX_ADD;
                                LayerBlendSource source1 = LayerBlendSource.LBS_CURRENT, source2 = LayerBlendSource.LBS_TEXTURE;
                                ColourValue arg1 = ColourValue.White, arg2 = ColourValue.White;
                                Real manualBlend = 0.0f;
                                
                                switch(atom0.id)
                                {
                                    case ID_SOURCE1:
                                        op = LayerBlendOperationEx.LBX_SOURCE1;
                                        break;
                                    case ID_SOURCE2:
                                        op = LayerBlendOperationEx.LBX_SOURCE2;
                                        break;
                                    case ID_MODULATE:
                                        op = LayerBlendOperationEx.LBX_MODULATE;
                                        break;
                                    case ID_MODULATE_X2:
                                        op = LayerBlendOperationEx.LBX_MODULATE_X2;
                                        break;
                                    case ID_MODULATE_X4:
                                        op = LayerBlendOperationEx.LBX_MODULATE_X4;
                                        break;
                                    case ID_ADD:
                                        op = LayerBlendOperationEx.LBX_ADD;
                                        break;
                                    case ID_ADD_SIGNED:
                                        op = LayerBlendOperationEx.LBX_ADD_SIGNED;
                                        break;
                                    case ID_ADD_SMOOTH:
                                        op = LayerBlendOperationEx.LBX_ADD_SMOOTH;
                                        break;
                                    case ID_SUBTRACT:
                                        op = LayerBlendOperationEx.LBX_SUBTRACT;
                                        break;
                                    case ID_BLEND_DIFFUSE_ALPHA:
                                        op = LayerBlendOperationEx.LBX_BLEND_DIFFUSE_ALPHA;
                                        break;
                                    case ID_BLEND_TEXTURE_ALPHA:
                                        op = LayerBlendOperationEx.LBX_BLEND_TEXTURE_ALPHA;
                                        break;
                                    case ID_BLEND_CURRENT_ALPHA:
                                        op = LayerBlendOperationEx.LBX_BLEND_CURRENT_ALPHA;
                                        break;
                                    case ID_BLEND_MANUAL:
                                        op = LayerBlendOperationEx.LBX_BLEND_MANUAL;
                                        break;
                                    case ID_DOT_PRODUCT:
                                        op = LayerBlendOperationEx.LBX_DOTPRODUCT;
                                        break;
                                    case ID_BLEND_DIFFUSE_COLOUR:
                                        op = LayerBlendOperationEx.LBX_BLEND_DIFFUSE_COLOUR;
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          i0.getValue() ~ " is not a valid first argument (must be \"source1\", \"source2\", \"modulate\", \"modulate_x2\", \"modulate_x4\", \"add\", \"add_signed\", \"add_smooth\", \"subtract\", \"blend_diffuse_alpha\", \"blend_texture_alpha\", \"blend_current_alpha\", \"blend_manual\", \"dot_product\", or \"blend_diffuse_colour\")");
                                }
                                
                                switch(atom1.id)
                                {
                                    case ID_SRC_CURRENT:
                                        source1 = LayerBlendSource.LBS_CURRENT;
                                        break;
                                    case ID_SRC_TEXTURE:
                                        source1 = LayerBlendSource.LBS_TEXTURE;
                                        break;
                                    case ID_SRC_DIFFUSE:
                                        source1 = LayerBlendSource.LBS_DIFFUSE;
                                        break;
                                    case ID_SRC_SPECULAR:
                                        source1 = LayerBlendSource.LBS_SPECULAR;
                                        break;
                                    case ID_SRC_MANUAL:
                                        source1 = LayerBlendSource.LBS_MANUAL;
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          i1.getValue() ~ " is not a valid second argument (must be \"src_current\", \"src_texture\", \"src_diffuse\", \"src_specular\", or \"src_manual\")");
                                }
                                
                                switch(atom2.id)
                                {
                                    case ID_SRC_CURRENT:
                                        source2 = LayerBlendSource.LBS_CURRENT;
                                        break;
                                    case ID_SRC_TEXTURE:
                                        source2 = LayerBlendSource.LBS_TEXTURE;
                                        break;
                                    case ID_SRC_DIFFUSE:
                                        source2 = LayerBlendSource.LBS_DIFFUSE;
                                        break;
                                    case ID_SRC_SPECULAR:
                                        source2 = LayerBlendSource.LBS_SPECULAR;
                                        break;
                                    case ID_SRC_MANUAL:
                                        source2 = LayerBlendSource.LBS_MANUAL;
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          i2.getValue() ~ " is not a valid third argument (must be \"src_current\", \"src_texture\", \"src_diffuse\", \"src_specular\", or \"src_manual\")");
                                }
                                
                                size_t k = 3;
                                if(op == LayerBlendOperationEx.LBX_BLEND_MANUAL)
                                {
                                    k++;
                                    AbstractNodePtr i3 = getNodeAt(prop.values, 3);
                                    if(!i3.isNull())
                                    {
                                        if(!get(i3, manualBlend))
                                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                              i3.getValue() ~ " is not a valid number argument");
                                    }
                                    else
                                    {
                                        compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line,
                                                          "fourth argument expected when blend_manual is used");
                                    }
                                }
                                
                                AbstractNodePtr j = getNodeAt(prop.values, k);// k is either 3 or 4
                                //if(op == LayerBlendOperationEx.LBX_BLEND_MANUAL)
                                    //++j;
                                
                                if(source1 == LayerBlendSource.LBS_MANUAL)
                                {
                                    if(!j.isNull())
                                    {
                                        if(!getColour(prop.values[k..$], arg1, 3))
                                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                              "valid colour expected when src_manual is used");
                                        k+=3;
                                    }
                                    else
                                    {
                                        compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line,
                                                          "valid colour expected when src_manual is used");
                                    }
                                }
                                if(source2 == LayerBlendSource.LBS_MANUAL)
                                {
                                    if(!j.isNull())
                                    {
                                        if(!getColour(prop.values[k..$], arg2, 3))
                                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                              "valid colour expected when src_manual is used");
                                    }
                                    else
                                    {
                                        compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line,
                                                          "valid colour expected when src_manual is used");
                                    }
                                }
                                
                                mUnit.setColourOperationEx(op, source1, source2, arg1, arg2, manualBlend);
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                            }
                        }
                        break;
                    case ID_COLOUR_OP_MULTIPASS_FALLBACK:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 2)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "colour_op_multiplass_fallback must have at most 2 arguments");
                        }
                        else if(prop.values.length == 1)
                        {
                            if(prop.values.front().type == ANT_ATOM)
                            {
                                AtomAbstractNode atom = cast(AtomAbstractNode)prop.values.front().get();
                                switch(atom.id)
                                {
                                    case ID_ADD:
                                        mUnit.setColourOpMultipassFallback(SceneBlendFactor.SBF_ONE, SceneBlendFactor.SBF_ONE);
                                        break;
                                    case ID_MODULATE:
                                        mUnit.setColourOpMultipassFallback(SceneBlendFactor.SBF_DEST_COLOUR, SceneBlendFactor.SBF_ZERO);
                                        break;
                                    case ID_COLOUR_BLEND:
                                        mUnit.setColourOpMultipassFallback(SceneBlendFactor.SBF_SOURCE_COLOUR, SceneBlendFactor.SBF_ONE_MINUS_SOURCE_COLOUR);
                                        break;
                                    case ID_ALPHA_BLEND:
                                        mUnit.setColourOpMultipassFallback(SceneBlendFactor.SBF_SOURCE_ALPHA, SceneBlendFactor.SBF_ONE_MINUS_SOURCE_ALPHA);
                                        break;
                                    case ID_REPLACE:
                                        mUnit.setColourOpMultipassFallback(SceneBlendFactor.SBF_ONE, SceneBlendFactor.SBF_ZERO);
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          "argument must be a valid scene blend type (add, modulate, colour_blend, alpha_blend, or replace)");
                                }
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "argument must be a valid scene blend type (add, modulate, colour_blend, alpha_blend, or replace)");
                            }
                        }
                        else
                        {
                            AbstractNodePtr i0 = getNodeAt(prop.values, 0), i1 = getNodeAt(prop.values, 1);
                            SceneBlendFactor sbf0, sbf1;
                            if(getSceneBlendFactor(i0, sbf0) && getSceneBlendFactor(i1, sbf1))
                                mUnit.setColourOpMultipassFallback(sbf0, sbf1);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "arguments must be valid scene blend factors");
                        }
                        break;
                    case ID_ALPHA_OP_EX:
                        if(prop.values.length < 3)
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line,
                                              "alpha_op_ex must have at least 3 arguments");
                        }
                        else if(prop.values.length > 6)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "alpha_op_ex must have at most 6 arguments");
                        }
                        else
                        {
                            AbstractNodePtr i0 = getNodeAt(prop.values, 0),
                                    i1 = getNodeAt(prop.values, 1),
                                    i2 = getNodeAt(prop.values, 2);
                            if(i0.type == ANT_ATOM && i1.type == ANT_ATOM && i2.type == ANT_ATOM)
                            {
                                AtomAbstractNode atom0 = cast(AtomAbstractNode)i0.get(),
                                        atom1 = cast(AtomAbstractNode)i1.get(),
                                        atom2 = cast(AtomAbstractNode)i2.get();
                                LayerBlendOperationEx op = LayerBlendOperationEx.LBX_ADD;
                                LayerBlendSource source1 = LayerBlendSource.LBS_CURRENT, source2 = LayerBlendSource.LBS_TEXTURE;
                                Real arg1 = 0.0f, arg2 = 0.0f;
                                Real manualBlend = 0.0f;
                                
                                switch(atom0.id)
                                {
                                    case ID_SOURCE1:
                                        op = LayerBlendOperationEx.LBX_SOURCE1;
                                        break;
                                    case ID_SOURCE2:
                                        op = LayerBlendOperationEx.LBX_SOURCE2;
                                        break;
                                    case ID_MODULATE:
                                        op = LayerBlendOperationEx.LBX_MODULATE;
                                        break;
                                    case ID_MODULATE_X2:
                                        op = LayerBlendOperationEx.LBX_MODULATE_X2;
                                        break;
                                    case ID_MODULATE_X4:
                                        op = LayerBlendOperationEx.LBX_MODULATE_X4;
                                        break;
                                    case ID_ADD:
                                        op = LayerBlendOperationEx.LBX_ADD;
                                        break;
                                    case ID_ADD_SIGNED:
                                        op = LayerBlendOperationEx.LBX_ADD_SIGNED;
                                        break;
                                    case ID_ADD_SMOOTH:
                                        op = LayerBlendOperationEx.LBX_ADD_SMOOTH;
                                        break;
                                    case ID_SUBTRACT:
                                        op = LayerBlendOperationEx.LBX_SUBTRACT;
                                        break;
                                    case ID_BLEND_DIFFUSE_ALPHA:
                                        op = LayerBlendOperationEx.LBX_BLEND_DIFFUSE_ALPHA;
                                        break;
                                    case ID_BLEND_TEXTURE_ALPHA:
                                        op = LayerBlendOperationEx.LBX_BLEND_TEXTURE_ALPHA;
                                        break;
                                    case ID_BLEND_CURRENT_ALPHA:
                                        op = LayerBlendOperationEx.LBX_BLEND_CURRENT_ALPHA;
                                        break;
                                    case ID_BLEND_MANUAL:
                                        op = LayerBlendOperationEx.LBX_BLEND_MANUAL;
                                        break;
                                    case ID_DOT_PRODUCT:
                                        op = LayerBlendOperationEx.LBX_DOTPRODUCT;
                                        break;
                                    case ID_BLEND_DIFFUSE_COLOUR:
                                        op = LayerBlendOperationEx.LBX_BLEND_DIFFUSE_COLOUR;
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          i0.getValue() ~ " is not a valid first argument (must be \"source1\", \"source2\", \"modulate\", \"modulate_x2\", \"modulate_x4\", \"add\", \"add_signed\", \"add_smooth\", \"subtract\", \"blend_diffuse_alpha\", \"blend_texture_alpha\", \"blend_current_alpha\", \"blend_manual\", \"dot_product\", or \"blend_diffuse_colour\")");
                                }
                                
                                switch(atom1.id)
                                {
                                    case ID_SRC_CURRENT:
                                        source1 = LayerBlendSource.LBS_CURRENT;
                                        break;
                                    case ID_SRC_TEXTURE:
                                        source1 = LayerBlendSource.LBS_TEXTURE;
                                        break;
                                    case ID_SRC_DIFFUSE:
                                        source1 = LayerBlendSource.LBS_DIFFUSE;
                                        break;
                                    case ID_SRC_SPECULAR:
                                        source1 = LayerBlendSource.LBS_SPECULAR;
                                        break;
                                    case ID_SRC_MANUAL:
                                        source1 = LayerBlendSource.LBS_MANUAL;
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          i1.getValue() ~ " is not a valid second argument (must be \"src_current\", \"src_texture\", \"src_diffuse\", \"src_specular\", or \"src_manual\")");
                                }
                                
                                switch(atom2.id)
                                {
                                    case ID_SRC_CURRENT:
                                        source2 = LayerBlendSource.LBS_CURRENT;
                                        break;
                                    case ID_SRC_TEXTURE:
                                        source2 = LayerBlendSource.LBS_TEXTURE;
                                        break;
                                    case ID_SRC_DIFFUSE:
                                        source2 = LayerBlendSource.LBS_DIFFUSE;
                                        break;
                                    case ID_SRC_SPECULAR:
                                        source2 = LayerBlendSource.LBS_SPECULAR;
                                        break;
                                    case ID_SRC_MANUAL:
                                        source2 = LayerBlendSource.LBS_MANUAL;
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          i2.getValue() ~ " is not a valid third argument (must be \"src_current\", \"src_texture\", \"src_diffuse\", \"src_specular\", or \"src_manual\")");
                                }
                                
                                size_t k = 3;
                                if(op == LayerBlendOperationEx.LBX_BLEND_MANUAL)
                                {
                                    k++;
                                    AbstractNodePtr i3 = getNodeAt(prop.values, 3);
                                    if(!i3.isNull())
                                    {
                                        if(!get(i3, manualBlend))
                                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                              "valid number expected when blend_manual is used");
                                    }
                                    else
                                    {
                                        compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line,
                                                          "valid number expected when blend_manual is used");
                                    }
                                }
                                
                                AbstractNodePtr j = getNodeAt(prop.values, k);
                                //if(op == LayerBlendOperationEx.LBX_BLEND_MANUAL)
                                //    ++j;
                                if(source1 == LayerBlendSource.LBS_MANUAL)
                                {
                                    if(!j.isNull())
                                    {
                                        if(!get(j, arg1))
                                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                             "valid colour expected when src_manual is used");
                                        else
                                            //++j;
                                            k++;
                                    }
                                    else
                                    {
                                        compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line,
                                                          "valid colour expected when src_manual is used");
                                    }
                                }
                                if(source2 == LayerBlendSource.LBS_MANUAL)
                                {
                                    if(!j.isNull())
                                    {
                                        if(!get(j, arg2))
                                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                              "valid colour expected when src_manual is used");
                                    }
                                    else
                                    {
                                        compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line,
                                                          "valid colour expected when src_manual is used");
                                    }
                                }
                                
                                mUnit.setAlphaOperation(op, source1, source2, arg1, arg2, manualBlend);
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                            }
                        }
                        break;
                    case ID_ENV_MAP:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "env_map must have at most 1 argument");
                        }
                        else
                        {
                            if(prop.values.front().type == ANT_ATOM)
                            {
                                AtomAbstractNode atom = cast(AtomAbstractNode)prop.values.front().get();
                                switch(atom.id)
                                {
                                    case ID_OFF:
                                        mUnit.setEnvironmentMap(false);
                                        break;
                                    case ID_SPHERICAL:
                                        mUnit.setEnvironmentMap(true, TextureUnitState.EnvMapType.ENV_CURVED);
                                        break;
                                    case ID_PLANAR:
                                        mUnit.setEnvironmentMap(true, TextureUnitState.EnvMapType.ENV_PLANAR);
                                        break;
                                    case ID_CUBIC_REFLECTION:
                                        mUnit.setEnvironmentMap(true, TextureUnitState.EnvMapType.ENV_REFLECTION);
                                        break;
                                    case ID_CUBIC_NORMAL:
                                        mUnit.setEnvironmentMap(true, TextureUnitState.EnvMapType.ENV_NORMAL);
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          prop.values.front().getValue() ~ " is not a valid argument (must be \"off\", \"spherical\", \"planar\", \"cubic_reflection\", or \"cubic_normal\")");
                                }
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front().getValue() ~ " is not a valid argument (must be \"off\", \"spherical\", \"planar\", \"cubic_reflection\", or \"cubic_normal\")");
                            }
                        }
                        break;
                    case ID_SCROLL:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 2)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "scroll must have at most 2 arguments");
                        }
                        else
                        {
                            AbstractNodePtr i0 = getNodeAt(prop.values, 0), i1 = getNodeAt(prop.values, 1);
                            Real x, y;
                            if(get(i0, x) && get(i1, y))
                                mUnit.setTextureScroll(x, y);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  i0.getValue() ~ " and/or " ~ i1.getValue() ~ " is invalid; both must be numbers");
                        }
                        break;
                    case ID_SCROLL_ANIM:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 2)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "scroll_anim must have at most 2 arguments");
                        }
                        else
                        {
                            AbstractNodePtr i0 = getNodeAt(prop.values, 0), i1 = getNodeAt(prop.values, 1);
                            Real x, y;
                            if(get(i0, x) && get(i1, y))
                                mUnit.setScrollAnimation(x, y);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  i0.getValue() ~ " and/or " ~ i1.getValue() ~ " is invalid; both must be numbers");
                        }
                        break;
                    case ID_ROTATE:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "rotate must have at most 1 argument");
                        }
                        else
                        {
                            Real angle;
                            if(get(prop.values.front(), angle))
                                mUnit.setTextureRotate(Radian(Degree(angle))); //FIXME can has implicit cast?
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front().getValue() ~ " is not a valid number value");
                        }
                        break;
                    case ID_ROTATE_ANIM:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "rotate_anim must have at most 1 argument");
                        }
                        else
                        {
                            Real angle;
                            if(get(prop.values.front(), angle))
                                mUnit.setRotateAnimation(angle);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front().getValue() ~ " is not a valid number value");
                        }
                        break;
                    case ID_SCALE:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 2)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "scale must have at most 2 arguments");
                        }
                        else
                        {
                            AbstractNodePtr i0 = getNodeAt(prop.values, 0), i1 = getNodeAt(prop.values, 1);
                            Real x, y;
                            if(get(i0, x) && get(i1, y))
                                mUnit.setTextureScale(x, y);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "first and second arguments must both be valid number values (received " ~ i0.getValue() ~ ", " ~ i1.getValue() ~ ")");
                        }
                        break;
                    case ID_WAVE_XFORM:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 6)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "wave_xform must have at most 6 arguments");
                        }
                        else
                        {
                            AbstractNodePtr i0 = getNodeAt(prop.values, 0), i1 = getNodeAt(prop.values, 1),
                                    i2 = getNodeAt(prop.values, 2), i3 = getNodeAt(prop.values, 3),
                                    i4 = getNodeAt(prop.values, 4), i5 = getNodeAt(prop.values, 5);
                            if(i0.type == ANT_ATOM && i1.type == ANT_ATOM && i2.type == ANT_ATOM &&
                               i3.type == ANT_ATOM && i4.type == ANT_ATOM && i5.type == ANT_ATOM)
                            {
                                AtomAbstractNode atom0 = cast(AtomAbstractNode)i0.get(), atom1 = cast(AtomAbstractNode)i1.get();
                                TextureUnitState.TextureTransformType type = TextureUnitState.TextureTransformType.TT_ROTATE;
                                WaveformType wave = WaveformType.WFT_SINE;
                                Real base = 0.0f, freq = 0.0f, phase = 0.0f, amp = 0.0f;
                                
                                switch(atom0.id)
                                {
                                    case ID_SCROLL_X:
                                        type = TextureUnitState.TextureTransformType.TT_TRANSLATE_U;
                                        break;
                                    case ID_SCROLL_Y:
                                        type = TextureUnitState.TextureTransformType.TT_TRANSLATE_V;
                                        break;
                                    case ID_SCALE_X:
                                        type = TextureUnitState.TextureTransformType.TT_SCALE_U;
                                        break;
                                    case ID_SCALE_Y:
                                        type = TextureUnitState.TextureTransformType.TT_SCALE_V;
                                        break;
                                    case ID_ROTATE:
                                        type = TextureUnitState.TextureTransformType.TT_ROTATE;
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          atom0.value ~ " is not a valid transform type (must be \"scroll_x\", \"scroll_y\", \"scale_x\", \"scale_y\", or \"rotate\")");
                                }
                                
                                switch(atom1.id)
                                {
                                    case ID_SINE:
                                        wave = WaveformType.WFT_SINE;
                                        break;
                                    case ID_TRIANGLE:
                                        wave = WaveformType.WFT_TRIANGLE;
                                        break;
                                    case ID_SQUARE:
                                        wave = WaveformType.WFT_SQUARE;
                                        break;
                                    case ID_SAWTOOTH:
                                        wave = WaveformType.WFT_SAWTOOTH;
                                        break;
                                    case ID_INVERSE_SAWTOOTH:
                                        wave = WaveformType.WFT_INVERSE_SAWTOOTH;
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          atom1.value ~ " is not a valid waveform type (must be \"sine\", \"triangle\", \"square\", \"sawtooth\", or \"inverse_sawtooth\")");
                                }
                                
                                if(!get(i2, base) || !get(i3, freq) || !get(i4, phase) || !get(i5, amp))
                                    compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                      "arguments 3, 4, 5, and 6 must be valid numbers; received " ~ i2.getValue() ~ ", " ~ i3.getValue() ~ ", " ~ i4.getValue() ~ ", " ~ i5.getValue());
                                
                                mUnit.setTransformAnimation(type, wave, base, freq, phase, amp);
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                            }
                        }
                        break;
                    case ID_TRANSFORM:
                    {
                        Matrix4 m;
                        if(getMatrix4(prop.values, m))
                            mUnit.setTextureTransform(m);
                        else
                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                    }
                        break;
                    case ID_BINDING_TYPE:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "binding_type must have at most 1 argument");
                        }
                        else
                        {
                            if(prop.values.front().type == ANT_ATOM)
                            {
                                AtomAbstractNode atom = cast(AtomAbstractNode)prop.values.front().get();
                                switch(atom.id)
                                {
                                    case ID_VERTEX:
                                        mUnit.setBindingType(TextureUnitState.BindingType.BT_VERTEX);
                                        break;
                                    case ID_FRAGMENT:
                                        mUnit.setBindingType(TextureUnitState.BindingType.BT_FRAGMENT);
                                        break;
                                    case ID_GEOMETRY:
                                        mUnit.setBindingType(TextureUnitState.BindingType.BT_GEOMETRY);
                                        break;
                                    case ID_TESSELATION_HULL:
                                        mUnit.setBindingType(TextureUnitState.BindingType.BT_TESSELATION_HULL);
                                        break;
                                    case ID_TESSELATION_DOMAIN:
                                        mUnit.setBindingType(TextureUnitState.BindingType.BT_TESSELATION_DOMAIN);
                                        break;
                                    case ID_COMPUTE:
                                        mUnit.setBindingType(TextureUnitState.BindingType.BT_COMPUTE);
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          atom.value ~ " is not a valid binding type (must be \"vertex\" or \"fragment\")");
                                }
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  prop.values.front().getValue() ~ " is not a valid binding type");
                            }
                        }
                        break;
                    case ID_CONTENT_TYPE:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 4)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "content_type must have at most 4 arguments");
                        }
                        else
                        {
                            if(prop.values.front().type == ANT_ATOM)
                            {
                                AtomAbstractNode atom = cast(AtomAbstractNode)prop.values.front().get();
                                switch(atom.id)
                                {
                                    case ID_NAMED:
                                        mUnit.setContentType(TextureUnitState.ContentType.CONTENT_NAMED);
                                        break;
                                    case ID_SHADOW:
                                        mUnit.setContentType(TextureUnitState.ContentType.CONTENT_SHADOW);
                                        break;
                                    case ID_COMPOSITOR:
                                        mUnit.setContentType(TextureUnitState.ContentType.CONTENT_COMPOSITOR);
                                        if (prop.values.length >= 3)
                                        {
                                            string compositorName;
                                            getString(getNodeAt(prop.values, 1), compositorName);
                                            string textureName;
                                            getString(getNodeAt(prop.values, 2), textureName);
                                            
                                            if (prop.values.length == 4)
                                            {
                                                uint mrtIndex;
                                                get(getNodeAt(prop.values, 3), mrtIndex);
                                                mUnit.setCompositorReference(compositorName, textureName, mrtIndex);
                                            }
                                            else
                                            {
                                                mUnit.setCompositorReference(compositorName, textureName);
                                            }
                                        }
                                        else
                                        {
                                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                              "content_type compositor must have an additional 2 or 3 parameters");
                                        }
                                        
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          atom.value ~ " is not a valid content type (must be \"named\" or \"shadow\" or \"compositor\")");
                                }
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                   prop.values.front().getValue() ~ " is not a valid content type");
                            }
                        }
                        break;
                    default:
                        compiler.addError(ScriptCompiler.CE_UNEXPECTEDTOKEN, prop.file, prop.line, 
                                          "token \"" ~ prop.name ~ "\" is not recognized");
                }               
            }
            else if(i.type == ANT_OBJECT)
            {
                processNode(compiler, i);
            }
        }
    }
}

class TextureSourceTranslator : ScriptTranslator
{
public:
    this() {}
    override void translate(ScriptCompiler compiler, /*const*/ AbstractNodePtr node)
    {
        ObjectAbstractNode obj = cast(ObjectAbstractNode)node.get();
        
        // It has to have one value identifying the texture source name
        if(obj.values.empty())
        {
            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, node.file, node.line,
                              "texture_source requires a type value");
            return;
        }
        
        // Set the value of the source
        ExternalTextureSourceManager.getSingleton().setCurrentPlugIn(obj.values.front().getValue());
        
        // Set up the technique, pass, and texunit levels
        if(ExternalTextureSourceManager.getSingleton().getCurrentPlugIn() !is null)
        {
            TextureUnitState texunit = obj.parent.context.get!TextureUnitState;
            Pass pass = texunit.getParent();
            Technique technique = pass.getParent();
            Material material = technique.getParent();
            
            ushort techniqueIndex = 0, passIndex = 0, texUnitIndex = 0;
            for(ushort i = 0; i < material.getNumTechniques(); i++)
            {
                if(material.getTechnique(i) == technique)
                {
                    techniqueIndex = i;
                    break;
                }
            }
            for(ushort i = 0; i < technique.getNumPasses(); i++)
            {
                if(technique.getPass(i) == pass)
                {
                    passIndex = i;
                    break;
                }
            }
            for(ushort i = 0; i < pass.getNumTextureUnitStates(); i++)
            {
                if(pass.getTextureUnitState(i) == texunit)
                {
                    texUnitIndex = i;
                    break;
                }
            }
            
            string tps = text(techniqueIndex, " ", passIndex, " ", texUnitIndex);
            
            ExternalTextureSourceManager.getSingleton().getCurrentPlugIn().setParameter( "set_T_P_S", tps );
            
            foreach(i; obj.children)
            {
                if(i.type == ANT_PROPERTY)
                {
                    PropertyAbstractNode prop = cast(PropertyAbstractNode)i.get();
                    // Glob the property values all together
                    string str = "";
                    foreach(j; prop.values)
                    {
                        if(j != prop.values[0])
                            str = str ~ " ";
                        str = str ~ j.getValue();
                    }
                ExternalTextureSourceManager.getSingleton().getCurrentPlugIn().setParameter(prop.name, str);
                }
                else if(i.type == ANT_OBJECT)
                {
                    processNode(compiler, i);
                }
            }
            
            ExternalTextureSourceManager.getSingleton().getCurrentPlugIn().createDefinedTexture(material.getName(), material.getGroup());
        }
    }
}

class GpuProgramTranslator : ScriptTranslator
{
public:
    this() {}
    override void translate(ScriptCompiler compiler, /*const*/ AbstractNodePtr node)
    {
        ObjectAbstractNode obj = cast(ObjectAbstractNode)node.get();
        
        // Must have a name
        if(obj.name.empty())
        {
            compiler.addError(ScriptCompiler.CE_OBJECTNAMEEXPECTED, obj.file, obj.line,
                              "gpu program object must have names");
            return;
        }
        
        // Must have a language type
        if(obj.values.empty())
        {
            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, obj.file, obj.line,
                              "gpu program object require language declarations");
            return;
        }
        
        // Get the language
        string language;
        if(!getString(obj.values.front(), language))
        {
            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, obj.file, obj.line);
            return;
        }
        
        if(language == "asm")
            translateGpuProgram(compiler, obj);
        else if(language == "unified")
            translateUnifiedGpuProgram(compiler, obj);
        else
            translateHighLevelGpuProgram(compiler, obj);
    }
    
protected:
    void translateGpuProgram(ScriptCompiler compiler, ObjectAbstractNode obj)
    {
        StringPair[] customParameters;
        string syntax, source;
        AbstractNodePtr params;
        foreach(i; obj.children)
        {
            if(i.type == ANT_PROPERTY)
            {
                PropertyAbstractNode prop = cast(PropertyAbstractNode)i.get();
                if(prop.id == ID_SOURCE)
                {
                    if(!prop.values.empty())
                    {
                        if(prop.values.front().type == ANT_ATOM)
                            source = (cast(AtomAbstractNode)prop.values.front().get()).value;
                        else
                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                              "source file expected");
                    }
                    else
                    {
                        compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line,
                                          "source file expected");
                    }
                }
                else if(prop.id == ID_SYNTAX)
                {
                    if(!prop.values.empty())
                    {
                        if(prop.values.front().type == ANT_ATOM)
                            syntax = (cast(AtomAbstractNode)prop.values.front().get()).value;
                        else
                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                              "syntax string expected");
                    }
                    else
                    {
                        compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line,
                                          "syntax string expected");
                    }
                }
                else
                {
                    string name = prop.name, value;
                    bool first = true;
                    foreach(it; prop.values)
                    {
                        if(it.type == ANT_ATOM)
                        {
                            if(!first)
                                value ~= " ";
                            else
                                first = false;
                            value ~= (cast(AtomAbstractNode)it.get()).value;
                        }
                    }
                    customParameters ~= StringPair(name, value);
                }
            }
            else if(i.type == ANT_OBJECT)
            {
                if((cast(ObjectAbstractNode)i.get()).id == ID_DEFAULT_PARAMS)
                    params = i;
                else
                    processNode(compiler, i);
            }
        }
        
        if (!GpuProgramManager.getSingleton().isSyntaxSupported(syntax))
        {
            compiler.addError(ScriptCompiler.CE_UNSUPPORTEDBYRENDERSYSTEM, obj.file, obj.line, ", Shader name: " ~ obj.name);
            //Register the unsupported program so that materials that use it know that
            //it exists but is unsupported
            GpuProgramPtr unsupportedProg = GpuProgramManager.getSingleton().create(obj.name, 
                                                                                    compiler.getResourceGroup(), translateIDToGpuProgramType(obj.id), syntax);
            return;
        }
        
        // Allocate the program
        GpuProgram prog;
        auto evt = new CreateGpuProgramScriptCompilerEvent(obj.file, obj.name, compiler.getResourceGroup(), source, syntax, translateIDToGpuProgramType(obj.id));
        bool processed = compiler._fireEvent(evt, &prog);
        if(!processed)
        {
            prog = cast(GpuProgram)(GpuProgramManager.getSingleton().createProgram(obj.name, 
                                                                                   compiler.getResourceGroup(), source, translateIDToGpuProgramType(obj.id), syntax).get());
        }
        
        // Check that allocation worked
        if(prog is null)
        {
            compiler.addError(ScriptCompiler.CE_OBJECTALLOCATIONERROR, obj.file, obj.line,
                              "gpu program \"" ~ obj.name ~ "\" could not be created");
            return;
        }
        
        obj.context = Any(prog);
        
        prog.setMorphAnimationIncluded(false);
        prog.setPoseAnimationIncluded(0);
        prog.setSkeletalAnimationIncluded(false);
        prog.setVertexTextureFetchRequired(false);
        prog._notifyOrigin(obj.file);
        
        // Set the custom parameters
        foreach(i; customParameters)
            prog.setParameter(i.first, i.second);
        
        // Set up default parameters
        if(prog.isSupported() && !params.isNull())
        {
            GpuProgramParametersPtr ptr = prog.getDefaultParameters();
            GpuProgramTranslator.translateProgramParameters(compiler, ptr, cast(ObjectAbstractNode)params.get());
        }
    }
    
    void translateHighLevelGpuProgram(ScriptCompiler compiler, ObjectAbstractNode obj)
    {
        if(obj.values.empty())
        {
            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, obj.file, obj.line);
            return;
        }
        string language;
        if(!getString(obj.values.front(), language))
        {
            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, obj.file, obj.line);
            return;
        }
        
        StringPair[] customParameters;
        string source;
        AbstractNodePtr params;
        foreach(i; obj.children)
        {
            if(i.type == ANT_PROPERTY)
            {
                PropertyAbstractNode prop = cast(PropertyAbstractNode)i.get();
                if(prop.id == ID_SOURCE)
                {
                    if(!prop.values.empty())
                    {
                        if(prop.values.front().type == ANT_ATOM)
                            source = (cast(AtomAbstractNode)prop.values.front().get()).value;
                        else
                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                              "source file expected");
                    }
                    else
                    {
                        compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line,
                                          "source file expected");
                    }
                }
                else
                {
                    string name = prop.name, value;
                    bool first = true;
                    foreach(it; prop.values)
                    {
                        if(it.type == ANT_ATOM)
                        {
                            if(!first)
                                value ~= " ";
                            else
                                first = false;
                            
                            if(prop.name == "attach")
                            {
                                auto evt = new ProcessResourceNameScriptCompilerEvent(ProcessResourceNameScriptCompilerEvent.GPU_PROGRAM, (cast(AtomAbstractNode)it.get()).value);
                                compiler._fireEvent(evt, null);
                                value ~= evt.mName;
                            }
                            else
                            {
                                value ~= (cast(AtomAbstractNode)it.get()).value;
                            }
                        }
                    }
                    customParameters ~= StringPair(name, value);
                }
            }
            else if(i.type == ANT_OBJECT)
            {
                if((cast(ObjectAbstractNode)i.get()).id == ID_DEFAULT_PARAMS)
                    params = i;
                else
                    processNode(compiler, i);
            }
        }
        
        // Allocate the program
        HighLevelGpuProgram prog;
        auto evt = new CreateHighLevelGpuProgramScriptCompilerEvent(obj.file, obj.name, compiler.getResourceGroup(), source, language, 
                                                         translateIDToGpuProgramType(obj.id));
        bool processed = compiler._fireEvent(evt, &prog);
        if(!processed)
        {
            prog = cast(HighLevelGpuProgram)(
                HighLevelGpuProgramManager.getSingleton().createProgram(obj.name, compiler.getResourceGroup(), 
                                                                     language, translateIDToGpuProgramType(obj.id)).get());
            prog.setSourceFile(source);
        }
        
        // Check that allocation worked
        if(prog is null)
        {
            compiler.addError(ScriptCompiler.CE_OBJECTALLOCATIONERROR, obj.file, obj.line,
                              "gpu program \"" ~ obj.name ~ "\" could not be created");
            return;
        }
        
        obj.context = Any(prog);
        
        prog.setMorphAnimationIncluded(false);
        prog.setPoseAnimationIncluded(0);
        prog.setSkeletalAnimationIncluded(false);
        prog.setVertexTextureFetchRequired(false);
        prog._notifyOrigin(obj.file);
        
        // Set the custom parameters
        foreach(i; customParameters)
            prog.setParameter(i.first, i.second);
        
        // Set up default parameters
        if(prog.isSupported() && !params.isNull())
        {
            GpuProgramParametersPtr ptr = prog.getDefaultParameters();
            GpuProgramTranslator.translateProgramParameters(compiler, ptr, cast(ObjectAbstractNode)params.get());
        }   
        
    }
    
    void translateUnifiedGpuProgram(ScriptCompiler compiler, ObjectAbstractNode obj)
    {
        StringPair[] customParameters;
        AbstractNodePtr params;
        
        foreach(i; obj.children)
        {
            if(i.type == ANT_PROPERTY)
            {
                PropertyAbstractNode prop = cast(PropertyAbstractNode)i.get();
                if(prop.name == "delegate")
                {
                    string value;
                    if(!prop.values.empty() && prop.values.front().type == ANT_ATOM)
                        value = (cast(AtomAbstractNode)prop.values.front().get()).value;
                    
                    auto evt = new ProcessResourceNameScriptCompilerEvent(ProcessResourceNameScriptCompilerEvent.GPU_PROGRAM, value);
                    compiler._fireEvent(evt, null);
                    customParameters ~= StringPair("delegate", evt.mName);
                }
                else
                {
                    string name = prop.name, value;
                    bool first = true;
                    foreach(it; prop.values)
                    {
                        if(it.type == ANT_ATOM)
                        {
                            if(!first)
                                value ~= " ";
                            else
                                first = false;
                            value ~= (cast(AtomAbstractNode)it.get()).value;
                        }
                    }
                    customParameters ~= StringPair(name, value);
                }
            }
            else if(i.type == ANT_OBJECT)
            {
                if((cast(ObjectAbstractNode)i.get()).id == ID_DEFAULT_PARAMS)
                    params = i;
                else
                    processNode(compiler, i);
            }
        }
        
        // Allocate the program
        HighLevelGpuProgram prog;
        auto evt = new CreateHighLevelGpuProgramScriptCompilerEvent(obj.file, obj.name, compiler.getResourceGroup(), "", "unified", translateIDToGpuProgramType(obj.id));
        bool processed = compiler._fireEvent(evt, &prog);
        
        if(!processed)
        {
            prog = cast(HighLevelGpuProgram)(
                HighLevelGpuProgramManager.getSingleton().createProgram(obj.name, compiler.getResourceGroup(), 
                                                                     "unified", translateIDToGpuProgramType(obj.id)).get());
        }
        
        // Check that allocation worked
        if(prog is null)
        {
            compiler.addError(ScriptCompiler.CE_OBJECTALLOCATIONERROR, obj.file, obj.line,
                              "gpu program \"" ~ obj.name ~ "\" could not be created");
            return;
        }
        
        obj.context = Any(prog);
        
        prog.setMorphAnimationIncluded(false);
        prog.setPoseAnimationIncluded(0);
        prog.setSkeletalAnimationIncluded(false);
        prog.setVertexTextureFetchRequired(false);
        prog._notifyOrigin(obj.file);
        
        // Set the custom parameters
        foreach(i; customParameters)
            prog.setParameter(i.first, i.second);
        
        // Set up default parameters
        if(prog.isSupported() && !params.isNull())
        {
            GpuProgramParametersPtr ptr = prog.getDefaultParameters();
            GpuProgramTranslator.translateProgramParameters(compiler, ptr, cast(ObjectAbstractNode)params.get());
        }
        
    }
public:
    static void translateProgramParameters(ScriptCompiler compiler, GpuProgramParametersPtr params, ObjectAbstractNode obj)
    {
        size_t animParametricsCount = 0;
        
        foreach(i; obj.children)
        {
            if(i.type == ANT_PROPERTY)
            {
                PropertyAbstractNode prop = cast(PropertyAbstractNode)i.get();
                switch(prop.id)
                {
                    case ID_SHARED_PARAMS_REF:
                    {
                        if(prop.values.length != 1)
                        {
                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                              "shared_params_ref requires a single parameter");
                            continue;
                        }
                        
                        AbstractNodePtr i0 = getNodeAt(prop.values, 0);
                        if(i0.type != ANT_ATOM)
                        {
                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                              "shared parameter set name expected");
                            continue;
                        }
                        AtomAbstractNode atom0 = cast(AtomAbstractNode)i0.get();
                        
                        try 
                        {
                            params.addSharedParameters(atom0.value);
                        }
                        catch(Exception e)
                        {
                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line, e.msg);
                        }
                    }
                        break;
                    case ID_PARAM_INDEXED:
                    case ID_PARAM_NAMED:
                    {
                        if(prop.values.length >= 3)
                        {
                            bool named = (prop.id == ID_PARAM_NAMED);
                            AbstractNodePtr i0 = getNodeAt(prop.values, 0), i1 = getNodeAt(prop.values, 1);
                            //auto k = prop.values[2..$];
                            size_t k = 2;
                            
                            if(i0.type != ANT_ATOM || i1.type != ANT_ATOM)
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "name or index and parameter type expected");
                                return;
                            }
                            
                            AtomAbstractNode atom0 = cast(AtomAbstractNode)i0.get(), atom1 = cast(AtomAbstractNode)i1.get();
                            if(!named && !StringUtil.isNumber(atom0.value))
                            {
                                compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line,
                                                  "parameter index expected");
                                return;
                            }
                            
                            string name;
                            size_t index = 0;
                            // Assign the name/index
                            if(named)
                                name = atom0.value;
                            else
                                index = to!int(atom0.value);
                            
                            // Determine the type
                            if(atom1.value == "matrix4x4")
                            {   
                                Matrix4 m;
                                if(getMatrix4(prop.values[k..$], m))
                                {
                                    k += 16;
                                    try
                                    {
                                        if(named)
                                            params.setNamedConstant(name, m);
                                        else
                                            params.setConstant(index, m);
                                    }
                                    catch
                                    {
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          "setting matrix4x4 parameter failed");
                                    }
                                }
                                else
                                {
                                    compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line,
                                                      "incorrect matrix4x4 declaration");
                                }
                            }
                            else if (atom1.value == "subroutine")
                            {
                                string s;
                                if (getString(prop.values[k], s))
                                {
                                    k++;
                                    try
                                    {
                                        if (named)
                                            params.setNamedSubroutine(name, s);
                                        else
                                            params.setSubroutine(index, s);
                                    }
                                    catch
                                    {
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                          "setting subroutine parameter failed");
                                    }
                                }
                                else
                                {
                                    compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line,
                                                      "incorrect subroutine declaration");
                                }
                            }
                            else if (atom1.value == "atomic_counter")
                            {
//                              string s;
//                              if (getString(k, s))
//                              {
//                                  try
//                                  {
//                                      if (named)
//                                          params.setNamedSubroutine(name, s);
//                                      else
//                                          params.setSubroutine(index, s);
//                                  }
//                                  catch
//                                  {
//                                      compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
//                                                        "setting subroutine parameter failed");
//                                  }
//                              }
//                              else
//                              {
//                                  compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line,
//                                                    "incorrect subroutine declaration");
//                              }
                            }
                            else
                            {
                                // Find the number of parameters
                                bool isValid = true;
                                GpuProgramParameters.ElementType type = GpuProgramParameters.ElementType.ET_REAL;
                                int count = 0;
                                if(atom1.value.indexOf("float") != -1 || atom1.value.indexOf("double") != -1)
                                {
                                    type = GpuProgramParameters.ElementType.ET_REAL;
                                    if(atom1.value.length >= 6)
                                        count = to!int(atom1.value[5..$]);
                                    else
                                    {
                                        count = 1;
                                    }
                                }
                                else if(atom1.value.indexOf("int") != -1)
                                {
                                    type = GpuProgramParameters.ElementType.ET_INT;
                                    if(atom1.value.length >= 4)
                                        count = to!int(atom1.value[3..$]);
                                    else
                                    {
                                        count = 1;
                                    }
                                }
                                else
                                {
                                    compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                      "incorrect type specified; only variants of int and float allowed");
                                    isValid = false;
                                }
                                
                                if(isValid)
                                {
                                    // First, clear out any offending auto constants
                                    if(named)
                                        params.clearNamedAutoConstant(name);
                                    else
                                        params.clearAutoConstant(index);
                                    
                                    int roundedCount = count%4 != 0 ? count + 4 - (count%4) : count;
                                    if(type == GpuProgramParameters.ElementType.ET_INT)
                                    {
                                        int[] vals;// = new int[roundedCount];
                                        if(get(prop.values[k..$], vals, roundedCount))
                                        {
                                            try
                                            {
                                                if(named)
                                                    params.setNamedConstant(name, vals.ptr, count, 1);
                                                else
                                                    params.setConstant(index, vals.ptr, roundedCount/4);
                                            }
                                            catch
                                            {
                                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                                  "setting of constant failed");
                                            }
                                        }
                                        else
                                        {
                                            compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line,
                                                              "incorrect integer constant declaration");
                                        }
                                    }
                                    else
                                    {
                                        float[] vals;// = new float[roundedCount];
                                        if(get(prop.values[k..$], vals, roundedCount))
                                        {
                                            try
                                            {
                                                if(named)
                                                    params.setNamedConstant(name, vals.ptr, count, 1);
                                                else
                                                    params.setConstant(index, vals.ptr, roundedCount/4);
                                            }
                                            catch
                                            {
                                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                                  "setting of constant failed");
                                            }
                                        }
                                        else
                                        {
                                            compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line,
                                                              "incorrect float constant declaration");
                                        }
                                    }
                                }
                            }
                        }
                        else
                        {
                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                              "param_named and param_indexed properties requires at least 3 arguments");
                        }
                    }
                        break;
                    case ID_PARAM_INDEXED_AUTO:
                    case ID_PARAM_NAMED_AUTO:
                    {
                        bool named = (prop.id == ID_PARAM_NAMED_AUTO);
                        string name;
                        
                        if(prop.values.length >= 2)
                        {
                            size_t index = 0;
                            AbstractNodePtr i0 = getNodeAt(prop.values, 0),
                                i1 = getNodeAt(prop.values, 1), i2 = getNodeAt(prop.values, 2), i3 = getNodeAt(prop.values, 3);
                            if(i0.type != ANT_ATOM || i1.type != ANT_ATOM)
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "name or index and auto constant type expected");
                                return;
                            }
                            AtomAbstractNode atom0 = cast(AtomAbstractNode)i0.get(), atom1 = cast(AtomAbstractNode)i1.get();
                            if(!named && !StringUtil.isNumber(atom0.value))
                            {
                                compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line,
                                                  "parameter index expected");
                                return;
                            }
                            
                            if(named)
                                name = atom0.value;
                            else
                                index = to!int(atom0.value);
                            
                            // Look up the auto constant
                            atom1.value = atom1.value.toLower();
                            GpuProgramParameters.AutoConstantDefinition *def =
                                GpuProgramParameters.getAutoConstantDefinition(atom1.value);
                            if(def)
                            {
                                final switch(def.dataType)
                                {
                                    case GpuProgramParameters.ACDataType.ACDT_NONE:
                                        // Set the auto constant
                                        try
                                        {
                                            if(named)
                                                params.setNamedAutoConstant(name, def.acType);
                                            else
                                                params.setAutoConstant(index, def.acType);
                                        }
                                        catch
                                        {
                                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                              "setting of constant failed");
                                        }
                                        break;
                                    case GpuProgramParameters.ACDataType.ACDT_INT:
                                        if(def.acType == GpuProgramParameters.AutoConstantType.ACT_ANIMATION_PARAMETRIC)
                                        {
                                            try
                                            {
                                                if(named)
                                                    params.setNamedAutoConstant(name, def.acType, animParametricsCount++);
                                                else
                                                    params.setAutoConstant(index, def.acType, animParametricsCount++);
                                            }
                                            catch
                                            {
                                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                                  "setting of constant failed");
                                            }
                                        }
                                        else
                                        {
                                            // Only certain texture projection auto params will assume 0
                                            // Otherwise we will expect that 3rd parameter
                                            if(i2.isNull())
                                            {
                                                if(def.acType == GpuProgramParameters.AutoConstantType.ACT_TEXTURE_VIEWPROJ_MATRIX ||
                                                   def.acType == GpuProgramParameters.AutoConstantType.ACT_TEXTURE_WORLDVIEWPROJ_MATRIX ||
                                                   def.acType == GpuProgramParameters.AutoConstantType.ACT_SPOTLIGHT_VIEWPROJ_MATRIX ||
                                                   def.acType == GpuProgramParameters.AutoConstantType.ACT_SPOTLIGHT_WORLDVIEWPROJ_MATRIX
                                                   )
                                                {
                                                    try
                                                    {
                                                        if(named)
                                                            params.setNamedAutoConstant(name, def.acType, 0);
                                                        else
                                                            params.setAutoConstant(index, def.acType, 0);
                                                    }
                                                    catch
                                                    {
                                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                                          "setting of constant failed");
                                                    }
                                                }
                                                else
                                                {
                                                    compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line,
                                                                      "extra parameters required by constant definition " ~ atom1.value);
                                                }
                                            }
                                            else
                                            {
                                                bool success = false;
                                                uint extraInfo = 0;
                                                if(i3.isNull())
                                                { // Handle only one extra value
                                                    if(get(i2, extraInfo))
                                                    {
                                                        success = true;
                                                    }
                                                }
                                                else
                                                { // Handle two extra values
                                                    uint extraInfo1 = 0, extraInfo2 = 0;
                                                    if(get(i2, extraInfo1) && get(i3, extraInfo2))
                                                    {
                                                        extraInfo = extraInfo1 | (extraInfo2 << 16);
                                                        success = true;
                                                    }
                                                }
                                                
                                                if(success)
                                                {
                                                    try
                                                    {
                                                        if(named)
                                                            params.setNamedAutoConstant(name, def.acType, extraInfo);
                                                        else
                                                            params.setAutoConstant(index, def.acType, extraInfo);
                                                    }
                                                    catch
                                                    {
                                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                                          "setting of constant failed");
                                                    }
                                                }
                                                else
                                                {
                                                    compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                                      "invalid auto constant extra info parameter");
                                                }
                                            }
                                        }
                                        break;
                                    case GpuProgramParameters.ACDataType.ACDT_REAL:
                                        if(def.acType == GpuProgramParameters.AutoConstantType.ACT_TIME ||
                                           def.acType == GpuProgramParameters.AutoConstantType.ACT_FRAME_TIME)
                                        {
                                            Real f = 1.0f;
                                            if(!i2.isNull())
                                                get(i2, f);
                                            
                                            try
                                            {
                                                if(named)
                                                    params.setNamedAutoConstantReal(name, def.acType, f);
                                                else
                                                    params.setAutoConstantReal(index, def.acType, f);
                                            }
                                            catch
                                            {
                                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                                  "setting of constant failed");
                                            }
                                        }
                                        else
                                        {
                                            if(!i2.isNull())
                                            {
                                                Real extraInfo = 0.0f;
                                                if(get(i2, extraInfo))
                                                {
                                                    try
                                                    {
                                                        if(named)
                                                            params.setNamedAutoConstantReal(name, def.acType, extraInfo);
                                                        else
                                                            params.setAutoConstantReal(index, def.acType, extraInfo);
                                                    }
                                                    catch
                                                    {
                                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                                          "setting of constant failed");
                                                    }
                                                }
                                                else
                                                {
                                                    compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                                      "incorrect float argument definition in extra parameters");
                                                }
                                            }
                                            else
                                            {
                                                compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line,
                                                                  "extra parameters required by constant definition " ~ atom1.value);
                                            }
                                        }
                                        break;
                                }
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                            }
                        }
                        else
                        {
                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                        }
                    }
                        break;
                    default:
                        compiler.addError(ScriptCompiler.CE_UNEXPECTEDTOKEN, prop.file, prop.line, 
                                          "token \"" ~ prop.name ~ "\" is not recognized");
                }
            }
        }
    }
}

class SharedParamsTranslator : ScriptTranslator
{
public:
    this(){}
    override void translate(ScriptCompiler compiler, /*const*/ AbstractNodePtr node)
    {
        ObjectAbstractNode obj = cast(ObjectAbstractNode)node.get();
        
        // Must have a name
        if(obj.name.empty())
        {
            compiler.addError(ScriptCompiler.CE_OBJECTNAMEEXPECTED, obj.file, obj.line,
                              "shared_params must be given a name");
            return;
        }
        
        GpuSharedParameters sharedParams;
        auto evt = new CreateGpuSharedParametersScriptCompilerEvent(obj.file, obj.name, compiler.getResourceGroup());
        bool processed = compiler._fireEvent(evt, &sharedParams);
        
        if(!processed)
        {
            sharedParams = GpuProgramManager.getSingleton().createSharedParameters(obj.name).get();
        }
        
        if(!sharedParams)
        {
            compiler.addError(ScriptCompiler.CE_OBJECTALLOCATIONERROR, obj.file, obj.line);
            return;
        }
        
        
        foreach(i; obj.children)
        {
            if(i.type == ANT_PROPERTY)
            {
                PropertyAbstractNode prop = cast(PropertyAbstractNode)i.get();
                switch(prop.id)
                {
                    default:
                        break;
                    case ID_SHARED_PARAM_NAMED:
                    {
                        if(prop.values.length < 2)
                        {
                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                              "shared_param_named - expected 2 or more arguments");
                            continue;
                        }
                        
                        AbstractNodePtr i0 = getNodeAt(prop.values, 0), i1 = getNodeAt(prop.values, 1);
                        
                        if(i0.type != ANT_ATOM || i1.type != ANT_ATOM)
                        {
                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                              "name and parameter type expected");
                            continue;
                        }
                        
                        
                        AtomAbstractNode atom0 = cast(AtomAbstractNode)i0.get();
                        
                        string pName = atom0.value;
                        GpuConstantType constType = GpuConstantType.GCT_UNKNOWN;
                        size_t arraySz = 1;
                        if (!getConstantType(i1, constType))
                        {
                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                              "invalid parameter type");
                            continue;
                        }
                        
                        bool isFloat = GpuConstantDefinition.isFloat(constType);
                        
                        auto mFloats = appender!(float[])();
                        auto mInts = appender!(int[])();
                        
                        AbstractNodeList otherVals = prop.values[2..$];
                        //std::advance(otherValsi, 2);
                        
                        foreach (otherValsi; otherVals)
                        {
                            if(otherValsi.type != ANT_ATOM)
                                continue;
                            
                            AtomAbstractNode atom = cast(AtomAbstractNode)otherValsi.get();
                            
                            if (atom.value.front == '[' && atom.value.back == ']')
                            {
                                string arrayStr = atom.value[1..$-1];
                                if(!StringUtil.isNumber(arrayStr))
                                {
                                    compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line,
                                                      "invalid array size");
                                    continue;
                                }
                                arraySz = to!int(arrayStr);
                            }
                            else
                            {
                                if(!StringUtil.isNumber(atom.value))
                                {
                                    compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line,
                                                      atom.value ~ " invalid - extra parameters to shared_param_named must be numbers");
                                    continue;
                                }
                                if (isFloat)
                                    mFloats.put(to!float(atom.value));
                                else
                                    mInts.put(to!int(atom.value));
                            }
                            
                        } // each extra param
                        
                        // define constant entry
                        try 
                        {
                            sharedParams.addConstantDefinition(pName, constType, arraySz);
                        }
                        catch(Exception e)
                        {
                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line, e.msg);
                            continue;
                        }
                        
                        
                        // initial values
                        size_t elemsExpected = GpuConstantDefinition.getElementSize(constType, false) * arraySz;
                        size_t elemsFound = isFloat ? mFloats.data.length : mInts.data.length;
                        if (elemsFound)
                        {
                            if (elemsExpected != elemsFound)
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line, 
                                                  "Wrong number of values supplied for parameter type");
                                continue;
                            }
                            
                            if (isFloat)
                                sharedParams.setNamedConstant(pName, mFloats.data.ptr, elemsFound);
                            else
                                sharedParams.setNamedConstant(pName, mInts.data.ptr, elemsFound);
                            
                        }
                    }
                }
            }
        }
        
        
        
    }
protected:
}

/**************************************************************************
 * Particle System section
 *************************************************************************/
class ParticleSystemTranslator : ScriptTranslator
{
protected:
    ParticleSystem mSystem;
public:
    this() {}
    override void translate(ScriptCompiler compiler, /*const*/ AbstractNodePtr node)
    {
        ObjectAbstractNode obj = cast(ObjectAbstractNode)node.get();
        // Find the name
        if(obj.name.empty())
        {
            compiler.addError(ScriptCompiler.CE_OBJECTNAMEEXPECTED, obj.file, obj.line);
            return;
        }
        
        // Allocate the particle system
        auto evt = new CreateParticleSystemScriptCompilerEvent(obj.file, obj.name, compiler.getResourceGroup());
        bool processed = compiler._fireEvent(evt, &mSystem);
        
        if(!processed)
        {
            mSystem = ParticleSystemManager.getSingleton().createTemplate(obj.name, compiler.getResourceGroup());
        }
        
        if(!mSystem)
        {
            compiler.addError(ScriptCompiler.CE_OBJECTALLOCATIONERROR, obj.file, obj.line);
            return;
        }
        
        mSystem._notifyOrigin(obj.file);
        
        mSystem.removeAllEmitters();
        mSystem.removeAllAffectors();
        
        obj.context = Any(mSystem);
        
        foreach(i; obj.children)
        {
            if(i.type == ANT_PROPERTY)
            {
                PropertyAbstractNode prop = cast(PropertyAbstractNode)i.get();
                switch(prop.id)
                {
                    case ID_MATERIAL:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else
                        {
                            if(prop.values.front().type == ANT_ATOM)
                            {
                                string name = (cast(AtomAbstractNode)prop.values.front().get()).value;
                                
                                auto locEvt = new ProcessResourceNameScriptCompilerEvent(ProcessResourceNameScriptCompilerEvent.MATERIAL, name);
                                compiler._fireEvent(locEvt, null);
                                
                                if(!mSystem.setParameter("material", locEvt.mName))
                                {
                                    if(mSystem.getRenderer())
                                    {
                                        if(!mSystem.getRenderer().setParameter("material", locEvt.mName))
                                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                              "material property could not be set with material \"" ~ locEvt.mName ~ "\"");
                                    }
                                }
                            }
                        }
                        break;
                    default:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else
                        {
                            string name = prop.name, value;
                            
                            // Glob the values together
                            foreach(it; prop.values)
                            {
                                if(it.type == ANT_ATOM)
                                {
                                    if(value.empty())
                                        value = (cast(AtomAbstractNode)it.get()).value;
                                    else
                                        value = value ~ " " ~ (cast(AtomAbstractNode)it.get()).value;
                                }
                                else
                                {
                                    compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                                    return;
                                }
                            }
                            
                            if(!mSystem.setParameter(name, value))
                            {
                                if(mSystem.getRenderer())
                                {
                                    if(!mSystem.getRenderer().setParameter(name, value))
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                                }
                            }
                        }
                }
            }
            else
            {
                processNode(compiler, i);
            }
        }
    }
}

class ParticleEmitterTranslator : ScriptTranslator
{
protected:
    ParticleEmitter mEmitter;
public:
    this() {}
    override void translate(ScriptCompiler compiler, /*const*/ AbstractNodePtr node)
    {
        ObjectAbstractNode obj = cast(ObjectAbstractNode)(node.get());
        
        // Must have a type as the first value
        if(obj.values.empty())
        {
            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, obj.file, obj.line);
            return;
        }
        
        string type;
        if(!getString(obj.values.front(), type))
        {
            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, obj.file, obj.line);
            return;
        }
        
        ParticleSystem system = obj.parent.context.get!ParticleSystem;
        mEmitter = system.addEmitter(type);
        
        foreach(i; obj.children)
        {
            if(i.type == ANT_PROPERTY)
            {
                PropertyAbstractNode prop = cast(PropertyAbstractNode)(i.get());
                string value;
                
                // Glob the values together
                foreach(it; prop.values)
                {
                    if(it.type == ANT_ATOM)
                    {
                        if(value.empty())
                            value = (cast(AtomAbstractNode)it.get()).value;
                        else
                            value = value ~ " " ~ (cast(AtomAbstractNode)it.get()).value;
                    }
                    else
                    {
                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                        break;
                    }
                }
                
                if(!mEmitter.setParameter(prop.name, value))
                {
                    compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                }
            }
            else
            {
                processNode(compiler, i);
            }
        }
    }
}

class ParticleAffectorTranslator : ScriptTranslator
{
protected:
    ParticleAffector mAffector;
public:
    this() {}
    override void translate(ScriptCompiler compiler, /*const*/ AbstractNodePtr node)
    {
        ObjectAbstractNode obj = cast(ObjectAbstractNode)(node.get());
        
        // Must have a type as the first value
        if(obj.values.empty())
        {
            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, obj.file, obj.line);
            return;
        }
        
        string type;
        if(!getString(obj.values.front(), type))
        {
            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, obj.file, obj.line);
            return;
        }
        
        ParticleSystem system = obj.parent.context.get!ParticleSystem;
        mAffector = system.addAffector(type);
        
        foreach(i; obj.children)
        {
            if(i.type == ANT_PROPERTY)
            {
                PropertyAbstractNode prop = cast(PropertyAbstractNode)(i.get());
                string value;
                
                // Glob the values together
                foreach(it; prop.values)
                {
                    if(it.type == ANT_ATOM)
                    {
                        if(value.empty())
                            value = (cast(AtomAbstractNode)it.get()).value;
                        else
                            value = value ~ " " ~ (cast(AtomAbstractNode)it.get()).value;
                    }
                    else
                    {
                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                        break;
                    }
                }
                
                if(!mAffector.setParameter(prop.name, value))
                {
                    compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                }
            }
            else
            {
                processNode(compiler, i);
            }
        }
    }
}

/**************************************************************************
* Compositor section
*************************************************************************/
class CompositorTranslator : ScriptTranslator
{
protected:
    Compositor mCompositor;
public:
    this() {}
    override void translate(ScriptCompiler compiler, /*const*/ AbstractNodePtr node)
    {
        ObjectAbstractNode obj = cast(ObjectAbstractNode)(node.get());
        if(obj.name.empty())
        {
            compiler.addError(ScriptCompiler.CE_OBJECTNAMEEXPECTED, obj.file, obj.line);
            return;
        }
        
        // Create the compositor
        auto evt = new CreateCompositorScriptCompilerEvent(obj.file, obj.name, compiler.getResourceGroup());
        bool processed = compiler._fireEvent(evt, &mCompositor);
        
        if(!processed)
        {
            mCompositor = cast(Compositor)(CompositorManager.getSingleton().create(obj.name, 
                                                                                   compiler.getResourceGroup()).get());
        }
        
        if(mCompositor is null)
        {
            compiler.addError(ScriptCompiler.CE_OBJECTALLOCATIONERROR, obj.file, obj.line);
            return;
        }
        
        // Prepare the compositor
        mCompositor.removeAllTechniques();
        mCompositor._notifyOrigin(obj.file);
        obj.context = Any(mCompositor);
        
        foreach(i; obj.children)
        {
            if(i.type == ANT_OBJECT)
            {
                processNode(compiler, i);
            }
            else
            {
                compiler.addError(ScriptCompiler.CE_UNEXPECTEDTOKEN, i.file, i.line,
                                  "token not recognized");
            }
        }
    }
}

class CompositionTechniqueTranslator : ScriptTranslator
{
protected:
    CompositionTechnique mTechnique;
public:
    this() {}
    override void translate(ScriptCompiler compiler, /*const*/ AbstractNodePtr node)
    {
        ObjectAbstractNode obj = cast(ObjectAbstractNode)(node.get());
        
        Compositor compositor = obj.parent.context.get!Compositor;
        mTechnique = compositor.createTechnique();
        obj.context = Any(mTechnique);
        
        foreach(i; obj.children)
        {
            if(i.type == ANT_OBJECT)
            {
                processNode(compiler, i);
            }
            else if(i.type == ANT_PROPERTY)
            {
                PropertyAbstractNode prop = cast(PropertyAbstractNode)(i.get());
                switch(prop.id)
                {
                    case ID_TEXTURE:
                    {
                        size_t atomIndex = 1;
                        
                        AbstractNodePtr it = getNodeAt(prop.values, 0);
                        
                        if(it.type != ANT_ATOM)
                        {
                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                            return;
                        }
                        // Save the first atom, should be name
                        AtomAbstractNode atom0 = cast(AtomAbstractNode)it.get();
                        
                        size_t width = 0, height = 0;
                        float widthFactor = 1.0f, heightFactor = 1.0f;
                        bool widthSet = false, heightSet = false, formatSet = false;
                        bool pooled = false;
                        bool hwGammaWrite = false;
                        bool fsaa = true;
                        ushort depthBufferId = DepthBuffer.PoolId.POOL_DEFAULT;
                        CompositionTechnique.TextureScope _scope = CompositionTechnique.TextureScope.TS_LOCAL;
                        PixelFormatList formats;
                        
                        while (atomIndex < prop.values.length)
                        {
                            it = getNodeAt(prop.values, atomIndex++);
                            if(it.type != ANT_ATOM)
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                                return;
                            }
                            AtomAbstractNode atom = cast(AtomAbstractNode)it.get();
                            
                            switch(atom.id)
                            {
                                case ID_TARGET_WIDTH:
                                    width = 0;
                                    widthSet = true;
                                    break;
                                case ID_TARGET_HEIGHT:
                                    height = 0;
                                    heightSet = true;
                                    break;
                                case ID_TARGET_WIDTH_SCALED:
                                case ID_TARGET_HEIGHT_SCALED:
                                {
                                    bool *pSetFlag;
                                    size_t *pSize;
                                    float *pFactor;
                                    
                                    if (atom.id == ID_TARGET_WIDTH_SCALED)
                                    {
                                        pSetFlag = &widthSet;
                                        pSize = &width;
                                        pFactor = &widthFactor;
                                    }
                                    else
                                    {
                                        pSetFlag = &heightSet;
                                        pSize = &height;
                                        pFactor = &heightFactor;
                                    }
                                    // advance to next to get scaling
                                    it = getNodeAt(prop.values, atomIndex++);
                                    if(it.isNull() || it.type != ANT_ATOM)
                                    {
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                                        return;
                                    }
                                    atom = cast(AtomAbstractNode)it.get();
                                    if (!StringUtil.isNumber(atom.value))
                                    {
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                                        return;
                                    }
                                    
                                    *pSize = 0;
                                    *pFactor = to!Real(atom.value);
                                    *pSetFlag = true;
                                }
                                    break;
                                case ID_POOLED:
                                    pooled = true;
                                    break;
                                case ID_SCOPE_LOCAL:
                                    _scope = CompositionTechnique.TextureScope.TS_LOCAL;
                                    break;
                                case ID_SCOPE_CHAIN:
                                    _scope = CompositionTechnique.TextureScope.TS_CHAIN;
                                    break;
                                case ID_SCOPE_GLOBAL:
                                    _scope = CompositionTechnique.TextureScope.TS_GLOBAL;
                                    break;
                                case ID_GAMMA:
                                    hwGammaWrite = true;
                                    break;
                                case ID_NO_FSAA:
                                    fsaa = false;
                                    break;
                                case ID_DEPTH_POOL:
                                {
                                    // advance to next to get the ID
                                    it = getNodeAt(prop.values, atomIndex++);
                                    if(it.isNull() || it.type != ANT_ATOM)
                                    {
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                                        return;
                                    }
                                    atom = cast(AtomAbstractNode)it.get();
                                    if (!StringUtil.isNumber(atom.value))
                                    {
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                                        return;
                                    }
                                    
                                    depthBufferId = to!ushort(atom.value);
                                }
                                    break;
                                default:
                                    if (StringUtil.isNumber(atom.value))
                                    {
                                        if (atomIndex == 2)
                                        {
                                            width = to!int(atom.value);
                                            widthSet = true;
                                        }
                                        else if (atomIndex == 3)
                                        {
                                            height = to!int(atom.value);
                                            heightSet = true;
                                        }
                                        else
                                        {
                                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                                            return;
                                        }
                                    }
                                    else
                                    {
                                        // pixel format?
                                        PixelFormat format = PixelUtil.getFormatFromName(atom.value, true);
                                        if (format == PixelFormat.PF_UNKNOWN)
                                        {
                                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                                            return;
                                        }
                                        formats ~= format;
                                        formatSet = true;
                                    }
                                    
                            }
                        }
                        if (!widthSet || !heightSet || !formatSet)
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                            return;
                        }
                        
                        
                        // No errors, create
                        CompositionTechnique.TextureDefinition def = mTechnique.createTextureDefinition(atom0.value);
                        def.width = width;
                        def.height = height;
                        def.widthFactor = widthFactor;
                        def.heightFactor = heightFactor;
                        def.formatList = formats;
                        def.fsaa = fsaa;
                        def.hwGammaWrite = hwGammaWrite;
                        def.depthBufferId = depthBufferId;
                        def.pooled = pooled;
                        def._scope = _scope;
                    }
                        break;
                    case ID_TEXTURE_REF:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length != 3)
                        {
                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                              "texture_ref only supports 3 argument");
                        }
                        else
                        {
                            string texName, refCompName, refTexName;
                            
                            AbstractNodePtr it = getNodeAt(prop.values, 0);
                            if(!getString(it, texName))
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "texture_ref must have 3 string arguments");
                            
                            it = getNodeAt(prop.values, 1);
                            if(!getString(it, refCompName))
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "texture_ref must have 3 string arguments");
                            
                            it = getNodeAt(prop.values, 2);
                            if(!getString(it, refTexName))
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "texture_ref must have 3 string arguments");
                            
                            CompositionTechnique.TextureDefinition refTexDef = 
                                mTechnique.createTextureDefinition(texName);
                            
                            refTexDef.refCompName = refCompName;
                            refTexDef.refTexName = refTexName;
                        }
                        break;
                    case ID_SCHEME:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "scheme only supports 1 argument");
                        }
                        else
                        {
                            AbstractNodePtr i0 = getNodeAt(prop.values, 0);
                            string scheme;
                            if(getString(i0, scheme))
                                mTechnique.setSchemeName(scheme);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "scheme must have 1 string argument");
                        }
                        break;
                    case ID_COMPOSITOR_LOGIC:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                        }
                        else if(prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line,
                                              "compositor logic only supports 1 argument");
                        }
                        else
                        {
                            AbstractNodePtr i0 = getNodeAt(prop.values, 0);
                            string logicName;
                            if(getString(i0, logicName))
                                mTechnique.setCompositorLogicName(logicName);
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line,
                                                  "compositor logic must have 1 string argument");
                        }
                        break;
                    default:
                        compiler.addError(ScriptCompiler.CE_UNEXPECTEDTOKEN, prop.file, prop.line, 
                                          "token \"" ~ prop.name ~ "\" is not recognized");
                }
            }
        }
    }
}

class CompositionTargetPassTranslator : ScriptTranslator
{
protected:
    CompositionTargetPass mTarget;
public:
    this() {}
    override void translate(ScriptCompiler compiler, /*const*/ AbstractNodePtr node)
    {
        ObjectAbstractNode obj = cast(ObjectAbstractNode)(node.get());
        
        CompositionTechnique technique = obj.parent.context.get!CompositionTechnique;
        if(obj.id == ID_TARGET)
        {
            mTarget = technique.createTargetPass();
            if(!obj.name.empty())
            {
                string name = obj.name;
                
                mTarget.setOutputName(name);
            }
        }
        else if(obj.id == ID_TARGET_OUTPUT)
        {
            mTarget = technique.getOutputTargetPass();
        }
        obj.context = Any(mTarget);
        
        foreach(i; obj.children)
        {
            if(i.type == ANT_OBJECT)
            {
                processNode(compiler, i);
            }
            else if(i.type == ANT_PROPERTY)
            {
                PropertyAbstractNode prop = cast(PropertyAbstractNode)(i.get());
                switch(prop.id)
                {
                    case ID_INPUT:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else if (prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else
                        {
                            if(prop.values.front().type == ANT_ATOM)
                            {
                                AtomAbstractNode atom = cast(AtomAbstractNode)prop.values.front().get();
                                switch(atom.id)
                                {
                                    case ID_NONE:
                                        mTarget.setInputMode(CompositionTargetPass.InputMode.IM_NONE);
                                        break;
                                    case ID_PREVIOUS:
                                        mTarget.setInputMode(CompositionTargetPass.InputMode.IM_PREVIOUS);
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                                }
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                            }
                        }
                        break;
                    case ID_ONLY_INITIAL:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else if (prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else
                        {
                            bool val;
                            if(getBoolean(prop.values.front(), val))
                            {
                                mTarget.setOnlyInitial(val);
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                            }
                        }
                        break;
                    case ID_VISIBILITY_MASK:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else if (prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else
                        {
                            uint val;
                            if(get(prop.values.front(), val))
                            {
                                mTarget.setVisibilityMask(val);
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                            }
                        }
                        break;
                    case ID_LOD_BIAS:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else if (prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else
                        {
                            float val;
                            if(get(prop.values.front(), val))
                            {
                                mTarget.setLodBias(val);
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                            }
                        }
                        break;
                    case ID_MATERIAL_SCHEME:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else if (prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else
                        {
                            string val;
                            if(getString(prop.values.front(), val))
                            {
                                mTarget.setMaterialScheme(val);
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                            }
                        }
                        break;
                    case ID_SHADOWS_ENABLED:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else if (prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else
                        {
                            bool val;
                            if(getBoolean(prop.values.front(), val))
                            {
                                mTarget.setShadowsEnabled(val);
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                            }
                        }
                        break;
                    default:
                        compiler.addError(ScriptCompiler.CE_UNEXPECTEDTOKEN, prop.file, prop.line, 
                                          "token \"" ~ prop.name ~ "\" is not recognized");
                }
            }
        }
    }
}

class CompositionPassTranslator : ScriptTranslator
{
protected:
    CompositionPass mPass;
public:
    this(){}
    override void translate(ScriptCompiler compiler, /*const*/ AbstractNodePtr node)
    {
        ObjectAbstractNode obj = cast(ObjectAbstractNode)(node.get());
        
        CompositionTargetPass target = obj.parent.context.get!CompositionTargetPass;
        mPass = target.createPass();
        obj.context = Any(mPass);
        
        // The name is the type of the pass
        if(obj.values.empty())
        {
            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, obj.file, obj.line);
            return;
        }
        string type;
        if(!getString(obj.values.front(), type))
        {
            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, obj.file, obj.line);
            return;
        }
        
        if(type == "clear")
            mPass.setType(CompositionPass.PassType.PT_CLEAR);
        else if(type == "stencil")
            mPass.setType(CompositionPass.PassType.PT_STENCIL);
        else if(type == "render_quad")
            mPass.setType(CompositionPass.PassType.PT_RENDERQUAD);
        else if(type == "render_scene")
            mPass.setType(CompositionPass.PassType.PT_RENDERSCENE);
        else if(type == "render_custom") {
            mPass.setType(CompositionPass.PassType.PT_RENDERCUSTOM);
            string customType;
            //This is the ugly one liner for safe access to the second parameter.
            if (obj.values.length < 2 || !getString(obj.values[1], customType))
            {
                compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, obj.file, obj.line);
                return;
            }
            mPass.setCustomType(customType);
        }
        else
        {
            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, obj.file, obj.line,
                              "pass types must be \"clear\", \"stencil\", \"render_quad\", \"render_scene\" or \"render_custom\".");
            return;
        }
        
        foreach(i; obj.children)
        {
            if(i.type == ANT_OBJECT)
            {
                processNode(compiler, i);
            }
            else if(i.type == ANT_PROPERTY)
            {
                PropertyAbstractNode prop = cast(PropertyAbstractNode)(i.get());
                switch(prop.id)
                {
                    case ID_CHECK:
                    {
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                            return;
                        }
                        bool val;
                        if(getBoolean(prop.values.front(), val))
                            mPass.setStencilCheck(val);
                        else
                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                    }
                        break;
                    case ID_COMP_FUNC:
                    {
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                            return;
                        }
                        CompareFunction func;
                        if(getCompareFunction(prop.values.front(), func))
                            mPass.setStencilFunc(func);
                        else
                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                    }
                        break;
                    case ID_REF_VALUE:
                    {
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line);
                            return;
                        }
                        uint val;
                        if(get(prop.values.front(), val))
                            mPass.setStencilRefValue(val);
                        else
                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                    }
                        break;
                    case ID_MASK:
                    {
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line);
                            return;
                        }
                        uint val;
                        if(get(prop.values.front(), val))
                            mPass.setStencilMask(val);
                        else
                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                    }
                        break;
                    case ID_FAIL_OP:
                    {
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                            return;
                        }
                        StencilOperation val;
                        if(getStencilOp(prop.values.front(), val))
                            mPass.setStencilFailOp(val);
                        else
                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                    }
                        break;
                    case ID_DEPTH_FAIL_OP:
                    {
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                            return;
                        }
                        StencilOperation val;
                        if(getStencilOp(prop.values.front(), val))
                            mPass.setStencilDepthFailOp(val);
                        else
                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                    }
                        break;
                    case ID_PASS_OP:
                    {
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                            return;
                        }
                        StencilOperation val;
                        if(getStencilOp(prop.values.front(), val))
                            mPass.setStencilPassOp(val);
                        else
                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                    }
                        break;
                    case ID_TWO_SIDED:
                    {
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                            return;
                        }
                        bool val;
                        if(getBoolean(prop.values.front(), val))
                            mPass.setStencilTwoSidedOperation(val);
                        else
                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                    }
                        break;
                    case ID_BUFFERS:
                    {
                        uint buffers = 0;
                        foreach(k; prop.values)
                        {
                            if(k.type == ANT_ATOM)
                            {
                                switch((cast(AtomAbstractNode)k.get()).id)
                                {
                                    case ID_COLOUR:
                                        buffers |= FrameBufferType.FBT_COLOUR;
                                        break;
                                    case ID_DEPTH:
                                        buffers |= FrameBufferType.FBT_DEPTH;
                                        break;
                                    case ID_STENCIL:
                                        buffers |= FrameBufferType.FBT_STENCIL;
                                        break;
                                    default:
                                        compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                                }
                            }
                            else
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                        }
                        mPass.setClearBuffers(buffers);
                    }
                        break;
                    case ID_COLOUR_VALUE:
                    {
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line);
                            return;
                        }
                        ColourValue val;
                        if(getColour(prop.values, val))
                            mPass.setClearColour(val);
                        else
                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                    }
                        break;
                    case ID_DEPTH_VALUE:
                    {
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line);
                            return;
                        }
                        Real val;
                        if(get(prop.values.front(), val))
                            mPass.setClearDepth(val);
                        else
                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                    }
                        break;
                    case ID_STENCIL_VALUE:
                    {
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line);
                            return;
                        }
                        uint val;
                        if(get(prop.values.front(), val))
                            mPass.setClearStencil(val);
                        else
                            compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                    }
                        break;
                    case ID_MATERIAL:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else if (prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else
                        {
                            string val;
                            if(getString(prop.values.front(), val))
                            {
                                auto evt = new ProcessResourceNameScriptCompilerEvent(ProcessResourceNameScriptCompilerEvent.MATERIAL, val);
                                compiler._fireEvent(evt, null);
                                mPass.setMaterialName(evt.mName);
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                            }
                        }
                        break;
                    case ID_INPUT:
                        if(prop.values.length < 2)
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else if (prop.values.length > 3)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else
                        {
                            AbstractNodePtr i0 = getNodeAt(prop.values, 0), i1 = getNodeAt(prop.values, 1), i2 = getNodeAt(prop.values, 2);
                            uint id;
                            string name;
                            if(get(i0, id) && getString(i1, name))
                            {
                                uint index = 0;
                                if(!i2.isNull())
                                {
                                    if(!get(i2, index))
                                    {
                                        compiler.addError(ScriptCompiler.CE_NUMBEREXPECTED, prop.file, prop.line);
                                        return;
                                    }
                                }
                                
                                mPass.setInput(id, name, index);
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                            }
                        }
                        break;
                    case ID_IDENTIFIER:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else if (prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else
                        {
                            uint val;
                            if(get(prop.values.front(), val))
                            {
                                mPass.setIdentifier(val);
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                            }
                        }
                        break;
                    case ID_FIRST_RENDER_QUEUE:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else if (prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else
                        {
                            uint val;
                            if(get(prop.values.front(), val))
                            {
                                mPass.setFirstRenderQueue(cast(ubyte)val);
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                            }
                        }
                        break;
                    case ID_LAST_RENDER_QUEUE:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else if (prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else
                        {
                            uint val;
                            if(get(prop.values.front(), val))
                            {
                                mPass.setLastRenderQueue(cast(ubyte)val);
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                            }
                        }
                        break;
                    case ID_MATERIAL_SCHEME:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else if (prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else
                        {
                            string val;
                            if(getString(prop.values.front(), val))
                            {
                                mPass.setMaterialScheme(val);
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                            }
                        }
                        break;
                    case ID_QUAD_NORMALS:
                        if(prop.values.empty())
                        {
                            compiler.addError(ScriptCompiler.CE_STRINGEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else if (prop.values.length > 1)
                        {
                            compiler.addError(ScriptCompiler.CE_FEWERPARAMETERSEXPECTED, prop.file, prop.line);
                            return;
                        }
                        else
                        {
                            if(prop.values.front().type == ANT_ATOM)
                            {
                                AtomAbstractNode atom = cast(AtomAbstractNode)prop.values.front().get();
                                if(atom.id == ID_CAMERA_FAR_CORNERS_VIEW_SPACE)
                                    mPass.setQuadFarCorners(true, true);
                                else if(atom.id == ID_CAMERA_FAR_CORNERS_WORLD_SPACE)
                                    mPass.setQuadFarCorners(true, false);
                                else
                                    compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                            }
                            else
                            {
                                compiler.addError(ScriptCompiler.CE_INVALIDPARAMETERS, prop.file, prop.line);
                            }
                        }
                        break;
                    default:
                        compiler.addError(ScriptCompiler.CE_UNEXPECTEDTOKEN, prop.file, prop.line, 
                                          "token \"" ~ prop.name ~ "\" is not recognized");
                }
            }
        }
    }
}

/**************************************************************************
     * BuiltinScriptTranslatorManager
     *************************************************************************/
/// This class manages the builtin translators
class BuiltinScriptTranslatorManager : ScriptTranslatorManager
{
private:
    MaterialTranslator mMaterialTranslator;
    TechniqueTranslator mTechniqueTranslator;
    PassTranslator mPassTranslator;
    TextureUnitTranslator mTextureUnitTranslator;
    TextureSourceTranslator mTextureSourceTranslator;
    GpuProgramTranslator mGpuProgramTranslator;
    SharedParamsTranslator mSharedParamsTranslator;
    ParticleSystemTranslator mParticleSystemTranslator;
    ParticleEmitterTranslator mParticleEmitterTranslator;
    ParticleAffectorTranslator mParticleAffectorTranslator;
    CompositorTranslator mCompositorTranslator;
    CompositionTechniqueTranslator mCompositionTechniqueTranslator;
    CompositionTargetPassTranslator mCompositionTargetPassTranslator;
    CompositionPassTranslator mCompositionPassTranslator;
public:
    this()
    {
        mMaterialTranslator = new MaterialTranslator;
        mTechniqueTranslator = new TechniqueTranslator;
        mPassTranslator = new PassTranslator;
        mTextureUnitTranslator = new TextureUnitTranslator;
        mTextureSourceTranslator = new TextureSourceTranslator;
        mGpuProgramTranslator = new GpuProgramTranslator;
        mSharedParamsTranslator = new SharedParamsTranslator;
        mParticleSystemTranslator = new ParticleSystemTranslator;
        mParticleEmitterTranslator = new ParticleEmitterTranslator;
        mParticleAffectorTranslator = new ParticleAffectorTranslator;
        mCompositorTranslator = new CompositorTranslator;
        mCompositionTechniqueTranslator = new CompositionTechniqueTranslator;
        mCompositionTargetPassTranslator = new CompositionTargetPassTranslator;
        mCompositionPassTranslator = new CompositionPassTranslator;
    }
    
    /// Returns the number of translators being managed
    size_t getNumTranslators() const
    {
        return 12;
    }
    
    /// Returns a manager for the given object abstract node, or null if it is not supported
    ScriptTranslator getTranslator(/*const*/ AbstractNodePtr node)
    {
        ScriptTranslator translator;
        
        if(node.type == ANT_OBJECT)
        {
            ObjectAbstractNode obj = cast(ObjectAbstractNode)node.get();
            ObjectAbstractNode parent = obj.parent ? cast(ObjectAbstractNode)obj.parent : null;
            if(obj.id == ID_MATERIAL)
                translator = mMaterialTranslator;
            else if(obj.id == ID_TECHNIQUE && parent && parent.id == ID_MATERIAL)
                translator = mTechniqueTranslator;
            else if(obj.id == ID_PASS && parent && parent.id == ID_TECHNIQUE)
                translator = mPassTranslator;
            else if(obj.id == ID_TEXTURE_UNIT && parent && parent.id == ID_PASS)
                translator = mTextureUnitTranslator;
            else if(obj.id == ID_TEXTURE_SOURCE && parent && parent.id == ID_TEXTURE_UNIT)
                translator = mTextureSourceTranslator;
            else if(obj.id == ID_FRAGMENT_PROGRAM || 
                    obj.id == ID_VERTEX_PROGRAM || 
                    obj.id == ID_GEOMETRY_PROGRAM ||
                    obj.id == ID_TESSELATION_HULL_PROGRAM || 
                    obj.id == ID_TESSELATION_DOMAIN_PROGRAM ||
                    obj.id == ID_COMPUTE_PROGRAM)
                translator = mGpuProgramTranslator;
            else if(obj.id == ID_SHARED_PARAMS)
                translator = mSharedParamsTranslator;
            else if(obj.id == ID_PARTICLE_SYSTEM)
                translator = mParticleSystemTranslator;
            else if(obj.id == ID_EMITTER)
                translator = mParticleEmitterTranslator;
            else if(obj.id == ID_AFFECTOR)
                translator = mParticleAffectorTranslator;
            else if(obj.id == ID_COMPOSITOR)
                translator = mCompositorTranslator;
            else if(obj.id == ID_TECHNIQUE && parent && parent.id == ID_COMPOSITOR)
                translator = mCompositionTechniqueTranslator;
            else if((obj.id == ID_TARGET || obj.id == ID_TARGET_OUTPUT) && parent && parent.id == ID_TECHNIQUE)
                translator = mCompositionTargetPassTranslator;
            else if(obj.id == ID_PASS && parent && (parent.id == ID_TARGET || parent.id == ID_TARGET_OUTPUT))
                translator = mCompositionPassTranslator;
        }
        
        return translator;
    }
}
/** @} */
/** @} */