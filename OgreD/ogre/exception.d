module ogre.exception;
//core.exception style object.Error or Exception????
///Annoying duplication, because __FILE__ and __LINE__

class OgreError: Exception
{
    string title;
    this(string msg, string title, string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        super( msg, file, line, next);
        this.title = title;
    }
}

class NotImplementedError: OgreError
{
    this(string msg = "Not implemented.", string title = "Error", string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        super(msg, title, file, line, next);
    }
}

//Basically RangeError
class ItemNotFoundError: OgreError
{
    this(string msg = "Item not found.", string title = "Error", string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        super(msg, title, file, line, next);
    }
}

class DuplicateItemError: OgreError
{
    this(string msg = "Item not found.", string title = "Error", string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        super(msg, title, file, line, next);
    }
}

class InvalidParamsError: OgreError
{
    this(string msg = "Invalid params.", string title = "Error", string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        super(msg, title, file, line, next);
    }
}

class RenderingApiError: OgreError
{
    this(string msg = "Rendering Api error.", string title = "Error", string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        super(msg, title, file, line, next);
    }
}

class FileNotFoundError: OgreError
{
    this(string msg = "File not found.", string title = "Error", string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        super(msg, title, file, line, next);
    }
}

class CannotWriteToFileError: OgreError
{
    this(string msg = "File not found.", string title = "Error", string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        super(msg, title, file, line, next);
    }
}

class InvalidStateError: OgreError
{
    this(string msg = "Invalid state error.", string title = "Error", string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        super(msg, title, file, line, next);
    }
}

class InternalError: OgreError
{
    this(string msg = "Internal error.", string title = "Error", string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        super(msg, title, file, line, next);
    }
}

class RTAssertionFailedError: OgreError
{
    this(string msg = "Runtime assertion error.", string title = "Error", string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        super(msg, title, file, line, next);
    }
}

// Event handlers onXXX needed?
static void onNotImplementedError(string msg = "Not implemented.", string title = "Error", string file = __FILE__, size_t line = __LINE__, Throwable next = null )
{
    throw new NotImplementedError(msg, title, file, line, next);
}

static void onItemNotFoundError(string msg = "Item not found.", string title = "Error", string file = __FILE__, size_t line = __LINE__, Throwable next = null )
{
    throw new ItemNotFoundError(msg, title, file, line, next);
}

unittest
{
    {
        auto err = new ItemNotFoundError();
        assert(err.line == __LINE__ - 1);
        assert(err.msg == "Item not found.");
    }
}