/*

Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

*/
module derelict.opengl3.ext;

private
{
    import derelict.opengl3.types;
    import derelict.opengl3.constants;
    import derelict.opengl3.internal;
}

enum : uint
{
    // GL_EXT_texture_filter_anisotropic
    GL_TEXTURE_MAX_ANISOTROPY_EXT       = 0x84FE,
    GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT   = 0x84FF,

    // GL_EXT_framebuffer_object
    GL_INVALID_FRAMEBUFFER_OPERATION_EXT = 0x0506,
    GL_MAX_RENDERBUFFER_SIZE_EXT        = 0x84E8,
    GL_FRAMEBUFFER_BINDING_EXT          = 0x8CA6,
    GL_RENDERBUFFER_BINDING_EXT         = 0x8CA7,
    GL_FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE_EXT = 0x8CD0,
    GL_FRAMEBUFFER_ATTACHMENT_OBJECT_NAME_EXT = 0x8CD1,
    GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_LEVEL_EXT = 0x8CD2,
    GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_CUBE_MAP_FACE_EXT = 0x8CD3,
    GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_3D_ZOFFSET_EXT = 0x8CD4,
    GL_FRAMEBUFFER_COMPLETE_EXT         = 0x8CD5,
    GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT_EXT = 0x8CD6,
    GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT_EXT = 0x8CD7,
    GL_FRAMEBUFFER_INCOMPLETE_DIMENSIONS_EXT = 0x8CD9,
    GL_FRAMEBUFFER_INCOMPLETE_FORMATS_EXT = 0x8CDA,
    GL_FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER_EXT = 0x8CDB,
    GL_FRAMEBUFFER_INCOMPLETE_READ_BUFFER_EXT = 0x8CDC,
    GL_FRAMEBUFFER_UNSUPPORTED_EXT      = 0x8CDD,
    GL_MAX_COLOR_ATTACHMENTS_EXT        = 0x8CDF,
    GL_COLOR_ATTACHMENT0_EXT            = 0x8CE0,
    GL_COLOR_ATTACHMENT1_EXT            = 0x8CE1,
    GL_COLOR_ATTACHMENT2_EXT            = 0x8CE2,
    GL_COLOR_ATTACHMENT3_EXT            = 0x8CE3,
    GL_COLOR_ATTACHMENT4_EXT            = 0x8CE4,
    GL_COLOR_ATTACHMENT5_EXT            = 0x8CE5,
    GL_COLOR_ATTACHMENT6_EXT            = 0x8CE6,
    GL_COLOR_ATTACHMENT7_EXT            = 0x8CE7,
    GL_COLOR_ATTACHMENT8_EXT            = 0x8CE8,
    GL_COLOR_ATTACHMENT9_EXT            = 0x8CE9,
    GL_COLOR_ATTACHMENT10_EXT           = 0x8CEA,
    GL_COLOR_ATTACHMENT11_EXT           = 0x8CEB,
    GL_COLOR_ATTACHMENT12_EXT           = 0x8CEC,
    GL_COLOR_ATTACHMENT13_EXT           = 0x8CED,
    GL_COLOR_ATTACHMENT14_EXT           = 0x8CEE,
    GL_COLOR_ATTACHMENT15_EXT           = 0x8CEF,
    GL_DEPTH_ATTACHMENT_EXT             = 0x8D00,
    GL_STENCIL_ATTACHMENT_EXT           = 0x8D20,
    GL_FRAMEBUFFER_EXT                  = 0x8D40,
    GL_RENDERBUFFER_EXT                 = 0x8D41,
    GL_RENDERBUFFER_WIDTH_EXT           = 0x8D42,
    GL_RENDERBUFFER_HEIGHT_EXT          = 0x8D43,
    GL_RENDERBUFFER_INTERNAL_FORMAT_EXT = 0x8D44,
    GL_STENCIL_INDEX1_EXT               = 0x8D46,
    GL_STENCIL_INDEX4_EXT               = 0x8D47,
    GL_STENCIL_INDEX8_EXT               = 0x8D48,
    GL_STENCIL_INDEX16_EXT              = 0x8D49,
    GL_RENDERBUFFER_RED_SIZE_EXT        = 0x8D50,
    GL_RENDERBUFFER_GREEN_SIZE_EXT      = 0x8D51,
    GL_RENDERBUFFER_BLUE_SIZE_EXT       = 0x8D52,
    GL_RENDERBUFFER_ALPHA_SIZE_EXT      = 0x8D53,
    GL_RENDERBUFFER_DEPTH_SIZE_EXT      = 0x8D54,
    GL_RENDERBUFFER_STENCIL_SIZE_EXT    = 0x8D55,
    //S3TC stuff
    GL_COMPRESSED_RGB_S3TC_DXT1_EXT     = 0x83F0,
    GL_COMPRESSED_RGBA_S3TC_DXT1_EXT    = 0x83F1,
    GL_COMPRESSED_RGBA_S3TC_DXT3_EXT    = 0x83F2,
    GL_COMPRESSED_RGBA_S3TC_DXT5_EXT    = 0x83F3,
    
