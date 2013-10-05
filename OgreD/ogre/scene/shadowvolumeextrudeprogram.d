module ogre.scene.shadowvolumeextrudeprogram;
import std.array;
import ogre.scene.light;
import ogre.exception;
import ogre.resources.resourcegroupmanager;
import ogre.materials.gpuprogram;
import ogre.resources.highlevelgpuprogram;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Scene
 *  @{
 */
/** Static class containing source for vertex programs for extruding shadow volumes
 @remarks
     This exists so we don't have to be dependent on an external media files.
     Assembler is used so we don't have to rely on particular plugins.
     The assembler contents of this file were generated from the following Cg:
 @code
     // Point light shadow volume extrude
     void shadowVolumeExtrudePointLight_vp (
         float4 position         : POSITION,
         float  wcoord           : TEXCOORD0,
        
         out float4 oPosition    : POSITION,
        
         uniform float4x4 worldViewProjMatrix,
         uniform float4   lightPos // homogeneous, object space
     )
     {
         // extrusion in object space
         // vertex unmodified if w==1, extruded if w==0
         float4 newpos = 
            (wcoord.xxxx * lightPos) + 
            float4(position.xyz - lightPos.xyz, 0);
        
         oPosition = mul(worldViewProjMatrix, newpos);
    
     }
    
     // Directional light extrude
     void shadowVolumeExtrudeDirLight_vp (
         float4 position         : POSITION,
         float  wcoord           : TEXCOORD0,
        
         out float4 oPosition    : POSITION,
        
         uniform float4x4 worldViewProjMatrix,
         uniform float4   lightPos // homogenous, object space
     )
     {
         // extrusion in object space
         // vertex unmodified if w==1, extruded if w==0
         float4 newpos = 
            (wcoord.xxxx * (position + lightPos)) - lightPos;
        
         oPosition = mul(worldViewProjMatrix, newpos);
        
     }
     // Point light shadow volume extrude - FINITE
     void shadowVolumeExtrudePointLightFinite_vp (
         float4 position         : POSITION,
         float  wcoord           : TEXCOORD0,
        
         out float4 oPosition    : POSITION,
        
         uniform float4x4 worldViewProjMatrix,
         uniform float4   lightPos, // homogeneous, object space
         uniform float    extrusionDistance // how far to extrude
     )
     {
         // extrusion in object space
         // vertex unmodified if w==1, extruded if w==0
         float3 extrusionDir = position.xyz - lightPos.xyz;
         extrusionDir = normalize(extrusionDir);
         
         float4 newpos = float4(position.xyz +  
            ((1 - wcoord.x) * extrusionDistance * extrusionDir), 1);
        
         oPosition = mul(worldViewProjMatrix, newpos);
    
     }
    
     // Directional light extrude - FINITE
     void shadowVolumeExtrudeDirLightFinite_vp (
         float4 position         : POSITION,
         float  wcoord           : TEXCOORD0,
        
         out float4 oPosition    : POSITION,
        
         uniform float4x4 worldViewProjMatrix,
         uniform float4   lightPos, // homogeneous, object space
         uniform float    extrusionDistance // how far to extrude
     )
     {
         // extrusion in object space
         // vertex unmodified if w==1, extruded if w==0
         // -ve lightPos is direction
        float4 newpos = float4(position.xyz - 
            (wcoord.x * extrusionDistance * lightPos.xyz), 1);
    
        oPosition = mul(worldViewProjMatrix, newpos);
    
     }       
 @endcode
 */
class ShadowVolumeExtrudeProgram //: public ShadowDataAlloc
{
private:
    enum string mPointArbvp1 = 
        `!!ARBvp1.0
        PARAM c5 = { 0, 0, 0, 0 };
        TEMP R0;
        ATTRIB v24 = vertex.texcoord[0];
        ATTRIB v16 = vertex.position;
        PARAM c0[4] = { program.local[0..3] };
        PARAM c4 = program.local[4];
        ADD R0.xyz, v16.xyzx, -c4.xyzx;
        MOV R0.w, c5.x;
        MAD R0, v24.x, c4, R0;
        DP4 result.position.x, c0[0], R0;
        DP4 result.position.y, c0[1], R0;
        DP4 result.position.z, c0[2], R0;
        DP4 result.position.w, c0[3], R0;
        END`;

    enum string mPointVs_1_1 = 
        `vs_1_1
        def c5, 0, 0, 0, 0
        dcl_texcoord0 v7
        dcl_position v0
        add r0.xyz, v0.xyz, -c4.xyz
        mov r0.w, c5.x
        mad r0, v7.x, c4, r0
        dp4 oPos.x, c0, r0
        dp4 oPos.y, c1, r0
        dp4 oPos.z, c2, r0
        dp4 oPos.w, c3, r0`;

    enum string mPointVs_4_0 = 
        `// Point light shadow volume extrude
        struct VS_OUTPUT
        {
            float4 Pos : SV_POSITION;
        };
        VS_OUTPUT vs_main (
            float4 position        : POSITION,
            float  wcoord          : TEXCOORD0,
            uniform float4x4 worldviewproj_matrix,
            uniform float4   light_position_object_space // homogeneous, object space
        )
        {
            // extrusion in object space
            // vertex unmodified if w==1, extruded if w==0
            float4 newpos = 
                (wcoord.xxxx * light_position_object_space) + 
                float4(position.xyz - light_position_object_space.xyz, 0);
            
            VS_OUTPUT output = (VS_OUTPUT)0;
            output.Pos = mul(worldviewproj_matrix, newpos);
            return output;
        }`;

    enum string mPointVs_glsl = 
        `#version 150
        // Point light shadow volume extrude
        in vec4 uv0;
        in vec4 vertex;
        uniform mat4 worldviewproj_matrix;
        uniform vec4 light_position_object_space; // homogenous, object space
        void main()
        {
            // Extrusion in object space
            // Vertex unmodified if w==1, extruded if w==0
            vec4 newpos = 
                (uv0.xxxx * light_position_object_space) + 
                vec4(vertex.xyz - light_position_object_space.xyz, 0.0);
                
            gl_Position = worldviewproj_matrix * newpos;
        }`;
    
    enum string mPointVs_glsles = 
        `#version 100
        precision highp float;
        precision highp int;
        precision lowp sampler2D;
        precision lowp samplerCube;\n
        // Point light shadow volume extrude
        attribute vec4 uv0;
        attribute vec4 position;\n
        uniform mat4 worldviewproj_matrix;
        uniform vec4 light_position_object_space; // homogenous, object space\n
        void main()
        {
            // Extrusion in object space
            // Vertex unmodified if w==1, extruded if w==0
            vec4 newpos = 
                (uv0.xxxx * light_position_object_space) + 
                vec4(position.xyz - light_position_object_space.xyz, 0.0);
            
            gl_Position = worldviewproj_matrix * newpos;
        }`;

    enum string mDirArbvp1 = 
        `!!ARBvp1.0
        TEMP R0;
        ATTRIB v24 = vertex.texcoord[0];
        ATTRIB v16 = vertex.position;
        PARAM c0[4] = { program.local[0..3] };
        PARAM c4 = program.local[4];
        ADD R0, v16, c4;
        MAD R0, v24.x, R0, -c4;
        DP4 result.position.x, c0[0], R0;
        DP4 result.position.y, c0[1], R0;
        DP4 result.position.z, c0[2], R0;
        DP4 result.position.w, c0[3], R0;
        END`;

    enum string mDirVs_1_1 = 
        `vs_1_1
        dcl_texcoord0 v7
        dcl_position v0
        add r0, v0, c4
        mad r0, v7.x, r0, -c4
        dp4 oPos.x, c0, r0
        dp4 oPos.y, c1, r0
        dp4 oPos.z, c2, r0
        dp4 oPos.w, c3, r0`;

    enum string mDirVs_4_0 = 
        `// Directional light extrude
        struct VS_OUTPUT
        {
            float4 Pos : SV_POSITION;
        };
        VS_OUTPUT vs_main (
            float4 position        : POSITION,
            float  wcoord          : TEXCOORD0,
        
            uniform float4x4 worldviewproj_matrix,
            uniform float4   light_position_object_space // homogenous, object space
            )
        {
            // extrusion in object space
            // vertex unmodified if w==1, extruded if w==0
            float4 newpos = 
                (wcoord.xxxx * (position + light_position_object_space)) - light_position_object_space;
        
            VS_OUTPUT output = (VS_OUTPUT)0;
            output.Pos = mul(worldviewproj_matrix, newpos);
            return output;
        }`;

    enum string mDirVs_glsl = 
        `#version 150
        // Directional light extrude
        in vec4 uv0;
        in vec4 vertex;
        uniform mat4 worldviewproj_matrix;
        uniform vec4 light_position_object_space; // homogenous, object space
        void main()
        {
            // Extrusion in object space
            // Vertex unmodified if w==1, extruded if w==0
            vec4 newpos = 
                (uv0.xxxx * (vertex + light_position_object_space)) - light_position_object_space;
        
            gl_Position = worldviewproj_matrix * newpos;
        }`;
    
    enum string mDirVs_glsles = 
        `#version 100
        precision highp float;
        precision highp int;
        precision lowp sampler2D;
        precision lowp samplerCube;\n
        // Directional light extrude
        attribute vec4 uv0;
        attribute vec4 position;\n
        uniform mat4 worldviewproj_matrix;
        uniform vec4 light_position_object_space; // homogenous, object space\n
        void main()
        {
            // Extrusion in object space
            // Vertex unmodified if w==1, extruded if w==0
            vec4 newpos = 
                (uv0.xxxx * (position + light_position_object_space)) - light_position_object_space;
        
            gl_Position = worldviewproj_matrix * newpos;
        }`;

    // same as above, except the color is set to 1 to enable _debug volumes to be seen
    enum string mPointArbvp1_debug = 
        `!!ARBvp1.0
        PARAM c5 = { 0, 0, 0, 0 };
        PARAM c6 = { 1, 1, 1, 1 };
        TEMP R0;
        ATTRIB v24 = vertex.texcoord[0];
        ATTRIB v16 = vertex.position;
        PARAM c0[4] = { program.local[0..3] };
        PARAM c4 = program.local[4];
        ADD R0.xyz, v16.xyzx, -c4.xyzx;
        MOV R0.w, c5.x;
        MAD R0, v24.x, c4, R0;
        DP4 result.position.x, c0[0], R0;
        DP4 result.position.y, c0[1], R0;
        DP4 result.position.z, c0[2], R0;
        DP4 result.position.w, c0[3], R0;
        MOV result.color.front.primary, c6.x;
        END`;

    enum string mPointVs_1_1_debug = 
        `vs_1_1
        def c5, 0, 0, 0, 0
        def c6, 1, 1, 1, 1
        dcl_texcoord0 v7
        dcl_position v0
        add r0.xyz, v0.xyz, -c4.xyz
        mov r0.w, c5.x
        mad r0, v7.x, c4, r0
        dp4 oPos.x, c0, r0
        dp4 oPos.y, c1, r0
        dp4 oPos.z, c2, r0
        dp4 oPos.w, c3, r0
        mov oD0, c6.x`;

    //static string mPointVs_4_0Debug;// = mPointVs_4_0;
    //static string mPointVs_glslDebug = mPointVs_glsl;
    //static string mPointVs_glslesDebug;// = mPointVs_glsles;
    alias mPointVs_4_0 mPointVs_4_0Debug;
    alias mPointVs_glsl mPointVs_glslDebug;
    alias mPointVs_glsles mPointVs_glslesDebug;

    enum string mDirArbvp1_debug = 
        `!!ARBvp1.0
        PARAM c5 = { 1, 1, 1, 1};
        TEMP R0;
        ATTRIB v24 = vertex.texcoord[0];
        ATTRIB v16 = vertex.position;
        PARAM c0[4] = { program.local[0..3] };
        PARAM c4 = program.local[4];
        ADD R0, v16, c4;
        MAD R0, v24.x, R0, -c4;
        DP4 result.position.x, c0[0], R0;
        DP4 result.position.y, c0[1], R0;
        DP4 result.position.z, c0[2], R0;
        DP4 result.position.w, c0[3], R0;
        MOV result.color.front.primary, c5.x;"
        END`;

    enum string mDirVs_1_1_debug = 
        `vs_1_1
        def c5, 1, 1, 1, 1
        dcl_texcoord0 v7
        dcl_position v0
        add r0, v0, c4
        mad r0, v7.x, r0, -c4
        dp4 oPos.x, c0, r0
        dp4 oPos.y, c1, r0
        dp4 oPos.z, c2, r0
        dp4 oPos.w, c3, r0
        mov oD0, c5.x`;

    //enum string mDirVs_4_0Debug;// = mDirVs_4_0;
    //enum string mDirVs_glslDebug = mDirVs_glsl;
    //enum string mDirVs_glslesDebug;// = mDirVs_glsles;
    alias mDirVs_4_0 mDirVs_4_0Debug;
    alias mDirVs_glsl mDirVs_glslDebug;
    alias mDirVs_glsles mDirVs_glslesDebug;
    
    enum string mPointArbvp1Finite = 
        `!!ARBvp1.0 
        PARAM c6 = { 1, 0, 0, 0 };
        TEMP R0, R1;
        ATTRIB v24 = vertex.texcoord[0];
        ATTRIB v16 = vertex.position;
        PARAM c0[4] = { program.local[0..3] };
        PARAM c5 = program.local[5];
        PARAM c4 = program.local[4];
        ADD R0.x, c6.x, -v24.x;
        MUL R0.w, R0.x, c5.x;
        ADD R0.xyz, v16.xyzx, -c4.xyzx;
        DP3 R1.w, R0.xyzx, R0.xyzx;     // R1.w = Vector3(vertex - lightpos).sqrLength()
        RSQ R1.w, R1.w;             // R1.w = 1 / Vector3(vertex - lightpos).length()
        MUL R0.xyz, R1.w, R0.xyzx;      // R0.xyz = Vector3(vertex - lightpos).normalisedCopy()
        MAD R0.xyz, R0.w, R0.xyzx, v16.xyzx;
        DPH result.position.x, R0.xyzz, c0[0];
        DPH result.position.y, R0.xyzz, c0[1];
        DPH result.position.z, R0.xyzz, c0[2];
        DPH result.position.w, R0.xyzz, c0[3];
        END`;

    enum string mPointVs_1_1Finite = 
        `vs_1_1
        def c6, 1, 0, 0, 0
        dcl_texcoord0 v7
        dcl_position v0
        add r0.x, c6.x, -v7.x
        mul r1.x, r0.x, c5.x
        add r0.yzw, v0.xxyz, -c4.xxyz
        dp3 r0.x, r0.yzw, r0.yzw
        rsq r0.x, r0.x
        mul r0.xyz, r0.x, r0.yzw
        mad r0.xyz, r1.x, r0.xyz, v0.xyz
        mov r0.w, c6.x
        dp4 oPos.x, c0, r0
        dp4 oPos.y, c1, r0
        dp4 oPos.z, c2, r0
        dp4 oPos.w, c3, r0`;

    enum string mPointVs_4_0Finite = 
        `// Point light shadow volume extrude - FINITE
        struct VS_OUTPUT
        {
            float4 Pos : SV_POSITION;
        };
        VS_OUTPUT vs_main (
            float4 position        : POSITION,
            float  wcoord          : TEXCOORD0,
        
            uniform float4x4 worldviewproj_matrix,
            uniform float4   light_position_object_space, // homogeneous, object space
           uniform float    shadow_extrusion_distance // how far to extrude
            )
        {
            // extrusion in object space
            // vertex unmodified if w==1, extruded if w==0
           float3 extrusionDir = position.xyz - light_position_object_space.xyz;
           extrusionDir = normalize(extrusionDir);
           
            float4 newpos = float4(position.xyz +  
                ((1 - wcoord.x) * shadow_extrusion_distance * extrusionDir), 1);
        
            VS_OUTPUT output = (VS_OUTPUT)0;
            output.Pos = mul(worldviewproj_matrix, newpos);
            return output;
        
        
        }`;

    enum string mPointVs_glslFinite = 
        `#version 150
        // Point light shadow volume extrude - FINITE
        in vec4 uv0;
        in vec4 vertex;
        uniform mat4 worldviewproj_matrix;
        uniform vec4 light_position_object_space; // homogenous, object space
        uniform float shadow_extrusion_distance; // how far to extrude
        void main()
        {
            // Extrusion in object space
            // Vertex unmodified if w==1, extruded if w==0
           vec3 extrusionDir = vertex.xyz - light_position_object_space.xyz;
           extrusionDir = normalize(extrusionDir);
           
            vec4 newpos = vec4(vertex.xyz +  
                ((1.0 - uv0.x) * shadow_extrusion_distance * extrusionDir), 1.0);
        
            gl_Position = worldviewproj_matrix * newpos;
        }`;
    
    enum string mPointVs_glslesFinite = 
        `#version 100
        precision highp float;
        precision highp int;
        precision lowp sampler2D;
        precision lowp samplerCube;\n
            // Point light shadow volume extrude - FINITE
            attribute vec4 uv0;
        attribute vec4 position;\n
            uniform mat4 worldviewproj_matrix;
        uniform vec4 light_position_object_space; // homogenous, object space
        uniform float shadow_extrusion_distance; // how far to extrude\n
        void main()
        {
            // Extrusion in object space
            // Vertex unmodified if w==1, extruded if w==0
            vec3 extrusionDir = position.xyz - light_position_object_space.xyz;
            extrusionDir = normalize(extrusionDir);
            
            vec4 newpos = vec4(position.xyz +  
                               ((1.0 - uv0.x) * shadow_extrusion_distance * extrusionDir), 1.0);
            
            gl_Position = worldviewproj_matrix * newpos;
        }`;

    enum string mDirArbvp1Finite = 
        `!!ARBvp1.0
        PARAM c6 = { 1, 0, 0, 0 };
        TEMP R0;
        ATTRIB v24 = vertex.texcoord[0];
        ATTRIB v16 = vertex.position;
        PARAM c0[4] = { program.local[0..3] };
        PARAM c4 = program.local[4];
        PARAM c5 = program.local[5];
        ADD R0.x, c6.x, -v24.x;
        MUL R0.x, R0.x, c5.x;
        MAD R0.xyz, -R0.x, c4.xyzx, v16.xyzx;
        DPH result.position.x, R0.xyzz, c0[0];
        DPH result.position.y, R0.xyzz, c0[1];
        DPH result.position.z, R0.xyzz, c0[2];
        DPH result.position.w, R0.xyzz, c0[3];
        END`;

    enum string mDirVs_1_1Finite = 
        `vs_1_1
        def c6, 1, 0, 0, 0
        dcl_texcoord0 v7
        dcl_position v0
        add r0.x, c6.x, -v7.x
        mul r0.x, r0.x, c5.x
        mad r0.xyz, -r0.x, c4.xyz, v0.xyz
        mov r0.w, c6.x
        dp4 oPos.x, c0, r0
        dp4 oPos.y, c1, r0
        dp4 oPos.z, c2, r0
        dp4 oPos.w, c3, r0`;

    enum string mDirVs_4_0Finite = 
        `// Directional light extrude - FINITE
        struct VS_OUTPUT
        {
            float4 Pos : SV_POSITION;
        };
        VS_OUTPUT vs_main (
            float4 position        : POSITION,
            float  wcoord          : TEXCOORD0,
            
            uniform float4x4 worldviewproj_matrix,
            uniform float4   light_position_object_space, // homogeneous, object space
            uniform float    shadow_extrusion_distance // how far to extrude
            )
        {
            // extrusion in object space
            // vertex unmodified if w==1, extruded if w==0
            // -ve light_position_object_space is direction
            float4 newpos = float4(position.xyz - 
                                   (wcoord.x * shadow_extrusion_distance * light_position_object_space.xyz), 1);
            
            VS_OUTPUT output = (VS_OUTPUT)0;
            output.Pos = mul(worldviewproj_matrix, newpos);
            return output;
            
        }`;

    enum string mDirVs_glslFinite = 
        `#version 150
        // Directional light extrude - FINITE
        in vec4 uv0;
        in vec4 vertex;
        uniform mat4 worldviewproj_matrix;
        uniform vec4 light_position_object_space; // homogenous, object space
        uniform float shadow_extrusion_distance;  // how far to extrude
        void main()
        {
            // Extrusion in object space
            // Vertex unmodified if w==1, extruded if w==0
            // -ve light_position_object_space is direction
            vec4 newpos = vec4(vertex.xyz - 
                (uv0.x * shadow_extrusion_distance * light_position_object_space.xyz), 1.0);
        
            gl_Position = worldviewproj_matrix * newpos;
        
        }`;
    
    enum string mDirVs_glslesFinite = 
        `#version 100
        precision highp float;
        precision highp int;
        precision lowp sampler2D;
        precision lowp samplerCube;\n
        // Directional light extrude - FINITE
        attribute vec4 uv0;
        attribute vec4 position;\n
        uniform mat4 worldviewproj_matrix;
        uniform vec4 light_position_object_space; // homogenous, object space
        uniform float shadow_extrusion_distance;  // how far to extrude\n
        void main()
        {
            // Extrusion in object space
            // Vertex unmodified if w==1, extruded if w==0
            // -ve light_position_object_space is direction
            vec4 newpos = vec4(position.xyz - 
                (uv0.x * shadow_extrusion_distance * light_position_object_space.xyz), 1.0);
        
            gl_Position = worldviewproj_matrix * newpos;
        
        }`;

    // same as above, except the color is set to 1 to enable _debug volumes to be seen
    enum string mPointArbvp1Finite_debug = 
        `!!ARBvp1.0
        PARAM c6 = { 1, 0, 0, 0 };
        TEMP R0, R1;
        ATTRIB v24 = vertex.texcoord[0];
        ATTRIB v16 = vertex.position;
        PARAM c0[4] = { program.local[0..3] };
        PARAM c5 = program.local[5];
        PARAM c4 = program.local[4];
        MOV result.color.front.primary, c6.x;
        ADD R0.x, c6.x, -v24.x;
        MUL R1.x, R0.x, c5.x;
        ADD R0.yzw, v16.xxyz, -c4.xxyz;
        DP3 R0.x, R0.yzwy, R0.yzwy;
        RSQ R0.x, R0.x;
        MUL R0.xyz, R0.x, R0.yzwy;
        MAD R0.xyz, R1.x, R0.xyzx, v16.xyzx;
        DPH result.position.x, R0.xyzz, c0[0];
        DPH result.position.y, R0.xyzz, c0[1];
        DPH result.position.z, R0.xyzz, c0[2];
        DPH result.position.w, R0.xyzz, c0[3];
        END`;

    enum string mPointVs_1_1Finite_debug = 
        `vs_1_1
        def c6, 1, 0, 0, 0
        dcl_texcoord0 v7
        dcl_position v0
        mov oD0, c6.x
        add r0.x, c6.x, -v7.x
        mul r1.x, r0.x, c5.x
        add r0.yzw, v0.xxyz, -c4.xxyz
        dp3 r0.x, r0.yzw, r0.yzw
        rsq r0.x, r0.x
        mul r0.xyz, r0.x, r0.yzw
        mad r0.xyz, r1.x, r0.xyz, v0.xyz
        mov r0.w, c6.x
        dp4 oPos.x, c0, r0
        dp4 oPos.y, c1, r0
        dp4 oPos.z, c2, r0
        dp4 oPos.w, c3, r0`;

    //enum string mPointVs_4_0FiniteDebug;// = mPointVs_4_0Finite;
    //enum string mPointVs_glslFiniteDebug = mPointVs_glslFinite;
    //enum string mPointVs_glslesFiniteDebug;// = mPointVs_glslesFinite;
    alias mPointVs_4_0Finite mPointVs_4_0FiniteDebug;
    alias mPointVs_glslFinite mPointVs_glslFiniteDebug;
    alias mPointVs_glslesFinite mPointVs_glslesFiniteDebug;

    enum string mDirArbvp1Finite_debug = 
        `!!ARBvp1.0
        PARAM c6 = { 1, 0, 0, 0 };
        TEMP R0;
        ATTRIB v24 = vertex.texcoord[0];
        ATTRIB v16 = vertex.position;
        PARAM c0[4] = { program.local[0..3] };
        PARAM c4 = program.local[4];
        PARAM c5 = program.local[5];
        MOV result.color.front.primary, c6.x;
        ADD R0.x, c6.x, -v24.x;
        MUL R0.x, R0.x, c5.x;
        MAD R0.xyz, -R0.x, c4.xyzx, v16.xyzx;
        DPH result.position.x, R0.xyzz, c0[0];
        DPH result.position.y, R0.xyzz, c0[1];
        DPH result.position.z, R0.xyzz, c0[2];
        DPH result.position.w, R0.xyzz, c0[3];
        END`;

    enum string mDirVs_1_1Finite_debug = 
        `vs_1_1
        def c6, 1, 0, 0, 0
        dcl_texcoord0 v7
        dcl_position v0
        mov oD0, c6.x
        add r0.x, c6.x, -v7.x
        mul r0.x, r0.x, c5.x
        mad r0.xyz, -r0.x, c4.xyz, v0.xyz
        mov r0.w, c6.x
        dp4 oPos.x, c0, r0
        dp4 oPos.y, c1, r0
        dp4 oPos.z, c2, r0
        dp4 oPos.w, c3, r0`;

    //enum string mDirVs_4_0FiniteDebug;// = mDirVs_4_0Finite;
    //enum string mDirVs_glslFiniteDebug = mDirVs_glslFinite;
    //enum string mDirVs_glslesFiniteDebug;// = mDirVs_glslesFinite;
    
    alias mDirVs_4_0Finite mDirVs_4_0FiniteDebug;
    alias mDirVs_glslFinite mDirVs_glslFiniteDebug;
    alias mDirVs_glslesFinite mDirVs_glslesFiniteDebug;
    
    enum string mGeneralFs_4_0 = 
        `struct VS_OUTPUT
        {
            float4 Pos : SV_POSITION;
        };
        float4 fs_main (VS_OUTPUT input): SV_Target
        {
            float4 finalColor = float4(1,1,1,1);
            return finalColor;
        }`;

    enum string mGeneralFs_glsl = 
        `#version 150
        out vec4 fragColour;
        void main()
        {
            fragColour = vec4(1.0);
        }`;
    
    enum string mGeneralFs_glsles = 
        `#version 100
        precision highp float;
        precision highp int;
        precision lowp sampler2D;
        precision lowp samplerCube;\n
        void main()
        {
            gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
        }`;

    
    static bool mInitialised;

    static this()
    {
        mPointVs_4_0Debug = mPointVs_4_0;
        mPointVs_glslesDebug = mPointVs_glsles;
        mDirVs_4_0Debug = mDirVs_4_0;
        mDirVs_glslesDebug = mDirVs_glsles;
        mPointVs_4_0FiniteDebug = mPointVs_4_0Finite;
        mPointVs_glslesFiniteDebug = mPointVs_glslesFinite;
        mDirVs_4_0FiniteDebug = mDirVs_4_0Finite;
        mDirVs_glslesFiniteDebug = mDirVs_glslesFinite;
    }

public:
    enum OGRE_NUM_SHADOW_EXTRUDER_PROGRAMS = 8;
    enum Programs
    {
        // Point light extruder, infinite distance
        POINT_LIGHT = 0,
        // Point light extruder, infinite distance, _debug mode
        POINT_LIGHT_DEBUG = 1,
        // Directional light extruder, infinite distance
        DIRECTIONAL_LIGHT = 2,
        // Directional light extruder, infinite distance, _debug mode
        DIRECTIONAL_LIGHT_DEBUG = 3,
        // Point light extruder, finite distance
        POINT_LIGHT_FINITE = 4,
        // Point light extruder, finite distance, _debug mode
        POINT_LIGHT_FINITE_DEBUG = 5,
        // Directional light extruder, finite distance
        DIRECTIONAL_LIGHT_FINITE = 6,
        // Directional light extruder, finite distance, _debug mode
        DIRECTIONAL_LIGHT_FINITE_DEBUG = 7
        
    }

    static string[OGRE_NUM_SHADOW_EXTRUDER_PROGRAMS] programNames =
        [
         "Ogre/ShadowExtrudePointLight",
         "Ogre/ShadowExtrudePointLightDebug",
         "Ogre/ShadowExtrudeDirLight",
         "Ogre/ShadowExtrudeDirLightDebug",
         "Ogre/ShadowExtrudePointLightFinite",
         "Ogre/ShadowExtrudePointLightFiniteDebug",
         "Ogre/ShadowExtrudeDirLightFinite",
         "Ogre/ShadowExtrudeDirLightFiniteDebug"
         ];

    static string frgProgramName = "";
    
    /// Initialise the creation of these vertex programs
    static void initialise()
    {
        if (!mInitialised)
        {
            string syntax;

            bool[OGRE_NUM_SHADOW_EXTRUDER_PROGRAMS] vertexProgramFinite = 
                [
                 false, false, false, false, 
                 true, true, true, true
                 ];

            bool[OGRE_NUM_SHADOW_EXTRUDER_PROGRAMS] vertexProgram_debug = 
                [
                 false, true, false, true, 
                 false, true, false, true
                 ];

            Light.LightTypes[OGRE_NUM_SHADOW_EXTRUDER_PROGRAMS] vertexProgramLightTypes = 
                [
                 Light.LightTypes.LT_POINT, Light.LightTypes.LT_POINT, 
                 Light.LightTypes.LT_DIRECTIONAL, Light.LightTypes.LT_DIRECTIONAL, 
                 Light.LightTypes.LT_POINT, Light.LightTypes.LT_POINT, 
                 Light.LightTypes.LT_DIRECTIONAL, Light.LightTypes.LT_DIRECTIONAL 
                 ];
            
            // load hardware extrusion programs for point & dir lights
            if (GpuProgramManager.getSingleton().isSyntaxSupported("arbvp1"))
            {
                // ARBvp1
                syntax = "arbvp1";
            }
            else if (GpuProgramManager.getSingleton().isSyntaxSupported("vs_1_1"))
            {
                syntax = "vs_1_1";
            }
            else if (
                (GpuProgramManager.getSingleton().isSyntaxSupported("vs_4_0"))
                || (GpuProgramManager.getSingleton().isSyntaxSupported("vs_4_0_level_9_1"))
                || (GpuProgramManager.getSingleton().isSyntaxSupported("vs_4_0_level_9_3"))
                )
            {
                syntax = "vs_4_0";
            }
            else if (GpuProgramManager.getSingleton().isSyntaxSupported("glsles"))
            {
                syntax = "glsles";
            }
            else if (GpuProgramManager.getSingleton().isSyntaxSupported("glsl"))
            {
                syntax = "glsl";
            }
            else
            {
                throw new InternalError(
                    "Vertex programs are supposedly supported, but neither "
                    "arbvp1, glsl, glsles, vs_1_1 nor vs_4_0 syntaxes are present.", 
                    "SceneManager.initShadowVolumeMaterials");
            }
            // Create all programs
            for (ushort v = 0; v < OGRE_NUM_SHADOW_EXTRUDER_PROGRAMS; ++v)
            {
                // Create _debug extruders
                if (GpuProgramManager.getSingleton().getByName(
                    programNames[v]).isNull())
                {
                    if (syntax == "vs_4_0")
                    {
                        SharedPtr!HighLevelGpuProgram vp = 
                            HighLevelGpuProgramManager.getSingleton().createProgram(
                                programNames[v], ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME,
                                "hlsl", GpuProgramType.GPT_VERTEX_PROGRAM);
                        vp.getAs().setSource(ShadowVolumeExtrudeProgram.getProgramSource(
                            vertexProgramLightTypes[v], syntax, 
                            vertexProgramFinite[v], vertexProgram_debug[v]));
                        
                        string targetSuffix = "s_4_0";
                        if(GpuProgramManager.getSingleton().isSyntaxSupported("vs_4_0") == false)
                        {
                            if(GpuProgramManager.getSingleton().isSyntaxSupported("vs_4_0_level_9_3"))
                            {
                                targetSuffix = "s_4_0_level_9_3";
                            }
                            else
                            {
                                targetSuffix = "s_4_0_level_9_1";
                            }
                        }
                        
                        vp.getAs().setParameter("target", "v" ~ targetSuffix);
                        vp.getAs().setParameter("entry_point", "vs_main");         
                        vp.get().load();
                        
                        if (frgProgramName is null || !frgProgramName.length)
                        {
                            frgProgramName = "Ogre/ShadowFrgProgram";
                            SharedPtr!HighLevelGpuProgram fp = 
                                HighLevelGpuProgramManager.getSingleton().createProgram(
                                    frgProgramName, ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME,
                                    "hlsl", GpuProgramType.GPT_FRAGMENT_PROGRAM);
                            fp.getAs().setSource(mGeneralFs_4_0);
                            fp.getAs().setParameter("target", "p" ~ targetSuffix);
                            fp.getAs().setParameter("entry_point", "fs_main");         
                            fp.get().load();
                        }
                    }
                    else if (syntax == "glsles")
                    {
                        SharedPtr!HighLevelGpuProgram vp = 
                            HighLevelGpuProgramManager.getSingleton().createProgram(
                                programNames[v], ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME,
                                "glsles", GpuProgramType.GPT_VERTEX_PROGRAM);
                        vp.getAs().setSource(ShadowVolumeExtrudeProgram.getProgramSource(
                            vertexProgramLightTypes[v], syntax, 
                            vertexProgramFinite[v], vertexProgram_debug[v]));
                        vp.getAs().setParameter("target", syntax);
                        vp.get().load();
                        
                        if (frgProgramName.empty())
                        {
                            frgProgramName = "Ogre/ShadowFrgProgram";
                            SharedPtr!HighLevelGpuProgram fp = 
                                HighLevelGpuProgramManager.getSingleton().createProgram(
                                    frgProgramName, ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME,
                                    "glsles", GpuProgramType.GPT_FRAGMENT_PROGRAM);
                            fp.getAs().setSource(mGeneralFs_glsles);
                            fp.getAs().setParameter("target", "glsles");
                            fp.get().load();
                        }
                    }
                    else if (syntax == "glsl")
                    {
                        HighLevelGpuProgramPtr vp = 
                            HighLevelGpuProgramManager.getSingleton().createProgram(
                                programNames[v], ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME,
                                "glsl", GpuProgramType.GPT_VERTEX_PROGRAM);
                        vp.setSource(ShadowVolumeExtrudeProgram.getProgramSource(
                            vertexProgramLightTypes[v], syntax, 
                            vertexProgramFinite[v], vertexProgramDebug[v]));
                        vp.setParameter("target", syntax);
                        vp.load();
                        
                        if (frgProgramName.empty())
                        {
                            frgProgramName = "Ogre/ShadowFrgProgram";
                            HighLevelGpuProgramPtr fp = 
                                HighLevelGpuProgramManager.getSingleton().createProgram(
                                    frgProgramName, ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME,
                                    "glsl", GpuProgramType.GPT_FRAGMENT_PROGRAM);
                            fp.setSource(mGeneralFs_glsl);
                            fp.setParameter("target", "glsl");
                            fp.load();
                        }
                    }
                    else
                    {
                        SharedPtr!GpuProgram vp = 
                            GpuProgramManager.getSingleton().createProgramFromString(
                                programNames[v], ResourceGroupManager.INTERNAL_RESOURCE_GROUP_NAME,
                                ShadowVolumeExtrudeProgram.getProgramSource(
                                vertexProgramLightTypes[v], syntax, 
                                vertexProgramFinite[v], vertexProgram_debug[v]),
                                GpuProgramType.GPT_VERTEX_PROGRAM, syntax);
                        vp.get().load();
                    }
                }
            }
            mInitialised = true;
        }
    }

    /// Shutdown & destroy the vertex programs
    static void shutdown()
    {
        if (mInitialised)
        {
            for (ushort v = 0; v < OGRE_NUM_SHADOW_EXTRUDER_PROGRAMS; ++v)
            {
                // Destroy _debug extruders
                GpuProgramManager.getSingleton().remove(programNames[v]);
            }
            mInitialised = false;
        }
    }

    /// Get extruder program source for point lights, compatible with arbvp1
    static string getPointLightExtruderArbvp1() { return mPointArbvp1; }
    /// Get extruder program source for point lights, compatible with `vs_1_1
    static string getPointLightExtruderVs_1_1() { return mPointVs_1_1; }
    /// Get extruder program source for point lights, compatible with vs_4_0
    static string getPointLightExtruderVs_4_0() { return mPointVs_4_0; }
    /// Get extruder program source for point lights, compatible with glsles
    static string getPointLightExtruderVs_glsles() { return mPointVs_glsles; }
    /// Get extruder program source for directional lights, compatible with arbvp1
    static string getDirectionalLightExtruderArbvp1() { return mDirArbvp1; }
    /// Get extruder program source for directional lights, compatible with `vs_1_1
    static string getDirectionalLightExtruderVs_1_1() { return mDirVs_1_1; }
    /// Get extruder program source for directional lights, compatible with vs_4_0
    static string getDirectionalLightExtruderVs_4_0() { return mDirVs_4_0; }
    /// Get extruder program source for directional lights, compatible with glsles
    static string getDirectionalLightExtruderVs_glsles() { return mDirVs_glsles; }
    
    /// Get extruder program source for _debug point lights, compatible with arbvp1
    static string getPointLightExtruderArbvp1_debug() { return mPointArbvp1_debug; }
    /// Get extruder program source for _debug point lights, compatible with `vs_1_1
    static string getPointLightExtruderVs_1_1_debug() { return mPointVs_1_1_debug; }
    /// Get extruder program source for _debug point lights, compatible with vs_4_0
    static string getPointLightExtruderVs_4_0_debug() { return mPointVs_4_0Debug; }
    /// Get extruder program source for _debug point lights, compatible with glsles
    static string getPointLightExtruderVs_glsles_debug() { return mPointVs_glslesDebug; }
    /// Get extruder program source for _debug directional lights, compatible with arbvp1
    static string getDirectionalLightExtruderArbvp1_debug() { return mDirArbvp1_debug; }
    /// Get extruder program source for _debug directional lights, compatible with `vs_1_1
    static string getDirectionalLightExtruderVs_1_1_debug() { return mDirVs_1_1_debug; }
    /// Get extruder program source for _debug directional lights, compatible with vs_4_0
    static string getDirectionalLightExtruderVs_4_0_debug() { return mDirVs_4_0Debug; }
    /// Get extruder program source for _debug directional lights, compatible with glsles
    static string getDirectionalLightExtruderVs_glsles_debug() { return mDirVs_glslesDebug; }

    /// General purpose method to get any of the program sources
    static string getProgramSource(Light.LightTypes lightType,string syntax, 
                                   bool finite, bool _debug)
    {
        if (lightType == Light.LightTypes.LT_DIRECTIONAL)
        {
            if (syntax == "arbvp1")
            {
                if (finite)
                {
                    if (_debug)
                    {
                        return getDirectionalLightExtruderArbvp1Finite_debug();
                    }
                    else
                    {
                        return getDirectionalLightExtruderArbvp1Finite();
                    }
                }
                else
                {
                    if (_debug)
                    {
                        return getDirectionalLightExtruderArbvp1_debug();
                    }
                    else
                    {
                        return getDirectionalLightExtruderArbvp1();
                    }
                }
            } 
            else if (syntax == "vs_1_1")
            {
                if (finite)
                {
                    if (_debug)
                    {
                        return getDirectionalLightExtruderVs_1_1Finite_debug();
                    }
                    else
                    {
                        return getDirectionalLightExtruderVs_1_1Finite();
                    }
                }
                else
                {
                    if (_debug)
                    {
                        return getDirectionalLightExtruderVs_1_1_debug();
                    }
                    else
                    {
                        return getDirectionalLightExtruderVs_1_1();
                    }
                }
            }
            else if (syntax == "vs_4_0")
            {
                if (finite)
                {
                    if (_debug)
                    {
                        return getDirectionalLightExtruderVs_4_0Finite_debug();
                    }
                    else
                    {
                        return getDirectionalLightExtruderVs_4_0Finite();
                    }
                }
                else
                {
                    if (_debug)
                    {
                        return getDirectionalLightExtruderVs_4_0_debug();
                    }
                    else
                    {
                        return getDirectionalLightExtruderVs_4_0();
                    }
                }
            }
            else if (syntax == "glsl")
            {
                if (finite)
                {
                    if (_debug)
                    {
                        return getDirectionalLightExtruderVs_glslFiniteDebug();
                    }
                    else
                    {
                        return getDirectionalLightExtruderVs_glslFinite();
                    }
                }
                else
                {
                    if (_debug)
                    {
                        return getDirectionalLightExtruderVs_glslDebug();
                    }
                    else
                    {
                        return getDirectionalLightExtruderVs_glsl();
                    }
                }
            }
            else if (syntax == "glsles")
            {
                if (finite)
                {
                    if (_debug)
                    {
                        return getDirectionalLightExtruderVs_glslesFinite_debug();
                    }
                    else
                    {
                        return getDirectionalLightExtruderVs_glslesFinite();
                    }
                }
                else
                {
                    if (_debug)
                    {
                        return getDirectionalLightExtruderVs_glsles_debug();
                    }
                    else
                    {
                        return getDirectionalLightExtruderVs_glsles();
                    }
                }
            }
            else
            {
                throw new InternalError(
                    "Vertex programs are supposedly supported, but neither "
                    "arbvp1, glsl, glsles, vs_1_1 nor vs_4_0 syntaxes are present.", 
                    "SceneManager.getProgramSource");
            }
            
        }
        else
        {
            if (syntax == "arbvp1")
            {
                if (finite)
                {
                    if (_debug)
                    {
                        return getPointLightExtruderArbvp1Finite_debug();
                    }
                    else
                    {
                        return getPointLightExtruderArbvp1Finite();
                    }
                }
                else
                {
                    if (_debug)
                    {
                        return getPointLightExtruderArbvp1_debug();
                    }
                    else
                    {
                        return getPointLightExtruderArbvp1();
                    }
                }
            }
            else if (syntax == "vs_1_1")
            {
                if (finite)
                {
                    if (_debug)
                    {
                        return getPointLightExtruderVs_1_1Finite_debug();
                    }
                    else
                    {
                        return getPointLightExtruderVs_1_1Finite();
                    }
                }
                else
                {
                    if (_debug)
                    {
                        return getPointLightExtruderVs_1_1_debug();
                    }
                    else
                    {
                        return getPointLightExtruderVs_1_1();
                    }
                }
            }
            else if (syntax == "vs_4_0")
            {
                if (finite)
                {
                    if (_debug)
                    {
                        return getPointLightExtruderVs_4_0Finite_debug();
                    }
                    else
                    {
                        return getPointLightExtruderVs_4_0Finite();
                    }
                }
                else
                {
                    if (_debug)
                    {
                        return getPointLightExtruderVs_4_0_debug();
                    }
                    else
                    {
                        return getPointLightExtruderVs_4_0();
                    }
                }
            }
            else if (syntax == "glsl")
            {
                if (finite)
                {
                    if (_debug)
                    {
                        return getPointLightExtruderVs_glslFiniteDebug();
                    }
                    else
                    {
                        return getPointLightExtruderVs_glslFinite();
                    }
                }
                else
                {
                    if (_debug)
                    {
                        return getPointLightExtruderVs_glslDebug();
                    }
                    else
                    {
                        return getPointLightExtruderVs_glsl();
                    }
                }
            }
            else if (syntax == "glsles")
            {
                if (finite)
                {
                    if (_debug)
                    {
                        return getPointLightExtruderVs_glslesFinite_debug();
                    }
                    else
                    {
                        return getPointLightExtruderVs_glslesFinite();
                    }
                }
                else
                {
                    if (_debug)
                    {
                        return getPointLightExtruderVs_glsles_debug();
                    }
                    else
                    {
                        return getPointLightExtruderVs_glsles();
                    }
                }
            }
            else
            {
                throw new InternalError(
                    "Vertex programs are supposedly supported, but neither "
                    "arbvp1, glsl, glsles, vs_1_1 nor vs_4_0 syntaxes are present.", 
                    "SceneManager.getProgramSource");
            }
            
        }
    }
    
    static string getProgramName(Light.LightTypes lightType, bool finite, bool _debug)
    {
        if (lightType == Light.LightTypes.LT_DIRECTIONAL)
        {
            if (finite)
            {
                if (_debug)
                {
                    return programNames[Programs.DIRECTIONAL_LIGHT_FINITE_DEBUG];
                }
                else
                {
                    return programNames[Programs.DIRECTIONAL_LIGHT_FINITE];
                }
            }
            else
            {
                if (_debug)
                {
                    return programNames[Programs.DIRECTIONAL_LIGHT_DEBUG];
                }
                else
                {
                    return programNames[Programs.DIRECTIONAL_LIGHT];
                }
            }
        }
        else
        {
            if (finite)
            {
                if (_debug)
                {
                    return programNames[Programs.POINT_LIGHT_FINITE_DEBUG];
                }
                else
                {
                    return programNames[Programs.POINT_LIGHT_FINITE];
                }
            }
            else
            {
                if (_debug)
                {
                    return programNames[Programs.POINT_LIGHT_DEBUG];
                }
                else
                {
                    return programNames[Programs.POINT_LIGHT];
                }
            }
        }
    }
    
    
    /// Get FINITE extruder program source for point lights, compatible with arbvp1
    static string getPointLightExtruderArbvp1Finite() { return mPointArbvp1Finite; }
    /// Get FINITE extruder program source for point lights, compatible with `vs_1_1
    static string getPointLightExtruderVs_1_1Finite() { return mPointVs_1_1Finite; }
    /// Get FINITE extruder program source for point lights, compatible with vs_4_0
    static string getPointLightExtruderVs_4_0Finite() { return mPointVs_4_0Finite; }
    /// Get FINITE extruder program source for point lights, compatible with glsles
    static string getPointLightExtruderVs_glslesFinite() { return mPointVs_glslesFinite; }
    /// Get FINITE extruder program source for directional lights, compatible with arbvp1
    static string getDirectionalLightExtruderArbvp1Finite() { return mDirArbvp1Finite; }
    /// Get FINITE extruder program source for directional lights, compatible with `vs_1_1
    static string getDirectionalLightExtruderVs_1_1Finite() { return mDirVs_1_1Finite; }
    /// Get FINITE extruder program source for directional lights, compatible with vs_4_0
    static string getDirectionalLightExtruderVs_4_0Finite() { return mDirVs_4_0Finite; }
    /// Get FINITE extruder program source for directional lights, compatible with glsles
    static string getDirectionalLightExtruderVs_glslesFinite() { return mDirVs_glslesFinite; }
    
    /// Get FINITE extruder program source for _debug point lights, compatible with arbvp1
    static string getPointLightExtruderArbvp1Finite_debug() { return mPointArbvp1Finite_debug; }
    /// Get extruder program source for _debug point lights, compatible with `vs_1_1
    static string getPointLightExtruderVs_1_1Finite_debug() { return mPointVs_1_1Finite_debug; }
    /// Get extruder program source for _debug point lights, compatible with vs_4_0
    static string getPointLightExtruderVs_4_0Finite_debug() { return mPointVs_4_0FiniteDebug; }
    /// Get extruder program source for _debug point lights, compatible with glsles
    static string getPointLightExtruderVs_glslesFinite_debug() { return mPointVs_glslesFiniteDebug; }
    /// Get FINITE extruder program source for _debug directional lights, compatible with arbvp1
    static string getDirectionalLightExtruderArbvp1Finite_debug() { return mDirArbvp1Finite_debug; }
    /// Get FINITE extruder program source for _debug directional lights, compatible with `vs_1_1
    static string getDirectionalLightExtruderVs_1_1Finite_debug() { return mDirVs_1_1Finite_debug; }
    /// Get FINITE extruder program source for _debug directional lights, compatible with vs_4_0
    static string getDirectionalLightExtruderVs_4_0Finite_debug() { return mDirVs_4_0FiniteDebug; }
    /// Get FINITE extruder program source for _debug directional lights, compatible with glsles
    static string getDirectionalLightExtruderVs_glslesFinite_debug() { return mDirVs_glslesFiniteDebug; }
    
}
/** @} */
/** @} */
