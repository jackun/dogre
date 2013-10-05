module ogre.resources.archive;
import core.sync.mutex;
//import std.container;
import std.string;
import std.file;

import ogre.sharedptr;
import ogre.resources.datastream;
import ogre.compat;
import ogre.general.generals;
import ogre.singleton;
import ogre.exception;
import std.stdio;
import ogre.general.log;

/** Information about a file/directory within the archive will be
returned using a FileInfo struct.
@see
Archive
*/
struct FileInfo {
    /// The archive in which the file has been found (for info when performing
    /// multi-Archive searches, note you should still open through ResourceGroupManager)
    //Archive* archive;
   Archive archive;
    /// The file's fully qualified name
    string filename;
    /// Path name; separated by '/' and ending with '/'
    string path;
    /// Base filename
    string basename;
    /// Compressed size
    size_t compressedSize;
    /// Uncompressed size
    size_t uncompressedSize;
}

//typedef vector<FileInfo>.type FileInfoList;
//typedef SharedPtr<FileInfoList> FileInfoListPtr;

alias FileInfo[] FileInfoList;
//NO //alias SharedPtr!(FileInfoList) FileInfoListPtr;

/** Archive-handling class.
@remarks
    An archive is a generic term for a container of files. This may be a
    filesystem folder, it may be a compressed archive, it may even be 
    a remote location shared on the web. This class is designed to be 
    subclassed to provide access to a range of file locations. 
@par
    Instances of this class are neverructed or even handled by end-user
    applications. They areructed by custom ArchiveFactory classes, 
    which plugins can register new instances of using ArchiveManager. 
    End-user applications will typically use ResourceManager or 
    ResourceGroupManager to manage resources at a higher level, rather than 
    reading files directly through this class. Doing it this way allows you
    to benefit from OGRE's automatic searching of multiple file locations 
    for the resources you are looking for.
*/
class Archive// : public ArchiveAlloc
{
protected:
    /// Archive name
    string mName; 
    /// Archive type code
    string mType;
    /// Read-only flag
    bool mReadOnly;
public:
    
    
    /** Constructor - don't call direct, used by ArchiveFactory.
    */
    this( string name, string archType )
    {
        mName = name;
        mType = archType;
        mReadOnly = true;
    }
    
    /** Default destructor.
    */
    ~this() {}
    
    /// Get the name of this archive
   string getName(){ return mName; }
    
    /// Returns whether this archive is case sensitive in the way it matches files
    abstract bool isCaseSensitive();
    
    /** Loads the archive.
    @remarks
        This initializes all the internal data of the class.
    @warning
        Do not call this function directly, it is meant to be used
        only by the ArchiveManager class.
    */
    abstract void load();
    
    /** Unloads the archive.
    @warning
        Do not call this function directly, it is meant to be used
        only by the ArchiveManager class.
    */
    abstract void unload();
    
    /** Reports whether this Archive is read-only, or whether the contents
        can be updated. 
    */
    bool isReadOnly(){ return mReadOnly; }
    
    /** Open a stream on a given file. 
    @note
        There is no equivalent 'close' method; the returned stream
        controls the lifecycle of this file operation.
    @param filename The fully qualified name of the file
    @param readOnly Whether to open the file in read-only mode or not (note, 
        if the archive is read-only then this cannot be set to false)
    @return A shared pointer to a DataStream which can be used to 
        read / write the file. If the file is not present, returns a null
        shared pointer.
    */
    abstract DataStream open(string filename, bool readOnly = true);
    
    /** Create a new file (or overwrite one already there). 
    @note If the archive is read-only then this method will fail.
    @param filename The fully qualified name of the file
    @return A shared pointer to a DataStream which can be used to 
    read / write the file. 
    */
    DataStream create(string filename)
    {
        throw new NotImplementedError(
            "This archive does not support creation of files.", 
            "Archive.create");
    }
    
    /** Delete a named file.
    @remarks Not possible on read-only archives
    @param filename The fully qualified name of the file
    */
    void remove(string filename)
    {
        throw new NotImplementedError(
            "This archive does not support removal of files.", 
            "Archive.remove");
    }
    
    /** List all file names in the archive.
    @note
        This method only returns filenames, you can also retrieve other
        information using listFileInfo.
    @param recursive Whether all paths of the archive are searched (if the 
        archive has a concept of that)
    @param dirs Set to true if you want the directories to be listed
        instead of files
    @return A list of filenames matching the criteria, all are fully qualified
    */
    abstract StringVector list(bool recursive = true, bool dirs = false);
    
