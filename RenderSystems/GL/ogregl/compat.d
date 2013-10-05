module ogregl.compat;
import ogre.compat;
import std.conv: to;
import derelict.opengl3.gl;

//No nVidia or ATI specific bits right now if ever
enum 
{
    NV_fragment_program = false,
    NV_fragment_program_option = false,
    NV_occlusion_query = false,
    NV_register_combiners = false,
    NV_texture_compression_vtc = false,
    NV_texture_shader = false,
    NV_vertex_program = false,
    NV_vertex_program2_option = false,
    NV_vertex_program3 = false,
    NV_vertex_program4 = false,
    NV_register_combiners2 = false,
    NV_fragment_program2 = false,
    NV_fragment_program4 = false,
    ATI_draw_buffers = false,
    ATI_fragment_shader = false,
    ATI_FS_GpuProgram = false,
    ATI_texture_float = false,
}


//Alias ARB suffixed to non-suffixed etc.
alias glClientActiveTexture     glClientActiveTextureARB;
alias glEnableVertexAttribArray glEnableVertexAttribArrayARB;
alias glVertexAttribPointer     glVertexAttribPointerARB;
//alias glGetProgramiv            glGetProgramivARB; //seg fault on 1.4 anyway
alias glDrawElementsInstanced   glDrawElementsInstancedARB;
alias glDisableVertexAttribArray glDisableVertexAttribArrayARB;
alias glVertexAttribDivisor     glVertexAttribDivisorARB;
alias glSecondaryColor3f        glSecondaryColor3fEXT;

    
string gluErrorString(GLenum errorNumber)
{
    //GLubyte *errString = gluErrorString (errorNumber);
    if(errorNumber==0)
    {
        return "No error";
    }

    //TODO Only gets inited once, right?
    enum string[GLenum] errors =
        [
         GL_INVALID_ENUM:      "Invalid enumerator.",
         GL_INVALID_VALUE:     "Invalid value.",
         GL_INVALID_OPERATION: "Invalid operation.",
         GL_INVALID_FRAMEBUFFER_OPERATION: "Invalid framebuffer operation.",
         GL_STACK_OVERFLOW:    "Stack overflow.",
         GL_STACK_UNDERFLOW:   "Stack underflow.",
         GL_OUT_OF_MEMORY:     "Out of memory.",
         GL_TABLE_TOO_LARGE:   "Table too large.",
         ];
    
    auto err = errorNumber in errors;
    return (err !is null ? *err : 
            "Unknown error: " ~ to!string(errorNumber)); //GLU errors
}