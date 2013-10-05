module ogregl.glsl.extsupport;
import derelict.opengl3.gl;
import ogre.general.log;
import ogregl.compat;
import ogre.exception;

void reportGLSLError(GLenum glErr, string ogreMethod, string errorTextPrefix, const GLhandleARB obj, bool forceInfoLog = false, bool forceException = false)
{
    bool errorsFound = false;
    string msg = errorTextPrefix;
    
    // get all the GL errors
    while (glErr != GL_NO_ERROR)
    {
        string glerrStr = gluErrorString(glErr);
        if (glerrStr)
        {
            msg ~= glerrStr;
        }
        glErr = glGetError();
        errorsFound = true;
    }
    
    
    // if errors were found then put them in the Log and raise and exception
    if (errorsFound || forceInfoLog)
    {
        // if shader or program object then get the log message and send to the log manager
        msg ~= logObjectInfo( msg, obj );
        
        if (forceException) 
        {
            throw new InternalError(msg, ogreMethod);
        }
    }
}

//-----------------------------------------------------------------------------
string logObjectInfo(string msg, GLuint obj)
{
    string logMessage = msg;
    
    if (obj > 0)
    {
        GLint infologLength = 0;
        
        if(glIsProgram(obj))
            glValidateProgram(obj);
        
        glGetProgramiv(obj, GL_INFO_LOG_LENGTH, &infologLength);
        
        if (infologLength > 0)
        {
            GLint charsWritten  = 0;
            
            GLchar[] infoLog = new GLchar[infologLength];
            
            //glGetInfoLogARB
            glGetProgramInfoLog(obj, infologLength, &charsWritten, infoLog.ptr);
            logMessage ~= std.conv.to!string(infoLog);
            LogManager.getSingleton().logMessage(logMessage);
            
            //delete [] infoLog;
        }
    }
    
    return logMessage;
    
}