module ogre.materials.materialserializer;

import core.stdc.string;
import std.algorithm;
import std.conv;
//import std.container;
import std.array;
import std.string;
import std.stdio: File;
alias std.string.indexOf indexOf;

import ogre.compat;
import ogre.config;
import ogre.exception;
import ogre.general.colourvalue;
import ogre.general.common;
import ogre.general.generals;
import ogre.general.log;
import ogre.image.images;
import ogre.image.pixelformat;
import ogre.materials.blendmode;
import ogre.materials.externaltexturesourcemanager;
import ogre.materials.gpuprogram;
import ogre.materials.material;
import ogre.materials.materialmanager;
import ogre.materials.pass;
import ogre.materials.technique;
import ogre.materials.textureunitstate;
import ogre.math.angles;
import ogre.math.matrix;
import ogre.rendersystem.rendersystem;
import ogre.resources.datastream;
import ogre.resources.texture;
import ogre.scene.light;
import ogre.sharedptr;
import ogre.strings;
import ogre.resources.highlevelgpuprogram;
import ogre.lod.lodstrategymanager;
import ogre.lod.lodstrategy;
import ogre.lod.distancelodstrategy;


// Maybe use Pegged etc. But first CTFE needs to be fixed to not use 999 TB of ram to compile

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Materials
 *  @{
 */
/** Enum to identify material sections. */
alias uint MaterialScriptSection;
enum : MaterialScriptSection
{
    MSS_NONE,
    MSS_MATERIAL,
    MSS_TECHNIQUE,
    MSS_PASS,
    MSS_TEXTUREUNIT,
    MSS_PROGRAM_REF,
    MSS_PROGRAM,
    MSS_DEFAULT_PARAMETERS,
    MSS_TEXTURESOURCE
}
/** Struct for holding a program definition which is in progress. */
struct MaterialScriptProgramDefinition
{
    string name;
    GpuProgramType progType;
    string language;
    string source;
    string syntax;
    bool supportsSkeletalAnimation;
    bool supportsMorphAnimation;
    ushort supportsPoseAnimation; // number of simultaneous poses supported
    bool usesVertexTextureFetch;
    pair!(string, string)[] customParameters;
}

/** Struct for holding the script context while parsing. */
struct MaterialScriptContext
{
    MaterialScriptSection section;
    string groupName;
    SharedPtr!Material material;
    Technique technique;
    Pass pass;
    TextureUnitState textureUnit;
    SharedPtr!GpuProgram program; // used when ref erencing a program, not when defining it
    bool isVertexProgramShadowCaster; // when ref erencing, are we in context of shadow caster
    bool isFragmentProgramShadowCaster; // when ref erencing, are we in context of shadow caster
    bool isVertexProgramShadowReceiver; // when ref erencing, are we in context of shadow caster
    bool isFragmentProgramShadowReceiver; // when ref erencing, are we in context of shadow caster
    GpuProgramParametersPtr programParams;
    ushort numAnimationParametrics;
    MaterialScriptProgramDefinition* programDef; // this is used while defining a program

    int techLev,    //Keep track of what tech, pass, and state level we are in
    passLev,
    stateLev;
    string[] defaultParamLines;

    // Error reporting state
    size_t lineNo;
    string filename;
    AliasTextureNamePairList textureAliases;
}

/// Function def for material attribute parser; return value determines if the next line should be {
//typedef bool (*ATTRIBUTE_PARSER)(string params, ref MaterialScriptContext context);
alias bool function(string params, ref MaterialScriptContext context) ATTRIBUTE_PARSER;

/** Class for serializing Materials to / from a .material script.*/
class MaterialSerializer //: public SerializerAlloc
{
public:

    // Material serialize event.
    alias uint SerializeEvent;
enum : SerializeEvent
    {
        MSE_PRE_WRITE,
        MSE_WRITE_BEGIN,
        MSE_WRITE_END,
        MSE_POST_WRITE
    }

    /** Class that allows listening in on the various stages of material serialization process.
     Sub-classing it enable extending the attribute set of any part in the material.
     */
    interface Listener
    {
        /** Called when material section event raised.
         @param ser The MaterialSerializer instance that writes the given material.
         @param event The current section writing stage.
         @param skip May set to true by sub-class instances in order to skip the following section write.
         This parameter relevant only when stage equals MSE_PRE_WRITE.
         @param mat The material that is being written.
         */
        void materialEventRaised(MaterialSerializer ser,
                                 SerializeEvent event, ref bool skip, Material mat);

        /** Called when technique section event raised.
         @param ser The MaterialSerializer instance that writes the given material.
         @param event The current section writing stage.
         @param skip May set to true by sub-class instances in order to skip the following section write.
         This parameter relevant only when stage equals MSE_PRE_WRITE.
         @param tech The technique that is being written.
         */
        void techniqueEventRaised(MaterialSerializer ser,
                                  SerializeEvent event, ref bool skip, Technique tech);

        /** Called when pass section event raised.
         @param ser The MaterialSerializer instance that writes the given material.
         @param event The current section writing stage.
         @param skip May set to true by sub-class instances in order to skip the following section write.
         This parameter relevant only when stage equals MSE_PRE_WRITE.
         @param pass The pass that is being written.
         */
        void passEventRaised(MaterialSerializer ser,
                             SerializeEvent event, ref bool skip, Pass pass);

        /** Called when GPU program reference section event raised.
         @param ser The MaterialSerializer instance that writes the given material.
         @param event The current section writing stage.
         @param skip May set to true by sub-class instances in order to skip the following section write.
         This parameter relevant only when stage equals MSE_PRE_WRITE.
         @param attrib The GPU program reference description (vertex_program_ref, fragment_program_ref, etc).
         @param program The program being written.
         @param params The program parameters.
         @param defaultParams The default program parameters.
         */
        void gpuProgramRefEventRaised(MaterialSerializer ser,
                                      SerializeEvent event, ref bool skip,
                                      string attrib,
                                      SharedPtr!GpuProgram program,
                                      SharedPtr!GpuProgramParameters params,
                                      GpuProgramParameters defaultParams);

        /** Called when texture unit state section event raised.
         @param ser The MaterialSerializer instance that writes the given material.
         @param event The current section writing stage.
         @param skip May set to true by sub-class instances in order to skip the following section write.
         This parameter relevant only when stage equals MSE_PRE_WRITE.
         @param textureUnit The texture unit state that is being written.
         */
        void textureUnitStateEventRaised(MaterialSerializer ser,
                                         SerializeEvent event, ref bool skip, TextureUnitState textureUnit);
    }

protected:
    /// Keyword-mapped attribute parsers.
    //typedef map<string, ATTRIBUTE_PARSER>::type AttribParserList;
    alias ATTRIBUTE_PARSER[string] AttribParserList;

    MaterialScriptContext mScriptContext;

    /** internal method for parsing a material
     @return true if it expects the next line to be a {
     */
    bool parseScriptLine(string line)
    {
        final switch(mScriptContext.section)
        {
            case MSS_NONE:
                if (line == "}")
                {
                    logParseError("Unexpected terminating brace.", mScriptContext);
                    return false;
                }
                else
                {
                    // find & invoke a parser
                    return invokeParser(line, mRootAttribParsers);
                }
                break;
            case MSS_MATERIAL:
                if (line == "}")
                {
                    // End of material
                    // if texture aliases were found, pass them to the material
                    // to update texture names used in Texture unit states
                    if (!mScriptContext.textureAliases.emptyAA())
                    {
                        // request material to update all texture names in TUS's
                        // that use texture aliases in the list
                        mScriptContext.material.applyTextureAliases(mScriptContext.textureAliases);
                    }

                    mScriptContext.section = MSS_NONE;
                    mScriptContext.material.setNull();
                    //Reset all levels for next material
                    mScriptContext.passLev = -1;
                    mScriptContext.stateLev= -1;
                    mScriptContext.techLev = -1;
                    mScriptContext.textureAliases.clear();
                }
                else
                {
                    // find & invoke a parser
                    return invokeParser(line, mMaterialAttribParsers);
                }
                break;
            case MSS_TECHNIQUE:
                if (line == "}")
                {
                    // End of technique
                    mScriptContext.section = MSS_MATERIAL;
                    mScriptContext.technique = null;
                    mScriptContext.passLev = -1;    //Reset pass level (yes, the pass level)
                }
                else
                {
                    // find & invoke a parser
                    return invokeParser(line, mTechniqueAttribParsers);
                }
                break;
            case MSS_PASS:
                if (line == "}")
                {
                    // End of pass
                    mScriptContext.section = MSS_TECHNIQUE;
                    mScriptContext.pass = null;
                    mScriptContext.stateLev = -1;   //Reset state level (yes, the state level)
                }
                else
                {
                    // find & invoke a parser
                    return invokeParser(line, mPassAttribParsers);
                }
                break;
            case MSS_TEXTUREUNIT:
                if (line == "}")
                {
                    // End of texture unit
                    mScriptContext.section = MSS_PASS;
                    mScriptContext.textureUnit = null;
                }
                else
                {
                    // find & invoke a parser
                    return invokeParser(line, mTextureUnitAttribParsers);
                }
                break;
            case MSS_TEXTURESOURCE:
                if( line == "}" )
                {
                    //End texture source section
                    //Finish creating texture here
                    string sMaterialName = mScriptContext.material.getName();
                    if( ExternalTextureSourceManager.getSingleton().getCurrentPlugIn() !is null)
                        ExternalTextureSourceManager.getSingleton().getCurrentPlugIn().
                            createDefinedTexture( sMaterialName, mScriptContext.groupName );
                    //Revert back to texture unit
                    mScriptContext.section = MSS_TEXTUREUNIT;
                }
                else
                {
                    // custom texture parameter, use original line
                    parseTextureCustomParameter(line, mScriptContext);
                }
                break;
            case MSS_PROGRAM_REF:
                if (line == "}")
                {
                    // End of program
                    mScriptContext.section = MSS_PASS;
                    mScriptContext.program.setNull();
                }
                else
                {
                    // find & invoke a parser
                    return invokeParser(line, mProgramRefAttribParsers);
                }
                break;
            case MSS_PROGRAM:
                // Program definitions are slightly different, they are deferred
                // until all the information required is known
                if (line == "}")
                {
                    // End of program
                    finishProgramDefinition();
                    mScriptContext.section = MSS_NONE;
                    destroy(mScriptContext.programDef);
                    mScriptContext.defaultParamLines.clear();
                    mScriptContext.programDef = null;
                }
                else
                {
                    // find & invoke a parser
                    // do this manually because we want to call a custom
                    // routine when the parser is not found
                    // First, split line on first divisor only
                    string[] splitCmd = StringUtil.split(line, " \t", 1);
                    // Find attribute parser
                    auto iparser = splitCmd[0] in mProgramAttribParsers;
                    if (iparser is null)
                    {
                        // custom parameter, use original line
                        parseProgramCustomParameter(line, mScriptContext);
                    }
                    else
                    {
                        string cmd = splitCmd.length >= 2? splitCmd[1]:"";
                        // Use parser with remainder
                        return (*iparser)(cmd, mScriptContext );
                    }

                }
                break;
            case MSS_DEFAULT_PARAMETERS:
                if (line == "}")
                {
                    // End of default parameters
                    mScriptContext.section = MSS_PROGRAM;
                }
                else
                {
                    // Save default parameter lines up until we finalise the program
                    mScriptContext.defaultParamLines ~= line;
                }

                
                break;
        }

        return false;
    }
    /** internal method for finding & invoking an attribute parser. */
    bool invokeParser(string line, AttribParserList parsers)
    {
        // First, split line on first divisor only
        string[] splitCmd = StringUtil.split(line, " \t", 1);

        // Find attribute parser
        auto iparser = splitCmd[0] in parsers;
        if (iparser is null)
        {
            // BAD command. BAD!
            logParseError("Unrecognised command: " ~ splitCmd[0], mScriptContext);
            return false;
        }
        else
        {
            string cmd;
            if(splitCmd.length >= 2)
            cmd = splitCmd[1];
            // Use parser, make sure we have 2 params before using splitCmd[1]
            return (*iparser)( cmd, mScriptContext );
        }
    }

    /** Internal method for saving a program definition which has been
     built up.
     */
    void finishProgramDefinition()
    {
        // Now it is time to create the program and propagate the parameters
        MaterialScriptProgramDefinition* def = mScriptContext.programDef;
        GpuProgramPtr gp;
        if (def.language == "asm")
        {
            // Native assembler
            // Validate
            if (def.source.empty())
            {
                logParseError("Invalid program definition for " ~ def.name ~
                              ", you must specify a source file.", mScriptContext);
            }
            if (def.syntax.empty())
            {
                logParseError("Invalid program definition for " ~ def.name ~
                              ", you must specify a syntax code.", mScriptContext);
            }
            // Create
            gp = GpuProgramManager.getSingleton().
                createProgram(def.name, mScriptContext.groupName, def.source,
                              def.progType, def.syntax);

        }
        else
        {
            // High-level program
            // Validate
            if (def.source.empty() && def.language != "unified")
            {
                logParseError("Invalid program definition for " ~ def.name ~
                              ", you must specify a source file.", mScriptContext);
            }
            // Create
            try
            {
                SharedPtr!HighLevelGpuProgram hgp = HighLevelGpuProgramManager.getSingleton().
                    createProgram(def.name, mScriptContext.groupName,
                                  def.language, def.progType);
                // Assign to generalised version
                gp = cast(GpuProgramPtr)hgp;
                // Set source file
                hgp.setSourceFile(def.source);

                // Set custom parameters
                foreach (i; def.customParameters)
                {
                    if (!hgp.setParameter(i.first, i.second))
                    {
                        logParseError("Error in program " ~ def.name ~
                                      " parameter " ~ i.first ~ " is not valid.", mScriptContext);
                    }
                }
            }
            catch (Exception e)
            {
                logParseError("Could not create GPU program '"
                              ~ def.name ~ "', error reported was: " ~ e.msg, mScriptContext);
                mScriptContext.program.setNull();
                mScriptContext.programParams.setNull();
                return;
            }
        }
        // Set skeletal animation option
        gp.setSkeletalAnimationIncluded(def.supportsSkeletalAnimation);
        // Set morph animation option
        gp.setMorphAnimationIncluded(def.supportsMorphAnimation);
        // Set pose animation option
        gp.setPoseAnimationIncluded(def.supportsPoseAnimation);
        // Set vertex texture usage
        gp.setVertexTextureFetchRequired(def.usesVertexTextureFetch);
        // set origin
        gp._notifyOrigin(mScriptContext.filename);

        // Set up to receive default parameters
        if (gp.isSupported()
            && !mScriptContext.defaultParamLines.empty())
        {
            mScriptContext.programParams = gp.getDefaultParameters();
            mScriptContext.numAnimationParametrics = 0;
            mScriptContext.program = gp;

            foreach (i; mScriptContext.defaultParamLines)
            {
                // find & invoke a parser
                // do this manually because we want to call a custom
                // routine when the parser is not found
                // First, split line on first divisor only
                string[] splitCmd = StringUtil.split(i, " \t", 1);
                // Find attribute parser
                auto iparser = splitCmd[0] in mProgramDefaultParamAttribParsers;
                if (iparser !is null)
                {
                    string cmd = splitCmd.length >= 2? splitCmd[1]:""; //TODO "" or null?
                    // Use parser with remainder
                    (*iparser)(cmd, mScriptContext );
                }

            }
            // Reset
            mScriptContext.program.setNull();
            mScriptContext.programParams.setNull();
        }

    }

    /// Parsers for the root of the material script
    AttribParserList mRootAttribParsers;
    /// Parsers for the material section of a script
    AttribParserList mMaterialAttribParsers;
    /// Parsers for the technique section of a script
    AttribParserList mTechniqueAttribParsers;
    /// Parsers for the pass section of a script
    AttribParserList mPassAttribParsers;
    /// Parsers for the texture unit section of a script
    AttribParserList mTextureUnitAttribParsers;
    /// Parsers for the program reference section of a script
    AttribParserList mProgramRefAttribParsers;
    /// Parsers for the program definition section of a script
    AttribParserList mProgramAttribParsers;
    /// Parsers for the program definition section of a script
    AttribParserList mProgramDefaultParamAttribParsers;

    /// Listeners list of this Serializer.
    //typedef vector<Listener*>::type         ListenerList;
    //typedef ListenerList::iterator          ListenerListIterator;
    //typedef ListenerList::const_iterator    ListenerListConstIterator;
    alias Listener[]    ListenerList;
    Listener[]          mListeners;

    
    void writeMaterial(SharedPtr!Material pMat,string materialName = "")
    {
        string outMaterialName;

        if (materialName.length > 0)
        {
            outMaterialName = materialName;
        }
        else
        {
            outMaterialName = pMat.getName();
        }

        LogManager.getSingleton().logMessage("MaterialSerializer : writing material " ~ outMaterialName ~ " to queue.", LML_NORMAL);

        bool skipWriting = false;

        // Fire pre-write event.
        fireMaterialEvent(MSE_PRE_WRITE, skipWriting, pMat.get());
        if (skipWriting)
            return;

        // Material name
        writeAttribute(0, "material");
        writeValue(quoteWord(outMaterialName));

        beginSection(0);
        {
            // Fire write begin event.
            fireMaterialEvent(MSE_WRITE_BEGIN, skipWriting, pMat.get());

            // Write LOD information
            Material.LodValueList valueIt = pMat.getUserLodValues();
            // Skip zero value
            //if (valueIt.hasMoreElements())
            //    valueIt.getNext();
            string attributeVal;
            foreach(i; 1..valueIt.length)
            {
                attributeVal ~= .to!string(valueIt[i]);
                if (i < valueIt.length)
                    attributeVal ~= " ";
            }
            if (!attributeVal.empty())
            {
                writeAttribute(1, "lod_values");
                writeValue(attributeVal);
            }

            
            // Shadow receive
            if (mDefaults ||
                pMat.getReceiveShadows() != true)
            {
                writeAttribute(1, "receive_shadows");
                writeValue(pMat.getReceiveShadows() ? "on" : "off");
            }

            // When rendering shadows, treat transparent things as opaque?
            if (mDefaults ||
                pMat.getTransparencyCastsShadows() == true)
            {
                writeAttribute(1, "transparency_casts_shadows");
                writeValue(pMat.getTransparencyCastsShadows() ? "on" : "off");
            }

            // Iterate over techniques
            auto it = pMat.getTechniques();
            foreach (t; it)
            {
                writeTechnique(t);
                mBuffer ~= "\n";
            }

            // Fire write end event.
            fireMaterialEvent(MSE_WRITE_END, skipWriting, pMat.get());
        }
        endSection(0);
        mBuffer ~= "\n";

        // Fire post section write event.
        fireMaterialEvent(MSE_POST_WRITE, skipWriting, pMat.get());
    }

    void writeTechnique(Technique pTech)
    {
        bool skipWriting = false;

        // Fire pre-write event.
        fireTechniqueEvent(MSE_PRE_WRITE, skipWriting, pTech);
        if (skipWriting)
            return;

        // Technique header
        writeAttribute(1, "technique");
        // only output technique name if it exists.
        if (!pTech.getName().empty())
            writeValue(quoteWord(pTech.getName()));

        beginSection(1);
        {
            // Fire write begin event.
            fireTechniqueEvent(MSE_WRITE_BEGIN, skipWriting, pTech);

            // Lod index
            if (mDefaults ||
                pTech.getLodIndex() != 0)
            {
                writeAttribute(2, "lod_index");
                writeValue(.to!string(pTech.getLodIndex()));
            }

            // Scheme name
            if (mDefaults ||
                pTech.getSchemeName() != MaterialManager.DEFAULT_SCHEME_NAME)
            {
                writeAttribute(2, "scheme");
                writeValue(quoteWord(pTech.getSchemeName()));
            }

            // ShadowCasterMaterial name
            if (!pTech.getShadowCasterMaterial().isNull())
            {
                writeAttribute(2, "shadow_caster_material");
                writeValue(quoteWord(pTech.getShadowCasterMaterial().getName()));
            }
            // ShadowReceiverMaterial name
            if (!pTech.getShadowReceiverMaterial().isNull())
            {
                writeAttribute(2, "shadow_receiver_material");
                writeValue(quoteWord(pTech.getShadowReceiverMaterial().getName()));
            }
            // GPU vendor rules
            auto vrit = pTech.getGPUVendorRules();
            foreach (rule; vrit)
            {
                writeAttribute(2, "gpu_vendor_rule");
                if (rule.includeOrExclude == Technique.INCLUDE)
                    writeValue("include");
                else
                    writeValue("exclude");
                writeValue(quoteWord(RenderSystemCapabilities.vendorToString(rule.vendor)));
            }
            // GPU device rules
            auto dnit = pTech.getGPUDeviceNameRules();
            foreach (rule; dnit)
            {
                writeAttribute(2, "gpu_device_rule");
                if (rule.includeOrExclude == Technique.INCLUDE)
                    writeValue("include");
                else
                    writeValue("exclude");
                writeValue(quoteWord(rule.devicePattern));
                writeValue(.to!string(rule.caseSensitive));
            }
            // Iterate over passes
            auto it = pTech.getPasses();
            foreach (p; it)
            {
                writePass(p);
                mBuffer ~= "\n";
            }

            // Fire write end event.
            fireTechniqueEvent(MSE_WRITE_END, skipWriting, pTech);
        }
        endSection(1);

        // Fire post section write event.
        fireTechniqueEvent(MSE_POST_WRITE, skipWriting, pTech);

    }

    void writePass(Pass pPass)
    {
        bool skipWriting = false;

        // Fire pre-write event.
        firePassEvent(MSE_PRE_WRITE, skipWriting, pPass);
        if (skipWriting)
            return;

        writeAttribute(2, "pass");
        // only output pass name if its not the default name
        if (pPass.getName() != .to!string(pPass.getIndex()))
            writeValue(quoteWord(pPass.getName()));

        beginSection(2);
        {
            // Fire write begin event.
            firePassEvent(MSE_WRITE_BEGIN, skipWriting, pPass);

            //lighting
            if (mDefaults ||
                pPass.getLightingEnabled() != true)
            {
                writeAttribute(3, "lighting");
                writeValue(pPass.getLightingEnabled() ? "on" : "off");
            }
            // max_lights
            if (mDefaults ||
                pPass.getMaxSimultaneousLights() != OGRE_MAX_SIMULTANEOUS_LIGHTS)
            {
                writeAttribute(3, "max_lights");
                writeValue(to!string(pPass.getMaxSimultaneousLights()));
            }
            // start_light
            if (mDefaults ||
                pPass.getStartLight() != 0)
            {
                writeAttribute(3, "start_light");
                writeValue(to!string(pPass.getStartLight()));
            }
            // iteration
            if (mDefaults ||
                pPass.getIteratePerLight() || (pPass.getPassIterationCount() > 1))
            {
                writeAttribute(3, "iteration");
                // pass iteration count
                if (pPass.getPassIterationCount() > 1 || pPass.getLightCountPerIteration() > 1)
                {
                    writeValue(to!string(pPass.getPassIterationCount()));
                    if (pPass.getIteratePerLight())
                    {
                        if (pPass.getLightCountPerIteration() > 1)
                        {
                            writeValue("per_n_lights");
                            writeValue(to!string(
                                pPass.getLightCountPerIteration()));
                        }
                        else
                        {
                            writeValue("per_light");
                        }
                    }
                }
                else
                {
                    writeValue(pPass.getIteratePerLight() ? "once_per_light" : "once");
                }

                if (pPass.getIteratePerLight() && pPass.getRunOnlyForOneLightType())
                {
                    final switch (pPass.getOnlyLightType())
                    {
                        case Light.LightTypes.LT_DIRECTIONAL:
                            writeValue("directional");
                            break;
                        case Light.LightTypes.LT_POINT:
                            writeValue("point");
                            break;
                        case Light.LightTypes.LT_SPOTLIGHT:
                            writeValue("spot");
                            break;
                    }
                }
            }

            if(mDefaults || pPass.getLightMask() != 0xFFFFFFFF)
            {
                writeAttribute(3, "light_mask");
                writeValue(to!string(pPass.getLightMask()));
            }

            if (pPass.getLightingEnabled())
            {
                // Ambient
                if (mDefaults ||
                    pPass.getAmbient().r != 1 ||
                    pPass.getAmbient().g != 1 ||
                    pPass.getAmbient().b != 1 ||
                    pPass.getAmbient().a != 1 ||
                    (pPass.getVertexColourTracking() & TVC_AMBIENT))
                {
                    writeAttribute(3, "ambient");
                    if (pPass.getVertexColourTracking() & TVC_AMBIENT)
                        writeValue("vertexcolour");
                    else
                        writeColourValue(pPass.getAmbient(), true);
                }

                // Diffuse
                if (mDefaults ||
                    pPass.getDiffuse().r != 1 ||
                    pPass.getDiffuse().g != 1 ||
                    pPass.getDiffuse().b != 1 ||
                    pPass.getDiffuse().a != 1 ||
                    (pPass.getVertexColourTracking() & TVC_DIFFUSE))
                {
                    writeAttribute(3, "diffuse");
                    if (pPass.getVertexColourTracking() & TVC_DIFFUSE)
                        writeValue("vertexcolour");
                    else
                        writeColourValue(pPass.getDiffuse(), true);
                }

                // Specular
                if (mDefaults ||
                    pPass.getSpecular().r != 0 ||
                    pPass.getSpecular().g != 0 ||
                    pPass.getSpecular().b != 0 ||
                    pPass.getSpecular().a != 1 ||
                    pPass.getShininess() != 0 ||
                    (pPass.getVertexColourTracking() & TVC_SPECULAR))
                {
                    writeAttribute(3, "specular");
                    if (pPass.getVertexColourTracking() & TVC_SPECULAR)
                    {
                        writeValue("vertexcolour");
                    }
                    else
                    {
                        writeColourValue(pPass.getSpecular(), true);
                    }
                    writeValue(to!string(pPass.getShininess()));

                }

                // Emissive
                if (mDefaults ||
                    pPass.getSelfIllumination().r != 0 ||
                    pPass.getSelfIllumination().g != 0 ||
                    pPass.getSelfIllumination().b != 0 ||
                    pPass.getSelfIllumination().a != 1 ||
                    (pPass.getVertexColourTracking() & TVC_EMISSIVE))
                {
                    writeAttribute(3, "emissive");
                    if (pPass.getVertexColourTracking() & TVC_EMISSIVE)
                        writeValue("vertexcolour");
                    else
                        writeColourValue(pPass.getSelfIllumination(), true);
                }
            }

            // Point size
            if (mDefaults ||
                pPass.getPointSize() != 1.0)
            {
                writeAttribute(3, "point_size");
                writeValue(to!string(pPass.getPointSize()));
            }

            // Point sprites
            if (mDefaults ||
                pPass.getPointSpritesEnabled())
            {
                writeAttribute(3, "point_sprites");
                writeValue(pPass.getPointSpritesEnabled() ? "on" : "off");
            }

            // Point attenuation
            if (mDefaults ||
                pPass.isPointAttenuationEnabled())
            {
                writeAttribute(3, "point_size_attenuation");
                writeValue(pPass.isPointAttenuationEnabled() ? "on" : "off");
                if (pPass.isPointAttenuationEnabled() &&
                    (pPass.getPointAttenuationConstant() != 0.0 ||
                 pPass.getPointAttenuationLinear() != 1.0 ||
                 pPass.getPointAttenuationQuadratic() != 0.0))
                {
                    writeValue(to!string(pPass.getPointAttenuationConstant()));
                    writeValue(to!string(pPass.getPointAttenuationLinear()));
                    writeValue(to!string(pPass.getPointAttenuationQuadratic()));
                }
            }

            // Point min size
            if (mDefaults ||
                pPass.getPointMinSize() != 0.0)
            {
                writeAttribute(3, "point_size_min");
                writeValue(to!string(pPass.getPointMinSize()));
            }

            // Point max size
            if (mDefaults ||
                pPass.getPointMaxSize() != 0.0)
            {
                writeAttribute(3, "point_size_max");
                writeValue(to!string(pPass.getPointMaxSize()));
            }

            // scene blend factor
            if (pPass.hasSeparateSceneBlending())
            {
                if (mDefaults ||
                    pPass.getSourceBlendFactor() != SceneBlendFactor.SBF_ONE ||
                    pPass.getDestBlendFactor() != SceneBlendFactor.SBF_ZERO ||
                    pPass.getSourceBlendFactorAlpha() != SceneBlendFactor.SBF_ONE ||
                    pPass.getDestBlendFactorAlpha() != SceneBlendFactor.SBF_ZERO)
                {
                    writeAttribute(3, "separate_scene_blend");
                    writeSceneBlendFactor(pPass.getSourceBlendFactor(), pPass.getDestBlendFactor(),
                                          pPass.getSourceBlendFactorAlpha(), pPass.getDestBlendFactorAlpha());
                }
            }
            else
            {
                if (mDefaults ||
                    pPass.getSourceBlendFactor() != SceneBlendFactor.SBF_ONE ||
                    pPass.getDestBlendFactor() != SceneBlendFactor.SBF_ZERO)
                {
                    writeAttribute(3, "scene_blend");
                    writeSceneBlendFactor(pPass.getSourceBlendFactor(), pPass.getDestBlendFactor());
                }
            }

            
            //depth check
            if (mDefaults ||
                pPass.getDepthCheckEnabled() != true)
            {
                writeAttribute(3, "depth_check");
                writeValue(pPass.getDepthCheckEnabled() ? "on" : "off");
            }
            // alpha_rejection
            if (mDefaults ||
                pPass.getAlphaRejectFunction() != CompareFunction.CMPF_ALWAYS_PASS ||
                pPass.getAlphaRejectValue() != 0)
            {
                writeAttribute(3, "alpha_rejection");
                writeCompareFunction(pPass.getAlphaRejectFunction());
                writeValue(to!string(pPass.getAlphaRejectValue()));
            }
            // alpha_to_coverage
            if (mDefaults ||
                pPass.isAlphaToCoverageEnabled())
            {
                writeAttribute(3, "alpha_to_coverage");
                writeValue(pPass.isAlphaToCoverageEnabled() ? "on" : "off");
            }
            // transparent_sorting
            if (mDefaults ||
                pPass.getTransparentSortingForced() == true ||
                pPass.getTransparentSortingEnabled() != true)
            {
                writeAttribute(3, "transparent_sorting");
                writeValue(pPass.getTransparentSortingForced() ? "force" :
                           (pPass.getTransparentSortingEnabled() ? "on" : "off"));
            }
            

            
            //depth write
            if (mDefaults ||
                pPass.getDepthWriteEnabled() != true)
            {
                writeAttribute(3, "depth_write");
                writeValue(pPass.getDepthWriteEnabled() ? "on" : "off");
            }

            //depth function
            if (mDefaults ||
                pPass.getDepthFunction() != CompareFunction.CMPF_LESS_EQUAL)
            {
                writeAttribute(3, "depth_func");
                writeCompareFunction(pPass.getDepthFunction());
            }

            //depth bias
            if (mDefaults ||
                pPass.getDepthBiasConstant() != 0 ||
                pPass.getDepthBiasSlopeScale() != 0)
            {
                writeAttribute(3, "depth_bias");
                writeValue(to!string(pPass.getDepthBiasConstant()));
                writeValue(to!string(pPass.getDepthBiasSlopeScale()));
            }
            //iteration depth bias
            if (mDefaults ||
                pPass.getIterationDepthBias() != 0)
            {
                writeAttribute(3, "iteration_depth_bias");
                writeValue(to!string(pPass.getIterationDepthBias()));
            }

            //light scissor
            if (mDefaults ||
                pPass.getLightScissoringEnabled() != false)
            {
                writeAttribute(3, "light_scissor");
                writeValue(pPass.getLightScissoringEnabled() ? "on" : "off");
            }

            //light clip planes
            if (mDefaults ||
                pPass.getLightClipPlanesEnabled() != false)
            {
                writeAttribute(3, "light_clip_planes");
                writeValue(pPass.getLightClipPlanesEnabled() ? "on" : "off");
            }

            // illumination stage
            if (pPass.getIlluminationStage() != IlluminationStage.IS_UNKNOWN)
            {
                writeAttribute(3, "illumination_stage");
                final switch(pPass.getIlluminationStage())
                {
                    case IlluminationStage.IS_AMBIENT:
                        writeValue("ambient");
                        break;
                    case IlluminationStage.IS_PER_LIGHT:
                        writeValue("per_light");
                        break;
                    case IlluminationStage.IS_DECAL:
                        writeValue("decal");
                        break;
                    case IlluminationStage.IS_UNKNOWN:
                        break;
                }
            }

            // hardware culling mode
            if (mDefaults ||
                pPass.getCullingMode() != CullingMode.CULL_CLOCKWISE)
            {
                CullingMode hcm = pPass.getCullingMode();
                writeAttribute(3, "cull_hardware");
                final switch (hcm)
                {
                    case CullingMode.CULL_NONE :
                        writeValue("none");
                        break;
                    case CullingMode.CULL_CLOCKWISE :
                        writeValue("clockwise");
                        break;
                    case CullingMode.CULL_ANTICLOCKWISE :
                        writeValue("anticlockwise");
                        break;
                }
            }

            // software culling mode
            if (mDefaults ||
                pPass.getManualCullingMode() != ManualCullingMode.MANUAL_CULL_BACK)
            {
                ManualCullingMode scm = pPass.getManualCullingMode();
                writeAttribute(3, "cull_software");
                final switch (scm)
                {
                    case ManualCullingMode.MANUAL_CULL_NONE :
                        writeValue("none");
                        break;
                    case ManualCullingMode.MANUAL_CULL_BACK :
                        writeValue("back");
                        break;
                    case ManualCullingMode.MANUAL_CULL_FRONT :
                        writeValue("front");
                        break;
                }
            }

            //shading
            if (mDefaults ||
                pPass.getShadingMode() != ShadeOptions.SO_GOURAUD)
            {
                writeAttribute(3, "shading");
                final switch (pPass.getShadingMode())
                {
                    case ShadeOptions.SO_FLAT:
                        writeValue("flat");
                        break;
                    case ShadeOptions.SO_GOURAUD:
                        writeValue("gouraud");
                        break;
                    case ShadeOptions.SO_PHONG:
                        writeValue("phong");
                        break;
                }
            }

            
            if (mDefaults ||
                pPass.getPolygonMode() != PolygonMode.PM_SOLID)
            {
                writeAttribute(3, "polygon_mode");
                final switch (pPass.getPolygonMode())
                {
                    case PolygonMode.PM_POINTS:
                        writeValue("points");
                        break;
                    case PolygonMode.PM_WIREFRAME:
                        writeValue("wireframe");
                        break;
                    case PolygonMode.PM_SOLID:
                        writeValue("solid");
                        break;
                }
            }

            // polygon mode overrideable
            if (mDefaults ||
                !pPass.getPolygonModeOverrideable())
            {
                writeAttribute(3, "polygon_mode_overrideable");
                writeValue(pPass.getPolygonModeOverrideable() ? "on" : "off");
            }

            // normalise normals
            if (mDefaults ||
                pPass.getNormaliseNormals() != false)
            {
                writeAttribute(3, "normalise_normals");
                writeValue(pPass.getNormaliseNormals() ? "on" : "off");
            }

            //fog override
            if (mDefaults ||
                pPass.getFogOverride() != false)
            {
                writeAttribute(3, "fog_override");
                writeValue(pPass.getFogOverride() ? "true" : "false");
                if (pPass.getFogOverride())
                {
                    final switch (pPass.getFogMode())
                    {
                        case FogMode.FOG_NONE:
                            writeValue("none");
                            break;
                        case FogMode.FOG_LINEAR:
                            writeValue("linear");
                            break;
                        case FogMode.FOG_EXP2:
                            writeValue("exp2");
                            break;
                        case FogMode.FOG_EXP:
                            writeValue("exp");
                            break;
                    }

                    if (pPass.getFogMode() != FogMode.FOG_NONE)
                    {
                        writeColourValue(pPass.getFogColour());
                        writeValue(to!string(pPass.getFogDensity()));
                        writeValue(to!string(pPass.getFogStart()));
                        writeValue(to!string(pPass.getFogEnd()));
                    }
                }
            }

            // nfz

            //  GPU Vertex and Fragment program references and parameters
            if (pPass.hasVertexProgram())
            {
                writeVertexProgramRef(pPass);
            }

            if (pPass.hasFragmentProgram())
            {
                writeFragmentProgramRef(pPass);
            }

            if (pPass.hasShadowCasterVertexProgram())
            {
                writeShadowCasterVertexProgramRef(pPass);
            }

            if (pPass.hasShadowReceiverVertexProgram())
            {
                writeShadowReceiverVertexProgramRef(pPass);
            }

            if (pPass.hasShadowReceiverFragmentProgram())
            {
                writeShadowReceiverFragmentProgramRef(pPass);
            }

            // Nested texture layers
            auto it = pPass.getTextureUnitStates();
            foreach(t; it)
            {
                writeTextureUnit(t);
            }

            // Fire write end event.
            firePassEvent(MSE_WRITE_END, skipWriting, pPass);
        }
        endSection(2);

        // Fire post section write event.
        firePassEvent(MSE_POST_WRITE, skipWriting, pPass);

        LogManager.getSingleton().logMessage("MaterialSerializer : done.", LML_NORMAL);
    }

    // nfz
    void writeVertexProgramRef(Pass pPass)
    {
        writeGpuProgramRef("vertex_program_ref",
                           pPass.getVertexProgram(), pPass.getVertexProgramParameters());
    }

    void writeShadowCasterVertexProgramRef(Pass pPass)
    {
        writeGpuProgramRef("shadow_caster_vertex_program_ref",
                           pPass.getShadowCasterVertexProgram(), pPass.getShadowCasterVertexProgramParameters());
    }

    void writeShadowCasterFragmentProgramRef(Pass pPass)
    {
        writeGpuProgramRef("shadow_caster_fragment_program_ref",
                           pPass.getShadowCasterFragmentProgram(), pPass.getShadowCasterFragmentProgramParameters());
    }

    void writeShadowReceiverVertexProgramRef(Pass pPass)
    {
        writeGpuProgramRef("shadow_receiver_vertex_program_ref",
                           pPass.getShadowReceiverVertexProgram(), pPass.getShadowReceiverVertexProgramParameters());
    }

    void writeShadowReceiverFragmentProgramRef(Pass pPass)
    {
        writeGpuProgramRef("shadow_receiver_fragment_program_ref",
                           pPass.getShadowReceiverFragmentProgram(), pPass.getShadowReceiverFragmentProgramParameters());
    }

    void writeFragmentProgramRef(Pass pPass)
    {
        writeGpuProgramRef("fragment_program_ref",
                           pPass.getFragmentProgram(), pPass.getFragmentProgramParameters());
    }

    void writeGpuProgramRef(string attrib, SharedPtr!GpuProgram program, GpuProgramParametersPtr params)
    {
        bool skipWriting = false;

        // Fire pre-write event.
        fireGpuProgramRefEvent(MSE_PRE_WRITE, skipWriting, attrib, program, params, null);
        if (skipWriting)
            return;

        mBuffer ~= "\n";
        writeAttribute(3, attrib);
        writeValue(quoteWord(program.getName()));
        beginSection(3);
        {
            // write out parameters
            GpuProgramParameters defaultParams = null;
            // does the GPU program have default parameters?
            if (program.hasDefaultParameters())
                defaultParams = program.getDefaultParameters().get();

            // Fire write begin event.
            fireGpuProgramRefEvent(MSE_WRITE_BEGIN, skipWriting, attrib, program, params, defaultParams);

            writeGPUProgramParameters(params, defaultParams);

            // Fire write end event.
            fireGpuProgramRefEvent(MSE_WRITE_END, skipWriting, attrib, program, params, defaultParams);
        }
        endSection(3);

        // add to GpuProgram container
        mGpuProgramDefinitionContainer.insert(program.getName());

        // Fire post section write event.
        fireGpuProgramRefEvent(MSE_POST_WRITE, skipWriting, attrib, program, params, null);
    }

    void writeGpuPrograms()
    {
        // iterate through gpu program names in container
        //GpuProgramDefIterator currentDef = mGpuProgramDefinitionContainer.begin();
        //GpuProgramDefIterator endDef = mGpuProgramDefinitionContainer.end();

        //while (currentDef != endDef)
        foreach(currentDef; mGpuProgramDefinitionContainer)
        {
            // get gpu program from gpu program manager
            GpuProgramPtr program = GpuProgramManager.getSingleton().getByName(currentDef);
            // write gpu program definition type to buffer
            // check program type for vertex program
            // write program type
            mGpuProgramBuffer ~= "\n";
            writeAttribute(0, program.getParameter("type"), false);

            // write program name
            writeValue( quoteWord(program.getName()), false);
            // write program language
            string language = program.getLanguage();
            writeValue( language, false );
            // write opening braces
            beginSection(0, false);
            {
                // write program source + filename
                writeAttribute(1, "source", false);
                writeValue(quoteWord(program.getSourceFile()), false);
                // write special parameters based on language
                ParameterList params = program.getParameters();
                //ParameterList::const_iterator currentParam = params.begin();
                //ParameterList::const_iterator endParam = params.end();

                //while (currentParam != endParam)
                foreach(currentParam; params)
                {
                    if (currentParam.name != "type" &&
                        currentParam.name !="assemble_code" &&
                        currentParam.name !="micro_code" &&
                        currentParam.name !="external_micro_code")
                    {
                        string paramstr = program.getParameter(currentParam.name);
                        if ((currentParam.name == "includes_skeletal_animation")
                            && (paramstr == "false"))
                            paramstr.clear();
                        if ((currentParam.name == "includes_morph_animation")
                            && (paramstr == "false"))
                            paramstr.clear();
                        if ((currentParam.name == "includes_pose_animation")
                            && (paramstr == "0"))
                            paramstr.clear();
                        if ((currentParam.name == "uses_vertex_texture_fetch")
                            && (paramstr == "false"))
                            paramstr.clear();

                        if ((language != "asm") && (currentParam.name == "syntax"))
                            paramstr.clear();

                        if (!paramstr.empty())
                        {
                            writeAttribute(1, currentParam.name, false);
                            writeValue(paramstr, false);
                        }
                    }
                    //++currentParam;
                }

                // write default parameters
                if (program.hasDefaultParameters())
                {
                    mGpuProgramBuffer ~= "\n";
                    auto gpuDefaultParams = program.getDefaultParameters();
                    writeAttribute(1, "default_params", false);
                    beginSection(1, false);
                    writeGPUProgramParameters(gpuDefaultParams, null, 2, false);
                    endSection(1, false);
                }
            }
            // write closing braces
            endSection(0, false);

            //++currentDef;

        }

        mGpuProgramBuffer ~= "\n";
    }

    void writeGPUProgramParameters(GpuProgramParametersPtr params, GpuProgramParameters defaultParams,
                                   ushort level = 4,bool useMainBuffer = true)
    {
        // iterate through the constant definitions
        if (params.hasNamedParameters())
        {
            writeNamedGpuProgramParameters(params, defaultParams, level, useMainBuffer);
        }
        else
        {
            writeLowLevelGpuProgramParameters(params, defaultParams, level, useMainBuffer);
        }
    }

    void writeNamedGpuProgramParameters(GpuProgramParametersPtr params, GpuProgramParameters defaultParams,
                                        ushort level = 4,bool useMainBuffer = true)
    {
        foreach(paramName, def; params.getConstantDefinitions().map)
        {
            // get any auto-link
            auto autoEntry = params.findAutoConstantEntry(paramName);
            GpuProgramParameters.AutoConstantEntry defaultAutoEntry = null;
            if (defaultParams)
            {
                defaultAutoEntry =
                    defaultParams.findAutoConstantEntry(paramName);
            }

            writeGpuProgramParameter("param_named",
                                     paramName, autoEntry, defaultAutoEntry, def.isFloat(), def.isDouble(),
                                     def.physicalIndex, def.elementSize * def.arraySize,
                                     params, defaultParams, level, useMainBuffer);
        }

    }

    void writeLowLevelGpuProgramParameters(GpuProgramParametersPtr params, GpuProgramParameters defaultParams,
                                           ushort level = 4,bool useMainBuffer = true)
    {
        // Iterate over the logical.physical mappings
        // This will represent the values which have been set

        // float params
        GpuLogicalBufferStructPtr floatLogical = params.getFloatLogicalBufferStruct();
        if( !floatLogical.isNull() )
        {
            synchronized(floatLogical.mLock)
            {
                foreach(logicalIndex, logicalUse; floatLogical.map)
                {
                    GpuProgramParameters.AutoConstantEntry autoEntry =
                        params.findFloatAutoConstantEntry(logicalIndex);
                    GpuProgramParameters.AutoConstantEntry defaultAutoEntry = null;
                    if (defaultParams)
                    {
                        defaultAutoEntry = defaultParams.findFloatAutoConstantEntry(logicalIndex);
                    }

                    writeGpuProgramParameter("param_indexed", 
                                             to!string(logicalIndex), autoEntry, 
                                             defaultAutoEntry, true, false, logicalUse.physicalIndex,
                                             logicalUse.currentSize,
                                             params, defaultParams, level, useMainBuffer);
                }
            }
        }
        
        // double params
        GpuLogicalBufferStructPtr doubleLogical = params.getDoubleLogicalBufferStruct();
        if( !doubleLogical.isNull() )
        {
            synchronized(doubleLogical.mLock)
            {
                foreach(logicalIndex, logicalUse; doubleLogical.map)
                {
                    GpuProgramParameters.AutoConstantEntry autoEntry =
                        params.findDoubleAutoConstantEntry(logicalIndex);
                    GpuProgramParameters.AutoConstantEntry defaultAutoEntry;
                    if (defaultParams)
                    {
                        defaultAutoEntry = defaultParams.findDoubleAutoConstantEntry(logicalIndex);
                    }
                    
                    writeGpuProgramParameter("param_indexed",
                                             to!string(logicalIndex), autoEntry,
                                             defaultAutoEntry, false, true, logicalUse.physicalIndex,
                                             logicalUse.currentSize,
                                             params, defaultParams, level, useMainBuffer);
                }
            }
        }
        

        // int params
        GpuLogicalBufferStructPtr intLogical = params.getIntLogicalBufferStruct();
        if( !intLogical.isNull() )
        {
            synchronized(intLogical.mLock)
            {
                foreach(logicalIndex, logicalUse; intLogical.map)
                {
                    GpuProgramParameters.AutoConstantEntry autoEntry =
                        params.findIntAutoConstantEntry(logicalIndex);
                    GpuProgramParameters.AutoConstantEntry defaultAutoEntry = null;
                    if (defaultParams)
                    {
                        defaultAutoEntry = defaultParams.findIntAutoConstantEntry(logicalIndex);
                    }

                    writeGpuProgramParameter("param_indexed",
                                             to!string(logicalIndex), autoEntry,
                                             defaultAutoEntry, false, false, logicalUse.physicalIndex,
                                             logicalUse.currentSize,
                                             params, defaultParams, level, useMainBuffer);
                }
            }

        }

    }

    void writeGpuProgramParameter(
        string commandName, string identifier,
        GpuProgramParameters.AutoConstantEntry autoEntry,
        GpuProgramParameters.AutoConstantEntry defaultAutoEntry,
        bool isFloat, bool isDouble, size_t physicalIndex, size_t physicalSize,
        GpuProgramParametersPtr params, GpuProgramParameters defaultParams,
        ushort level,bool useMainBuffer)
    {
        // Skip any params with array qualifiers
        // These are only for convenience of setters, the full array will be
        // written using the base, non-array identifier
        if (identifier.indexOf("[") != -1)
        {
            return;
        }

        // get any auto-link
        // don't duplicate constants that are defined as a default parameter
        bool different = false;
        if (defaultParams)
        {
            // if default is auto but we're not or vice versa
            if ((autoEntry is null) != (defaultAutoEntry is null))
            {
                different = true;
            }
            else if (autoEntry)
            {
                // both must be auto
                // compare the auto values
                different = (autoEntry.paramType != defaultAutoEntry.paramType
                             || autoEntry.data != defaultAutoEntry.data);
            }
            else
            {
                // compare the non-auto (raw buffer) values
                // param buffers are always initialised with all zeros
                // so unset == unset
                if (isFloat)
                {
                    different = memcmp(
                        params.getFloatPointer(physicalIndex),
                        defaultParams.getFloatPointer(physicalIndex),
                        float.sizeof * physicalSize) != 0;
                }
                else if (isDouble)
                {
                    different = memcmp(
                        params.getDoublePointer(physicalIndex),
                        defaultParams.getDoublePointer(physicalIndex),
                        double.sizeof * physicalSize) != 0;
                }
                else
                {
                    different = memcmp(
                        params.getIntPointer(physicalIndex),
                        defaultParams.getIntPointer(physicalIndex),
                        int.sizeof * physicalSize) != 0;
                }
            }
        }

        if (!defaultParams || different)
        {
            string label = commandName;

            // is it auto
            if (autoEntry)
                label ~= "_auto";

            writeAttribute(level, label, useMainBuffer);
            // output param index / name
            writeValue(quoteWord(identifier), useMainBuffer);

            // if auto output auto type name and data if needed
            if (autoEntry)
            {
                GpuProgramParameters.AutoConstantDefinition* autoConstDef =
                    GpuProgramParameters.getAutoConstantDefinition(autoEntry.paramType);

                assert(autoConstDef !is null, "Bad auto constant Definition Table");
                // output auto constant name
                writeValue(quoteWord(autoConstDef.name), useMainBuffer);
                // output data if it uses it
                switch(autoConstDef.dataType)
                {
                    case GpuProgramParameters.ACDataType.ACDT_REAL:
                        writeValue(to!string(autoEntry.fData), useMainBuffer);
                        break;

                    case GpuProgramParameters.ACDataType.ACDT_INT:
                        writeValue(to!string(autoEntry.data), useMainBuffer);
                        break;

                    default:
                        break;
                }
            }
            else // not auto so output all the values used
            {
                string countLabel;

                // only write a number if > 1
                if (physicalSize > 1)
                    countLabel = to!string(physicalSize);

                if (isFloat)
                {
                    // Get pointer to start of values
                    float* pFloat = params.getFloatPointer(physicalIndex);

                    writeValue("float" ~ countLabel, useMainBuffer);
                    // iterate through real constants
                    for (size_t f = 0 ; f < physicalSize; ++f)
                    {
                        writeValue(to!string(*pFloat++), useMainBuffer);
                    }
                }
                else if (isDouble)
                {
                    // Get pointer to start of values
                    double* pDouble = params.getDoublePointer(physicalIndex);
                    
                    writeValue("double" ~ countLabel, useMainBuffer);
                    // iterate through real constants
                    for (size_t f = 0 ; f < physicalSize; ++f)
                    {
                        writeValue(to!string(*pDouble++), useMainBuffer);
                    }
                }
                else
                {
                    // Get pointer to start of values
                    int* pInt = params.getIntPointer(physicalIndex);

                    writeValue("int" ~ countLabel, useMainBuffer);
                    // iterate through real constants
                    for (size_t f = 0 ; f < physicalSize; ++f)
                    {
                        writeValue(to!string(*pInt++), useMainBuffer);
                    }

                } // end if (float/int)

            }

        }

    }

    void writeTextureUnit(TextureUnitState pTex)
    {
        bool skipWriting = false;

        // Fire pre-write event.
        fireTextureUnitStateEvent(MSE_PRE_WRITE, skipWriting, pTex);
        if (skipWriting)
            return;

        LogManager.getSingleton().logMessage("MaterialSerializer : parsing texture layer.", LML_NORMAL);
        mBuffer ~= "\n";
        writeAttribute(3, "texture_unit");
        // only write out name if its not equal to the default name
        if (pTex.getName() != to!string(pTex.getParent().getTextureUnitStateIndex(pTex)))
            writeValue(quoteWord(pTex.getName()));

        beginSection(3);
        {
            // Fire write begin event.
            fireTextureUnitStateEvent(MSE_WRITE_BEGIN, skipWriting, pTex);

            // texture_alias
            if (!pTex.getTextureNameAlias().empty())
            {
                writeAttribute(4, "texture_alias");
                writeValue(quoteWord(pTex.getTextureNameAlias()));
            }

            //texture name
            if (pTex.getNumFrames() == 1 && !pTex.getTextureName().empty() && !pTex.isCubic())
            {
                writeAttribute(4, "texture");
                writeValue(quoteWord(pTex.getTextureName()));

                switch (pTex.getTextureType())
                {
                    case TextureType.TEX_TYPE_1D:
                        writeValue("1d");
                        break;
                    case TextureType.TEX_TYPE_2D:
                        // nothing, this is the default
                        break;
                    case TextureType.TEX_TYPE_3D:
                        writeValue("3d");
                        break;
                    case TextureType.TEX_TYPE_CUBE_MAP:
                        // nothing, deal with this as cubic_texture since it copes with all variants
                        break;
                    default:
                        break;
                }

                if (pTex.getNumMipmaps() != TextureMipmap.MIP_DEFAULT)
                {
                    writeValue(to!string(pTex.getNumMipmaps()));
                }

                if (pTex.getIsAlpha())
                {
                    writeValue("alpha");
                }

                if (pTex.getDesiredFormat() != PixelFormat.PF_UNKNOWN)
                {
                    writeValue(PixelUtil.getFormatName(pTex.getDesiredFormat()));
                }
            }

            //anim. texture
            if (pTex.getNumFrames() > 1 && !pTex.isCubic())
            {
                writeAttribute(4, "anim_texture");
                foreach (n; 0..pTex.getNumFrames())
                    writeValue(quoteWord(pTex.getFrameTextureName(n)));
                writeValue(to!string(pTex.getAnimationDuration()));
            }

            //cubic texture
            if (pTex.isCubic())
            {
                writeAttribute(4, "cubic_texture");
                foreach (n; 0..pTex.getNumFrames())
                    writeValue(quoteWord(pTex.getFrameTextureName(n)));

                //combinedUVW/separateUW
                if (pTex.getTextureType() == TextureType.TEX_TYPE_CUBE_MAP)
                    writeValue("combinedUVW");
                else
                    writeValue("separateUV");
            }

            //anisotropy level
            if (mDefaults ||
                pTex.getTextureAnisotropy() != 1)//FIXME uint compared to -1?
            {
                writeAttribute(4, "max_anisotropy");
                writeValue(to!string(pTex.getTextureAnisotropy()));
            }

            //texture coordinate set
            if (mDefaults ||
                pTex.getTextureCoordSet() != 0)
            {
                writeAttribute(4, "tex_coord_set");
                writeValue(to!string(pTex.getTextureCoordSet()));
            }

            //addressing mode
            TextureUnitState.UVWAddressingMode uvw =
                pTex.getTextureAddressingMode();
            if (mDefaults ||
                uvw.u != TextureUnitState.TAM_WRAP ||
                uvw.v != TextureUnitState.TAM_WRAP ||
                uvw.w != TextureUnitState.TAM_WRAP )
            {
                writeAttribute(4, "tex_address_mode");
                if (uvw.u == uvw.v && uvw.u == uvw.w)
                {
                    writeValue(convertTexAddressMode(uvw.u));
                }
                else
                {
                    writeValue(convertTexAddressMode(uvw.u));
                    writeValue(convertTexAddressMode(uvw.v));
                    if (uvw.w != TextureUnitState.TAM_WRAP)
                    {
                        writeValue(convertTexAddressMode(uvw.w));
                    }
                }
            }

            //border colour
            ColourValue borderColour =
                pTex.getTextureBorderColour();
            if (mDefaults ||
                borderColour != ColourValue.Black)
            {
                writeAttribute(4, "tex_border_colour");
                writeColourValue(borderColour, true);
            }

            //filtering
            if (mDefaults ||
                pTex.getTextureFiltering(FilterType.FT_MIN) != FilterOptions.FO_LINEAR ||
                pTex.getTextureFiltering(FilterType.FT_MAG) != FilterOptions.FO_LINEAR ||
                pTex.getTextureFiltering(FilterType.FT_MIP) != FilterOptions.FO_POINT)
            {
                writeAttribute(4, "filtering");
                writeValue(
                    convertFiltering(pTex.getTextureFiltering(FilterType.FT_MIN))
                    ~ " "
                    ~ convertFiltering(pTex.getTextureFiltering(FilterType.FT_MAG))
                    ~ " "
                    ~ convertFiltering(pTex.getTextureFiltering(FilterType.FT_MIP)));
            }

            // Mip biasing
            if (mDefaults ||
                pTex.getTextureMipmapBias() != 0.0f)
            {
                writeAttribute(4, "mipmap_bias");
                writeValue(
                    to!string(pTex.getTextureMipmapBias()));
            }

            // colour_op_ex
            if (mDefaults ||
                pTex.getColourBlendMode().operation != LayerBlendOperationEx.LBX_MODULATE ||
                pTex.getColourBlendMode().source1 != LayerBlendSource.LBS_TEXTURE ||
                pTex.getColourBlendMode().source2 != LayerBlendSource.LBS_CURRENT)
            {
                writeAttribute(4, "colour_op_ex");
                writeLayerBlendOperationEx(pTex.getColourBlendMode().operation);
                writeLayerBlendSource(pTex.getColourBlendMode().source1);
                writeLayerBlendSource(pTex.getColourBlendMode().source2);
                if (pTex.getColourBlendMode().operation == LayerBlendOperationEx.LBX_BLEND_MANUAL)
                    writeValue(to!string(pTex.getColourBlendMode().factor));
                if (pTex.getColourBlendMode().source1 == LayerBlendSource.LBS_MANUAL)
                    writeColourValue(pTex.getColourBlendMode().colourArg1, false);
                if (pTex.getColourBlendMode().source2 == LayerBlendSource.LBS_MANUAL)
                    writeColourValue(pTex.getColourBlendMode().colourArg2, false);

                //colour_op_multipass_fallback
                writeAttribute(4, "colour_op_multipass_fallback");
                writeSceneBlendFactor(pTex.getColourBlendFallbackSrc());
                writeSceneBlendFactor(pTex.getColourBlendFallbackDest());
            }

            // alpha_op_ex
            if (mDefaults ||
                pTex.getAlphaBlendMode().operation != LayerBlendOperationEx.LBX_MODULATE ||
                pTex.getAlphaBlendMode().source1 != LayerBlendSource.LBS_TEXTURE ||
                pTex.getAlphaBlendMode().source2 != LayerBlendSource.LBS_CURRENT)
            {
                writeAttribute(4, "alpha_op_ex");
                writeLayerBlendOperationEx(pTex.getAlphaBlendMode().operation);
                writeLayerBlendSource(pTex.getAlphaBlendMode().source1);
                writeLayerBlendSource(pTex.getAlphaBlendMode().source2);
                if (pTex.getAlphaBlendMode().operation == LayerBlendOperationEx.LBX_BLEND_MANUAL)
                    writeValue(to!string(pTex.getAlphaBlendMode().factor));
                else if (pTex.getAlphaBlendMode().source1 == LayerBlendSource.LBS_MANUAL)
                    writeValue(to!string(pTex.getAlphaBlendMode().alphaArg1));
                else if (pTex.getAlphaBlendMode().source2 == LayerBlendSource.LBS_MANUAL)
                    writeValue(to!string(pTex.getAlphaBlendMode().alphaArg2));
            }

            bool individualTransformElems = false;
            // rotate
            if (mDefaults ||
                pTex.getTextureRotate() != Radian(0))
            {
                writeAttribute(4, "rotate");
                writeValue(to!string(pTex.getTextureRotate().valueDegrees()));
                individualTransformElems = true;
            }

            // scroll
            if (mDefaults ||
                pTex.getTextureUScroll() != 0 ||
                pTex.getTextureVScroll() != 0 )
            {
                writeAttribute(4, "scroll");
                writeValue(to!string(pTex.getTextureUScroll()));
                writeValue(to!string(pTex.getTextureVScroll()));
                individualTransformElems = true;
            }
            // scale
            if (mDefaults ||
                pTex.getTextureUScale() != 1.0 ||
                pTex.getTextureVScale() != 1.0 )
            {
                writeAttribute(4, "scale");
                writeValue(to!string(pTex.getTextureUScale()));
                writeValue(to!string(pTex.getTextureVScale()));
                individualTransformElems = true;
            }

            // free transform
            if (!individualTransformElems &&
                (mDefaults ||
             pTex.getTextureTransform() != Matrix4.IDENTITY))
            {
                writeAttribute(4, "transform");
                Matrix4 xform = pTex.getTextureTransform();
                for (int row = 0; row < 4; ++row)
                {
                    for (int col = 0; col < 4; ++col)
                    {
                        writeValue(to!string(xform[row][col]));
                    }
                }
            }

            // Used to store the u and v speeds of scroll animation effects
            float scrollAnimU = 0;
            float scrollAnimV = 0;

            auto effMap = pTex.getEffects();
            if (!effMap.emptyAA())
            {
                foreach (k, efs; effMap)
                {
                    foreach (ef; efs)
                        switch (ef.type)
                    {
                        case TextureUnitState.TextureEffectType.ET_ENVIRONMENT_MAP :
                        writeEnvironmentMapEffect(ef, pTex);
                        break;
                        case TextureUnitState.TextureEffectType.ET_ROTATE :
                        writeRotationEffect(ef, pTex);
                        break;
                        case TextureUnitState.TextureEffectType.ET_UVSCROLL :
                        scrollAnimU = scrollAnimV = ef.arg1;
                        break;
                        case TextureUnitState.TextureEffectType.ET_USCROLL :
                        scrollAnimU = ef.arg1;
                        break;
                        case TextureUnitState.TextureEffectType.ET_VSCROLL :
                        scrollAnimV = ef.arg1;
                        break;
                        case TextureUnitState.TextureEffectType.ET_TRANSFORM :
                        writeTransformEffect(ef, pTex);
                        break;
                        default:
                        break;
                    }
                }
            }

            // u and v scroll animation speeds merged, if present serialize scroll_anim
            if(scrollAnimU || scrollAnimV) {
                TextureUnitState.TextureEffect texEffect;
                texEffect.arg1 = scrollAnimU;
                texEffect.arg2 = scrollAnimV;
                writeScrollEffect(texEffect, pTex);
            }

            // Binding type
            TextureUnitState.BindingType bt = pTex.getBindingType();
            if (mDefaults ||
                bt != TextureUnitState.BindingType.BT_FRAGMENT)
            {
                writeAttribute(4, "binding_type");
                switch(bt)
                {
                    case TextureUnitState.BindingType.BT_FRAGMENT:
                        writeValue("fragment");
                        break;
                    case TextureUnitState.BindingType.BT_VERTEX:
                        writeValue("vertex");
                        break;
                    case TextureUnitState.BindingType.BT_GEOMETRY:
                    case TextureUnitState.BindingType.BT_TESSELATION_DOMAIN:
                    case TextureUnitState.BindingType.BT_TESSELATION_HULL:
                    case TextureUnitState.BindingType.BT_COMPUTE:
                        break;
                    default:
                        break;
                }

            }
            // Content type
            if (mDefaults ||
                pTex.getContentType() != TextureUnitState.ContentType.CONTENT_NAMED)
            {
                writeAttribute(4, "content_type");
                final switch(pTex.getContentType())
                {
                    case TextureUnitState.ContentType.CONTENT_NAMED:
                        writeValue("named");
                        break;
                    case TextureUnitState.ContentType.CONTENT_SHADOW:
                        writeValue("shadow");
                        break;
                    case TextureUnitState.ContentType.CONTENT_COMPOSITOR:
                        writeValue("compositor");
                        writeValue(quoteWord(pTex.getReferencedCompositorName()));
                        writeValue(quoteWord(pTex.getReferencedTextureName()));
                        writeValue(to!string(pTex.getReferencedMRTIndex()));
                        break;
                }
            }

            // Fire write end event.
            fireTextureUnitStateEvent(MSE_WRITE_END, skipWriting, pTex);
        }
        endSection(3);

        // Fire post section write event.
        fireTextureUnitStateEvent(MSE_POST_WRITE, skipWriting, pTex);

    }

    void writeSceneBlendFactor(SceneBlendFactor c_src,SceneBlendFactor c_dest,
                               SceneBlendFactor a_src,SceneBlendFactor a_dest)
    {
        writeSceneBlendFactor(c_src, c_dest);
        writeSceneBlendFactor(a_src, a_dest);
    }

    void writeSceneBlendFactor(SceneBlendFactor sbf_src,SceneBlendFactor sbf_dst)
    {
        if (sbf_src == SceneBlendFactor.SBF_ONE && sbf_dst == SceneBlendFactor.SBF_ONE )
            writeValue("add");
        else if (sbf_src == SceneBlendFactor.SBF_DEST_COLOUR && sbf_dst == SceneBlendFactor.SBF_ZERO)
            writeValue("modulate");
        else if (sbf_src == SceneBlendFactor.SBF_SOURCE_COLOUR && sbf_dst == SceneBlendFactor.SBF_ONE_MINUS_SOURCE_COLOUR)
            writeValue("colour_blend");
        else if (sbf_src == SceneBlendFactor.SBF_SOURCE_ALPHA && sbf_dst == SceneBlendFactor.SBF_ONE_MINUS_SOURCE_ALPHA)
            writeValue("alpha_blend");
        else
        {
            writeSceneBlendFactor(sbf_src);
            writeSceneBlendFactor(sbf_dst);
        }
    }

    void writeSceneBlendFactor(SceneBlendFactor sbf)
    {
        final switch (sbf)
        {
            case SceneBlendFactor.SBF_DEST_ALPHA:
                writeValue("dest_alpha");
                break;
            case SceneBlendFactor.SBF_DEST_COLOUR:
                writeValue("dest_colour");
                break;
            case SceneBlendFactor.SBF_ONE:
                writeValue("one");
                break;
            case SceneBlendFactor.SBF_ONE_MINUS_DEST_ALPHA:
                writeValue("one_minus_dest_alpha");
                break;
            case SceneBlendFactor.SBF_ONE_MINUS_DEST_COLOUR:
                writeValue("one_minus_dest_colour");
                break;
            case SceneBlendFactor.SBF_ONE_MINUS_SOURCE_ALPHA:
                writeValue("one_minus_src_alpha");
                break;
            case SceneBlendFactor.SBF_ONE_MINUS_SOURCE_COLOUR:
                writeValue("one_minus_src_colour");
                break;
            case SceneBlendFactor.SBF_SOURCE_ALPHA:
                writeValue("src_alpha");
                break;
            case SceneBlendFactor.SBF_SOURCE_COLOUR:
                writeValue("src_colour");
                break;
            case SceneBlendFactor.SBF_ZERO:
                writeValue("zero");
                break;
        }
    }

    void writeCompareFunction(CompareFunction cf)
    {
        final switch (cf)
        {
            case CompareFunction.CMPF_ALWAYS_FAIL:
                writeValue("always_fail");
                break;
            case CompareFunction.CMPF_ALWAYS_PASS:
                writeValue("always_pass");
                break;
            case CompareFunction.CMPF_EQUAL:
                writeValue("equal");
                break;
            case CompareFunction.CMPF_GREATER:
                writeValue("greater");
                break;
            case CompareFunction.CMPF_GREATER_EQUAL:
                writeValue("greater_equal");
                break;
            case CompareFunction.CMPF_LESS:
                writeValue("less");
                break;
            case CompareFunction.CMPF_LESS_EQUAL:
                writeValue("less_equal");
                break;
            case CompareFunction.CMPF_NOT_EQUAL:
                writeValue("not_equal");
                break;
        }
    }

    void writeColourValue(ColourValue colour, bool writeAlpha = false)
    {
        writeValue(to!string(colour.r));
        writeValue(to!string(colour.g));
        writeValue(to!string(colour.b));
        if (writeAlpha)
            writeValue(to!string(colour.a));
    }

    void writeLayerBlendOperationEx(LayerBlendOperationEx op)
    {
        final switch (op)
        {
            case LayerBlendOperationEx.LBX_ADD:
                writeValue("add");
                break;
            case LayerBlendOperationEx.LBX_ADD_SIGNED:
                writeValue("add_signed");
                break;
            case LayerBlendOperationEx.LBX_ADD_SMOOTH:
                writeValue("add_smooth");
                break;
            case LayerBlendOperationEx.LBX_BLEND_CURRENT_ALPHA:
                writeValue("blend_current_alpha");
                break;
            case LayerBlendOperationEx.LBX_BLEND_DIFFUSE_COLOUR:
                writeValue("blend_diffuse_colour");
                break;
            case LayerBlendOperationEx.LBX_BLEND_DIFFUSE_ALPHA:
                writeValue("blend_diffuse_alpha");
                break;
            case LayerBlendOperationEx.LBX_BLEND_MANUAL:
                writeValue("blend_manual");
                break;
            case LayerBlendOperationEx.LBX_BLEND_TEXTURE_ALPHA:
                writeValue("blend_texture_alpha");
                break;
            case LayerBlendOperationEx.LBX_MODULATE:
                writeValue("modulate");
                break;
            case LayerBlendOperationEx.LBX_MODULATE_X2:
                writeValue("modulate_x2");
                break;
            case LayerBlendOperationEx.LBX_MODULATE_X4:
                writeValue("modulate_x4");
                break;
            case LayerBlendOperationEx.LBX_SOURCE1:
                writeValue("source1");
                break;
            case LayerBlendOperationEx.LBX_SOURCE2:
                writeValue("source2");
                break;
            case LayerBlendOperationEx.LBX_SUBTRACT:
                writeValue("subtract");
                break;
            case LayerBlendOperationEx.LBX_DOTPRODUCT:
                writeValue("dotproduct");
                break;
        }
    }

    void writeLayerBlendSource(LayerBlendSource lbs)
    {
        final switch (lbs)
        {
            case LayerBlendSource.LBS_CURRENT:
                writeValue("src_current");
                break;
            case LayerBlendSource.LBS_DIFFUSE:
                writeValue("src_diffuse");
                break;
            case LayerBlendSource.LBS_MANUAL:
                writeValue("src_manual");
                break;
            case LayerBlendSource.LBS_SPECULAR:
                writeValue("src_specular");
                break;
            case LayerBlendSource.LBS_TEXTURE:
                writeValue("src_texture");
                break;
        }
    }

    //typedef multimap<TextureUnitState::TextureEffectType, TextureUnitState::TextureEffect>::type EffectMap;

    void writeRotationEffect(TextureUnitState.TextureEffect effect,TextureUnitState pTex)
    {
        if (effect.arg1)
        {
            writeAttribute(4, "rotate_anim");
            writeValue(to!string(effect.arg1));
        }
    }

    void writeTransformEffect(TextureUnitState.TextureEffect effect,TextureUnitState pTex)
    {
        writeAttribute(4, "wave_xform");

        final switch (effect.subtype)
        {
            case TextureUnitState.TextureTransformType.TT_ROTATE:
                writeValue("rotate");
                break;
            case TextureUnitState.TextureTransformType.TT_SCALE_U:
                writeValue("scale_x");
                break;
            case TextureUnitState.TextureTransformType.TT_SCALE_V:
                writeValue("scale_y");
                break;
            case TextureUnitState.TextureTransformType.TT_TRANSLATE_U:
                writeValue("scroll_x");
                break;
            case TextureUnitState.TextureTransformType.TT_TRANSLATE_V:
                writeValue("scroll_y");
                break;
        }

        final switch (effect.waveType)
        {
            case WaveformType.WFT_INVERSE_SAWTOOTH:
                writeValue("inverse_sawtooth");
                break;
            case WaveformType.WFT_SAWTOOTH:
                writeValue("sawtooth");
                break;
            case WaveformType.WFT_SINE:
                writeValue("sine");
                break;
            case WaveformType.WFT_SQUARE:
                writeValue("square");
                break;
            case WaveformType.WFT_TRIANGLE:
                writeValue("triangle");
                break;
            case WaveformType.WFT_PWM:
                writeValue("pwm");
                break;
        }

        writeValue(to!string(effect.base));
        writeValue(to!string(effect.frequency));
        writeValue(to!string(effect.phase));
        writeValue(to!string(effect.amplitude));
    }

    void writeScrollEffect(TextureUnitState.TextureEffect effect,TextureUnitState pTex)
    {
        if (effect.arg1 || effect.arg2)
        {
            writeAttribute(4, "scroll_anim");
            writeValue(to!string(effect.arg1));
            writeValue(to!string(effect.arg2));
        }
    }

    void writeEnvironmentMapEffect(TextureUnitState.TextureEffect effect,TextureUnitState pTex)
    {
        writeAttribute(4, "env_map");
        final switch (effect.subtype)
        {
            case TextureUnitState.EnvMapType.ENV_PLANAR:
                writeValue("planar");
                break;
            case TextureUnitState.EnvMapType.ENV_CURVED:
                writeValue("spherical");
                break;
            case TextureUnitState.EnvMapType.ENV_NORMAL:
                writeValue("cubic_normal");
                break;
            case TextureUnitState.EnvMapType.ENV_REFLECTION:
                writeValue("cubic_reflection");
                break;
        }
    }

    string convertFiltering(FilterOptions fo)
    {
        switch (fo)
        {
            case FilterOptions.FO_NONE:
                return "none";
            case FilterOptions.FO_POINT:
                return "point";
            case FilterOptions.FO_LINEAR:
                return "linear";
            case FilterOptions.FO_ANISOTROPIC:
                return "anisotropic";
            default:
                break;
        }

        return "point";
    }

    
    /** Internal methods that invokes registered listeners callback.
     @see Listener::materialEventRaised.
     */
    void fireMaterialEvent(SerializeEvent event, ref bool skip,Material mat)
    {
        foreach(it; mListeners)
        {
            it.materialEventRaised(this, event, skip, mat);
            if (skip)
                break;
        }
    }

    /** Internal methods that invokes registered listeners callback.
     @see Listener::techniqueEventRaised.
     */
    void fireTechniqueEvent(SerializeEvent event, ref bool skip,Technique tech)
    {
        foreach(it; mListeners)
        {
            it.techniqueEventRaised(this, event, skip, tech);
            if (skip)
                break;
        }
    }

    /** Internal methods that invokes registered listeners callback.
     @see Listener::passEventRaised.
     */
    void firePassEvent(SerializeEvent event, ref bool skip,Pass pass)
    {
        foreach(it; mListeners)
        {
            it.passEventRaised(this, event, skip, pass);
            if (skip)
                break;
        }
    }

    /** Internal methods that invokes registered listeners callback.
     @see Listener::gpuProgramRefEventRaised.
     */
    void fireGpuProgramRefEvent(SerializeEvent event, ref bool skip,
                                string attrib,
                                SharedPtr!GpuProgram program,
                                GpuProgramParametersPtr params,
                                GpuProgramParameters defaultParams)
    {
        foreach(it; mListeners)
        {
            it.gpuProgramRefEventRaised(this, event, skip, attrib, program, params, defaultParams);
            if (skip)
                break;
        }
    }

    
    /** Internal methods that invokes registered listeners callback.
     @see Listener::textureUnitStateEventRaised.
     */
    void fireTextureUnitStateEvent(SerializeEvent event, ref bool skip,TextureUnitState textureUnit)
    {
        foreach(it; mListeners)
        {
            it.textureUnitStateEventRaised(this, event, skip, textureUnit);
            if (skip)
                break;
        }
    }

public:
    /** defaultructor*/
    this()
    {
        // Set up root attribute parsers
        mRootAttribParsers["material"] = &parseMaterial;
        mRootAttribParsers["vertex_program"] = &parseVertexProgram;
        mRootAttribParsers["geometry_program"] = &parseGeometryProgram;
        mRootAttribParsers["fragment_program"] = &parseFragmentProgram;

        // Set up material attribute parsers
        mMaterialAttribParsers["lod_values"] = &parseLodValues;
        mMaterialAttribParsers["lod_strategy"] = &parseLodStrategy;
        mMaterialAttribParsers["lod_distances"] = &parseLodDistances;
        mMaterialAttribParsers["receive_shadows"] = &parseReceiveShadows;
        mMaterialAttribParsers["transparency_casts_shadows"] = &parseTransparencyCastsShadows;
        mMaterialAttribParsers["technique"] = &parseTechnique;
        mMaterialAttribParsers["set_texture_alias"] = &parseSetTextureAlias;

        // Set up technique attribute parsers
        mTechniqueAttribParsers["lod_index"] = &parseLodIndex;
        mTechniqueAttribParsers["shadow_caster_material"] = &parseShadowCasterMaterial;
        mTechniqueAttribParsers["shadow_receiver_material"] = &parseShadowReceiverMaterial;
        mTechniqueAttribParsers["scheme"] = &parseScheme;
        mTechniqueAttribParsers["gpu_vendor_rule"] = &parseGPUVendorRule;
        mTechniqueAttribParsers["gpu_device_rule"] = &parseGPUDeviceRule;
        mTechniqueAttribParsers["pass"] = &parsePass;

        // Set up pass attribute parsers
        mPassAttribParsers["ambient"] = &parseAmbient;
        mPassAttribParsers["diffuse"] = &parseDiffuse;
        mPassAttribParsers["specular"] = &parseSpecular;
        mPassAttribParsers["emissive"] = &parseEmissive;
        mPassAttribParsers["scene_blend"] = &parseSceneBlend;
        mPassAttribParsers["separate_scene_blend"] = &parseSeparateSceneBlend;
        mPassAttribParsers["depth_check"] = &parseDepthCheck;
        mPassAttribParsers["depth_write"] = &parseDepthWrite;
        mPassAttribParsers["depth_func"] = &parseDepthFunc;
        mPassAttribParsers["normalise_normals"] = &parseNormaliseNormals;
        mPassAttribParsers["alpha_rejection"] = &parseAlphaRejection;
        mPassAttribParsers["alpha_to_coverage"] = &parseAlphaToCoverage;
        mPassAttribParsers["transparent_sorting"] = &parseTransparentSorting;
        mPassAttribParsers["colour_write"] = &parseColourWrite;
        mPassAttribParsers["light_scissor"] = &parseLightScissor;
        mPassAttribParsers["light_clip_planes"] = &parseLightClip;
        mPassAttribParsers["cull_hardware"] = &parseCullHardware;
        mPassAttribParsers["cull_software"] = &parseCullSoftware;
        mPassAttribParsers["lighting"] = &parseLighting;
        mPassAttribParsers["fog_override"] = &parseFogging;
        mPassAttribParsers["shading"] = &parseShading;
        mPassAttribParsers["polygon_mode"] = &parsePolygonMode;
        mPassAttribParsers["polygon_mode_overrideable"] = &parsePolygonModeOverrideable;
        mPassAttribParsers["depth_bias"] = &parseDepthBias;
        mPassAttribParsers["iteration_depth_bias"] = &parseIterationDepthBias;
        mPassAttribParsers["texture_unit"] = &parseTextureUnit;
        mPassAttribParsers["vertex_program_ref"] = &parseVertexProgramRef;
        mPassAttribParsers["geometry_program_ref"] = &parseGeometryProgramRef;
        mPassAttribParsers["shadow_caster_vertex_program_ref"] = &parseShadowCasterVertexProgramRef;
        mPassAttribParsers["shadow_caster_fragment_program_ref"] = &parseShadowCasterFragmentProgramRef;
        mPassAttribParsers["shadow_receiver_vertex_program_ref"] = &parseShadowReceiverVertexProgramRef;
        mPassAttribParsers["shadow_receiver_fragment_program_ref"] = &parseShadowReceiverFragmentProgramRef;
        mPassAttribParsers["fragment_program_ref"] = &parseFragmentProgramRef;
        mPassAttribParsers["max_lights"] = &parseMaxLights;
        mPassAttribParsers["start_light"] = &parseStartLight;
        mPassAttribParsers["iteration"] = &parseIteration;
        mPassAttribParsers["point_size"] = &parsePointSize;
        mPassAttribParsers["point_sprites"] = &parsePointSprites;
        mPassAttribParsers["point_size_attenuation"] = &parsePointAttenuation;
        mPassAttribParsers["point_size_min"] = &parsePointSizeMin;
        mPassAttribParsers["point_size_max"] = &parsePointSizeMax;
        mPassAttribParsers["illumination_stage"] = &parseIlluminationStage;

        // Set up texture unit attribute parsers
        mTextureUnitAttribParsers["texture_source"] = &parseTextureSource;
        mTextureUnitAttribParsers["texture"] = &parseTexture;
        mTextureUnitAttribParsers["anim_texture"] = &parseAnimTexture;
        mTextureUnitAttribParsers["cubic_texture"] = &parseCubicTexture;
        mTextureUnitAttribParsers["binding_type"] = &parseBindingType;
        mTextureUnitAttribParsers["tex_coord_set"] = &parseTexCoord;
        mTextureUnitAttribParsers["tex_address_mode"] = &parseTexAddressMode;
        mTextureUnitAttribParsers["tex_border_colour"] = &parseTexBorderColour;
        mTextureUnitAttribParsers["colour_op"] = &parseColourOp;
        mTextureUnitAttribParsers["colour_op_ex"] = &parseColourOpEx;
        mTextureUnitAttribParsers["colour_op_multipass_fallback"] = &parseColourOpFallback;
        mTextureUnitAttribParsers["alpha_op_ex"] = &parseAlphaOpEx;
        mTextureUnitAttribParsers["env_map"] = &parseEnvMap;
        mTextureUnitAttribParsers["scroll"] = &parseScroll;
        mTextureUnitAttribParsers["scroll_anim"] = &parseScrollAnim;
        mTextureUnitAttribParsers["rotate"] = &parseRotate;
        mTextureUnitAttribParsers["rotate_anim"] = &parseRotateAnim;
        mTextureUnitAttribParsers["scale"] = &parseScale;
        mTextureUnitAttribParsers["wave_xform"] = &parseWaveXform;
        mTextureUnitAttribParsers["transform"] = &parseTransform;
        mTextureUnitAttribParsers["filtering"] = &parseFiltering;
        mTextureUnitAttribParsers["compare_test"] = &parseCompareTest;
        mTextureUnitAttribParsers["compare_func"] = &parseCompareFunction;
        mTextureUnitAttribParsers["max_anisotropy"] = &parseAnisotropy;
        mTextureUnitAttribParsers["texture_alias"] = &parseTextureAlias;
        mTextureUnitAttribParsers["mipmap_bias"] = &parseMipmapBias;
        mTextureUnitAttribParsers["content_type"] = &parseContentType;

        // Set up program reference attribute parsers
        mProgramRefAttribParsers["param_indexed"] = &parseParamIndexed;
        mProgramRefAttribParsers["param_indexed_auto"] = &parseParamIndexedAuto;
        mProgramRefAttribParsers["param_named"] = &parseParamNamed;
        mProgramRefAttribParsers["param_named_auto"] = &parseParamNamedAuto;

        // Set up program definition attribute parsers
        mProgramAttribParsers["source"] = &parseProgramSource;
        mProgramAttribParsers["syntax"] = &parseProgramSyntax;
        mProgramAttribParsers["includes_skeletal_animation"] = &parseProgramSkeletalAnimation;
        mProgramAttribParsers["includes_morph_animation"] = &parseProgramMorphAnimation;
        mProgramAttribParsers["includes_pose_animation"] = &parseProgramPoseAnimation;
        mProgramAttribParsers["uses_vertex_texture_fetch"] = &parseProgramVertexTextureFetch;
        mProgramAttribParsers["default_params"] = &parseDefaultParams;

        // Set up program default param attribute parsers
        mProgramDefaultParamAttribParsers["param_indexed"] = &parseParamIndexed;
        mProgramDefaultParamAttribParsers["param_indexed_auto"] = &parseParamIndexedAuto;
        mProgramDefaultParamAttribParsers["param_named"] = &parseParamNamed;
        mProgramDefaultParamAttribParsers["param_named_auto"] = &parseParamNamedAuto;

        mScriptContext.section = MSS_NONE;
        mScriptContext.material.setNull();
        //mScriptContext.technique = null;
        //mScriptContext.pass = null;
        //mScriptContext.textureUnit = null;
        mScriptContext.program.setNull();
        mScriptContext.lineNo = 0;
        mScriptContext.filename.clear();
        mScriptContext.techLev = -1;
        mScriptContext.passLev = -1;
        mScriptContext.stateLev = -1;

        mBuffer.clear();
    }

    /** default destructor*/
    ~this() {}

    /** Queue an in-memory Material to the internal buffer for export.
     @param pMat Material pointer
     @param clearQueued If true, any materials already queued will be removed
     @param exportDefaults If true, attributes which are defaulted will be
     included in the script exported, otherwise they will be omitted
     @param materialName Allow exporting the given material under a different name.
     In case of empty string the original material name will be used.
     */
    void queueForExport(SharedPtr!Material pMat, bool clearQueued = false,
                        bool exportDefaults = false,string materialName = "")
    {
        if (clearQueued)
            clearQueue();

        mDefaults = exportDefaults;
        writeMaterial(pMat, materialName);
    }

    /** Exports queued material(s) to a named material script file.
     @param filename the file name of the material script to be exported
     @param includeProgDef If true, vertex program and fragment program
     definitions will be written at the top of the material script
     @param programFilename the file name of the vertex / fragment program
     script to be exported. This is only used if there are program definitions
     to be exported and includeProgDef is false
     when calling queueForExport.
     */
    void exportQueued(string fileName,bool includeProgDef = false,string programFilename = "")
    {
        // write out gpu program definitions to the buffer
        writeGpuPrograms();

        if (mBuffer.empty())
            throw new InvalidParamsError("Queue is empty !", "MaterialSerializer.exportQueued");

        LogManager.getSingleton().logMessage("MaterialSerializer : writing material(s) to material script : " ~ fileName, LML_NORMAL);

        auto fp = File(fileName, "w");
        if (!fp.isOpen())
            throw new CannotWriteToFileError("Cannot create material file.",
                                             "MaterialSerializer.export");

        // output gpu program definitions to material script file if includeProgDef is true
        if (includeProgDef && !mGpuProgramBuffer.empty())
        {
            fp.write(mGpuProgramBuffer);
        }

        // output main buffer holding material script
        fp.write(mBuffer);
        fp.close();

        // write program script if program filename and program definitions
        // were not included in material script
        if (!includeProgDef && !mGpuProgramBuffer.empty() && !programFilename.empty())
        {
            auto locFp = File(programFilename, "w");
            if (!locFp.isOpen())
                throw new CannotWriteToFileError("Cannot create program material file.",
                                                 "MaterialSerializer.export");
            locFp.write(mGpuProgramBuffer);
            locFp.close();
        }

        LogManager.getSingleton().logMessage("MaterialSerializer : done.", LML_NORMAL);
        clearQueue();
    }

    /** Exports a single in-memory Material to the named material script file.
     @param exportDefaults if true then exports all values including defaults
     @param includeProgDef if true includes Gpu shader program definitions in the
     export material script otherwise if false then program definitions will
     be exported to a separate file with name programFilename if
     programFilename is not empty
     @param programFilename the file name of the vertex / fragment program
     script to be exported. This is only used if includeProgDef is false.
     @param materialName Allow exporting the given material under a different name.
     In case of empty string the original material name will be used.
     */
    void exportMaterial(SharedPtr!Material pMat,string fileName, bool exportDefaults = false,
                        bool includeProgDef = false,string programFilename = "",
                        string materialName = "")
    {
        clearQueue();
        mDefaults = exportDefaults;
        writeMaterial(pMat, materialName);
        exportQueued(fileName, includeProgDef, programFilename);
    }

    /** Returns a string representing the parsed material(s) */
    string getQueuedAsstring()
    {
        return mBuffer;
    }

    /** Clears the internal buffer */
    void clearQueue()
    {
        mBuffer.clear();
        mGpuProgramBuffer.clear();
        mGpuProgramDefinitionContainer.clear();
    }

    /** Parses a Material script file passed as a stream.
     */
    void parseScript(DataStream stream, string groupName)
    {
        string line;
        bool nextIsOpenBrace = false;

        mScriptContext.section = MSS_NONE;
        mScriptContext.material.setNull();
        mScriptContext.technique = null;
        mScriptContext.pass = null;
        mScriptContext.textureUnit = null;
        mScriptContext.program.setNull();
        mScriptContext.lineNo = 0;
        mScriptContext.techLev = -1;
        mScriptContext.passLev = -1;
        mScriptContext.stateLev = -1;
        mScriptContext.filename = stream.getName();
        mScriptContext.groupName = groupName;
        while(!stream.eof())
        {
            line = stream.getLine();
            mScriptContext.lineNo++;

            // DEBUG LINE
            LogManager.getSingleton().logMessage("About to attempt line(#" ~
                                                 to!string(mScriptContext.lineNo) ~ "): " ~ line);

            // Ignore comments & blanks
            if (!(line.length == 0 || line.startsWith("//")))
            {
                if (nextIsOpenBrace)
                {
                    // NB, parser will have changed context already
                    if (line != "{")
                    {
                        logParseError("Expecting '{' but got " ~
                                      line ~ " instead.", mScriptContext);
                    }
                    nextIsOpenBrace = false;
                }
                else
                {
                    nextIsOpenBrace = parseScriptLine(line);
                }

            }
        }

        // Check all braces were closed
        if (mScriptContext.section != MSS_NONE)
        {
            logParseError("Unexpected end of file.", mScriptContext);
        }

        // Make sure we invalidate our context shared pointer (don't want to hold on)
        mScriptContext.material.setNull();

    }

    /** Register a listener to this Serializer.
     @see MaterialSerializer::Listener
     */
    void addListener(Listener listener)
    {
        mListeners ~= listener;
    }

    /** Remove a listener from this Serializer.
     @see MaterialSerializer::Listener
     */
    void removeListener(Listener listener)
    {
        mListeners.removeFromArray(listener);
    }

private:
    string mBuffer;
    string mGpuProgramBuffer;
    //typedef set<string>::type GpuProgramDefinitionContainer;
    alias string[] GpuProgramDefinitionContainer;
    //typedef GpuProgramDefinitionContainer::iterator GpuProgramDefIterator;
    GpuProgramDefinitionContainer mGpuProgramDefinitionContainer;
    bool mDefaults;

public:
    void beginSection(ushort level,bool useMainBuffer = true)
    {
        string buffer = (useMainBuffer ? mBuffer : mGpuProgramBuffer);
        buffer ~= "\n";
        foreach (i; 0..level)
        {
            buffer ~= "\t";
        }
        buffer ~= "{";
    }
    void endSection(ushort level,bool useMainBuffer = true)
    {
        string buffer = (useMainBuffer ? mBuffer : mGpuProgramBuffer);
        buffer ~= "\n";
        foreach (i; 0..level)
        {
            buffer ~= "\t";
        }
        buffer ~= "}";
    }

    void writeAttribute(ushort level,string att,bool useMainBuffer = true)
    {
        string buffer = (useMainBuffer ? mBuffer : mGpuProgramBuffer);
        buffer ~= "\n";
        foreach (i; 0..level)
        {
            buffer ~= "\t";
        }
        buffer ~= att;
    }

    void writeValue(string val,bool useMainBuffer = true)
    {
        string buffer = (useMainBuffer ? mBuffer : mGpuProgramBuffer);
        buffer ~= (" " ~ val);
    }

    string quoteWord(string val)
    {
        if (val.indexOf(" ") != -1 ||
            val.indexOf("\t") != -1)
            return ("\"" ~ val ~ "\"");
        else return val;
    }

    
    void writeComment(ushort level,string comment,bool useMainBuffer = true)
    {
        string buffer = (useMainBuffer ? mBuffer : mGpuProgramBuffer);
        buffer ~= "\n";
        foreach (i; 0..level)
        {
            buffer ~= "\t";
        }
        buffer ~= "// " ~ comment;
    }

}

//-----------------------------------------------------------------------
// Internal parser methods
//-----------------------------------------------------------------------
void logParseError(string error, ref MaterialScriptContext context)
{
    // log material name only if filename not specified
    if (context.filename.empty() && !context.material.isNull())
    {
        LogManager.getSingleton().logMessage(
            "Error in material " ~ context.material.getName() ~
            " : " ~ error);
    }
    else
    {
        if (!context.material.isNull())
        {
            LogManager.getSingleton().logMessage(
                "Error in material " ~ context.material.getName() ~
                " at line " ~ to!string(context.lineNo) ~
                " of " ~ context.filename ~ ": " ~ error);
        }
        else
        {
            LogManager.getSingleton().logMessage(
                "Error at line " ~ to!string(context.lineNo) ~
                " of " ~ context.filename ~ ": " ~ error);
        }
    }
}
//-----------------------------------------------------------------------
ColourValue _parseColourValue(string[] vecparams)
{
    return ColourValue(
        to!Real(vecparams[0]) ,
        to!Real(vecparams[1]) ,
        to!Real(vecparams[2]) ,
        (vecparams.length==4) ? to!Real(vecparams[3]) : 1.0f ) ;
}
//-----------------------------------------------------------------------
string convertTexAddressMode(TextureUnitState.TextureAddressingMode tam)
{
    final switch (tam)
    {
        case TextureUnitState.TAM_BORDER:
            return "border";
        case TextureUnitState.TAM_CLAMP:
            return "clamp";
        case TextureUnitState.TAM_MIRROR:
            return "mirror";
        case TextureUnitState.TAM_WRAP:
            return "wrap";
    }

    return "wrap";
}
//-----------------------------------------------------------------------
FilterOptions convertFiltering(string s)
{
    if (s == "none") //TODO D can do string switch
    {
        return FilterOptions.FO_NONE;
    }
    else if (s == "point")
    {
        return FilterOptions.FO_POINT;
    }
    else if (s == "linear")
    {
        return FilterOptions.FO_LINEAR;
    }
    else if (s == "anisotropic")
    {
        return FilterOptions.FO_ANISOTROPIC;
    }

    return FilterOptions.FO_POINT;
}
//-----------------------------------------------------------------------
bool parseAmbient(string params, ref MaterialScriptContext context)
{
    string[] vecparams = StringUtil.split(params, " \t");
    // Must be 1, 3 or 4 parameters
    if (vecparams.length == 1) {
        if(vecparams[0] == "vertexcolour") {
            context.pass.setVertexColourTracking(context.pass.getVertexColourTracking() | TVC_AMBIENT);
        } else {
            logParseError(
                "Bad ambient attribute, single parameter flag must be 'vertexcolour'",
                context);
        }
    }
    else if (vecparams.length == 3 || vecparams.length == 4)
    {
        context.pass.setAmbient( _parseColourValue(vecparams) );
        context.pass.setVertexColourTracking(context.pass.getVertexColourTracking() & ~TVC_AMBIENT);
    }
    else
    {
        logParseError(
            "Bad ambient attribute, wrong number of parameters (expected 1, 3 or 4)",
            context);
    }
    return false;
}
//-----------------------------------------------------------------------
bool parseDiffuse(string params, ref MaterialScriptContext context)
{
    string[] vecparams = StringUtil.split(params, " \t");
    // Must be 1, 3 or 4 parameters
    if (vecparams.length == 1) {
        if(vecparams[0] == "vertexcolour") {
            context.pass.setVertexColourTracking(context.pass.getVertexColourTracking() | TVC_DIFFUSE);
        } else {
            logParseError(
                "Bad diffuse attribute, single parameter flag must be 'vertexcolour'",
                context);
        }
    }
    else if (vecparams.length == 3 || vecparams.length == 4)
    {
        context.pass.setDiffuse( _parseColourValue(vecparams) );
        context.pass.setVertexColourTracking(context.pass.getVertexColourTracking() & ~TVC_DIFFUSE);
    }
    else
    {
        logParseError(
            "Bad diffuse attribute, wrong number of parameters (expected 1, 3 or 4)",
            context);
    }        return false;
}
//-----------------------------------------------------------------------
bool parseSpecular(string params, ref MaterialScriptContext context)
{
    string[] vecparams = StringUtil.split(params, " \t");
    // Must be 2, 4 or 5 parameters
    if(vecparams.length == 2)
    {
        if(vecparams[0] == "vertexcolour") {
            context.pass.setVertexColourTracking(context.pass.getVertexColourTracking() | TVC_SPECULAR);
            context.pass.setShininess(to!Real(vecparams[1]) );
        }
        else
        {
            logParseError(
                "Bad specular attribute, double parameter statement must be 'vertexcolour <shininess>'",
                context);
        }
    }
    else if(vecparams.length == 4 || vecparams.length == 5)
    {
        context.pass.setSpecular(
            to!Real(vecparams[0]),
            to!Real(vecparams[1]),
            to!Real(vecparams[2]),
            vecparams.length == 5?
            to!Real(vecparams[3]) : 1.0f);
        context.pass.setVertexColourTracking(context.pass.getVertexColourTracking() & ~TVC_SPECULAR);
        context.pass.setShininess(
            to!Real(vecparams[vecparams.length - 1]) );
    }
    else
    {
        logParseError(
            "Bad specular attribute, wrong number of parameters (expected 2, 4 or 5)",
            context);
    }
    return false;
}
//-----------------------------------------------------------------------
bool parseEmissive(string params, ref MaterialScriptContext context)
{
    string[] vecparams = StringUtil.split(params, " \t");
    // Must be 1, 3 or 4 parameters
    if (vecparams.length == 1) {
        if(vecparams[0] == "vertexcolour") {
            context.pass.setVertexColourTracking(context.pass.getVertexColourTracking() | TVC_EMISSIVE);
        } else {
            logParseError(
                "Bad emissive attribute, single parameter flag must be 'vertexcolour'",
                context);
        }
    }
    else if (vecparams.length == 3 || vecparams.length == 4)
    {
        context.pass.setSelfIllumination( _parseColourValue(vecparams) );
        context.pass.setVertexColourTracking(context.pass.getVertexColourTracking() & ~TVC_EMISSIVE);
    }
    else
    {
        logParseError(
            "Bad emissive attribute, wrong number of parameters (expected 1, 3 or 4)",
            context);
    }
    return false;
}
//-----------------------------------------------------------------------
SceneBlendFactor convertBlendFactor(string param)
{
    if (param == "one")
        return SceneBlendFactor.SBF_ONE;
    else if (param == "zero")
        return SceneBlendFactor.SBF_ZERO;
    else if (param == "dest_colour")
        return SceneBlendFactor.SBF_DEST_COLOUR;
    else if (param == "src_colour")
        return SceneBlendFactor.SBF_SOURCE_COLOUR;
    else if (param == "one_minus_dest_colour")
        return SceneBlendFactor.SBF_ONE_MINUS_DEST_COLOUR;
    else if (param == "one_minus_src_colour")
        return SceneBlendFactor.SBF_ONE_MINUS_SOURCE_COLOUR;
    else if (param == "dest_alpha")
        return SceneBlendFactor.SBF_DEST_ALPHA;
    else if (param == "src_alpha")
        return SceneBlendFactor.SBF_SOURCE_ALPHA;
    else if (param == "one_minus_dest_alpha")
        return SceneBlendFactor.SBF_ONE_MINUS_DEST_ALPHA;
    else if (param == "one_minus_src_alpha")
        return SceneBlendFactor.SBF_ONE_MINUS_SOURCE_ALPHA;
    else
    {
        throw new InvalidParamsError("Invalid blend factor.", "convertBlendFactor");
    }

    
}
//-----------------------------------------------------------------------
bool parseSceneBlend(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    string[] vecparams = StringUtil.split(params, " \t");
    // Should be 1 or 2 params
    if (vecparams.length == 1)
    {
        //simple
        SceneBlendType stype;
        if (vecparams[0] == "add")
            stype = SceneBlendType.SBT_ADD;
        else if (vecparams[0] == "modulate")
            stype = SceneBlendType.SBT_MODULATE;
        else if (vecparams[0] == "colour_blend")
            stype = SceneBlendType.SBT_TRANSPARENT_COLOUR;
        else if (vecparams[0] == "alpha_blend")
            stype = SceneBlendType.SBT_TRANSPARENT_ALPHA;
        else
        {
            logParseError(
                "Bad scene_blend attribute, unrecognised parameter '" ~ vecparams[0] ~ "'",
                context);
            return false;
        }
        context.pass.setSceneBlending(stype);

    }
    else if (vecparams.length == 2)
    {
        //src/dest
        SceneBlendFactor src, dest;

        try {
            src = convertBlendFactor(vecparams[0]);
            dest = convertBlendFactor(vecparams[1]);
            context.pass.setSceneBlending(src,dest);
        }
        catch (Exception e)
        {
            logParseError("Bad scene_blend attribute, " ~ e.msg, context);
        }

    }
    else
    {
        logParseError(
            "Bad scene_blend attribute, wrong number of parameters (expected 1 or 2)",
            context);
    }

    return false;

}
//-----------------------------------------------------------------------
bool parseSeparateSceneBlend(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    string[] vecparams = StringUtil.split(params, " \t");
    // Should be 2 or 4 params
    if (vecparams.length == 2)
    {
        //simple
        SceneBlendType stype;
        if (vecparams[0] == "add")
            stype = SceneBlendType.SBT_ADD;
        else if (vecparams[0] == "modulate")
            stype = SceneBlendType.SBT_MODULATE;
        else if (vecparams[0] == "colour_blend")
            stype = SceneBlendType.SBT_TRANSPARENT_COLOUR;
        else if (vecparams[0] == "alpha_blend")
            stype = SceneBlendType.SBT_TRANSPARENT_ALPHA;
        else
        {
            logParseError(
                "Bad separate_scene_blend attribute, unrecognised parameter '" ~ vecparams[0] ~ "'",
                context);
            return false;
        }

        SceneBlendType stypea;
        if (vecparams[0] == "add")
            stypea = SceneBlendType.SBT_ADD;
        else if (vecparams[0] == "modulate")
            stypea = SceneBlendType.SBT_MODULATE;
        else if (vecparams[0] == "colour_blend")
            stypea = SceneBlendType.SBT_TRANSPARENT_COLOUR;
        else if (vecparams[0] == "alpha_blend")
            stypea = SceneBlendType.SBT_TRANSPARENT_ALPHA;
        else
        {
            logParseError(
                "Bad separate_scene_blend attribute, unrecognised parameter '" ~ vecparams[1] ~ "'",
                context);
            return false;
        }

        context.pass.setSeparateSceneBlending(stype, stypea);
    }
    else if (vecparams.length == 4)
    {
        //src/dest
        SceneBlendFactor src, dest;
        SceneBlendFactor srca, desta;

        try {
            src = convertBlendFactor(vecparams[0]);
            dest = convertBlendFactor(vecparams[1]);
            srca = convertBlendFactor(vecparams[2]);
            desta = convertBlendFactor(vecparams[3]);
            context.pass.setSeparateSceneBlending(src,dest,srca,desta);
        }
        catch (Exception e)
        {
            logParseError("Bad separate_scene_blend attribute, " ~ e.msg, context);
        }

    }
    else
    {
        logParseError(
            "Bad separate_scene_blend attribute, wrong number of parameters (expected 2 or 4)",
            context);
    }

    return false;
}
//-----------------------------------------------------------------------
CompareFunction convertCompareFunction(string param)
{
    if (param == "always_fail")
        return CompareFunction.CMPF_ALWAYS_FAIL;
    else if (param == "always_pass")
        return CompareFunction.CMPF_ALWAYS_PASS;
    else if (param == "less")
        return CompareFunction.CMPF_LESS;
    else if (param == "less_equal")
        return CompareFunction.CMPF_LESS_EQUAL;
    else if (param == "equal")
        return CompareFunction.CMPF_EQUAL;
    else if (param == "not_equal")
        return CompareFunction.CMPF_NOT_EQUAL;
    else if (param == "greater_equal")
        return CompareFunction.CMPF_GREATER_EQUAL;
    else if (param == "greater")
        return CompareFunction.CMPF_GREATER;
    else
        throw new InvalidParamsError("Invalid compare function", "convertCompareFunction");

}
//-----------------------------------------------------------------------
bool parseDepthCheck(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    if (params == "on")
        context.pass.setDepthCheckEnabled(true);
    else if (params == "off")
        context.pass.setDepthCheckEnabled(false);
    else
        logParseError(
            "Bad depth_check attribute, valid parameters are 'on' or 'off'.",
            context);

    return false;
}
//-----------------------------------------------------------------------
bool parseDepthWrite(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    if (params == "on")
        context.pass.setDepthWriteEnabled(true);
    else if (params == "off")
        context.pass.setDepthWriteEnabled(false);
    else
        logParseError(
            "Bad depth_write attribute, valid parameters are 'on' or 'off'.",
            context);
    return false;
}
//-----------------------------------------------------------------------
bool parseLightScissor(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    if (params == "on")
        context.pass.setLightScissoringEnabled(true);
    else if (params == "off")
        context.pass.setLightScissoringEnabled(false);
    else
        logParseError(
            "Bad light_scissor attribute, valid parameters are 'on' or 'off'.",
            context);
    return false;
}
//-----------------------------------------------------------------------
bool parseLightClip(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    if (params == "on")
        context.pass.setLightClipPlanesEnabled(true);
    else if (params == "off")
        context.pass.setLightClipPlanesEnabled(false);
    else
        logParseError(
            "Bad light_clip_planes attribute, valid parameters are 'on' or 'off'.",
            context);
    return false;
}
//-----------------------------------------------------------------------
bool parseDepthFunc(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    try {
        CompareFunction func = convertCompareFunction(params);
        context.pass.setDepthFunction(func);
    }
    catch (Exception)
    {
        logParseError("Bad depth_func attribute, invalid function parameter.", context);
    }

    return false;
}
//-----------------------------------------------------------------------
bool parseNormaliseNormals(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    if (params == "on")
        context.pass.setNormaliseNormals(true);
    else if (params == "off")
        context.pass.setNormaliseNormals(false);
    else
        logParseError(
            "Bad normalise_normals attribute, valid parameters are 'on' or 'off'.",
            context);
    return false;
}
//-----------------------------------------------------------------------
bool parseColourWrite(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    if (params == "on")
        context.pass.setColourWriteEnabled(true);
    else if (params == "off")
        context.pass.setColourWriteEnabled(false);
    else
        logParseError(
            "Bad colour_write attribute, valid parameters are 'on' or 'off'.",
            context);
    return false;
}

//-----------------------------------------------------------------------
bool parseCullHardware(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    if (params=="none")
        context.pass.setCullingMode(CullingMode.CULL_NONE);
    else if (params=="anticlockwise")
        context.pass.setCullingMode(CullingMode.CULL_ANTICLOCKWISE);
    else if (params=="clockwise")
        context.pass.setCullingMode(CullingMode.CULL_CLOCKWISE);
    else
        logParseError(
            "Bad cull_hardware attribute, valid parameters are "
            "'none', 'clockwise' or 'anticlockwise'.", context);
    return false;
}
//-----------------------------------------------------------------------
bool parseCullSoftware(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    if (params=="none")
        context.pass.setManualCullingMode(ManualCullingMode.MANUAL_CULL_NONE);
    else if (params=="back")
        context.pass.setManualCullingMode(ManualCullingMode.MANUAL_CULL_BACK);
    else if (params=="front")
        context.pass.setManualCullingMode(ManualCullingMode.MANUAL_CULL_FRONT);
    else
        logParseError(
            "Bad cull_software attribute, valid parameters are 'none', "
            "'front' or 'back'.", context);
    return false;
}
//-----------------------------------------------------------------------
bool parseLighting(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    if (params=="on")
        context.pass.setLightingEnabled(true);
    else if (params=="off")
        context.pass.setLightingEnabled(false);
    else
        logParseError(
            "Bad lighting attribute, valid parameters are 'on' or 'off'.", context);
    return false;
}
//-----------------------------------------------------------------------
bool parseMaxLights(string params, ref MaterialScriptContext context)
{
    context.pass.setMaxSimultaneousLights(to!short(params));
    return false;
}
//-----------------------------------------------------------------------
bool parseStartLight(string params, ref MaterialScriptContext context)
{
    context.pass.setStartLight(to!short(params));
    return false;
}
//-----------------------------------------------------------------------
void parseIterationLightTypes(string params, ref MaterialScriptContext context)
{
    // Parse light type
    if (params == "directional")
    {
        context.pass.setIteratePerLight(true, true, Light.LightTypes.LT_DIRECTIONAL);
    }
    else if (params == "point")
    {
        context.pass.setIteratePerLight(true, true, Light.LightTypes.LT_POINT);
    }
    else if (params == "spot")
    {
        context.pass.setIteratePerLight(true, true, Light.LightTypes.LT_SPOTLIGHT);
    }
    else
    {
        logParseError("Bad iteration attribute, valid values for light type parameter "
                      "are 'point' or 'directional' or 'spot'.", context);
    }

}
//-----------------------------------------------------------------------
bool parseIteration(string params, ref MaterialScriptContext context)
{
    // we could have more than one parameter
    /** combinations could be:
     iteration once
     iteration once_per_light [light type]
     iteration <number>
     iteration <number> [per_light] [light type]
     iteration <number> [per_n_lights] <num_lights> [light type]
     */
    params = params.toLower();
    string[] vecparams = StringUtil.split(params, " \t");
    if (vecparams.length < 1 || vecparams.length > 4)
    {
        logParseError("Bad iteration attribute, expected 1 to 3 parameters.", context);
        return false;
    }

    if (vecparams[0]=="once")
        context.pass.setIteratePerLight(false, false);
    else if (vecparams[0]=="once_per_light")
    {
        if (vecparams.length == 2)
        {
            parseIterationLightTypes(vecparams[1], context);
        }
        else
        {
            context.pass.setIteratePerLight(true, false);
        }

    }
    else // could be using form: <number> [per_light] [light type]
    {
        int passIterationCount = to!int(vecparams[0]);
        if (passIterationCount > 0)
        {
            context.pass.setPassIterationCount(passIterationCount);
            if (vecparams.length > 1)
            {
                if (vecparams[1] == "per_light")
                {
                    if (vecparams.length == 3)
                    {
                        parseIterationLightTypes(vecparams[2], context);
                    }
                    else
                    {
                        context.pass.setIteratePerLight(true, false);
                    }
                }
                else if (vecparams[1] == "per_n_lights")
                {
                    if (vecparams.length < 3)
                    {
                        logParseError(
                            "Bad iteration attribute, expected number of lights.",
                            context);
                    }
                    else
                    {
                        // Parse num lights
                        context.pass.setLightCountPerIteration(
                            to!short(vecparams[2]));
                        // Light type
                        if (vecparams.length == 4)
                        {
                            parseIterationLightTypes(vecparams[3], context);
                        }
                        else
                        {
                            context.pass.setIteratePerLight(true, false);
                        }
                    }
                }
                else
                    logParseError(
                        "Bad iteration attribute, valid parameters are <number> [per_light|per_n_lights <num_lights>] [light type].", context);
            }
        }
        else
            logParseError(
                "Bad iteration attribute, valid parameters are 'once' or 'once_per_light' or <number> [per_light|per_n_lights <num_lights>] [light type].", context);
    }
    return false;
}
//-----------------------------------------------------------------------
bool parsePointSize(string params, ref MaterialScriptContext context)
{
    context.pass.setPointSize(to!Real(params));
    return false;
}
//-----------------------------------------------------------------------
bool parsePointSprites(string params, ref MaterialScriptContext context)
{
    if (params=="on")
        context.pass.setPointSpritesEnabled(true);
    else if (params=="off")
        context.pass.setPointSpritesEnabled(false);
    else
        logParseError(
            "Bad point_sprites attribute, valid parameters are 'on' or 'off'.", context);

    return false;
}
//-----------------------------------------------------------------------
bool parsePointAttenuation(string params, ref MaterialScriptContext context)
{
    string[] vecparams = StringUtil.split(params, " \t");
    if (vecparams.length != 1 && vecparams.length != 4)
    {
        logParseError("Bad point_size_attenuation attribute, 1 or 4 parameters expected", context);
        return false;
    }
    if (vecparams[0] == "off")
    {
        context.pass.setPointAttenuation(false);
    }
    else if (vecparams[0] == "on")
    {
        if (vecparams.length == 4)
        {
            context.pass.setPointAttenuation(true,
                                             to!Real(vecparams[1]),
                                             to!Real(vecparams[2]),
                                             to!Real(vecparams[3]));
        }
        else
        {
            context.pass.setPointAttenuation(true);
        }
    }

    return false;
}
//-----------------------------------------------------------------------
bool parsePointSizeMin(string params, ref MaterialScriptContext context)
{
    context.pass.setPointMinSize(
        to!Real(params));
    return false;
}
//-----------------------------------------------------------------------
bool parsePointSizeMax(string params, ref MaterialScriptContext context)
{
    context.pass.setPointMaxSize(
        to!Real(params));
    return false;
}
//-----------------------------------------------------------------------
bool parseFogging(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    string[] vecparams = StringUtil.split(params, " \t");
    if (vecparams[0]=="true")
    {
        // if true, we need to see if they supplied all arguments, or just the 1... if just the one,
        // Assume they want to disable the default fog from effecting this material.
        if( vecparams.length == 8 )
        {
            FogMode mFogtype;
            if( vecparams[1] == "none" )
                mFogtype = FogMode.FOG_NONE;
            else if( vecparams[1] == "linear" )
                mFogtype = FogMode.FOG_LINEAR;
            else if( vecparams[1] == "exp" )
                mFogtype = FogMode.FOG_EXP;
            else if( vecparams[1] == "exp2" )
                mFogtype = FogMode.FOG_EXP2;
            else
            {
                logParseError(
                    "Bad fogging attribute, valid parameters are "
                    "'none', 'linear', 'exp', or 'exp2'.", context);
                return false;
            }

            context.pass.setFog(
                true,
                mFogtype,
                ColourValue(
                to!Real(vecparams[2]),
                to!Real(vecparams[3]),
                to!Real(vecparams[4])),
                to!Real(vecparams[5]),
                to!Real(vecparams[6]),
                to!Real(vecparams[7])
                );
        }
        else
        {
            context.pass.setFog(true);
        }
    }
    else if (vecparams[0]=="false")
        context.pass.setFog(false);
    else
        logParseError(
            "Bad fog_override attribute, valid parameters are 'true' or 'false'.",
            context);

    return false;
}
//-----------------------------------------------------------------------
bool parseShading(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    if (params=="flat")
        context.pass.setShadingMode(ShadeOptions.SO_FLAT);
    else if (params=="gouraud")
        context.pass.setShadingMode(ShadeOptions.SO_GOURAUD);
    else if (params=="phong")
        context.pass.setShadingMode(ShadeOptions.SO_PHONG);
    else
        logParseError("Bad shading attribute, valid parameters are 'flat', "
                      "'gouraud' or 'phong'.", context);

    return false;
}
//-----------------------------------------------------------------------
bool parsePolygonMode(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    if (params=="solid")
        context.pass.setPolygonMode(PolygonMode.PM_SOLID);
    else if (params=="wireframe")
        context.pass.setPolygonMode(PolygonMode.PM_WIREFRAME);
    else if (params=="points")
        context.pass.setPolygonMode(PolygonMode.PM_POINTS);
    else
        logParseError("Bad polygon_mode attribute, valid parameters are 'solid', "
                      "'wireframe' or 'points'.", context);

    return false;
}
//-----------------------------------------------------------------------
bool parsePolygonModeOverrideable(string params, ref MaterialScriptContext context)
{
    params = params.toLower();

    context.pass.setPolygonModeOverrideable(to!bool(params));//FIXME Ogre uses yes/no/on/off as booleans too
    return false;
}
//-----------------------------------------------------------------------
bool parseFiltering(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    string[] vecparams = StringUtil.split(params, " \t");
    // Must be 1 or 3 parameters
    if (vecparams.length == 1)
    {
        // Simple format
        if (vecparams[0]=="none")
            context.textureUnit.setTextureFiltering(TextureFilterOptions.TFO_NONE);
        else if (vecparams[0]=="bilinear")
            context.textureUnit.setTextureFiltering(TextureFilterOptions.TFO_BILINEAR);
        else if (vecparams[0]=="trilinear")
            context.textureUnit.setTextureFiltering(TextureFilterOptions.TFO_TRILINEAR);
        else if (vecparams[0]=="anisotropic")
            context.textureUnit.setTextureFiltering(TextureFilterOptions.TFO_ANISOTROPIC);
        else
        {
            logParseError("Bad filtering attribute, valid parameters for simple format are "
                          "'none', 'bilinear', 'trilinear' or 'anisotropic'.", context);
            return false;
        }
    }
    else if (vecparams.length == 3)
    {
        // Complex format
        context.textureUnit.setTextureFiltering(
            convertFiltering(vecparams[0]),
            convertFiltering(vecparams[1]),
            convertFiltering(vecparams[2]));

        
    }
    else
    {
        logParseError(
            "Bad filtering attribute, wrong number of parameters (expected 1, 3 or 4)",
            context);
    }

    return false;
}
//-----------------------------------------------------------------------
bool parseCompareTest(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    try
    {
        if(params == "on")
        {
            context.textureUnit.setTextureCompareEnabled(true);
        }
        else if(params == "off")
        {
            context.textureUnit.setTextureCompareEnabled(false);
        }
        else
        {
            throw new InvalidParamsError("Invalid compare setting", "parseCompareEnabled");
        }
    }
    catch (Exception)
    {
        logParseError("Bad compare_test attribute, invalid function parameter.", context);
    }

    return false;
}
//-----------------------------------------------------------------------
bool parseCompareFunction(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    try {
        CompareFunction func = convertCompareFunction(params);
        context.textureUnit.setTextureCompareFunction(func);
    }
    catch (Exception)
    {
        logParseError("Bad compare_func attribute, invalid function parameter.", context);
    }

    return false;
}
//-----------------------------------------------------------------------
// Texture layer attributes
bool parseTexture(string params, ref MaterialScriptContext context)
{
    string[] vecparams = StringUtil.split(params, " \t");
    size_t numParams = vecparams.length;
    if (numParams > 5)
    {
        logParseError("Invalid texture attribute - expected only up to 5 parameters.",
                      context);
    }
    TextureType tt = TextureType.TEX_TYPE_2D;
    int mipmaps = TextureMipmap.MIP_DEFAULT; // When passed to TextureManager::load, this means default to default number of mipmaps
    bool isAlpha = false;
    bool hwGamma = false;
    PixelFormat desiredFormat = PixelFormat.PF_UNKNOWN;
    for (size_t p = 1; p < numParams; ++p)
    {
        vecparams[p] = vecparams[p].toLower();
        if (vecparams[p] == "1d")
        {
            tt = TextureType.TEX_TYPE_1D;
        }
        else if (vecparams[p] == "2d")
        {
            tt = TextureType.TEX_TYPE_2D;
        }
        else if (vecparams[p] == "3d")
        {
            tt = TextureType.TEX_TYPE_3D;
        }
        else if (vecparams[p] == "cubic")
        {
            tt = TextureType.TEX_TYPE_CUBE_MAP;
        }
        else if (vecparams[p] == "unlimited")
        {
            mipmaps = TextureMipmap.MIP_UNLIMITED;
        }
        else if (isDigits(vecparams[p]))
        {
            mipmaps = to!int(vecparams[p]);
        }
        else if (vecparams[p] == "alpha")
        {
            isAlpha = true;
        }
        else if (vecparams[p] == "gamma")
        {
            hwGamma = true;
        }
        else if ((desiredFormat = PixelUtil.getFormatFromName(vecparams[p], true)) != PixelFormat.PF_UNKNOWN)
        {
            // nothing to do here
        }
        else
        {
            logParseError("Invalid texture option - " ~ vecparams[p] ~ ".",
                          context);
        }
    }

    context.textureUnit.setTextureName(vecparams[0], tt);
    context.textureUnit.setNumMipmaps(mipmaps);
    context.textureUnit.setIsAlpha(isAlpha);
    context.textureUnit.setDesiredFormat(desiredFormat);
    context.textureUnit.setHardwareGammaEnabled(hwGamma);
    return false;
}
//---------------------------------------------------------------------
bool parseBindingType(string params, ref MaterialScriptContext context)
{
    if (params == "fragment")
    {
        context.textureUnit.setBindingType(TextureUnitState.BindingType.BT_FRAGMENT);
    }
    else if (params == "vertex")
    {
        context.textureUnit.setBindingType(TextureUnitState.BindingType.BT_VERTEX);
    }
    else if (params == "geometry")
    {
        context.textureUnit.setBindingType(TextureUnitState.BindingType.BT_GEOMETRY);
    }
    else if (params == "tesselation_hull")
    {
        context.textureUnit.setBindingType(TextureUnitState.BindingType.BT_TESSELATION_HULL);
    }
    else if (params == "tesselation_domain")
    {
        context.textureUnit.setBindingType(TextureUnitState.BindingType.BT_TESSELATION_DOMAIN);
    }
    else if (params == "compute")
    {
        context.textureUnit.setBindingType(TextureUnitState.BindingType.BT_COMPUTE);
    }
    else
    {
        logParseError("Invalid binding_type option - "~params~".",
                      context);
    }
    return false;
}
//-----------------------------------------------------------------------
bool parseAnimTexture(string params, ref MaterialScriptContext context)
{
    string[] vecparams = StringUtil.split(params, " \t");
    size_t numParams = vecparams.length;
    // Determine which form it is
    // Must have at least 3 params though
    if (numParams < 3)
    {
        logParseError("Bad anim_texture attribute, wrong number of parameters "
                      "(expected at least 3)", context);
        return false;
    }
    if (numParams == 3 && to!int(vecparams[1]) != 0 )
    {
        // First form using base name & number of frames
        context.textureUnit.setAnimatedTextureName(
            vecparams[0],
            to!int(vecparams[1]),
            to!Real(vecparams[2]));
    }
    else
    {
        // Second form using individual names
        context.textureUnit.setAnimatedTextureName(
            vecparams,
            cast(uint)(numParams-1),
            to!Real(vecparams[numParams-1]));
    }
    return false;

}
//-----------------------------------------------------------------------
bool parseCubicTexture(string params, ref MaterialScriptContext context)
{

    string[] vecparams = StringUtil.split(params, " \t");
    size_t numParams = vecparams.length;

    // Get final param
    bool useUVW;
    string uvOpt = vecparams[numParams-1];
    uvOpt = uvOpt.toLower();
    if (uvOpt == "combineduvw")
        useUVW = true;
    else if (uvOpt == "separateuv")
        useUVW = false;
    else
    {
        logParseError("Bad cubic_texture attribute, final parameter must be "
                      "'combinedUVW' or 'separateUV'.", context);
        return false;
    }
    // Determine which form it is
    if (numParams == 2)
    {
        // First form using base name
        context.textureUnit.setCubicTextureName(vecparams[0], useUVW);
    }
    else if (numParams == 7)
    {
        // Second form using individual names
        // Can use vecparams[0] as array start point
        context.textureUnit.setCubicTextureName(vecparams, useUVW);
    }
    else
    {
        logParseError(
            "Bad cubic_texture attribute, wrong number of parameters (expected 2 or 7)",
            context);
        return false;
    }

    return false;
}
//-----------------------------------------------------------------------
bool parseTexCoord(string params, ref MaterialScriptContext context)
{
    context.textureUnit.setTextureCoordSet(to!int(params));

    return false;
}
//-----------------------------------------------------------------------
TextureUnitState.TextureAddressingMode convTexAddressMode(string params, ref MaterialScriptContext context)
{
    if (params=="wrap")
        return TextureUnitState.TAM_WRAP;
    else if (params=="mirror")
        return TextureUnitState.TAM_MIRROR;
    else if (params=="clamp")
        return TextureUnitState.TAM_CLAMP;
    else if (params=="border")
        return TextureUnitState.TAM_BORDER;
    else
        logParseError("Bad tex_address_mode attribute, valid parameters are "
                      "'wrap', 'mirror', 'clamp' or 'border'.", context);
    // default
    return TextureUnitState.TAM_WRAP;
}
//-----------------------------------------------------------------------
bool parseTexAddressMode(string params, ref MaterialScriptContext context)
{
    params = params.toLower();

    string[] vecparams = StringUtil.split(params, " \t");
    size_t numParams = vecparams.length;

    if (numParams > 3 || numParams < 1)
    {
        logParseError("Invalid number of parameters to tex_address_mode"
                      " - must be between 1 and 3", context);
    }
    if (numParams == 1)
    {
        // Single-parameter option
        context.textureUnit.setTextureAddressingMode(
            convTexAddressMode(vecparams[0], context));
    }
    else
    {
        // 2-3 parameter option
        TextureUnitState.UVWAddressingMode uvw;
        uvw.u = convTexAddressMode(vecparams[0], context);
        uvw.v = convTexAddressMode(vecparams[1], context);
        if (numParams == 3)
        {
            // w
            uvw.w = convTexAddressMode(vecparams[2], context);
        }
        else
        {
            uvw.w = TextureUnitState.TAM_WRAP;
        }
        context.textureUnit.setTextureAddressingMode(uvw);
    }
    return false;
}
//-----------------------------------------------------------------------
bool parseTexBorderColour(string params, ref MaterialScriptContext context)
{
    string[] vecparams = StringUtil.split(params, " \t");
    // Must be 3 or 4 parameters
    if (vecparams.length == 3 || vecparams.length == 4)
    {
        context.textureUnit.setTextureBorderColour( _parseColourValue(vecparams) );
    }
    else
    {
        logParseError(
            "Bad tex_border_colour attribute, wrong number of parameters (expected 3 or 4)",
            context);
    }
    return false;
}
//-----------------------------------------------------------------------
bool parseColourOp(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    if (params=="replace")
        context.textureUnit.setColourOperation(LayerBlendOperation.LBO_REPLACE);
    else if (params=="add")
        context.textureUnit.setColourOperation(LayerBlendOperation.LBO_ADD);
    else if (params=="modulate")
        context.textureUnit.setColourOperation(LayerBlendOperation.LBO_MODULATE);
    else if (params=="alpha_blend")
        context.textureUnit.setColourOperation(LayerBlendOperation.LBO_ALPHA_BLEND);
    else
        logParseError("Bad colour_op attribute, valid parameters are "
                      "'replace', 'add', 'modulate' or 'alpha_blend'.", context);

    return false;
}
//-----------------------------------------------------------------------
bool parseAlphaRejection(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    string[] vecparams = StringUtil.split(params, " \t");
    if (vecparams.length != 2)
    {
        logParseError(
            "Bad alpha_rejection attribute, wrong number of parameters (expected 2)",
            context);
        return false;
    }

    CompareFunction cmp;
    try {
        cmp = convertCompareFunction(vecparams[0]);
    }
    catch (Exception)
    {
        logParseError("Bad alpha_rejection attribute, invalid compare function.", context);
        return false;
    }

    context.pass.setAlphaRejectSettings(cmp, to!ubyte(vecparams[1]));

    return false;
}
//---------------------------------------------------------------------
bool parseAlphaToCoverage(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    if (params == "on")
        context.pass.setAlphaToCoverageEnabled(true);
    else if (params == "off")
        context.pass.setAlphaToCoverageEnabled(false);
    else
        logParseError(
            "Bad alpha_to_coverage attribute, valid parameters are 'on' or 'off'.",
            context);

    return false;
}
//-----------------------------------------------------------------------
bool parseTransparentSorting(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    if (params == "on")
        context.pass.setTransparentSortingEnabled(true);
    else if (params == "off")
        context.pass.setTransparentSortingEnabled(false);
    else if (params == "force")
        context.pass.setTransparentSortingForced(true);
    else
        logParseError(
            "Bad transparent_sorting attribute, valid parameters are 'on' or 'off'.",
            context);

    return false;
}
//-----------------------------------------------------------------------
LayerBlendOperationEx convertBlendOpEx(string param)
{
    if (param == "source1")
        return LayerBlendOperationEx.LBX_SOURCE1;
    else if (param == "source2")
        return LayerBlendOperationEx.LBX_SOURCE2;
    else if (param == "modulate")
        return LayerBlendOperationEx.LBX_MODULATE;
    else if (param == "modulate_x2")
        return LayerBlendOperationEx.LBX_MODULATE_X2;
    else if (param == "modulate_x4")
        return LayerBlendOperationEx.LBX_MODULATE_X4;
    else if (param == "add")
        return LayerBlendOperationEx.LBX_ADD;
    else if (param == "add_signed")
        return LayerBlendOperationEx.LBX_ADD_SIGNED;
    else if (param == "add_smooth")
        return LayerBlendOperationEx.LBX_ADD_SMOOTH;
    else if (param == "subtract")
        return LayerBlendOperationEx.LBX_SUBTRACT;
    else if (param == "blend_diffuse_colour")
        return LayerBlendOperationEx.LBX_BLEND_DIFFUSE_COLOUR;
    else if (param == "blend_diffuse_alpha")
        return LayerBlendOperationEx.LBX_BLEND_DIFFUSE_ALPHA;
    else if (param == "blend_texture_alpha")
        return LayerBlendOperationEx.LBX_BLEND_TEXTURE_ALPHA;
    else if (param == "blend_current_alpha")
        return LayerBlendOperationEx.LBX_BLEND_CURRENT_ALPHA;
    else if (param == "blend_manual")
        return LayerBlendOperationEx.LBX_BLEND_MANUAL;
    else if (param == "dotproduct")
        return LayerBlendOperationEx.LBX_DOTPRODUCT;
    else
        throw new InvalidParamsError("Invalid blend function", "convertBlendOpEx");
}
//-----------------------------------------------------------------------
LayerBlendSource convertBlendSource(string param)
{
    if (param == "src_current")
        return LayerBlendSource.LBS_CURRENT;
    else if (param == "src_texture")
        return LayerBlendSource.LBS_TEXTURE;
    else if (param == "src_diffuse")
        return LayerBlendSource.LBS_DIFFUSE;
    else if (param == "src_specular")
        return LayerBlendSource.LBS_SPECULAR;
    else if (param == "src_manual")
        return LayerBlendSource.LBS_MANUAL;
    else
        throw new InvalidParamsError("Invalid blend source", "convertBlendSource");
}
//-----------------------------------------------------------------------
bool parseColourOpEx(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    string[] vecparams = StringUtil.split(params, " \t");
    size_t numParams = vecparams.length;

    if (numParams < 3 || numParams > 10)
    {
        logParseError(
            "Bad colour_op_ex attribute, wrong number of parameters (expected 3 to 10)",
            context);
        return false;
    }
    LayerBlendOperationEx op;
    LayerBlendSource src1, src2;
    Real manual = 0.0;
    ColourValue colSrc1 = ColourValue.White;
    ColourValue colSrc2 = ColourValue.White;

    try {
        op = convertBlendOpEx(vecparams[0]);
        src1 = convertBlendSource(vecparams[1]);
        src2 = convertBlendSource(vecparams[2]);

        if (op == LayerBlendOperationEx.LBX_BLEND_MANUAL)
        {
            if (numParams < 4)
            {
                logParseError("Bad colour_op_ex attribute, wrong number of parameters "
                              "(expected 4 for manual blend)", context);
                return false;
            }
            manual = to!Real(vecparams[3]);
        }

        if (src1 == LayerBlendSource.LBS_MANUAL)
        {
            uint parIndex = 3;
            if (op == LayerBlendOperationEx.LBX_BLEND_MANUAL)
                parIndex++;

            if (numParams < parIndex + 3)
            {
                logParseError("Bad colour_op_ex attribute, wrong number of parameters "
                              "(expected " ~ to!string(parIndex + 3) ~ ")", context);
                return false;
            }

            colSrc1.r = to!Real(vecparams[parIndex++]);
            colSrc1.g = to!Real(vecparams[parIndex++]);
            colSrc1.b = to!Real(vecparams[parIndex++]);
            if (numParams > parIndex)
            {
                colSrc1.a = to!Real(vecparams[parIndex]);
            }
            else
            {
                colSrc1.a = 1.0f;
            }
        }

        if (src2 == LayerBlendSource.LBS_MANUAL)
        {
            uint parIndex = 3;
            if (op == LayerBlendOperationEx.LBX_BLEND_MANUAL)
                parIndex++;
            if (src1 == LayerBlendSource.LBS_MANUAL)
                parIndex += 3;

            if (numParams < parIndex + 3)
            {
                logParseError("Bad colour_op_ex attribute, wrong number of parameters "
                              "(expected " ~ to!string(parIndex + 3) ~ ")", context);
                return false;
            }

            colSrc2.r = to!Real(vecparams[parIndex++]);
            colSrc2.g = to!Real(vecparams[parIndex++]);
            colSrc2.b = to!Real(vecparams[parIndex++]);
            if (numParams > parIndex)
            {
                colSrc2.a = to!Real(vecparams[parIndex]);
            }
            else
            {
                colSrc2.a = 1.0f;
            }
        }
    }
    catch (Exception e)
    {
        logParseError("Bad colour_op_ex attribute, " ~ e.msg, context);
        return false;
    }

    context.textureUnit.setColourOperationEx(op, src1, src2, colSrc1, colSrc2, manual);
    return false;
}
//-----------------------------------------------------------------------
bool parseColourOpFallback(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    string[] vecparams = StringUtil.split(params, " \t");
    if (vecparams.length != 2)
    {
        logParseError("Bad colour_op_multipass_fallback attribute, wrong number "
                      "of parameters (expected 2)", context);
        return false;
    }

    //src/dest
    SceneBlendFactor src, dest;

    try {
        src = convertBlendFactor(vecparams[0]);
        dest = convertBlendFactor(vecparams[1]);
        context.textureUnit.setColourOpMultipassFallback(src,dest);
    }
    catch (Exception e)
    {
        logParseError("Bad colour_op_multipass_fallback attribute, "
                      ~ e.msg, context);
    }
    return false;
}
//-----------------------------------------------------------------------
bool parseAlphaOpEx(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    string[] vecparams = StringUtil.split(params, " \t");
    size_t numParams = vecparams.length;
    if (numParams < 3 || numParams > 6)
    {
        logParseError("Bad alpha_op_ex attribute, wrong number of parameters "
                      "(expected 3 to 6)", context);
        return false;
    }
    LayerBlendOperationEx op;
    LayerBlendSource src1, src2;
    Real manual = 0.0;
    Real arg1 = 1.0, arg2 = 1.0;

    try {
        op = convertBlendOpEx(vecparams[0]);
        src1 = convertBlendSource(vecparams[1]);
        src2 = convertBlendSource(vecparams[2]);
        if (op == LayerBlendOperationEx.LBX_BLEND_MANUAL)
        {
            if (numParams != 4)
            {
                logParseError("Bad alpha_op_ex attribute, wrong number of parameters "
                              "(expected 4 for manual blend)", context);
                return false;
            }
            manual = to!Real(vecparams[3]);
        }
        if (src1 == LayerBlendSource.LBS_MANUAL)
        {
            uint parIndex = 3;
            if (op == LayerBlendOperationEx.LBX_BLEND_MANUAL)
                parIndex++;

            if (numParams < parIndex)
            {
                logParseError(
                    "Bad alpha_op_ex attribute, wrong number of parameters (expected " ~
                    to!string(parIndex - 1) ~ ")", context);
                return false;
            }

            arg1 = to!Real(vecparams[parIndex]);
        }

        if (src2 == LayerBlendSource.LBS_MANUAL)
        {
            uint parIndex = 3;
            if (op == LayerBlendOperationEx.LBX_BLEND_MANUAL)
                parIndex++;
            if (src1 == LayerBlendSource.LBS_MANUAL)
                parIndex++;

            if (numParams < parIndex)
            {
                logParseError(
                    "Bad alpha_op_ex attribute, wrong number of parameters "
                    "(expected " ~ to!string(parIndex - 1) ~ ")", context);
                return false;
            }

            arg2 = to!Real(vecparams[parIndex]);
        }
    }
    catch (Exception e)
    {
        logParseError("Bad alpha_op_ex attribute, " ~ e.msg, context);
        return false;
    }

    context.textureUnit.setAlphaOperation(op, src1, src2, arg1, arg2, manual);
    return false;
}
//-----------------------------------------------------------------------
bool parseEnvMap(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    if (params=="off")
        context.textureUnit.setEnvironmentMap(false);
    else if (params=="spherical")
        context.textureUnit.setEnvironmentMap(true, TextureUnitState.EnvMapType.ENV_CURVED);
    else if (params=="planar")
        context.textureUnit.setEnvironmentMap(true, TextureUnitState.EnvMapType.ENV_PLANAR);
    else if (params=="cubic_reflection")
        context.textureUnit.setEnvironmentMap(true, TextureUnitState.EnvMapType.ENV_REFLECTION);
    else if (params=="cubic_normal")
        context.textureUnit.setEnvironmentMap(true, TextureUnitState.EnvMapType.ENV_NORMAL);
    else
        logParseError("Bad env_map attribute, valid parameters are 'off', "
                      "'spherical', 'planar', 'cubic_reflection' and 'cubic_normal'.", context);

    return false;
}
//-----------------------------------------------------------------------
bool parseScroll(string params, ref MaterialScriptContext context)
{
    string[] vecparams = StringUtil.split(params, " \t");
    if (vecparams.length != 2)
    {
        logParseError("Bad scroll attribute, wrong number of parameters (expected 2)", context);
        return false;
    }
    context.textureUnit.setTextureScroll(
        to!Real(vecparams[0]),
        to!Real(vecparams[1]));

    
    return false;
}
//-----------------------------------------------------------------------
bool parseScrollAnim(string params, ref MaterialScriptContext context)
{
    string[] vecparams = StringUtil.split(params, " \t");
    if (vecparams.length != 2)
    {
        logParseError("Bad scroll_anim attribute, wrong number of "
                      "parameters (expected 2)", context);
        return false;
    }
    context.textureUnit.setScrollAnimation(
        to!Real(vecparams[0]),
        to!Real(vecparams[1]));

    return false;
}
//-----------------------------------------------------------------------
bool parseRotate(string params, ref MaterialScriptContext context)
{
    context.textureUnit.setTextureRotate(
        StringConverter.parseAngle(params,Radian(0)));

    return false;
}
//-----------------------------------------------------------------------
bool parseRotateAnim(string params, ref MaterialScriptContext context)
{
    context.textureUnit.setRotateAnimation(
        to!Real(params));

    return false;
}
//-----------------------------------------------------------------------
bool parseScale(string params, ref MaterialScriptContext context)
{
    string[] vecparams = StringUtil.split(params, " \t");
    if (vecparams.length != 2)
    {
        std.stdio.writeln(params);
        std.stdio.writeln(vecparams);
        logParseError("Bad scale attribute, wrong number of parameters (expected 2)", context);
        return false;
    }
    context.textureUnit.setTextureScale(
        to!Real(vecparams[0]),
        to!Real(vecparams[1]));

    return false;
}
//-----------------------------------------------------------------------
bool parseWaveXform(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    string[] vecparams = StringUtil.split(params, " \t");

    if (vecparams.length != 6)
    {
        logParseError("Bad wave_xform attribute, wrong number of parameters "
                      "(expected 6)", context);
        return false;
    }
    TextureUnitState.TextureTransformType ttype;
    WaveformType waveType;
    // Check transform type
    if (vecparams[0]=="scroll_x")
        ttype = TextureUnitState.TextureTransformType.TT_TRANSLATE_U;
    else if (vecparams[0]=="scroll_y")
        ttype = TextureUnitState.TextureTransformType.TT_TRANSLATE_V;
    else if (vecparams[0]=="rotate")
        ttype = TextureUnitState.TextureTransformType.TT_ROTATE;
    else if (vecparams[0]=="scale_x")
        ttype = TextureUnitState.TextureTransformType.TT_SCALE_U;
    else if (vecparams[0]=="scale_y")
        ttype = TextureUnitState.TextureTransformType.TT_SCALE_V;
    else
    {
        logParseError("Bad wave_xform attribute, parameter 1 must be 'scroll_x', "
                      "'scroll_y', 'rotate', 'scale_x' or 'scale_y'", context);
        return false;
    }
    // Check wave type
    if (vecparams[1]=="sine")
        waveType = WaveformType.WFT_SINE;
    else if (vecparams[1]=="triangle")
        waveType = WaveformType.WFT_TRIANGLE;
    else if (vecparams[1]=="square")
        waveType = WaveformType.WFT_SQUARE;
    else if (vecparams[1]=="sawtooth")
        waveType = WaveformType.WFT_SAWTOOTH;
    else if (vecparams[1]=="inverse_sawtooth")
        waveType = WaveformType.WFT_INVERSE_SAWTOOTH;
    else
    {
        logParseError("Bad wave_xform attribute, parameter 2 must be 'sine', "
                      "'triangle', 'square', 'sawtooth' or 'inverse_sawtooth'", context);
        return false;
    }

    context.textureUnit.setTransformAnimation(
        ttype,
        waveType,
        to!Real(vecparams[2]),
        to!Real(vecparams[3]),
        to!Real(vecparams[4]),
        to!Real(vecparams[5]) );

    return false;
}
//-----------------------------------------------------------------------
bool parseTransform(string params, ref MaterialScriptContext context)
{
    string[] vecparams = StringUtil.split(params, " \t");
    if (vecparams.length != 16)
    {
        logParseError("Bad transform attribute, wrong number of parameters (expected 16)", context);
        return false;
    }
    Matrix4 xform = Matrix4(
        to!Real(vecparams[0]),
        to!Real(vecparams[1]),
        to!Real(vecparams[2]),
        to!Real(vecparams[3]),
        to!Real(vecparams[4]),
        to!Real(vecparams[5]),
        to!Real(vecparams[6]),
        to!Real(vecparams[7]),
        to!Real(vecparams[8]),
        to!Real(vecparams[9]),
        to!Real(vecparams[10]),
        to!Real(vecparams[11]),
        to!Real(vecparams[12]),
        to!Real(vecparams[13]),
        to!Real(vecparams[14]),
        to!Real(vecparams[15]) );
    context.textureUnit.setTextureTransform(xform);

    
    return false;
}
//-----------------------------------------------------------------------
bool parseDepthBias(string params, ref MaterialScriptContext context)
{
    string[] vecparams = StringUtil.split(params, " \t");

    float constantBias = to!float(vecparams[0]);
    float slopeScaleBias = 0.0f;
    if (vecparams.length > 1)
    {
        slopeScaleBias = to!float(vecparams[1]);
    }
    context.pass.setDepthBias(constantBias, slopeScaleBias);

    return false;
}
//-----------------------------------------------------------------------
bool parseIterationDepthBias(string params, ref MaterialScriptContext context)
{
    string[] vecparams = StringUtil.split(params, " \t");

    float bias = to!float(vecparams[0]);
    context.pass.setIterationDepthBias(bias);

    return false;
}
//-----------------------------------------------------------------------
bool parseAnisotropy(string params, ref MaterialScriptContext context)
{
    context.textureUnit.setTextureAnisotropy(to!int(params));

    return false;
}
//-----------------------------------------------------------------------
bool parseTextureAlias(string params, ref MaterialScriptContext context)
{
    context.textureUnit.setTextureNameAlias(params);

    return false;
}
//-----------------------------------------------------------------------
bool parseMipmapBias(string params, ref MaterialScriptContext context)
{
    context.textureUnit.setTextureMipmapBias(to!float(params));

    return false;
}
//-----------------------------------------------------------------------
bool parseContentType(string params, ref MaterialScriptContext context)
{
    string[] vecparams = StringUtil.split(params, " \t");//FIXME StringUtil::tokenise
    if (vecparams.empty())
    {
        logParseError("No content_type specified", context);
        return false;
    }
    string paramType = vecparams[0];
    if (paramType == "named")
    {
        context.textureUnit.setContentType(TextureUnitState.ContentType.CONTENT_NAMED);
    }
    else if (paramType == "shadow")
    {
        context.textureUnit.setContentType(TextureUnitState.ContentType.CONTENT_SHADOW);
    }
    else if (paramType == "compositor")
    {
        context.textureUnit.setContentType(TextureUnitState.ContentType.CONTENT_COMPOSITOR);
        if (vecparams.length == 3)
        {
            context.textureUnit.setCompositorReference(vecparams[1], vecparams[2]);
        }
        else if (vecparams.length == 4)
        {
            context.textureUnit.setCompositorReference(vecparams[1], vecparams[2],
                                                       to!uint(vecparams[3]));
        }
        else
        {
            logParseError("compositor content_type requires 2 or 3 extra params", context);
        }
    }
    else
    {
        logParseError("Invalid content_type specified : " ~ paramType, context);
    }
    return false;
}
//-----------------------------------------------------------------------
bool parseIlluminationStage(string params, ref MaterialScriptContext context)
{
    if (params == "ambient")
    {
        context.pass.setIlluminationStage(IlluminationStage.IS_AMBIENT);
    }
    else if (params == "per_light")
    {
        context.pass.setIlluminationStage(IlluminationStage.IS_PER_LIGHT);
    }
    else if (params == "decal")
    {
        context.pass.setIlluminationStage(IlluminationStage.IS_DECAL);
    }
    else
    {
        logParseError("Invalid illumination_stage specified.", context);
    }
    return false;
}
//-----------------------------------------------------------------------
bool parseLodValues(string params, ref MaterialScriptContext context)
{
    string[] vecparams = StringUtil.split(params, " \t");

    // iterate over the parameters and parse values out of them
    Material.LodValueList lodList;
    foreach (i; vecparams)
    {
        lodList ~= to!Real(i);
    }

    context.material.setLodLevels(lodList);

    return false;
}
//-----------------------------------------------------------------------
bool parseLodIndex(string params, ref MaterialScriptContext context)
{
    context.technique.setLodIndex(to!short(params));
    return false;
}
//-----------------------------------------------------------------------
bool parseScheme(string params, ref MaterialScriptContext context)
{
    context.technique.setSchemeName(params);
    return false;
}
//-----------------------------------------------------------------------
bool parseGPUVendorRule(string params, ref MaterialScriptContext context)
{
    Technique.GPUVendorRule rule;
    string[] vecparams = StringUtil.split(params, " \t");
    if (vecparams.length != 2)
    {
        logParseError("Wrong number of parameters for gpu_vendor_rule, expected 2", context);
        return false;
    }
    if (vecparams[0] == "include")
    {
        rule.includeOrExclude = Technique.INCLUDE;
    }
    else if (vecparams[0] == "exclude")
    {
        rule.includeOrExclude = Technique.EXCLUDE;
    }
    else
    {
        logParseError("Wrong parameter to gpu_vendor_rule, expected 'include' or 'exclude'", context);
        return false;
    }

    rule.vendor = RenderSystemCapabilities.vendorFromString(vecparams[1]);
    if (rule.vendor == GPUVendor.GPU_UNKNOWN)
    {
        logParseError("Unknown vendor '" ~ vecparams[1] ~ "' ignored in gpu_vendor_rule", context);
        return false;
    }
    context.technique.addGPUVendorRule(rule);
    return false;
}
//-----------------------------------------------------------------------
bool parseGPUDeviceRule(string params, ref MaterialScriptContext context)
{
    Technique.GPUDeviceNameRule rule;
    string[] vecparams = StringUtil.split(params, " \t");
    if (vecparams.length != 2 && vecparams.length != 3)
    {
        logParseError("Wrong number of parameters for gpu_vendor_rule, expected 2 or 3", context);
        return false;
    }
    if (vecparams[0] == "include")
    {
        rule.includeOrExclude = Technique.INCLUDE;
    }
    else if (vecparams[0] == "exclude")
    {
        rule.includeOrExclude = Technique.EXCLUDE;
    }
    else
    {
        logParseError("Wrong parameter to gpu_device_rule, expected 'include' or 'exclude'", context);
        return false;
    }

    rule.devicePattern = vecparams[1];
    if (vecparams.length == 3)
        rule.caseSensitive = to!bool(vecparams[2]);

    context.technique.addGPUDeviceNameRule(rule);
    return false;
}
//-----------------------------------------------------------------------
bool parseShadowCasterMaterial(string params, ref MaterialScriptContext context)
{
    context.technique.setShadowCasterMaterial(params);
    return false;
}
//-----------------------------------------------------------------------
bool parseShadowReceiverMaterial(string params, ref MaterialScriptContext context)
{
    context.technique.setShadowReceiverMaterial(params);
    return false;
}
//-----------------------------------------------------------------------
bool parseSetTextureAlias(string params, ref MaterialScriptContext context)
{
    string[] vecparams = StringUtil.split(params, " \t");
    if (vecparams.length != 2)
    {
        logParseError("Wrong number of parameters for texture_alias, expected 2", context);
        return false;
    }
    // first parameter is alias name and second parameter is texture name
    context.textureAliases[vecparams[0]] = vecparams[1];

    return false;
}

//-----------------------------------------------------------------------
void processManualProgramParam(bool isNamed, string commandname,
                               string[] vecparams, ref MaterialScriptContext context,
                               size_t index = 0, string paramName = null)
{
    // NB we assume that the first element of vecparams is taken up with either
    // the index or the parameter name, which we ignore

    // Determine type
    size_t start, dims, roundedDims, i;
    bool isReal;
    bool isMatrix4x4 = false;

    vecparams[1] = vecparams[1].toLower();

    if (vecparams[1] == "matrix4x4")
    {
        dims = 16;
        isReal = true;
        isMatrix4x4 = true;
    }
    else if ((start = vecparams[1].indexOf("float")) != -1)
    {
        // find the dimensionality
        //start = vecparams[1].find_first_not_of("float");
        start = vecparams[1].length == 5 ? -1 : 5; // Is "floatXXX" or just "float"
        // Assume 1 if not specified
        if (start == -1)
        {
            dims = 1;
        }
        else
        {
            dims = to!int(vecparams[1][start..$]);
        }
        isReal = true;
    }
    else if ((start = vecparams[1].indexOf("double")) != -1)
    {
        // find the dimensionality
        //start = vecparams[1].find_first_not_of("double");
        start = vecparams[1].length == 6 ? -1 : 6; // Is "doubleXXX" or just "double"
        // Assume 1 if not specified
        if (start == -1)
        {
            dims = 1;
        }
        else
        {
            dims = dims = to!int(vecparams[1][start..$]);
        }
        isReal = true;
    }
    
    else if ((start = vecparams[1].indexOf("int")) != -1)
    {
        // find the dimensionality
        //start = vecparams[1].find_first_not_of("int");
        start = vecparams[1].length == 3 ? -1 : 3; //Is "intXX" or just "int"
        // Assume 1 if not specified
        if (start == -1)
        {
            dims = 1;
        }
        else
        {
            dims = to!int(vecparams[1][start..$]);
        }
        isReal = false;
    }
    else
    {
        logParseError("Invalid " ~ commandname ~ " attribute - unrecognised "
                      "parameter type " ~ vecparams[1], context);
        return;
    }

    if (vecparams.length != 2 + dims)
    {
        logParseError("Invalid " ~ commandname ~ " attribute - you need " ~
                      to!string(2 + dims) ~ " parameters for a parameter of "
                      "type " ~ vecparams[1], context);
    }

    // clear any auto parameter bound to this constant, it would override this setting
    // can cause problems overriding materials or changing default params
    if (isNamed)
        context.programParams.clearNamedAutoConstant(paramName);
    else
        context.programParams.clearAutoConstant(index);

    
    // Round dims to multiple of 4
    if (dims %4 != 0)
    {
        roundedDims = dims + 4 - (dims % 4);
    }
    else
    {
        roundedDims = dims;
    }

    // Now parse all the values
    if (isReal)
    {
        Real[] realBuffer = new Real[roundedDims];
        // Do specified values
        for (i = 0; i < dims; ++i)
        {
            realBuffer[i] = to!Real(vecparams[i+2]);
        }
        // Fill up to multiple of 4 with zero
        for (; i < roundedDims; ++i)
        {
            realBuffer[i] = 0.0f;

        }

        if (isMatrix4x4)
        {
            // its a Matrix4x4 so pass as a Matrix4
            // use specialized setConstant that takes a matrix so matrix is transposed if required
            Matrix4 m4x4 = Matrix4(
                realBuffer[0],  realBuffer[1],  realBuffer[2],  realBuffer[3],
                realBuffer[4],  realBuffer[5],  realBuffer[6],  realBuffer[7],
                realBuffer[8],  realBuffer[9],  realBuffer[10], realBuffer[11],
                realBuffer[12], realBuffer[13], realBuffer[14], realBuffer[15]
                );
            if (isNamed)
                context.programParams.setNamedConstant(paramName, m4x4);
            else
                context.programParams.setConstant(index, m4x4);
        }
        else
        {
            // Set
            if (isNamed)
            {
                // For named, only set up to the precise number of elements
                // (no rounding to 4 elements)
                // GLSL can support sub-float4 elements and we support that
                // in the buffer now. Note how we set the 'multiple' param to 1
                context.programParams.setNamedConstant(paramName, realBuffer.ptr,
                                                       dims, 1);
            }
            else
            {
                context.programParams.setConstant(index, realBuffer.ptr,
                                                  cast(size_t)(roundedDims * 0.25));
            }

        }

    }
    else
    {
        int[] intBuffer = new int[roundedDims];
        // Do specified values
        for (i = 0; i < dims; ++i)
        {
            intBuffer[i] = to!int(vecparams[i+2]);
        }
        // Fill to multiple of 4 with 0
        for (; i < roundedDims; ++i)
        {
            intBuffer[i] = 0;
        }
        // Set
        if (isNamed)
        {
            // For named, only set up to the precise number of elements
            // (no rounding to 4 elements)
            // GLSL can support sub-float4 elements and we support that
            // in the buffer now. Note how we set the 'multiple' param to 1
            context.programParams.setNamedConstant(paramName, intBuffer.ptr,
                                                   dims, 1);
        }
        else
        {
            context.programParams.setConstant(index, intBuffer.ptr,
                                              cast(size_t)(roundedDims * 0.25));
        }
    }
}
//-----------------------------------------------------------------------
void processAutoProgramParam(bool isNamed, string commandname,
                             string[] vecparams, ref MaterialScriptContext context,
                             size_t index = 0, string paramName = null)
{
    // NB we assume that the first element of vecparams is taken up with either
    // the index or the parameter name, which we ignore

    // make sure param is in lower case
    vecparams[1] = vecparams[1].toLower();

    // lookup the param to see if its a valid auto constant
    GpuProgramParameters.AutoConstantDefinition* autoConstantDef =
        context.programParams.getAutoConstantDefinition(vecparams[1]);

    // exit with error msg if the auto constant definition wasn't found
    if (autoConstantDef is null)
    {
        logParseError("Invalid " ~ commandname ~ " attribute - "
                      ~ vecparams[1], context);
        return;
    }

    // add AutoConstant based on the type of data it uses
    final switch (autoConstantDef.dataType)
    {
        case GpuProgramParameters.ACDataType.ACDT_NONE:
            if (isNamed)
                context.programParams.setNamedAutoConstant(paramName, autoConstantDef.acType, 0);
            else
                context.programParams.setAutoConstant(index, autoConstantDef.acType, 0);
            break;

        case GpuProgramParameters.ACDataType.ACDT_INT:
        {
            // Special case animation_parametric, we need to keep track of number of times used
            if (autoConstantDef.acType == GpuProgramParameters.AutoConstantType.ACT_ANIMATION_PARAMETRIC)
            {
                if (isNamed)
                    context.programParams.setNamedAutoConstant(
                        paramName, autoConstantDef.acType, context.numAnimationParametrics++);
                else
                    context.programParams.setAutoConstant(
                        index, autoConstantDef.acType, context.numAnimationParametrics++);
            }
            // Special case texture projector - assume 0 if data not specified
            else if ((autoConstantDef.acType == GpuProgramParameters.AutoConstantType.ACT_TEXTURE_VIEWPROJ_MATRIX ||
                      autoConstantDef.acType == GpuProgramParameters.AutoConstantType.ACT_TEXTURE_WORLDVIEWPROJ_MATRIX ||
                      autoConstantDef.acType == GpuProgramParameters.AutoConstantType.ACT_SPOTLIGHT_VIEWPROJ_MATRIX ||
                      autoConstantDef.acType == GpuProgramParameters.AutoConstantType.ACT_SPOTLIGHT_WORLDVIEWPROJ_MATRIX)
                     && vecparams.length == 2)
            {
                if (isNamed)
                    context.programParams.setNamedAutoConstant(
                        paramName, autoConstantDef.acType, 0);
                else
                    context.programParams.setAutoConstant(
                        index, autoConstantDef.acType, 0);

            }
            else
            {

                if (vecparams.length != 3)
                {
                    logParseError("Invalid " ~ commandname ~ " attribute - "
                                  "expected 3 parameters.", context);
                    return;
                }

                size_t extraParam = to!int(vecparams[2]);
                if (isNamed)
                    context.programParams.setNamedAutoConstant(
                        paramName, autoConstantDef.acType, extraParam);
                else
                    context.programParams.setAutoConstant(
                        index, autoConstantDef.acType, extraParam);
            }
        }
            break;

        case GpuProgramParameters.ACDataType.ACDT_REAL:
        {
            // special handling for time
            if (autoConstantDef.acType == GpuProgramParameters.AutoConstantType.ACT_TIME ||
                autoConstantDef.acType == GpuProgramParameters.AutoConstantType.ACT_FRAME_TIME)
            {
                Real factor = 1.0f;
                if (vecparams.length == 3)
                {
                    factor = to!Real(vecparams[2]);
                }

                if (isNamed)
                    context.programParams.setNamedAutoConstantReal(paramName,
                                                                   autoConstantDef.acType, factor);
                else
                    context.programParams.setAutoConstantReal(index,
                                                              autoConstantDef.acType, factor);
            }
            else // normal processing for auto constants that take an extra real value
            {
                if (vecparams.length != 3)
                {
                    logParseError("Invalid " ~ commandname ~ " attribute - "
                                  "expected 3 parameters.", context);
                    return;
                }

                Real rData = to!Real(vecparams[2]);
                if (isNamed)
                    context.programParams.setNamedAutoConstantReal(paramName,
                                                                   autoConstantDef.acType, rData);
                else
                    context.programParams.setAutoConstantReal(index,
                                                              autoConstantDef.acType, rData);
            }
        }
            break;

    } // end switch

    
}

//-----------------------------------------------------------------------
bool parseParamIndexed(string params, ref MaterialScriptContext context)
{
    // NB skip this if the program is not supported or could not be found
    if (context.program.isNull() || !context.program.isSupported())
    {
        return false;
    }

    params = params.toLower();
    string[] vecparams = StringUtil.split(params, " \t");
    if (vecparams.length < 3)
    {
        logParseError("Invalid param_indexed attribute - expected at least 3 parameters.",
                      context);
        return false;
    }

    // Get start index
    size_t index = to!int(vecparams[0]);

    processManualProgramParam(false, "param_indexed", vecparams, context, index);

    return false;
}
//-----------------------------------------------------------------------
bool parseParamIndexedAuto(string params, ref MaterialScriptContext context)
{
    // NB skip this if the program is not supported or could not be found
    if (context.program.isNull() || !context.program.isSupported())
    {
        return false;
    }

    params = params.toLower();
    string[] vecparams = StringUtil.split(params, " \t");
    if (vecparams.length != 2 && vecparams.length != 3)
    {
        logParseError("Invalid param_indexed_auto attribute - expected 2 or 3 parameters.",
                      context);
        return false;
    }

    // Get start index
    size_t index = to!int(vecparams[0]);

    processAutoProgramParam(false, "param_indexed_auto", vecparams, context, index);

    return false;
}
//-----------------------------------------------------------------------
bool parseParamNamed(string params, ref MaterialScriptContext context)
{
    // NB skip this if the program is not supported or could not be found
    if (context.program.isNull() || !context.program.isSupported())
    {
        return false;
    }

    string[] vecparams = StringUtil.split(params, " \t");
    if (vecparams.length < 3)
    {
        logParseError("Invalid param_named attribute - expected at least 3 parameters.",
                      context);
        return false;
    }

    try {
        GpuConstantDefinition* def =
            context.programParams.getConstantDefinition(vecparams[0]);
    }
    catch (Exception e)
    {
        logParseError("Invalid param_named attribute - " ~ e.msg, context);
        return false;
    }

    processManualProgramParam(true, "param_named", vecparams, context, 0, vecparams[0]);

    return false;
}
//-----------------------------------------------------------------------
bool parseParamNamedAuto(string params, ref MaterialScriptContext context)
{
    // NB skip this if the program is not supported or could not be found
    if (context.program.isNull() || !context.program.isSupported())
    {
        return false;
    }

    string[] vecparams = StringUtil.split(params, " \t");
    if (vecparams.length != 2 && vecparams.length != 3)
    {
        logParseError("Invalid param_indexed_auto attribute - expected 2 or 3 parameters.",
                      context);
        return false;
    }

    // Get start index from name
    try {
        GpuConstantDefinition* def =
            context.programParams.getConstantDefinition(vecparams[0]);
    }
    catch (Exception e)
    {
        logParseError("Invalid param_named_auto attribute - " ~ e.msg, context);
        return false;
    }

    processAutoProgramParam(true, "param_named_auto", vecparams, context, 0, vecparams[0]);

    return false;
}
//-----------------------------------------------------------------------
bool parseMaterial(string params, ref MaterialScriptContext context)
{
    // nfz:
    // check params for reference to parent material to copy from
    // syntax: material name : parentMaterialName
    // check params for a colon after the first name and extract the parent name
    string[] vecparams = StringUtil.split(params, ":", 1);
    MaterialPtr basematerial;

    // Create a brand new material
    if (vecparams.length >= 2)
    {
        // if a second parameter exists then assume its the name of the base material
        // that this new material should clone from
        vecparams[1] = vecparams[1].strip();
        // make sure base material exists
        basematerial = MaterialManager.getSingleton().getByName(vecparams[1]);
        // if it doesn't exist then report error in log and just create a new material
        if (basematerial.isNull())
        {
            logParseError("parent material: " ~ vecparams[1] ~ " not found for new material:"
                          ~ vecparams[0], context);
        }
    }

    // get rid of leading and trailing white space from material name
    vecparams[0] = vecparams[0].strip();

    context.material =
        MaterialManager.getSingleton().create(vecparams[0], context.groupName);

    if (!basematerial.isNull())
    {
        // copy parent material details to new material
        basematerial.copyDetailsTo(context.material);
    }
    else
    {
        // Remove pre-created technique from defaults
        context.material.removeAllTechniques();
    }

    context.material._notifyOrigin(context.filename);

    // update section
    context.section = MSS_MATERIAL;

    // Return TRUE because this must be followed by a {
    return true;
}
//-----------------------------------------------------------------------
bool parseTechnique(string params, ref MaterialScriptContext context)
{

    // if params is not empty then see if the technique name already exists
    if (!params.empty() && (context.material.getNumTechniques() > 0))
    {
        // find the technique with name = params
        Technique foundTechnique = context.material.getTechnique(params);
        if (foundTechnique)
        {
            // figure out technique index by iterating through technique container
            // would be nice if each technique remembered its index
            int count = 0;
            auto i = context.material.getTechniques();
            foreach(t; i)
            {
                if (foundTechnique == t)//i.peekNext())
                    break;
                //i.moveNext();
                ++count;
            }

            context.techLev = count;
        }
        else
        {
            // name was not found so a new technique is needed
            // position technique level to the end index
            // a new technique will be created later on
            context.techLev = context.material.getNumTechniques();
        }

    }
    else
    {
        // no name was given in the script so a new technique will be created
        // Increase technique level depth
        ++context.techLev;
    }

    // Create a new technique if it doesn't already exist
    if (context.material.getNumTechniques() > context.techLev)
    {
        context.technique = context.material.getTechnique(cast(ushort)context.techLev);
    }
    else
    {
        context.technique = context.material.createTechnique();
        if (!params.empty())
            context.technique.setName(params);
    }

    // update section
    context.section = MSS_TECHNIQUE;

    // Return TRUE because this must be followed by a {
    return true;
}
//-----------------------------------------------------------------------
bool parsePass(string params, ref MaterialScriptContext context)
{
    // if params is not empty then see if the pass name already exists
    if (!params.empty() && (context.technique.getNumPasses() > 0))
    {
        // find the pass with name = params
        Pass foundPass = context.technique.getPass(params);
        if (foundPass)
        {
            context.passLev = foundPass.getIndex();
        }
        else
        {
            // name was not found so a new pass is needed
            // position pass level to the end index
            // a new pass will be created later on
            context.passLev = context.technique.getNumPasses();
        }

    }
    else
    {
        //Increase pass level depth
        ++context.passLev;
    }

    if (context.technique.getNumPasses() > context.passLev)
    {
        context.pass = context.technique.getPass(cast(ushort)context.passLev);
    }
    else
    {
        // Create a new pass
        context.pass = context.technique.createPass();
        if (!params.empty())
            context.pass.setName(params);
    }

    // update section
    context.section = MSS_PASS;

    // Return TRUE because this must be followed by a {
    return true;
}
//-----------------------------------------------------------------------
bool parseTextureUnit(string params, ref MaterialScriptContext context)
{
    // if params is a name then see if that texture unit exists
    // if not then log the warning and just move on to the next TU from current
    if (!params.empty() && (context.pass.getNumTextureUnitStates() > 0))
    {
        // specifying a TUS name in the script for a TU means that a specific TU is being requested
        // try to get the specific TU
        // if the index requested is not valid, just creat a new TU
        // find the TUS with name = params
        TextureUnitState foundTUS = context.pass.getTextureUnitState(params);
        if (foundTUS)
        {
            context.stateLev = context.pass.getTextureUnitStateIndex(foundTUS);
        }
        else
        {
            // name was not found so a new TUS is needed
            // position TUS level to the end index
            // a new TUS will be created later on
            context.stateLev = cast(int)(context.pass.getNumTextureUnitStates());
        }
    }
    else
    {
        //Increase Texture Unit State level depth
        ++context.stateLev;
    }

    if (context.pass.getNumTextureUnitStates() > cast(size_t)(context.stateLev))
    {
        context.textureUnit = context.pass.getTextureUnitState(cast(ushort)context.stateLev);
    }
    else
    {
        // Create a new texture unit
        context.textureUnit = context.pass.createTextureUnitState();
        if (!params.empty())
            context.textureUnit.setName(params);
    }
    // update section
    context.section = MSS_TEXTUREUNIT;

    // Return TRUE because this must be followed by a {
    return true;
}

//-----------------------------------------------------------------------
bool parseVertexProgramRef(string params, ref MaterialScriptContext context)
{
    // update section
    context.section = MSS_PROGRAM_REF;

    // check if pass has a vertex program already
    if (context.pass.hasVertexProgram())
    {
        // if existing pass vertex program has same name as params
        // or params is empty then use current vertex program
        if (params.empty() || (context.pass.getVertexProgramName() == params))
        {
            context.program = context.pass.getVertexProgram();
        }
    }

    // if context.program was not set then try to get the vertex program using the name
    // passed in params
    if (context.program.isNull())
    {
        context.program = GpuProgramManager.getSingleton().getByName(params);
        if (context.program.isNull())
        {
            // Unknown program
            logParseError("Invalid vertex_program_ref entry - vertex program "
                          ~ params ~ " has not been defined.", context);
            return true;
        }

        // Set the vertex program for this pass
        context.pass.setVertexProgram(params);
    }

    context.isVertexProgramShadowCaster = false;
    context.isFragmentProgramShadowCaster = false;
    context.isVertexProgramShadowReceiver = false;
    context.isFragmentProgramShadowReceiver = false;

    // Create params? Skip this if program is not supported
    if (context.program.isSupported())
    {
        context.programParams = context.pass.getVertexProgramParameters();
        context.numAnimationParametrics = 0;
    }

    // Return TRUE because this must be followed by a {
    return true;
}
//-----------------------------------------------------------------------
bool parseGeometryProgramRef(string params, ref MaterialScriptContext context)
{
    // update section
    context.section = MSS_PROGRAM_REF;

    // check if pass has a vertex program already
    if (context.pass.hasGeometryProgram())
    {
        // if existing pass vertex program has same name as params
        // or params is empty then use current vertex program
        if (params.empty() || (context.pass.getGeometryProgramName() == params))
        {
            context.program = context.pass.getGeometryProgram();
        }
    }

    // if context.program was not set then try to get the geometry program using the name
    // passed in params
    if (context.program.isNull())
    {
        context.program = GpuProgramManager.getSingleton().getByName(params);
        if (context.program.isNull())
        {
            // Unknown program
            logParseError("Invalid geometry_program_ref entry - vertex program "
                          ~ params ~ " has not been defined.", context);
            return true;
        }

        // Set the vertex program for this pass
        context.pass.setGeometryProgram(params);
    }

    context.isVertexProgramShadowCaster = false;
    context.isFragmentProgramShadowCaster = false;
    context.isVertexProgramShadowReceiver = false;
    context.isFragmentProgramShadowReceiver = false;

    // Create params? Skip this if program is not supported
    if (context.program.isSupported())
    {
        context.programParams = context.pass.getGeometryProgramParameters();
        context.numAnimationParametrics = 0;
    }

    // Return TRUE because this must be followed by a {
    return true;
}
//-----------------------------------------------------------------------
bool parseShadowCasterVertexProgramRef(string params, ref MaterialScriptContext context)
{
    // update section
    context.section = MSS_PROGRAM_REF;

    context.program = GpuProgramManager.getSingleton().getByName(params);
    if (context.program.isNull())
    {
        // Unknown program
        logParseError("Invalid shadow_caster_vertex_program_ref entry - vertex program "
                      ~ params ~ " has not been defined.", context);
        return true;
    }

    context.isVertexProgramShadowCaster = true;
    context.isFragmentProgramShadowCaster = false;
    context.isVertexProgramShadowReceiver = false;
    context.isFragmentProgramShadowReceiver = false;

    // Set the vertex program for this pass
    context.pass.setShadowCasterVertexProgram(params);

    // Create params? Skip this if program is not supported
    if (context.program.isSupported())
    {
        context.programParams = context.pass.getShadowCasterVertexProgramParameters();
        context.numAnimationParametrics = 0;
    }

    // Return TRUE because this must be followed by a {
    return true;
}
//-----------------------------------------------------------------------
bool parseShadowCasterFragmentProgramRef(string params, ref MaterialScriptContext context)
{
    // update section
    context.section = MSS_PROGRAM_REF;

    context.program = GpuProgramManager.getSingleton().getByName(params);
    if (context.program.isNull())
    {
        // Unknown program
        logParseError("Invalid shadow_caster_fragment_program_ref entry - fragment program "
                      ~ params ~ " has not been defined.", context);
        return true;
    }

    context.isVertexProgramShadowCaster = false;
    context.isFragmentProgramShadowCaster = true;
    context.isVertexProgramShadowReceiver = false;
    context.isFragmentProgramShadowReceiver = false;

    // Set the vertex program for this pass
    context.pass.setShadowCasterFragmentProgram(params);

    // Create params? Skip this if program is not supported
    if (context.program.isSupported())
    {
        context.programParams = context.pass.getShadowCasterFragmentProgramParameters();
        context.numAnimationParametrics = 0;
    }

    // Return TRUE because this must be followed by a {
    return true;
}
//-----------------------------------------------------------------------
bool parseShadowReceiverVertexProgramRef(string params, ref MaterialScriptContext context)
{
    // update section
    context.section = MSS_PROGRAM_REF;

    context.program = GpuProgramManager.getSingleton().getByName(params);
    if (context.program.isNull())
    {
        // Unknown program
        logParseError("Invalid shadow_receiver_vertex_program_ref entry - vertex program "
                      ~ params ~ " has not been defined.", context);
        return true;
    }

    
    context.isVertexProgramShadowCaster = false;
    context.isFragmentProgramShadowCaster = false;
    context.isVertexProgramShadowReceiver = true;
    context.isFragmentProgramShadowReceiver = false;

    // Set the vertex program for this pass
    context.pass.setShadowReceiverVertexProgram(params);

    // Create params? Skip this if program is not supported
    if (context.program.isSupported())
    {
        context.programParams = context.pass.getShadowReceiverVertexProgramParameters();
        context.numAnimationParametrics = 0;
    }

    // Return TRUE because this must be followed by a {
    return true;
}
//-----------------------------------------------------------------------
bool parseShadowReceiverFragmentProgramRef(string params, ref MaterialScriptContext context)
{
    // update section
    context.section = MSS_PROGRAM_REF;

    context.program = GpuProgramManager.getSingleton().getByName(params);
    if (context.program.isNull())
    {
        // Unknown program
        logParseError("Invalid shadow_receiver_fragment_program_ref entry - fragment program "
                      ~ params ~ " has not been defined.", context);
        return true;
    }

    
    context.isVertexProgramShadowCaster = false;
    context.isFragmentProgramShadowCaster = false;
    context.isVertexProgramShadowReceiver = false;
    context.isFragmentProgramShadowReceiver = true;

    // Set the vertex program for this pass
    context.pass.setShadowReceiverFragmentProgram(params);

    // Create params? Skip this if program is not supported
    if (context.program.isSupported())
    {
        context.programParams = context.pass.getShadowReceiverFragmentProgramParameters();
        context.numAnimationParametrics = 0;
    }

    // Return TRUE because this must be followed by a {
    return true;
}
//-----------------------------------------------------------------------
bool parseFragmentProgramRef(string params, ref MaterialScriptContext context)
{
    // update section
    context.section = MSS_PROGRAM_REF;

    // check if pass has a fragment program already
    if (context.pass.hasFragmentProgram())
    {
        // if existing pass fragment program has same name as params
        // or params is empty then use current fragment program
        if (params.empty() || (context.pass.getFragmentProgramName() == params))
        {
            context.program = context.pass.getFragmentProgram();
        }
    }

    // if context.program was not set then try to get the fragment program using the name
    // passed in params
    if (context.program.isNull())
    {
        context.program = GpuProgramManager.getSingleton().getByName(params);
        if (context.program.isNull())
        {
            // Unknown program
            logParseError("Invalid fragment_program_ref entry - fragment program "
                          ~ params ~ " has not been defined.", context);
            return true;
        }

        // Set the vertex program for this pass
        context.pass.setFragmentProgram(params);
    }

    // Create params? Skip this if program is not supported
    if (context.program.isSupported())
    {
        context.programParams = context.pass.getFragmentProgramParameters();
        context.numAnimationParametrics = 0;
    }

    // Return TRUE because this must be followed by a {
    return true;
}
//-----------------------------------------------------------------------
bool parseVertexProgram(string params, ref MaterialScriptContext context)
{
    // update section
    context.section = MSS_PROGRAM;

    // Create new program definition-in-progress
    context.programDef = new MaterialScriptProgramDefinition;
    context.programDef.progType = GpuProgramType.GPT_VERTEX_PROGRAM;
    context.programDef.supportsSkeletalAnimation = false;
    context.programDef.supportsMorphAnimation = false;
    context.programDef.supportsPoseAnimation = 0;
    context.programDef.usesVertexTextureFetch = false;

    // Get name and language code
    string[] vecparams = StringUtil.split(params, " \t");
    if (vecparams.length != 2)
    {
        logParseError("Invalid vertex_program entry - expected "
                      "2 parameters.", context);
        return true;
    }
    // Name, preserve case
    context.programDef.name = vecparams[0];
    // language code, make lower case
    context.programDef.language = vecparams[1];
    context.programDef.language = context.programDef.language.toLower();

    // Return TRUE because this must be followed by a {
    return true;
}
//-----------------------------------------------------------------------
bool parseGeometryProgram(string params, ref MaterialScriptContext context)
{
    // update section
    context.section = MSS_PROGRAM;

    // Create new program definition-in-progress
    context.programDef = new MaterialScriptProgramDefinition;
    context.programDef.progType = GpuProgramType.GPT_GEOMETRY_PROGRAM;
    context.programDef.supportsSkeletalAnimation = false;
    context.programDef.supportsMorphAnimation = false;
    context.programDef.supportsPoseAnimation = 0;
    context.programDef.usesVertexTextureFetch = false;

    // Get name and language code
    string[] vecparams = StringUtil.split(params, " \t");
    if (vecparams.length != 2)
    {
        logParseError("Invalid geometry_program entry - expected "
                      "2 parameters.", context);
        return true;
    }
    // Name, preserve case
    context.programDef.name = vecparams[0];
    // language code, make lower case
    context.programDef.language = vecparams[1];
    context.programDef.language = context.programDef.language.toLower();

    // Return TRUE because this must be followed by a {
    return true;
}
//-----------------------------------------------------------------------
bool parseFragmentProgram(string params, ref MaterialScriptContext context)
{
    // update section
    context.section = MSS_PROGRAM;

    // Create new program definition-in-progress
    context.programDef = new MaterialScriptProgramDefinition;
    context.programDef.progType = GpuProgramType.GPT_FRAGMENT_PROGRAM;
    context.programDef.supportsSkeletalAnimation = false;
    context.programDef.supportsMorphAnimation = false;
    context.programDef.supportsPoseAnimation = 0;
    context.programDef.usesVertexTextureFetch = false;

    // Get name and language code
    string[] vecparams = StringUtil.split(params, " \t");
    if (vecparams.length != 2)
    {
        logParseError("Invalid fragment_program entry - expected "
                      "2 parameters.", context);
        return true;
    }
    // Name, preserve case
    context.programDef.name = vecparams[0];
    // language code, make lower case
    context.programDef.language = vecparams[1];
    context.programDef.language = context.programDef.language.toLower();

    // Return TRUE because this must be followed by a {
    return true;

}
//-----------------------------------------------------------------------
bool parseProgramSource(string params, ref MaterialScriptContext context)
{
    // Source filename, preserve case
    context.programDef.source = params;

    return false;
}
//-----------------------------------------------------------------------
bool parseProgramSkeletalAnimation(string params, ref MaterialScriptContext context)
{
    // Source filename, preserve case
    context.programDef.supportsSkeletalAnimation = to!bool(params);

    return false;
}
//-----------------------------------------------------------------------
bool parseProgramMorphAnimation(string params, ref MaterialScriptContext context)
{
    // Source filename, preserve case
    context.programDef.supportsMorphAnimation = to!bool(params);

    return false;
}
//-----------------------------------------------------------------------
bool parseProgramPoseAnimation(string params, ref MaterialScriptContext context)
{
    // Source filename, preserve case
    context.programDef.supportsPoseAnimation = to!short(params);

    return false;
}
//-----------------------------------------------------------------------
bool parseProgramVertexTextureFetch(string params, ref MaterialScriptContext context)
{
    // Source filename, preserve case
    context.programDef.usesVertexTextureFetch = to!bool(params);

    return false;
}
//-----------------------------------------------------------------------
bool parseProgramSyntax(string params, ref MaterialScriptContext context)
{
    // Syntax code, make lower case
    params = params.toLower();
    context.programDef.syntax = params;

    return false;
}
//-----------------------------------------------------------------------
bool parseProgramCustomParameter(string params, ref MaterialScriptContext context)
{
    // This params object does not have the command stripped
    // Lower case the command, but not the value incase it's relevant
    // Split only up to first delimiter, program deals with the rest
    string[] vecparams = StringUtil.split(params, " \t", 1);
    if (vecparams.length != 2)
    {
        logParseError("Invalid custom program parameter entry; "
                      "there must be a parameter name and at least one value.",
                      context);
        return false;
    }

    context.programDef.customParameters ~= pair!(string, string)(vecparams[0], vecparams[1]);

    return false;
}

//-----------------------------------------------------------------------
bool parseTextureSource(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    string[] vecparams = StringUtil.split(params, " \t");
    if (vecparams.length != 1)
        logParseError("Invalid texture source attribute - expected 1 parameter.", context);
    //The only param should identify which ExternalTextureSource is needed
    ExternalTextureSourceManager.getSingleton().setCurrentPlugIn( vecparams[0] );

    if(	ExternalTextureSourceManager.getSingleton().getCurrentPlugIn() !is null )
    {
        string tps = to!string( context.techLev ) ~ " "
            ~ to!string( context.passLev ) ~ " "
                ~ to!string( context.stateLev);

        ExternalTextureSourceManager.getSingleton().getCurrentPlugIn().setParameter( "set_T_P_S", tps );
    }

    // update section
    context.section = MSS_TEXTURESOURCE;
    // Return TRUE because this must be followed by a {
    return true;
}

//-----------------------------------------------------------------------
bool parseTextureCustomParameter(string params, ref MaterialScriptContext context)
{
    // This params object does not have the command stripped
    // Split only up to first delimiter, program deals with the rest
    string[] vecparams = StringUtil.split(params, " \t", 1);
    if (vecparams.length != 2)
    {
        logParseError("Invalid texture parameter entry; "
                      "there must be a parameter name and at least one value.",
                      context);
        return false;
    }

    if(	ExternalTextureSourceManager.getSingleton().getCurrentPlugIn() !is null )
        ////First is command, next could be a string with one or more values
        ExternalTextureSourceManager.getSingleton().getCurrentPlugIn().setParameter( vecparams[0], vecparams[1] );

    return false;
}
//-----------------------------------------------------------------------
bool parseReceiveShadows(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    if (params == "on")
        context.material.setReceiveShadows(true);
    else if (params == "off")
        context.material.setReceiveShadows(false);
    else
        logParseError(
            "Bad receive_shadows attribute, valid parameters are 'on' or 'off'.",
            context);

    return false;

}
//-----------------------------------------------------------------------
bool parseDefaultParams(string params, ref MaterialScriptContext context)
{
    context.section = MSS_DEFAULT_PARAMETERS;
    // Should be a brace next
    return true;
}

//-----------------------------------------------------------------------
bool parseTransparencyCastsShadows(string params, ref MaterialScriptContext context)
{
    params = params.toLower();
    if (params == "on")
        context.material.setTransparencyCastsShadows(true);
    else if (params == "off")
        context.material.setTransparencyCastsShadows(false);
    else
        logParseError(
            "Bad transparency_casts_shadows attribute, valid parameters are 'on' or 'off'.",
            context);

    return false;

}
//-----------------------------------------------------------------------
bool parseLodStrategy(string params, ref MaterialScriptContext context)
{
    LodStrategy strategy = LodStrategyManager.getSingleton().getStrategy(params);

    if (strategy is null)
        logParseError(
            "Bad lod_strategy attribute, available lod strategy name expected.",
            context);

    context.material.setLodStrategy(strategy);

    return false;
}
//-----------------------------------------------------------------------
bool parseLodDistances(string params, ref MaterialScriptContext context)
{
    // Set to distance strategy
    context.material.setLodStrategy(DistanceLodStrategy.getSingleton());

    string[] vecparams = StringUtil.split(params, " \t");

    // iterate over the parameters and parse values out of them
    Material.LodValueList lodList;
    foreach (i; vecparams)
    {
        lodList ~= to!Real(i);
    }

    context.material.setLodLevels(lodList);

    return false;
}
/** @} */
/** @} */
