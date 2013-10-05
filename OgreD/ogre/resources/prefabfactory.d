module ogre.resources.prefabfactory;
import ogre.resources.mesh;
import ogre.rendersystem.vertex;
import ogre.math.axisalignedbox;
import ogre.math.maths;
import ogre.compat;
import ogre.rendersystem.hardware;
import ogre.math.vector;
import core.math;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Resources
 *  @{
 */
/** A factory class that can create various mesh prefabs. 
 @remarks
 This class is used by OgreMeshManager to offload the loading of various prefab types 
 to a central location.
 */
class PrefabFactory
{
public:
    /** If the given mesh has a known prefab resource name (e.g "Prefab_Plane") 
     then this prefab will be created as a submesh of the given mesh.

     @param mesh The mesh that the potential prefab will be created in.
     @return true if a prefab has been created, otherwise false.
     */
    static bool createPrefab(ref Mesh mesh)
    {
        string resourceName = mesh.getName();
        
        if(resourceName == "Prefab_Plane")
        {
            createPlane(mesh);
            return true;
        }
        else if(resourceName == "Prefab_Cube")
        {
            createCube(mesh);
            return true;
        }
        else if(resourceName == "Prefab_Sphere")
        {
            createSphere(mesh);
            return true;
        }
        
        return false;
    }

private:
    /// Creates a plane as a submesh of the given mesh
    static void createPlane(ref Mesh mesh)
    {
        SubMesh sub = mesh.createSubMesh();
        float[32] vertices = [
                              -100, -100, 0,  // pos
                              0,0,1,          // normal
                              0,1,            // texcoord
                              100, -100, 0,
                              0,0,1,
                              1,1,
                              100,  100, 0,
                              0,0,1,
                              1,0,
                              -100,  100, 0 ,
                              0,0,1,
                              0,0 
                              ];
        mesh.sharedVertexData = new VertexData();
        mesh.sharedVertexData.vertexCount = 4;
        VertexDeclaration decl = mesh.sharedVertexData.vertexDeclaration;
        VertexBufferBinding bind = mesh.sharedVertexData.vertexBufferBinding;
        
        size_t offset = 0;
        decl.addElement(0, offset, VertexElementType.VET_FLOAT3, VertexElementSemantic.VES_POSITION);
        offset += VertexElement.getTypeSize(VertexElementType.VET_FLOAT3);
        decl.addElement(0, offset, VertexElementType.VET_FLOAT3, VertexElementSemantic.VES_NORMAL);
        offset += VertexElement.getTypeSize(VertexElementType.VET_FLOAT3);
        decl.addElement(0, offset, VertexElementType.VET_FLOAT2, VertexElementSemantic.VES_TEXTURE_COORDINATES, 0);
        offset += VertexElement.getTypeSize(VertexElementType.VET_FLOAT2);
        
        SharedPtr!HardwareVertexBuffer vBuf = 
            HardwareBufferManager.getSingleton().createVertexBuffer(
                offset, 4, HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY);
        mesh.sharedVertexData.vertexBufferBinding.setBinding(0, vBuf);
        debug(STDERR) std.stdio.stderr.writeln("PrefabFactory.createPlane vbuf@",vBuf._refCounted._store," ref:", vBuf._refCounted.refCount);
        
        vBuf.get().writeData(0, vBuf.get().getSizeInBytes(), vertices.ptr, true);
        
        sub.useSharedVertices = true;
        SharedPtr!HardwareIndexBuffer ibuf = HardwareBufferManager.getSingleton().
            createIndexBuffer(
                HardwareIndexBuffer.IndexType.IT_16BIT, 
                6, 
                HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY);
        
        ushort[6] faces = [0,1,2,
                           0,2,3 ];
        sub.indexData.indexBuffer = ibuf;
        sub.indexData.indexCount = 6;
        sub.indexData.indexStart =0;
        ibuf.get().writeData(0, ibuf.get().getSizeInBytes(), faces.ptr, true);
        
        mesh._setBounds(AxisAlignedBox(-100,-100,0,100,100,0), true);
        mesh._setBoundingSphereRadius(Math.Sqrt(100*100+100*100));
        debug(STDERR) std.stdio.stderr.writeln("PrefabFactory.createPlane vbuf@",vBuf._refCounted._store," ref:", vBuf._refCounted.refCount);
        debug(STDERR) std.stdio.stderr.writeln("PrefabFactory.createPlane ibuf ref:", ibuf._refCounted.refCount);
    }
    
    /// Creates a 100x100x100 cube as a submesh of the given mesh
    static void createCube(ref Mesh mesh)
    {
        SubMesh sub = mesh.createSubMesh();
        
        const int NUM_VERTICES = 4 * 6; // 4 vertices per side * 6 sides
        const int NUM_ENTRIES_PER_VERTEX = 8;
        const int NUM_VERTEX_ENTRIES = NUM_VERTICES * NUM_ENTRIES_PER_VERTEX;
        const int NUM_INDICES = 3 * 2 * 6; // 3 indices per face * 2 faces per side * 6 sides
        
        Real CUBE_SIZE = 100.0f;
        Real CUBE_HALF_SIZE = CUBE_SIZE / 2.0f;
        
        // Create 4 vertices per side instead of 6 that are shared for the whole cube.
        // The reason for this is with only 6 vertices the normals will look bad
        // since each vertex can "point" in a different direction depending on the face it is included in.
        float[NUM_VERTEX_ENTRIES] vertices = 
            [
             // front side
             -CUBE_HALF_SIZE, -CUBE_HALF_SIZE, CUBE_HALF_SIZE,   // pos
             0,0,1,  // normal
             0,1,    // texcoord
             CUBE_HALF_SIZE, -CUBE_HALF_SIZE, CUBE_HALF_SIZE,
             0,0,1,
             1,1,
             CUBE_HALF_SIZE,  CUBE_HALF_SIZE, CUBE_HALF_SIZE,
             0,0,1,
             1,0,
             -CUBE_HALF_SIZE,  CUBE_HALF_SIZE, CUBE_HALF_SIZE ,
             0,0,1,
             0,0,
             
             // back side
             CUBE_HALF_SIZE, -CUBE_HALF_SIZE, -CUBE_HALF_SIZE,
             0,0,-1,
             0,1,
             -CUBE_HALF_SIZE, -CUBE_HALF_SIZE, -CUBE_HALF_SIZE,
             0,0,-1,
             1,1,
             -CUBE_HALF_SIZE, CUBE_HALF_SIZE, -CUBE_HALF_SIZE,
             0,0,-1,
             1,0,
             CUBE_HALF_SIZE, CUBE_HALF_SIZE, -CUBE_HALF_SIZE,
             0,0,-1,
             0,0,
             
             // left side
             -CUBE_HALF_SIZE, -CUBE_HALF_SIZE, -CUBE_HALF_SIZE,
             -1,0,0,
             0,1,
             -CUBE_HALF_SIZE, -CUBE_HALF_SIZE, CUBE_HALF_SIZE,
             -1,0,0,
             1,1,
             -CUBE_HALF_SIZE, CUBE_HALF_SIZE, CUBE_HALF_SIZE,
             -1,0,0,
             1,0,
             -CUBE_HALF_SIZE, CUBE_HALF_SIZE, -CUBE_HALF_SIZE,
             -1,0,0,
             0,0, 
             
             // right side
             CUBE_HALF_SIZE, -CUBE_HALF_SIZE, CUBE_HALF_SIZE,
             1,0,0,
             0,1,
             CUBE_HALF_SIZE, -CUBE_HALF_SIZE, -CUBE_HALF_SIZE,
             1,0,0,
             1,1,
             CUBE_HALF_SIZE, CUBE_HALF_SIZE, -CUBE_HALF_SIZE,
             1,0,0,
             1,0,
             CUBE_HALF_SIZE, CUBE_HALF_SIZE, CUBE_HALF_SIZE,
             1,0,0,
             0,0,
             
             // up side
             -CUBE_HALF_SIZE, CUBE_HALF_SIZE, CUBE_HALF_SIZE,
             0,1,0,
             0,1,
             CUBE_HALF_SIZE, CUBE_HALF_SIZE, CUBE_HALF_SIZE,
             0,1,0,
             1,1,
             CUBE_HALF_SIZE, CUBE_HALF_SIZE, -CUBE_HALF_SIZE,
             0,1,0,
             1,0,
             -CUBE_HALF_SIZE, CUBE_HALF_SIZE, -CUBE_HALF_SIZE,
             0,1,0,
             0,0,
             
             // down side
             -CUBE_HALF_SIZE, -CUBE_HALF_SIZE, -CUBE_HALF_SIZE,
             0,-1,0,
             0,1,
             CUBE_HALF_SIZE, -CUBE_HALF_SIZE, -CUBE_HALF_SIZE,
             0,-1,0,
             1,1,
             CUBE_HALF_SIZE, -CUBE_HALF_SIZE, CUBE_HALF_SIZE,
             0,-1,0,
             1,0,
             -CUBE_HALF_SIZE, -CUBE_HALF_SIZE, CUBE_HALF_SIZE,
             0,-1,0,
             0,0 ];
        
        mesh.sharedVertexData = new VertexData();
        mesh.sharedVertexData.vertexCount = NUM_VERTICES;
        VertexDeclaration decl = mesh.sharedVertexData.vertexDeclaration;
        VertexBufferBinding bind = mesh.sharedVertexData.vertexBufferBinding;
        
        size_t offset = 0;
        decl.addElement(0, offset, VertexElementType.VET_FLOAT3, VertexElementSemantic.VES_POSITION);
        offset += VertexElement.getTypeSize(VertexElementType.VET_FLOAT3);
        decl.addElement(0, offset, VertexElementType.VET_FLOAT3, VertexElementSemantic.VES_NORMAL);
        offset += VertexElement.getTypeSize(VertexElementType.VET_FLOAT3);
        decl.addElement(0, offset, VertexElementType.VET_FLOAT2, VertexElementSemantic.VES_TEXTURE_COORDINATES, 0);
        offset += VertexElement.getTypeSize(VertexElementType.VET_FLOAT2);
        
        SharedPtr!HardwareVertexBuffer vBuf = 
            HardwareBufferManager.getSingleton().createVertexBuffer(
                offset, NUM_VERTICES, HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY);
        bind.setBinding(0, vBuf);
        
        vBuf.get().writeData(0, vBuf.get().getSizeInBytes(), vertices.ptr, true);
        
        sub.useSharedVertices = true;
        SharedPtr!HardwareIndexBuffer ibuf = HardwareBufferManager.getSingleton().
            createIndexBuffer(
                HardwareIndexBuffer.IndexType.IT_16BIT, 
                NUM_INDICES,
                HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY);
        
        ushort[NUM_INDICES] faces = 
            [
             // front
             0,1,2,
             0,2,3,
             
             // back
             4,5,6,
             4,6,7,
             
             // left
             8,9,10,
             8,10,11,
             
             // right
             12,13,14,
             12,14,15,
             
             // up
             16,17,18,
             16,18,19,
             
             // down
             20,21,22,
             20,22,23
             ];
        
        sub.indexData.indexBuffer = ibuf;
        sub.indexData.indexCount = NUM_INDICES;
        sub.indexData.indexStart = 0;
        ibuf.get().writeData(0, ibuf.get().getSizeInBytes(), faces.ptr, true);
        
        mesh._setBounds(AxisAlignedBox(-CUBE_HALF_SIZE, -CUBE_HALF_SIZE, -CUBE_HALF_SIZE,
                                       CUBE_HALF_SIZE, CUBE_HALF_SIZE, CUBE_HALF_SIZE), true);
        
        mesh._setBoundingSphereRadius(CUBE_HALF_SIZE);
    }
    
    /// Creates a sphere with a diameter of 100 units as a submesh of the given mesh
    static void createSphere(ref Mesh mesh)
    {
        // sphere creation code taken from the DeferredShading sample, originally from the wiki
        SubMesh pSphereVertex = mesh.createSubMesh();
        
        int NUM_SEGMENTS = 16;
        int NUM_RINGS = 16;
        Real SPHERE_RADIUS = 50.0;
        
        mesh.sharedVertexData = new VertexData();
        VertexData vertexData = mesh.sharedVertexData;
        
        // define the vertex format
        VertexDeclaration vertexDecl = vertexData.vertexDeclaration;
        size_t currOffset = 0;
        // positions
        vertexDecl.addElement(0, currOffset, VertexElementType.VET_FLOAT3, VertexElementSemantic.VES_POSITION);
        currOffset += VertexElement.getTypeSize(VertexElementType.VET_FLOAT3);
        // normals
        vertexDecl.addElement(0, currOffset, VertexElementType.VET_FLOAT3, VertexElementSemantic.VES_NORMAL);
        currOffset += VertexElement.getTypeSize(VertexElementType.VET_FLOAT3);
        // two dimensional texture coordinates
        vertexDecl.addElement(0, currOffset, VertexElementType.VET_FLOAT2, VertexElementSemantic.VES_TEXTURE_COORDINATES, 0);
        
        // allocate the vertex buffer
        vertexData.vertexCount = (NUM_RINGS + 1) * (NUM_SEGMENTS+1);
        SharedPtr!HardwareVertexBuffer vBuf = HardwareBufferManager.getSingleton().createVertexBuffer(vertexDecl.getVertexSize(0), vertexData.vertexCount, HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY, false);
        VertexBufferBinding binding = vertexData.vertexBufferBinding;
        binding.setBinding(0, vBuf);
        float* pVertex = cast(float*)(vBuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
        
        // allocate index buffer
        pSphereVertex.indexData.indexCount = 6 * NUM_RINGS * (NUM_SEGMENTS + 1);
        pSphereVertex.indexData.indexBuffer = HardwareBufferManager.getSingleton().createIndexBuffer(HardwareIndexBuffer.IndexType.IT_16BIT, pSphereVertex.indexData.indexCount, HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY, false);
        SharedPtr!HardwareIndexBuffer iBuf = pSphereVertex.indexData.indexBuffer;
        ushort* pIndices = cast(ushort*)(iBuf.get().lock(HardwareBuffer.LockOptions.HBL_DISCARD));
        
        float fDeltaRingAngle = (Math.PI / NUM_RINGS);
        float fDeltaSegAngle = (2 * Math.PI / NUM_SEGMENTS);
        ushort wVerticeIndex = 0 ;
        
        // Generate the group of rings for the sphere
        for( int ring = 0; ring <= NUM_RINGS; ring++ ) {
            float r0 = SPHERE_RADIUS * sin (ring * fDeltaRingAngle);
            float y0 = SPHERE_RADIUS * cos (ring * fDeltaRingAngle);
            
            // Generate the group of segments for the current ring
            for(int seg = 0; seg <= NUM_SEGMENTS; seg++) {
                float x0 = r0 * sin(seg * fDeltaSegAngle);
                float z0 = r0 * cos(seg * fDeltaSegAngle);
                
                // Add one vertex to the strip which makes up the sphere
                *pVertex++ = x0;
                *pVertex++ = y0;
                *pVertex++ = z0;
                
                Vector3 vNormal = Vector3(x0, y0, z0).normalisedCopy();
                *pVertex++ = vNormal.x;
                *pVertex++ = vNormal.y;
                *pVertex++ = vNormal.z;
                
                *pVertex++ = cast(float) seg / cast(float) NUM_SEGMENTS;
                *pVertex++ = cast(float) ring / cast(float) NUM_RINGS;
                
                if (ring != NUM_RINGS) {
                    // each vertex (except the last) has six indicies pointing to it
                    *pIndices++ = cast(ushort)(wVerticeIndex + NUM_SEGMENTS + 1);
                    *pIndices++ = wVerticeIndex;               
                    *pIndices++ = cast(ushort)(wVerticeIndex + NUM_SEGMENTS);
                    *pIndices++ = cast(ushort)(wVerticeIndex + NUM_SEGMENTS + 1);
                    *pIndices++ = cast(ushort)(wVerticeIndex + 1);
                    *pIndices++ = wVerticeIndex;
                    wVerticeIndex ++;
                }
            }; // end for seg
        } // end for ring
        
        // Unlock
        vBuf.get().unlock();
        iBuf.get().unlock();
        // Generate face list
        pSphereVertex.useSharedVertices = true;
        
        // the original code was missing this line:
        mesh._setBounds( AxisAlignedBox( Vector3(-SPHERE_RADIUS, -SPHERE_RADIUS, -SPHERE_RADIUS), 
                                        Vector3(SPHERE_RADIUS, SPHERE_RADIUS, SPHERE_RADIUS) ), false );
        
        mesh._setBoundingSphereRadius(SPHERE_RADIUS);
    }
}
/** @} */
/** @} */