    /** List all files in the archive with accompanying information.
    @param recursive Whether all paths of the archive are searched (if the 
        archive has a concept of that)
    @param dirs Set to true if you want the directories to be listed
        instead of files
    @return A list of structures detailing quite a lot of information about
        all the files in the archive.
    */
    abstract FileInfoList listFileInfo(bool recursive = true, bool dirs = false);
    
    /** Find all file or directory names matching a given pattern
        in this archive.
    @note
        This method only returns filenames, you can also retrieve other
        information using findFileInfo.
    @param pattern The pattern to search for; wildcards (*) are allowed
    @param recursive Whether all paths of the archive are searched (if the 
        archive has a concept of that)
    @param dirs Set to true if you want the directories to be listed
        instead of files
    @return A list of filenames matching the criteria, all are fully qualified
    */
    abstract StringVector find(string pattern, bool recursive = true,
                               bool dirs = false);
    
    /** Find out if the named file exists (note: fully qualified filename required) */
    abstract bool exists(string filename); 
    
    /** Retrieve the modification time of a given file */
    time_t getModifiedTime(string filename); 
    
    
    /** Find all files or directories matching a given pattern in this
        archive and get some detailed information about them.
    @param pattern The pattern to search for; wildcards (*) are allowed
    @param recursive Whether all paths of the archive are searched (if the 
    archive has a concept of that)
    @param dirs Set to true if you want the directories to be listed
        instead of files
    @return A list of file information structures for all files matching 
        the criteria.
    */
    abstract FileInfoList findFileInfo(string pattern, 
                                       bool recursive = true, bool dirs = false);
    
    /// Return the type code of this Archive
   string getType(){ return mType; }
    
}


/** Abstract factory class, archive codec plugins can register concrete
    subclasses of this.
    @remarks
        All access to 'archives' (collections of files, compressed or
        just folders, maybe even remote) is managed via the abstract
        Archive class. Plugins are expected to provide the
        implementation for the actual codec itself, but because a
        subclass of Archive has to be created for every archive, a
        factory class is required to create the appropriate subclass.
    @par
        So archive plugins create a subclass of Archive AND a subclass
        of ArchiveFactory which creates instances of the Archive
        subclass. See the 'Zip' and 'FileSystem' plugins for examples.
        Each Archive and ArchiveFactory subclass pair deal with a
        single archive type (identified by a string).
*/
class ArchiveFactory : FactoryObj!Archive //, public ArchiveAlloc
{
public:
    ~this() {}
    /** Creates a new object.
    @param name Name of the object to create
    @return
        An object created by the factory. The type of the object depends on
        the factory.
    */
    abstract Archive createInstance(string name, bool readOnly);
    
    override Archive createInstance(string name) { return createInstance(name, true); }
}

/** This class manages the available ArchiveFactory plugins. 
*/
class ArchiveManager// : public Singleton<ArchiveManager>, public ArchiveAlloc
{
    mixin Singleton!ArchiveManager;
    
protected:
    //typedef map<String, ArchiveFactory*>.type ArchiveFactoryMap;
    alias ArchiveFactory[string] ArchiveFactoryMap;
    /// Factories available to create archives, indexed by archive type (String identifier e.g. 'Zip')
    ArchiveFactoryMap mArchFactories;
    /// Currently loaded archives
    //typedef map<String, Archive*>.type ArchiveMap;
    alias Archive[string] ArchiveMap;
    ArchiveMap mArchives;
    
public:
    /** Default constructor - should never get called by a client app.
    */
    this() {}
    
    /** Default destructor.
    */
    ~this()
    {
        // Unload & delete resources in turn
        foreach(arch; mArchives)
        {
            // Unload
            arch.unload();
            // Find factory to destroy
            auto fit = arch.getType() in mArchFactories;
            if (fit is null)
            {
                // Factory not found
                throw new ItemNotFoundError( "Cannot find an archive factory "
                                            "to deal with archive of type " ~ arch.getType(), "ArchiveManager.~ArchiveManager");
            }
            fit.destroyInstance(arch);
            
        }
        // Empty the list
        mArchives.clear();
    }
    
