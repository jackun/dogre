module ogre.animation.skeletonserializer;

import ogre.animation.animations;
import ogre.general.log;
import ogre.resources.datastream;
import ogre.exception;
import ogre.math.vector;
import ogre.math.quaternion;
import ogre.general.serializer;


/// Skeleton compatibility versions
enum SkeletonVersion 
{
    /// OGRE version v1.0+
    SKELETON_VERSION_1_0,
    /// OGRE version v1.8+
    SKELETON_VERSION_1_8,
    
    /// Latest version available
    SKELETON_VERSION_LATEST = 100
}

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Animation
 *  @{
 */

/** Definition of the OGRE .skeleton file format 

 .skeleton files are binary files (for read efficiency at runtime) and are arranged into chunks 
 of data, very like 3D Studio's format.
 A chunk always consists of:
 ushort CHUNK_ID        : one of the following chunk ids identifying the chunk
 unsigned long  LENGTH          : length of the chunk in bytes, including this header
 void*          DATA            : the data, which may contain other sub-chunks (various data types)
 
 A .skeleton file contains both the definition of the Skeleton object and the animations it contains. It
 contains only a single skeleton but can contain multiple animations.

 
 */
enum SkeletonChunkID {
    SKELETON_HEADER            = 0x1000,
    // char* version           : Version number check
    SKELETON_BLENDMODE         = 0x1010, // optional
    // ushort blendmode     : SkeletonAnimationBlendMode
    
    SKELETON_BONE              = 0x2000,
    // Repeating section defining each bone in the system. 
    // Bones are assigned indexes automatically based on their order of declaration
    // starting with 0.
    
    // char* name                       : name of the bone
    // ushort handle            : handle of the bone, should be contiguous & start at 0
    // Vector3 position                 : position of this bone relative to parent 
    // Quaternion orientation           : orientation of this bone relative to parent 
    // Vector3 scale                    : scale of this bone relative to parent 
    
    SKELETON_BONE_PARENT       = 0x3000,
    // Record of the parent of a single bone, used to build the node tree
    // Repeating section, listed in Bone Index order, one per Bone
    
    // ushort handle             : child bone
    // ushort parentHandle   : parent bone
    
    SKELETON_ANIMATION         = 0x4000,
    // A single animation for this skeleton
    
    // char* name                       : Name of the animation
    // float length                      : Length of the animation in seconds
    
    SKELETON_ANIMATION_BASEINFO = 0x4010,
    // [Optional] base keyframe information
    // char* baseAnimationName (blank for self)
    // float baseKeyFrameTime
    
    SKELETON_ANIMATION_TRACK = 0x4100,
    // A single animation track (relates to a single bone)
    // Repeating section (within SKELETON_ANIMATION)
    
    // ushort boneIndex     : Index of bone to apply to
    
    SKELETON_ANIMATION_TRACK_KEYFRAME = 0x4110,
    // A single keyframe within the track
    // Repeating section
    
    // float time                    : The time position (seconds)
    // Quaternion rotate            : Rotation to apply at this keyframe
    // Vector3 translate            : Translation to apply at this keyframe
    // Vector3 scale                : Scale to apply at this keyframe
    SKELETON_ANIMATION_LINK         = 0x5000
    // Link to another skeleton, to re-use its animations
    
    // char* skeletonName                   : name of skeleton to get animations from
    // float scale                          : scale to apply to trans/scale keys
    
}

/// stream overhead = ID + size
const uint SSTREAM_OVERHEAD_SIZE = ushort.sizeof + uint.sizeof;
const ushort HEADER_STREAM_ID_EXT = 0x1000;

/** Class for serialising skeleton data to/from an OGRE .skeleton file.
 @remarks
 This class allows exporters to write OGRE .skeleton files easily, and allows the
 OGRE engine to import .skeleton files into instantiated OGRE Skeleton objects.
 Note that a .skeleton file includes not only the Skeleton, but also definitions of
 any Animations it uses.
 @par
 To export a Skeleton:<OL>
 <LI>Create a Skeleton object and populate it using it's methods.</LI>
 <LI>Call the exportSkeleton method</LI>
 </OL>
 */
class SkeletonSerializer : Serializer
{
    
public:
    this()
    {
        // Version number
        // NB changed to include bone names in 1.1
        mVersion = "[Unknown]";
    }

    ~this() {}
    
    
    /** Exports a skeleton to the file specified. 
     @remarks
     This method takes an externally created Skeleton object, and exports both it
     and animations it uses to a .skeleton file.
     @param pSkeleton Weak reference to the Skeleton to export
     @param filename The destination filename
     @param endianMode The endian mode to write in
     */
    void exportSkeleton(ref Skeleton pSkeleton, string filename,
                        SkeletonVersion ver = SkeletonVersion.SKELETON_VERSION_LATEST, Endian endianMode = Endian.ENDIAN_NATIVE)
    {
        auto stream = new FileHandleDataStream(filename, DataStream.AccessMode.WRITE);
        
        exportSkeleton(pSkeleton, stream, ver, endianMode);
        
        stream.close();
    }
    
    /** Exports a skeleton to the stream specified. 
     @remarks
     This method takes an externally created Skeleton object, and exports both it
     and animations it uses to a .skeleton file.
     @param pSkeleton Weak reference to the Skeleton to export
     @param stream The destination stream
     @param endianMode The endian mode to write in
     */
    void exportSkeleton(ref Skeleton pSkeleton, DataStream stream,
                        SkeletonVersion ver = SkeletonVersion.SKELETON_VERSION_LATEST, Endian endianMode = Endian.ENDIAN_NATIVE)
    {
        setWorkingVersion(ver);
        // Decide on endian mode
        determineEndianness(endianMode);
        
        string msg;
        mStream = stream;
        if (!stream.isWriteable())
        {
            throw new CannotWriteToFileError(
                "Unable to write to stream " ~ stream.getName(),
                "SkeletonSerializer.exportSkeleton");
        }
        
        
        writeFileHeader();
        
        // Write main skeleton data
        LogManager.getSingleton().logMessage("Exporting bones..");
        writeSkeleton(pSkeleton, ver);
        LogManager.getSingleton().logMessage("Bones exported.");
        
        // Write all animations
        ushort numAnims = pSkeleton.getNumAnimations();
        LogManager.getSingleton().stream()
            << "Exporting animations, count=" << numAnims;
        for (ushort i = 0; i < numAnims; ++i)
        {
            Animation pAnim = pSkeleton.getAnimation(i);
            LogManager.getSingleton().stream()
                << "Exporting animation: " << pAnim.getName();
            writeAnimation(pSkeleton, pAnim, ver);
            LogManager.getSingleton().logMessage("Animation exported.");
            
        }
        
        // Write links
        auto linkIt = pSkeleton.getLinkedSkeletonAnimSourceList();
        foreach(LinkedSkeletonAnimationSource link; linkIt)
        {
            writeSkeletonAnimationLink(pSkeleton, &link);
        }       
        
    }
    /** Imports Skeleton and animation data from a .skeleton file DataStream.
     @remarks
     This method imports data from a DataStream opened from a .skeleton file and places it's
     contents into the Skeleton object which is passed in. 
     @param stream The DataStream holding the .skeleton data. Must be initialised (pos at the start of the buffer).
     @param pDest Weak reference to the Skeleton object which will receive the data. Should be blank already.
     */
    void importSkeleton(DataStream stream, ref Skeleton pSkel)
    {
        // Determine endianness (must be the first thing we do!)
        determineEndianness(stream);
        
        // Check header
        readFileHeader(stream);
        
        ushort streamID;
        while(!stream.eof())
        {
            streamID = readChunk(stream);
            switch (streamID)
            {
                case SkeletonChunkID.SKELETON_BLENDMODE:
                {
                    // Optional blend mode
                    ushort blendMode;
                    readShorts(stream, &blendMode, 1);
                    pSkel.setBlendMode(cast(SkeletonAnimationBlendMode)(blendMode));
                    break;
                }
                case SkeletonChunkID.SKELETON_BONE:
                    readBone(stream, pSkel);
                    break;
                case SkeletonChunkID.SKELETON_BONE_PARENT:
                    readBoneParent(stream, pSkel);
                    break;
                case SkeletonChunkID.SKELETON_ANIMATION:
                    readAnimation(stream, pSkel);
                    break;
                case SkeletonChunkID.SKELETON_ANIMATION_LINK:
                    readSkeletonAnimationLink(stream, pSkel);
                    break;
                default:
                    break;
            }
        }
        
        // Assume bones are stored in the binding pose
        pSkel.setBindingPose();
        
        
    }
    
    // TODO: provide Cal3D importer?
    
protected:
    
    void setWorkingVersion(SkeletonVersion ver)
    {
        if (ver == SkeletonVersion.SKELETON_VERSION_1_0)
            mVersion = "[Serializer_v1.10]";
        else mVersion = "[Serializer_v1.80]";
    }
    
    // Internal export methods
    void writeSkeleton(ref Skeleton pSkel, SkeletonVersion ver)
    {
        // Write blend mode
        if (ver > SkeletonVersion.SKELETON_VERSION_1_0)
        {
            writeChunkHeader(SkeletonChunkID.SKELETON_BLENDMODE, SSTREAM_OVERHEAD_SIZE + ushort.sizeof);
            ushort blendMode = cast(ushort)(pSkel.getBlendMode());
            writeShorts(&blendMode, 1);
        }
        
        // Write each bone
        ushort numBones = pSkel.getNumBones();
        ushort i;
        for (i = 0; i < numBones; ++i)
        {
            Bone pBone = pSkel.getBone(i);
            writeBone(pSkel, pBone);
        }
        // Write parents
        for (i = 0; i < numBones; ++i)
        {
            Bone pBone = pSkel.getBone(i);
            ushort handle = pBone.getHandle();
            Bone pParent = cast(Bone)pBone.getParent(); 
            if (pParent !is null) 
            {
                writeBoneParent(pSkel, handle, pParent.getHandle());             
            }
        }
    }

    void writeBone(ref Skeleton pSkel, ref Bone pBone)
    {
        writeChunkHeader(SkeletonChunkID.SKELETON_BONE, calcBoneSize(pSkel, pBone));
        
        ushort handle = pBone.getHandle();
        // char* name
        writeString(pBone.getName());
        // ushort handle            : handle of the bone, should be contiguous & start at 0
        writeShorts(&handle, 1);
        // Vector3 position                 : position of this bone relative to parent 
        writeObject(pBone.getPosition());
        // Quaternion orientation           : orientation of this bone relative to parent 
        writeObject(pBone.getOrientation());
        // Vector3 scale                    : scale of this bone relative to parent 
        if (pBone.getScale() != Vector3.UNIT_SCALE)
        {
            writeObject(pBone.getScale());
        }
    }

    void writeBoneParent(ref Skeleton pSkel, ushort boneId, ushort parentId)
    {
        writeChunkHeader(SkeletonChunkID.SKELETON_BONE_PARENT, calcBoneParentSize(pSkel));
        
        // ushort handle             : child bone
        writeShorts(&boneId, 1);
        // ushort parentHandle   : parent bone
        writeShorts(&parentId, 1);
        
    }

    void writeAnimation(ref Skeleton pSkel, Animation anim, SkeletonVersion ver)
    {
        writeChunkHeader(SkeletonChunkID.SKELETON_ANIMATION, calcAnimationSize(pSkel, anim));
        
        // char* name                       : Name of the animation
        writeString(anim.getName());
        // float length                      : Length of the animation in seconds
        float len = anim.getLength();
        writeFloats(&len, 1);
        
        if (ver > SkeletonVersion.SKELETON_VERSION_1_0)
        {
            if (anim.getUseBaseKeyFrame())
            {
                size_t size = SSTREAM_OVERHEAD_SIZE;
                // char* baseAnimationName (including terminator)
                size += anim.getBaseKeyFrameAnimationName().length + 1;
                // float baseKeyFrameTime
                size += float.sizeof;
                
                writeChunkHeader(SkeletonChunkID.SKELETON_ANIMATION_BASEINFO, size);
                
                // char* baseAnimationName (blank for self)
                writeString(anim.getBaseKeyFrameAnimationName());
                
                // float baseKeyFrameTime
                float t = cast(float)anim.getBaseKeyFrameTime();
                writeFloats(&t, 1);
            }
        }
        
        // Write all tracks
        auto trackIt = anim.getNodeTracks();
        foreach(track; trackIt)
        {
            writeAnimationTrack(pSkel, track);
        }
        
    }

    void writeAnimationTrack(ref Skeleton pSkel, NodeAnimationTrack track)
    {
        writeChunkHeader(SkeletonChunkID.SKELETON_ANIMATION_TRACK, calcAnimationTrackSize(pSkel, track));
        
        // ushort boneIndex     : Index of bone to apply to
        Bone bone = cast(Bone)track.getAssociatedNode();
        ushort boneid = bone.getHandle();
        writeShorts(&boneid, 1);
        
        // Write all keyframes
        for (ushort i = 0; i < track.getNumKeyFrames(); ++i)
        {
            writeKeyFrame(pSkel, track.getNodeKeyFrame(i));
        }
        
    }

    void writeKeyFrame(ref Skeleton pSkel, TransformKeyFrame key)
    {
        
        writeChunkHeader(SkeletonChunkID.SKELETON_ANIMATION_TRACK_KEYFRAME, 
                         calcKeyFrameSize(pSkel, key));
        
        // float time                    : The time position (seconds)
        float time = key.getTime();
        writeFloats(&time, 1);
        // Quaternion rotate            : Rotation to apply at this keyframe
        writeObject(key.getRotation());
        // Vector3 translate            : Translation to apply at this keyframe
        writeObject(key.getTranslate());
        // Vector3 scale                : Scale to apply at this keyframe
        if (key.getScale() != Vector3.UNIT_SCALE)
        {
            writeObject(key.getScale());
        }
    }

    void writeSkeletonAnimationLink(ref Skeleton pSkel, 
                                    LinkedSkeletonAnimationSource* link)
    {
        writeChunkHeader(SkeletonChunkID.SKELETON_ANIMATION_LINK, 
                         calcSkeletonAnimationLinkSize(pSkel, link));
        
        // char* skeletonName
        writeString(link.skeletonName);
        // float scale
        writeFloats(&(link.scale), 1);
        
    }
    
    // Internal import methods
    override void readFileHeader(DataStream stream)
    {
        ushort headerID;
        
        // Read header ID
        readShorts(stream, &headerID, 1);
        
        if (headerID == HEADER_STREAM_ID_EXT)
        {
            // Read version
            string ver = readString(stream);
            if ((ver != "[Serializer_v1.10]") &&
                (ver != "[Serializer_v1.80]"))
            {
                throw new InternalError( 
                            "Invalid file: version incompatible, file reports " ~ ver,
                            "Serializer.readFileHeader");
            }
            mVersion = ver;
        }
        else
        {
            throw new InternalError("Invalid file: no header", 
                        "Serializer.readFileHeader");
        }
    }

    void readBone(DataStream stream, ref Skeleton pSkel)
    {
        // char* name
        string name = readString(stream);
        // ushort handle            : handle of the bone, should be contiguous & start at 0
        ushort handle;
        readShorts(stream, &handle, 1);
        
        // Create new bone
        Bone pBone = pSkel.createBone(name, handle);
        
        // Vector3 position                 : position of this bone relative to parent 
        Vector3 pos;
        readObject(stream, pos);
        pBone.setPosition(pos);
        // Quaternion orientation           : orientation of this bone relative to parent 
        Quaternion q;
        readObject(stream, q);
        pBone.setOrientation(q);
        // Do we have scale?
        if (mCurrentstreamLen > calcBoneSizeWithoutScale(pSkel, pBone))
        {
            Vector3 scale;
            readObject(stream, scale);
            pBone.setScale(scale);
        }
    }

    void readBoneParent(DataStream stream, ref Skeleton pSkel)
    {
        // All bones have been created by this point
        Bone child, parent;
        ushort childHandle, parentHandle;
        
        // ushort handle             : child bone
        readShorts(stream, &childHandle, 1);
        // ushort parentHandle   : parent bone
        readShorts(stream, &parentHandle, 1);
        
        // Find bones
        parent = pSkel.getBone(parentHandle);
        child = pSkel.getBone(childHandle);
        
        // attach
        parent.addChild(child);
        
    }

    void readAnimation(DataStream stream, ref Skeleton pSkel)
    {
        // char* name                       : Name of the animation
        string name = readString(stream);
        // float length                      : Length of the animation in seconds
        float len;
        readFloats(stream, &len, 1);
        
        Animation pAnim = pSkel.createAnimation(name, len);
        
        // Read all tracks
        if (!stream.eof())
        {
            ushort streamID = readChunk(stream);
            // Optional base info is possible
            if (streamID == SkeletonChunkID.SKELETON_ANIMATION_BASEINFO)
            {
                // char baseAnimationName
                string baseAnimName = readString(stream);
                // float baseKeyFrameTime
                float baseKeyTime;
                readFloats(stream, &baseKeyTime, 1);
                
                pAnim.setUseBaseKeyFrame(true, baseKeyTime, baseAnimName);
                
                if (!stream.eof())
                {
                    // Get next stream
                    streamID = readChunk(stream);
                }
            }
            
            while(streamID == SkeletonChunkID.SKELETON_ANIMATION_TRACK && !stream.eof())
            {
                readAnimationTrack(stream, pAnim, pSkel);
                
                if (!stream.eof())
                {
                    // Get next stream
                    streamID = readChunk(stream);
                }
            }
            if (!stream.eof())
            {
                // Backpedal back to start of this stream if we've found a non-track
                stream.skip(-SSTREAM_OVERHEAD_SIZE);
            }
            
        }

    }

    void readAnimationTrack(DataStream stream, ref Animation anim, ref Skeleton pSkel)
    {
        // ushort boneIndex     : Index of bone to apply to
        ushort boneHandle;
        readShorts(stream, &boneHandle, 1);
        
        // Find bone
        Bone targetBone = pSkel.getBone(boneHandle);
        
        // Create track
        NodeAnimationTrack pTrack = anim.createNodeTrack(boneHandle, targetBone);
        
        // Keep looking for nested keyframes
        if (!stream.eof())
        {
            ushort streamID = readChunk(stream);
            while(streamID == SkeletonChunkID.SKELETON_ANIMATION_TRACK_KEYFRAME && !stream.eof())
            {
                readKeyFrame(stream, pTrack, pSkel);
                
                if (!stream.eof())
                {
                    // Get next stream
                    streamID = readChunk(stream);
                }
            }
            if (!stream.eof())
            {
                // Backpedal back to start of this stream if we've found a non-keyframe
                stream.skip(-SSTREAM_OVERHEAD_SIZE);
            }
            
        }
        
        
    }

    void readKeyFrame(DataStream stream, ref NodeAnimationTrack track, ref Skeleton pSkel)
    {
        // float time                    : The time position (seconds)
        float time;
        readFloats(stream, &time, 1);
        
        TransformKeyFrame kf = track.createNodeKeyFrame(time);
        
        // Quaternion rotate            : Rotation to apply at this keyframe
        Quaternion rot;
        readObject(stream, rot);
        kf.setRotation(rot);
        // Vector3 translate            : Translation to apply at this keyframe
        Vector3 trans;
        readObject(stream, trans);
        kf.setTranslate(trans);
        // Do we have scale?
        if (mCurrentstreamLen > calcKeyFrameSizeWithoutScale(pSkel, kf))
        {
            Vector3 scale;
            readObject(stream, scale);
            kf.setScale(scale);
        }
    }

    void readSkeletonAnimationLink(DataStream stream, ref Skeleton pSkel)
    {
        // char* skeletonName
        string skelName = readString(stream);
        // float scale
        float scale;
        readFloats(stream, &scale, 1);
        
        pSkel.addLinkedSkeletonAnimationSource(skelName, scale);
        
    }
    
    size_t calcBoneSize(ref Skeleton pSkel, ref Bone pBone)
    {
        size_t size = SSTREAM_OVERHEAD_SIZE;
        
        // handle
        size += ushort.sizeof;
        
        // position
        size += float.sizeof * 3;
        
        // orientation
        size += float.sizeof * 4;
        
        // scale
        if (pBone.getScale() != Vector3.UNIT_SCALE)
        {
            size += float.sizeof * 3;
        }
        
        return size;
    }

    size_t calcBoneSizeWithoutScale(ref Skeleton pSkel, ref Bone pBone)
    {
        size_t size = SSTREAM_OVERHEAD_SIZE;
        
        // handle
        size += ushort.sizeof;
        
        // position
        size += float.sizeof * 3;
        
        // orientation
        size += float.sizeof * 4;
        
        return size;
    }

    size_t calcBoneParentSize(ref Skeleton pSkel)
    {
        size_t size = SSTREAM_OVERHEAD_SIZE;
        
        // handle
        size += ushort.sizeof;
        
        // parent handle
        size += ushort.sizeof;
        
        return size;
    }

    size_t calcAnimationSize(ref Skeleton pSkel, Animation pAnim)
    {
        size_t size = SSTREAM_OVERHEAD_SIZE;
        
        // Name, including terminator
        size += pAnim.getName().length + 1;
        // length
        size += float.sizeof;
        
        // Nested animation tracks
        auto trackIt = pAnim.getNodeTracks();
        foreach(track; trackIt)
        {
            size += calcAnimationTrackSize(pSkel, track);
        }
        
        return size;
    }

    size_t calcAnimationTrackSize(ref Skeleton pSkel, NodeAnimationTrack pTrack)
    {
        size_t size = SSTREAM_OVERHEAD_SIZE;
        
        // ushort boneIndex     : Index of bone to apply to
        size += ushort.sizeof;
        
        // Nested keyframes
        for (ushort i = 0; i < pTrack.getNumKeyFrames(); ++i)
        {
            size += calcKeyFrameSize(pSkel, pTrack.getNodeKeyFrame(i));
        }
        
        return size;
    }

    size_t calcKeyFrameSize(ref Skeleton pSkel, TransformKeyFrame pKey)
    {
        size_t size = SSTREAM_OVERHEAD_SIZE;
        
        // float time                    : The time position (seconds)
        size += float.sizeof;
        // Quaternion rotate            : Rotation to apply at this keyframe
        size += float.sizeof * 4;
        // Vector3 translate            : Translation to apply at this keyframe
        size += float.sizeof * 3;
        // Vector3 scale                : Scale to apply at this keyframe
        if (pKey.getScale() != Vector3.UNIT_SCALE)
        {
            size += float.sizeof * 3;
        }
        
        return size;
    }

    size_t calcKeyFrameSizeWithoutScale(ref Skeleton pSkel, TransformKeyFrame pKey)
    {
        size_t size = SSTREAM_OVERHEAD_SIZE;
        
        // float time                    : The time position (seconds)
        size += float.sizeof;
        // Quaternion rotate            : Rotation to apply at this keyframe
        size += float.sizeof * 4;
        // Vector3 translate            : Translation to apply at this keyframe
        size += float.sizeof * 3;
        
        return size;
    }

    size_t calcSkeletonAnimationLinkSize(ref Skeleton pSkel, 
                                         LinkedSkeletonAnimationSource* link)
    {
        size_t size = SSTREAM_OVERHEAD_SIZE;
        
        // char* skeletonName
        size += link.skeletonName.length + 1;
        // float scale
        size += float.sizeof;
        
        return size;
        
    }

}
/** @} */
/** @} */