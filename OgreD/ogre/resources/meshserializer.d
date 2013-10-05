module ogre.resources.meshserializer;

//import std.container;

import ogre.compat;
import ogre.resources.mesh;
import ogre.resources.datastream;
import ogre.exception;
import ogre.general.serializer;
import ogre.general.log;

enum ushort HEADER_CHUNK_ID = 0x1000;

/// Mesh compatibility versions
enum MeshVersion 
{
    /// Latest version available
    MESH_VERSION_LATEST,
    
    /// OGRE version v1.8+
    MESH_VERSION_1_8,
    /// OGRE version v1.7+
    MESH_VERSION_1_7,
    /// OGRE version v1.4+
    MESH_VERSION_1_4,
    /// OGRE version v1.0+
    MESH_VERSION_1_0,
    
    /// Legacy versions, DO NOT USE for writing
    MESH_VERSION_LEGACY
}

/** \addtogroup Core
    *  @{
    */
/** \addtogroup Resources
    *  @{
    */
/** 
     @remarks
        This class allows users to hook into the mesh loading process and
        modify references within the mesh as they are loading. Material and
        skeletal references can be processed using this interface which allows
        finer control over resources.
    */
interface MeshSerializerListener
{
public:
    /// Called to override the loading of the given named material
    void processMaterialName(Mesh mesh, string name);
    /// Called to override the reference to a skeleton
    void processSkeletonName(Mesh mesh, string name);
    /// Allows to do changes on mesh after it's completely loaded. For example you can generate LOD levels here.
    void processMeshCompleted(Mesh mesh);
}

/** Class for serialising mesh data to/from an OGRE .mesh file.
    @remarks
        This class allows exporters to write OGRE .mesh files easily, and allows the
        OGRE engine to import .mesh files into instantiated OGRE Meshes.
        Note that a .mesh file can include not only the Mesh, but also definitions of
        any Materials it uses (although this is optional, the .mesh can rely on the
        Material being loaded from another source, especially useful if you want to
        take advantage of OGRE's advanced Material properties which may not be available
        in your modeller).
    @par
        To export a Mesh:<OL>
        <LI>Use the MaterialManager methods to create any dependent Material objects, if you want
            to export them with the Mesh.</LI>
        <LI>Create a Mesh object and populate it using it's methods.</LI>
        <LI>Call the exportMesh method</LI>
        </OL>
    @par
        It's important to realise that this exporter uses OGRE terminology. In this context,
        'Mesh' means a top-level mesh structure which can actually contain many SubMeshes, each
        of which has only one Material. Modelling packages may ref er to these differently, for
        example in Milkshape, it says 'Model' instead of 'Mesh' and 'Mesh' instead of 'SubMesh', 
        but the theory is the same.
    */
class MeshSerializer : Serializer
{
public:
    this()
    {
        //mListener = null;
        // Init implementations
        // String identifiers have not always been 100% unified with OGRE version
        
        // Note MUST be added in reverse order so latest is first in the list
        mVersionData.insert(new MeshVersionData(
            MeshVersion.MESH_VERSION_1_8, "[MeshSerializer_v1.8]", 
            new MeshSerializerImpl()));
        
        mVersionData.insert(new MeshVersionData(
            MeshVersion.MESH_VERSION_1_7, "[MeshSerializer_v1.41]", 
            new MeshSerializerImpl_v1_41()));
        
        mVersionData.insert(new MeshVersionData(
            MeshVersion.MESH_VERSION_1_4, "[MeshSerializer_v1.40]", 
            new MeshSerializerImpl_v1_4()));
        
        mVersionData.insert(new MeshVersionData(
            MeshVersion.MESH_VERSION_1_0, "[MeshSerializer_v1.30]", 
            new MeshSerializerImpl_v1_3()));
        mVersionData.insert(new MeshVersionData(
            MeshVersion.MESH_VERSION_LEGACY, "[MeshSerializer_v1.20]", 
            new MeshSerializerImpl_v1_2()));
        
        mVersionData.insert(new MeshVersionData(
            MeshVersion.MESH_VERSION_LEGACY, "[MeshSerializer_v1.10]", 
            new MeshSerializerImpl_v1_1()));
    }

    ~this()
    {
        // delete map
        foreach (i; mVersionData)
        {
            destroy(i);
        }
        mVersionData.clear();
    }
    
    
    /** Exports a mesh to the file specified, in the latest format
        @remarks
            This method takes an externally created Mesh object, and exports it
            to a .mesh file in the latest format version available.
        @param pMesh Pointer to the Mesh to export
        @param filename The destination filename
        @param endianMode The endian mode of the written file
        */
    void exportMesh(Mesh pMesh,string filename,
                    Endian endianMode = Endian.ENDIAN_NATIVE)
    {

        //DataStream stream(new FileStreamDataStream(f));
        auto stream = new FileHandleDataStream(filename, DataStream.AccessMode.WRITE);
        exportMesh(pMesh, stream, endianMode);
        stream.close();
    }
    