    //EXT_texture_sRGB
    GL_SRGB_EXT                             = 0x8C40,
    GL_SRGB8_EXT                            = 0x8C41,
    GL_SRGB_ALPHA_EXT                       = 0x8C42,
    GL_SRGB8_ALPHA8_EXT                     = 0x8C43,
    GL_SLUMINANCE_ALPHA_EXT                 = 0x8C44,
    GL_SLUMINANCE8_ALPHA8_EXT               = 0x8C45,
    GL_SLUMINANCE_EXT                       = 0x8C46,
    GL_SLUMINANCE8_EXT                      = 0x8C47,
    GL_COMPRESSED_SRGB_EXT                  = 0x8C48,
    GL_COMPRESSED_SRGB_ALPHA_EXT            = 0x8C49,
    GL_COMPRESSED_SLUMINANCE_EXT            = 0x8C4A,
    GL_COMPRESSED_SLUMINANCE_ALPHA_EXT      = 0x8C4B,
    GL_COMPRESSED_SRGB_S3TC_DXT1_EXT        = 0x8C4C,
    GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT  = 0x8C4D,
    GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT  = 0x8C4E,
    GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT  = 0x8C4F,
    //EXT_framebuffer_sRGB
    GL_FRAMEBUFFER_SRGB_EXT                 = 0x8DB9,
    GL_FRAMEBUFFER_SRGB_CAPABLE_EXT         = 0x8DBA,
}

// GL_EXT_texture_filter_anisotropic
private __gshared bool _EXT_texture_filter_anisotropic;
bool EXT_texture_filter_anisotropic() @property { return _EXT_texture_filter_anisotropic; }

// GL_EXT_framebuffer_object
extern(System)
{
    alias nothrow GLboolean function(GLuint) da_glIsRenderbufferEXT;
    alias nothrow void function(GLenum, GLuint) da_glBindRenderbufferEXT;
    alias nothrow void function(GLsizei, in GLuint*) da_glDeleteRenderbuffersEXT;
    alias nothrow void function(GLsizei, GLuint*) da_glGenRenderbuffersEXT;
    alias nothrow void function(GLenum, GLenum, GLsizei, GLsizei) da_glRenderbufferStorageEXT;
    alias nothrow void function(GLenum, GLenum, GLint*) da_glGetRenderbufferParameterivEXT;
    alias nothrow GLboolean function(GLuint) da_glIsFramebufferEXT;
    alias nothrow void function(GLenum, GLuint) da_glBindFramebufferEXT;
    alias nothrow void function(GLsizei, in GLuint*) da_glDeleteFramebuffersEXT;
    alias nothrow void function(GLsizei, GLuint*) da_glGenFramebuffersEXT;
    alias nothrow GLenum function(GLenum) da_glCheckFramebufferStatusEXT;
    alias nothrow void function(GLenum, GLenum, GLenum, GLuint, GLint) da_glFramebufferTexture1DEXT;
    alias nothrow void function(GLenum, GLenum, GLenum, GLuint, GLint) da_glFramebufferTexture2DEXT;
    alias nothrow void function(GLenum, GLenum, GLenum, GLuint, GLint, GLint) da_glFramebufferTexture3DEXT;
    alias nothrow void function(GLenum, GLenum, GLenum, GLuint) da_glFramebufferRenderbufferEXT;
    alias nothrow void function(GLenum, GLenum, GLenum, GLint*) da_glGetFramebufferAttachmentParameterivEXT;
    alias nothrow void function(GLenum) da_glGenerateMipmapEXT;
}

__gshared
{
    da_glIsRenderbufferEXT glIsRenderbufferEXT;
    da_glBindRenderbufferEXT glBindRenderbufferEXT;
    da_glDeleteRenderbuffersEXT glDeleteRenderbuffersEXT;
    da_glGenRenderbuffersEXT glGenRenderbuffersEXT;
    da_glRenderbufferStorageEXT glRenderbufferStorageEXT;
    da_glGetRenderbufferParameterivEXT glGetRenderbufferParameterivEXT;
    da_glIsFramebufferEXT glIsFramebufferEXT;
    da_glBindFramebufferEXT glBindFramebufferEXT;
    da_glDeleteFramebuffersEXT glDeleteFramebuffersEXT;
    da_glGenFramebuffersEXT glGenFramebuffersEXT;
    da_glCheckFramebufferStatusEXT glCheckFramebufferStatusEXT;
    da_glFramebufferTexture1DEXT glFramebufferTexture1DEXT;
    da_glFramebufferTexture2DEXT glFramebufferTexture2DEXT;
    da_glFramebufferTexture3DEXT glFramebufferTexture3DEXT;
    da_glFramebufferRenderbufferEXT glFramebufferRenderbufferEXT;
    da_glGetFramebufferAttachmentParameterivEXT glGetFramebufferAttachmentParameterivEXT;
    da_glGenerateMipmapEXT glGenerateMipmapEXT;
}