    /** Opens an archive for file reading.
        @remarks
            The archives are created using class factories within
            extension libraries.
        @param filename
            The filename that will be opened
        @param ref Library
            The library that contains the data-handling code
        @return
            If the function succeeds, a valid pointer to an Archive
            object is returned.
        @par
            If the function fails, an exception is thrown.
    */
    Archive load(string filename,string archiveType, bool readOnly)
    {
        auto i = filename in mArchives;
        Archive pArch;
        
        if (i is null)
        {
            // Search factories
            auto it = archiveType in mArchFactories;
            if (it is null)
                // Factory not found
                throw new ItemNotFoundError( "Cannot find an archive factory "
                                            "to deal with archive of type " ~ archiveType, "ArchiveManager.load");
            
            pArch = (*it).createInstance(filename, readOnly);
            pArch.load();
            mArchives[filename] = pArch;
            
        }
        else
        {
            pArch = *i;
        }
        return pArch;
    }
    
    /** Unloads an archive.
    @remarks
        You must ensure that this archive is not being used before removing it.
    */
    void unload(ref Archive arch)
    {
        unload(arch.getName());
    }
    /** Unloads an archive by name.
    @remarks
        You must ensure that this archive is not being used before removing it.
    */
    void unload(string filename)
    {
        auto i = filename in mArchives;
        
        if (i !is null)
        {
            (*i).unload();
            // Find factory to destroy
            auto fit = (*i).getType() in mArchFactories;
            if (fit is null)
            {
                // Factory not found
                throw new ItemNotFoundError( "Cannot find an archive factory "
                                            "to deal with archive of type " ~ (*i).getType(), "ArchiveManager.~ArchiveManager");
            }
            (*fit).destroyInstance(*i);
            mArchives.remove(filename);
        }
    }
    
    //typedef MapIterator<ArchiveMap> ArchiveMapIterator;
    /** Get an iterator over the Archives in this Manager. */
    //ArchiveMapIterator getArchiveIterator();
    
    /** Adds a new ArchiveFactory to the list of available factories.
        @remarks
            Plugin developers who add new archive codecs need to call
            this after defining their ArchiveFactory subclass and
            Archive subclasses for their archive type.
    */
    void addArchiveFactory(ref ArchiveFactory factory)
    {        
        mArchFactories[factory.getType()] = factory;
        LogManager.getSingleton().logMessage("ArchiveFactory for archive type " ~ factory.getType() ~ " registered.");
    }
}


/** Specialisation of the Archive class to allow reading of files from 
    filesystem folders / directories.
*/
class FileSystemArchive : Archive 
{
protected:
    /** Utility method to retrieve all files in a directory matching pattern.
    @param pattern
        File pattern.
    @param recursive
        Whether to cascade down directories.
    @param dirs
        Set to @c true if you want the directories to be listed instead of files.
    @param simpleList
        Populated if retrieving a simple list.
    @param detailList
        Populated if retrieving a detailed list  (if simpleList is null).
        @todo 'patterns'
    */
    void findFiles(string pattern, bool recursive, bool dirs,
                   StringVector* simpleList, FileInfoList* detailList)
    {
        // pattern can contain a directory name, separate it from mask
        size_t pos1 = pattern.lastIndexOf ('/');
        size_t pos2 = pattern.lastIndexOf ('\\');
        if (pos1 == -1 || ((pos2 != -1) && (pos1 < pos2)))
            pos1 = pos2;
        string directory;
        if (pos1 != -1)
            directory = pattern[0 .. pos1 + 1];
        
        //string full_pattern = concatenate_path(mName, pattern);
        string full_pattern = concatenate_path(mName, directory);

        Log.Stream stream;
        debug
        {
            stream = LogManager.getSingleton().stream();
            stream << "--- findFiles --- Pattern: " << pattern << stream.endl << stream.Flush();
        }
        
        //FIXME dirEntries is too seg. fault happy with invalid paths durr
        if(!full_pattern.isDir)
        {
            LogManager.getSingleton().logMessage(full_pattern ~ " does not look like a valid path!");
            return;
        }
        
        //NOTE: C++ version has path and wildcards etc all in one full_pattern, but separately here
        foreach(entry; dirEntries(full_pattern, pattern, recursive ? SpanMode.breadth : SpanMode.shallow))
        {
            if (dirs == entry.isDir &&
                ( !msIgnoreHidden || true /+ !entry.isHidden +/ ) &&
                (!dirs || !is_reserved_dir (entry.name)))
            {
                debug {stream << entry.name << stream.endl;}
                if (simpleList !is null)
                {
                    //simpleList.insertBack(directory + tagData.name);
                    (*simpleList).insert(entry.name);
                }
                else
                {
                    FileInfo fi;
                    fi.archive = this;
                    fi.filename = entry.name; //directory + tagData.name;
                    fi.basename = std.path.baseName(entry.name);
                    fi.path = std.path.dirName(entry.name); //directory;
                    fi.compressedSize = cast(size_t)entry.size;
                    fi.uncompressedSize = cast(size_t)entry.size;
                    (*detailList).insert(fi);
                }
            }
        }
        
        debug(DBGARCHIVE)
        {
            if(simpleList !is null)
                stream << (*simpleList);
            else
                stream << (*detailList);
        }
    }
    