    /** Exports a mesh to the file specified, in a specific version format. 
         @remarks
         This method takes an externally created Mesh object, and exports it
         to a .mesh file in the specified format version. Note that picking a
         format version other that the latest will cause some information to be
         lost.
         @param pMesh Pointer to the Mesh to export
         @param filename The destination filename
         @param version Mesh version to write
         @param endianMode The endian mode of the written file
         */
    void exportMesh(Mesh pMesh,string filename,
                    MeshVersion _version,
                    Endian endianMode = Endian.ENDIAN_NATIVE)
    {
        //DataStreamPtr stream(OGRE_NEW FileStreamDataStream(f));
        auto stream = new FileHandleDataStream(filename, DataStream.AccessMode.WRITE);
        exportMesh(pMesh, stream, _version, endianMode);
        stream.close();
    }
    
    /** Exports a mesh to the stream specified, in the latest format. 
        @remarks
         This method takes an externally created Mesh object, and exports it
         to a .mesh file in the latest format version. 
        @param pMesh Pointer to the Mesh to export
        @param stream Writeable stream
        @param endianMode The endian mode of the written file
        */
    void exportMesh(Mesh pMesh, DataStream stream,
                    Endian endianMode = Endian.ENDIAN_NATIVE)
    {
        exportMesh(pMesh, stream, MeshVersion.MESH_VERSION_LATEST, endianMode);
    }
    
    /** Exports a mesh to the stream specified, in a specific version format. 
         @remarks
         This method takes an externally created Mesh object, and exports it
         to a .mesh file in the specified format version. Note that picking a
         format version other that the latest will cause some information to be
         lost.
         @param pMesh Pointer to the Mesh to export
         @param stream Writeable stream
         @param version Mesh version to write
         @param endianMode The endian mode of the written file
         */
    void exportMesh(Mesh pMesh, DataStream stream,
                    MeshVersion _version,
                    Endian endianMode = Endian.ENDIAN_NATIVE)
    {
        if (_version == MeshVersion.MESH_VERSION_LEGACY)
            throw new InvalidParamsError(
                        "You may not supply a legacy version number (pre v1.0) for writing meshes.",
                        "MeshSerializer.exportMesh");
        
        MeshSerializerImpl impl = null;
        if (_version == MeshVersion.MESH_VERSION_LATEST)
            impl = mVersionData[0].impl;
        else 
        {
            foreach (i; mVersionData)
            {
                if (_version == i._version)
                {
                    impl = i.impl;
                    break;
                }
            }
        }
        
        if (impl is null)
            throw new InternalError("Cannot find serializer implementation for " ~
                                    "specified version", "MeshSerializer.exportMesh");
        
        
        impl.exportMesh(pMesh, stream, endianMode);
    }
    
    /** Imports Mesh and (optionally) Material data from a .mesh file DataStream.
        @remarks
            This method imports data from a DataStream opened from a .mesh file and places it's
            contents into the Mesh object which is passed in. 
        @param stream The DataStream holding the .mesh data. Must be initialised (pos at the start of the buffer).
        @param pDest Pointer to the Mesh object which will receive the data. Should be blank already.
        */
    void importMesh(DataStream stream, ref Mesh pDest)
    {
        determineEndianness(stream);
        
        // Read header and determine the version
        ushort headerID;
        
        // Read header ID
        readShorts(stream, &headerID, 1);
        
        if (headerID != HEADER_CHUNK_ID)
        {
            throw new InternalError("File header not found",
                        "MeshSerializer.importMesh");
        }
        // Read version
        string ver = readString(stream);
        // Jump back to start
        stream.seek(0);
        
        // Find the implementation to use
        MeshSerializerImpl impl = null;
        foreach (i; mVersionData)
        {
            if (i.versionString == ver)
            {
                impl = i.impl;
                break;
            }
        }           
        if (impl is null)
            throw new InternalError("Cannot find serializer implementation for " ~
                        "mesh version " ~ ver, "MeshSerializer.importMesh");
        
        // Call implementation
        impl.importMesh(stream, pDest, mListener);
        // Warn on old version of mesh
        if (ver != mVersionData[0].versionString)
        {
            LogManager.getSingleton().logMessage("WARNING: " ~ pDest.getName() ~ 
                                                 " is an older format (" ~ ver ~ "); you should upgrade it as soon as possible" ~
                                                 " using the OgreMeshUpgrade tool.");
        }
        
        if(mListener)
            mListener.processMeshCompleted(pDest);
    }
    
    /// Sets the listener for this serializer
    void setListener(ref MeshSerializerListener listener)
    {
        mListener = listener;
    }

    /// Returns the current listener
    MeshSerializerListener getListener()
    {
        return mListener;
    }
    
protected:
    
    class MeshVersionData //: public SerializerAlloc
    {
    public:
        MeshVersion _version;
        string versionString;
        MeshSerializerImpl impl;
        
        this(MeshVersion _ver,string _string, MeshSerializerImpl _impl)
        {
            _version = _ver;
            versionString = _string;
            impl = _impl;
        }
        
        ~this() { destroy(impl); }
    }
    
    //typedef vector<MeshVersionData*>::type MeshVersionDataList;
    alias MeshVersionData[] MeshVersionDataList;
    MeshVersionDataList mVersionData;
    
    MeshSerializerListener mListener;
    
}
/** @} */
/** @} */