private __gshared bool _EXT_framebuffer_object;
bool EXT_framebuffer_object() @property { return _EXT_framebuffer_object; }
private void load_EXT_framebuffer_object()
{
    try
    {
        bindGLFunc(cast(void**)&glIsRenderbufferEXT, "glIsRenderbufferEXT");
        bindGLFunc(cast(void**)&glBindRenderbufferEXT, "glBindRenderbufferEXT");
        bindGLFunc(cast(void**)&glDeleteRenderbuffersEXT, "glDeleteRenderbuffersEXT");
        bindGLFunc(cast(void**)&glGenRenderbuffersEXT, "glGenRenderbuffersEXT");
        bindGLFunc(cast(void**)&glRenderbufferStorageEXT, "glRenderbufferStorageEXT");
        bindGLFunc(cast(void**)&glGetRenderbufferParameterivEXT, "glGetRenderbufferParameterivEXT");
        bindGLFunc(cast(void**)&glIsFramebufferEXT, "glIsFramebufferEXT");
        bindGLFunc(cast(void**)&glBindFramebufferEXT, "glBindFramebufferEXT");
        bindGLFunc(cast(void**)&glDeleteFramebuffersEXT, "glDeleteFramebuffersEXT");
        bindGLFunc(cast(void**)&glGenFramebuffersEXT, "glGenFramebuffersEXT");
        bindGLFunc(cast(void**)&glCheckFramebufferStatusEXT, "glCheckFramebufferStatusEXT");
        bindGLFunc(cast(void**)&glFramebufferTexture1DEXT, "glFramebufferTexture1DEXT");
        bindGLFunc(cast(void**)&glFramebufferTexture2DEXT, "glFramebufferTexture2DEXT");
        bindGLFunc(cast(void**)&glFramebufferTexture3DEXT, "glFramebufferTexture3DEXT");
        bindGLFunc(cast(void**)&glFramebufferRenderbufferEXT, "glFramebufferRenderbufferEXT");
        bindGLFunc(cast(void**)&glGetFramebufferAttachmentParameterivEXT, "glGetFramebufferAttachmentParameterivEXT");
        bindGLFunc(cast(void**)&glGenerateMipmapEXT, "glGenerateMipmapEXT");
        _EXT_framebuffer_object = true;
    }
    catch(Exception e)
    {
        _EXT_framebuffer_object = false;
    }
}

//Added. Not in vanilla Derelict3
//Just bare it. Use old stencil stuff. I dont know, maybe can be worked around in < GL20.
private __gshared bool _EXT_stencil_two_side;
bool EXT_stencil_two_side() @property { return _EXT_stencil_two_side; }
extern(System)
{
    alias nothrow void function(GLenum face) da_glActiveStencilFaceEXT;
}

__gshared
{
    da_glActiveStencilFaceEXT glActiveStencilFaceEXT;
}
private void load_EXT_stencil_two_side()
{
    try
    {
        bindGLFunc(cast(void**)&glActiveStencilFaceEXT, "glActiveStencilFaceEXT");
        _EXT_stencil_two_side = true;
    }
    catch(Exception e)
    {
        _EXT_stencil_two_side = false;
    }
}

//EXT_transform_feedback used as glBindBufferOffsetNV
private __gshared bool _EXT_transform_feedback;
bool EXT_transform_feedback() @property { return _EXT_transform_feedback; }
extern(System)
{

    alias nothrow void function(GLenum,GLuint,GLuint,GLintptr) da_glBeginTransformFeedbackEXT;
    alias nothrow void function(GLenum) da_glBindBufferOffsetEXT;
    alias nothrow void function(GLuint,GLuint index, GLsizei bufSize, GLsizei* length, GLsizei *size, GLenum *type, GLchar *name) da_glGetTransformFeedbackVaryingEXT;
    alias nothrow void function(GLuint,GLsizei count, const GLchar ** varyings, GLenum bufferMode) da_glTransformFeedbackVaryingsEXT;
    //ignoring others
}