    static bool is_reserved_dir (string fn)
    {
        return (fn [0] == '.' && (fn [1] == 0 || (fn [1] == '.' && fn [2] == 0)));
    }
    
    static bool is_absolute_path(string path)
    {
        if(!path.length) return false;
        version(Windows)
        {
            if (std.ascii.isAlpha(path[0]) && path[1] == ':')
                return true;
        }
        else
            return path[0] == '/' || path[0] == '\\';
        return false;
    }
    
    static string concatenate_path(string base,string name)
    {
        if (base is null || is_absolute_path(name))
            return name;
        else
            return base ~ '/' ~ name;
    }
    
    //OGRE_AUTO_MUTEX
    Mutex mLock;
public:
    this(string name,string archType, bool readOnly )
    {
        super(name, archType);
        // Even failed attempt to write to read only location violates Apple AppStore validation process.
        // And successfull writing to some probe file does not prove that whole location with subfolders 
        // is writable. Therefore we accept read only flag from outside and do not try to be too smart.
        mReadOnly = readOnly;
    }
    
    ~this()
    {
        unload();
    }
    
    /// @copydoc Archive.isCaseSensitive
    override bool isCaseSensitive()
    {
        version(Windows)
            return false;
        else
            return true;
    }
    
    /// @copydoc Archive.load
    override void load()
    {
        // nothing to do here
    }
    /// @copydoc Archive.unload
    override void unload()
    {
        // nothing to see here, move along
    }
    
    /// @copydoc Archive.open
    override DataStream open(string filename, bool readOnly = true)
    {
        string full_path = concatenate_path(mName, filename);
        //string full_path = filename; // FIXME meshes' path is not full while materials' etc are ???
        if(filename.indexOf(mName) > -1)
            full_path = filename;
        stderr.writeln("Archive open: ", mName, " , ", filename);
        // Use filesystem to determine size 
        // (quicker than streaming to the end and back)
        //struct stat tagStat;
        //int ret = stat(full_path.c_str(), &tagStat);
        //assert(ret == 0 && "Problem getting file size" );
        //()ret;  // Silence warning
        //ulong fsize = std.file.getSize(filename);
        
        // Always open in binary mode
        // Also, always include reading
        /*std.ios.openmode mode = std.ios.in | std.ios.binary;
        std.istream* baseStream = 0;
        std.ifstream* roStream = 0;
        std.fstream* rwStream = 0;*/
        File *hFile;
        File roFile, rwFile;
        
        if (!readOnly && isReadOnly())
        {
            throw new InvalidParamsError(
                "Cannot open a file in read-write mode in a read-only archive",
                "FileSystemArchive.open");
        }
        
        if (!readOnly)
        {
            /*mode |= std.ios.out;
            rwStream = OGRE_NEW_T(std.fstream, MEMCATEGORY_GENERAL)();
            rwStream->open(full_path.c_str(), mode);
            baseStream = rwStream;*/
            rwFile = File(full_path, "rwb");
            hFile = &rwFile;
        }
        else
        {
            /*roStream = OGRE_NEW_T(std.ifstream, MEMCATEGORY_GENERAL)();
            roStream->open(full_path.c_str(), mode);
            baseStream = roStream;*/
            roFile = File(full_path, "rb");
            hFile = &roFile;
        }
        
        
        // Should check ensure open succeeded, in case fail for some reason.
        if (!hFile.isOpen())
        {
            //OGRE_DELETE_T(roStream, basic_ifstream, MEMCATEGORY_GENERAL);
            //OGRE_DELETE_T(rwStream, basic_fstream, MEMCATEGORY_GENERAL);
            throw new FileNotFoundError(
                "Cannot open file: " ~ filename,
                "FileSystemArchive.open");
        }
        
        /// Construct return stream, tell it to delete on destroy
        //FileStreamDataStream* stream = 0;
        FileHandleDataStream stream;
        if (rwFile.isOpen())
        {
            // use the writeable stream 
            stream = new FileHandleDataStream(filename,
                                              rwFile, DataStream.AccessMode.READ | 
                                              DataStream.AccessMode.WRITE);
        }
        else
        {
            // read-only stream
            stream = new FileHandleDataStream(filename,
                                              roFile, DataStream.AccessMode.READ);
        }
        return stream;
    }
    