__gshared
{
    da_glBeginTransformFeedbackEXT glBeginTransformFeedbackEXT;
    da_glBindBufferOffsetEXT glBindBufferOffsetEXT;
    da_glGetTransformFeedbackVaryingEXT glGetTransformFeedbackVaryingEXT;
    da_glTransformFeedbackVaryingsEXT glTransformFeedbackVaryingsEXT;
}
private void load_EXT_transform_feedback()
{
    try
    {
        bindGLFunc(cast(void**)&glBeginTransformFeedbackEXT, "glBeginTransformFeedbackEXT");
        bindGLFunc(cast(void**)&glBindBufferOffsetEXT, "glBindBufferOffsetEXT");
        bindGLFunc(cast(void**)&glGetTransformFeedbackVaryingEXT, "glGetTransformFeedbackVaryingEXT");
        bindGLFunc(cast(void**)&glTransformFeedbackVaryingsEXT, "glTransformFeedbackVaryingsEXT");
        _EXT_transform_feedback = true;
    }
    catch(Exception e)
    {
        _EXT_transform_feedback = false;
    }
}


//Added. Not in vanilla Derelict3
private __gshared bool _EXT_texture_env_combine;
bool EXT_texture_env_combine() @property { return _EXT_texture_env_combine; }
private __gshared bool _EXT_texture_env_dot3; bool EXT_texture_env_dot3() @property { return _EXT_texture_env_dot3; }
private __gshared bool _EXT_texture_cube_map; bool EXT_texture_cube_map() @property { return _EXT_texture_cube_map; }
private __gshared bool _EXT_point_parameters; bool EXT_point_parameters() @property { return _EXT_point_parameters; }
private __gshared bool _EXT_stencil_wrap; bool EXT_stencil_wrap() @property { return _EXT_stencil_wrap; }
private __gshared bool _EXT_texture_compression_s3tc; bool EXT_texture_compression_s3tc() @property { return _EXT_texture_compression_s3tc; }
private __gshared bool _EXT_secondary_color; bool EXT_secondary_color() @property { return _EXT_secondary_color; }
private __gshared bool _EXT_pixel_buffer_object; bool EXT_pixel_buffer_object() @property { return _EXT_pixel_buffer_object; }
private __gshared bool _EXT_geometry_shader4; bool EXT_geometry_shader4() @property { return _EXT_geometry_shader4; }
private __gshared bool _EXT_texture_lod_bias; bool EXT_texture_lod_bias() @property { return _EXT_texture_lod_bias; }
private __gshared bool _EXT_blend_equation_separate; bool EXT_blend_equation_separate() @property { return _EXT_blend_equation_separate; }
private __gshared bool _EXT_framebuffer_blit; bool EXT_framebuffer_blit() @property { return _EXT_framebuffer_blit; }
private __gshared bool _EXT_framebuffer_multisample; bool EXT_framebuffer_multisample() @property { return _EXT_framebuffer_multisample; }

package void loadEXT(GLVersion glversion)
{
    _EXT_texture_filter_anisotropic = isExtSupported(glversion, "GL_EXT_texture_filter_anisotropic");
    _EXT_framebuffer_object = isExtSupported(glversion, "GL_EXT_framebuffer_object");
    if(_EXT_framebuffer_object) load_EXT_framebuffer_object();

    //Added. Not in vanilla Derelict3
    _EXT_framebuffer_multisample = isExtSupported(glversion, "GL_EXT_framebuffer_multisample");
    _EXT_framebuffer_blit = isExtSupported(glversion, "GL_EXT_framebuffer_blit");
    _EXT_blend_equation_separate = isExtSupported(glversion, "GL_EXT_blend_equation_separate");
    _EXT_texture_lod_bias = isExtSupported(glversion, "GL_EXT_texture_lod_bias");
    _EXT_geometry_shader4 = isExtSupported(glversion, "GL_EXT_geometry_shader4");
    _EXT_pixel_buffer_object = isExtSupported(glversion, "GL_EXT_pixel_buffer_object");
    _EXT_secondary_color  = isExtSupported(glversion, "GL_EXT_secondary_color");
    _EXT_texture_compression_s3tc = isExtSupported(glversion, "GL_EXT_texture_compression_s3tc");
    _EXT_stencil_wrap = isExtSupported(glversion, "GL_EXT_stencil_wrap");
    _EXT_point_parameters = isExtSupported(glversion, "GL_EXT_point_parameters");
    _EXT_texture_cube_map = isExtSupported(glversion, "GL_EXT_texture_cube_map");
    _EXT_texture_env_dot3 = isExtSupported(glversion, "GL_EXT_texture_env_dot3");
    _EXT_stencil_two_side = isExtSupported(glversion, "GL_EXT_stencil_two_side");
    _EXT_texture_env_combine = isExtSupported(glversion, "GL_EXT_texture_env_combine");
    if(_EXT_stencil_two_side) load_EXT_stencil_two_side();
    _EXT_transform_feedback = isExtSupported(glversion, "GL_EXT_transform_feedback");
    if(_EXT_transform_feedback) load_EXT_transform_feedback();
}