    /// @copydoc Archive.create
    override DataStream create(string filename)
    {
        if (isReadOnly())
        {
            throw new InvalidParamsError(
                "Cannot create a file in a read-only archive", 
                "FileSystemArchive.remove");
        }
        
        string full_path = concatenate_path(mName, filename);
        
        // Always open in binary mode
        // Also, always include reading
        /*std.ios.openmode mode = std.ios.out | std.ios.binary;
        std.fstream* rwStream = OGRE_NEW_T(std.fstream, MEMCATEGORY_GENERAL)();
        rwStream->open(full_path.c_str(), mode);*/
        auto rwFile = File(full_path, "rwb");
        
        // Should check ensure open succeeded, in case fail for some reason.
        if (!rwFile.isOpen())
        {
            //OGRE_DELETE_T(rwStream, basic_fstream, MEMCATEGORY_GENERAL);
            throw new FileNotFoundError(
                "Cannot open file: " ~ filename,
                "FileSystemArchive.create");
        }
        
        auto stream = new FileHandleDataStream(filename, rwFile, 
                                               DataStream.AccessMode.READ |
                                               DataStream.AccessMode.WRITE);
        
        return stream;
    }
    
    /// @copydoc Archive.remove
    override void remove(string filename)
    {
        if (isReadOnly())
        {
            throw new InvalidParamsError(
                "Cannot remove a file from a read-only archive", 
                "FileSystemArchive.remove");
        }
        string full_path = concatenate_path(mName, filename);
        std.file.remove(full_path);
        
    }
    
    /// @copydoc Archive.list
    override StringVector list(bool recursive = true, bool dirs = false)
    {
        StringVector ret;
        
        findFiles("*", recursive, dirs, &ret, null);
        
        return ret;
    }
    
    /// @copydoc Archive.listFileInfo
    override FileInfoList listFileInfo(bool recursive = true, bool dirs = false)
    {
        FileInfoList ret;
        
        findFiles("*", recursive, dirs, null, &ret);
        
        return ret;
    }
    
    /// @copydoc Archive.find
    override StringVector find(string pattern, bool recursive = true,
                               bool dirs = false)
    {
        StringVector ret;
        
        findFiles(pattern, recursive, dirs, &ret, null);
        
        return ret;
        
    }
    
    /// @copydoc Archive.findFileInfo
    override FileInfoList findFileInfo(string pattern, bool recursive = true,
                                       bool dirs = false)
    {
        FileInfoList ret;
        
        findFiles(pattern, recursive, dirs, null, &ret);
        
        return ret;
    }
    
    /// @copydoc Archive.exists
    override bool exists(string filename)
    {
        string full_path = concatenate_path(mName, filename);
        return std.file.exists(full_path);
    }
    
    /// @copydoc Archive.getModifiedTime
    override time_t getModifiedTime(string filename)
    {
        string full_path = concatenate_path(mName, filename);
        auto t = std.file.timeLastModified(full_path);
        return t.toUnixTime(); // from 1970 etc. ?
    }
    
    
    /// Set whether filesystem enumeration will include hidden files or not.
    /// This should be called prior to declaring and/or initializing filesystem
    /// resource locations. The default is true (ignore hidden files).
    static void setIgnoreHidden(bool ignore)
    {
        msIgnoreHidden = ignore;
    }
    
    /// Get whether hidden files are ignored during filesystem enumeration.
    static bool getIgnoreHidden()
    {
        return msIgnoreHidden;
    }
    
    static bool msIgnoreHidden = true;
}

/** Specialisation of ArchiveFactory for FileSystem files. */
class FileSystemArchiveFactory : ArchiveFactory
{
public:
    ~this() {}
    /// @copydoc FactoryObj.getType
    override string getType()
    {
        immutable static string name = "FileSystem";
        return name;
    }
    /// @copydoc FactoryObj.createInstance
    override Archive createInstance(string name, bool readOnly ) 
    {
        return new FileSystemArchive(name, "FileSystem", readOnly);
    }
    /// @copydoc FactoryObj.destroyInstance
    override void destroyInstance(ref Archive ptr) { destroy(ptr); }
}
