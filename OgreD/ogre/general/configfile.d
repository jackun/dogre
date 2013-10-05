module ogre.general.configfile;

import std.algorithm;
import std.string;
import std.stdio;

import ogre.resources.datastream;
import ogre.exception;
import ogre.resources.resourcegroupmanager;
import ogre.compat;
import ogre.strings;

/** \addtogroup Core
    *  @{
    */
/** \addtogroup General
    *  @{
    */
/** Class for quickly loading settings from a text file.
        @remarks
            This class is designed to quickly parse a simple file containing
            key/value pairs, mainly for use in configuration settings.
        @par
            This is a very simplified approach, no multiple values per key
            are allowed, no grouping or context is being kept etc.
        @par
            By default the key/values pairs are tokenised based on a
            separator of Tab, the colon (:) or equals (=) character. Each
            key - value pair must end in a carriage return.
        @par
            Settings can be optionally grouped in sections, using a header
            beforehand of the form [SectionName]. 
    */
//TODO Not sure if keep as class or struct
class ConfigFile //: public ConfigAlloc
{
public:
    
    this(){}

    ~this()
    {
        foreach (k,v; mSettings)
        {
            destroy(v);
        }
    }

    /// load from a filename (not using resource group locations)
    void load(string filename,string separators = "\t:=", bool trimWhitespace = true)
    {
        loadDirect(filename, separators, trimWhitespace);
    }

    /// load from a filename (using resource group locations)
    void load(string filename,string resourceGroup,string separators = "\t:=", bool trimWhitespace = true)
    {
        loadFromResourceSystem(filename, resourceGroup, separators, trimWhitespace);
    }

    /// load from a data stream
    void load(DataStream stream,string separators = "\t:=", bool trimWhitespace = true)
    {
        /* Clear current settings map */
        clear();
        
        string currentSection;
        SettingsMultiMap currentSettings;// = OGRE_NEW_T(SettingsMultiMap, MEMCATEGORY_GENERAL)();
        mSettings[currentSection] = currentSettings;
        
        
        /* Process the file line for line */
        string line, optName, optVal;
        while (!stream.eof())
        {
            line = stream.getLine();
            /* Ignore comments & blanks */
            if (line.length > 0 && line[0] != '#' && line[0] != '@')
            {
                if (line[0] == '[' && line[$-1] == ']')
                {
                    // Section
                    currentSection = line[1..$-1];
                    auto seci = currentSection in mSettings;
                    if (seci is null)
                    {
                        mSettings[currentSection] = currentSettings;
                    }
                    else
                    {
                        mSettings[currentSection] = *seci;
                    } 
                }
                else
                {
                    /* Find the first separator character and split the string there */
                    //TODO maxSplit limit implemented?
                    string[] splits = StringUtil.split(line, separators, 2);
                    if(splits.length == 2)
                    {
                        if(trimWhitespace)
                        {
                            //foreach(i; 0..splits.length)
                            //    splits[i] = splits[i].strip();
                            splits[0] = splits[0].strip();
                            splits[1] = splits[1].strip();
                        }
                        if((splits[0] in mSettings[currentSection]) is null)
                            mSettings[currentSection][splits[0]] = null;
                        mSettings[currentSection][splits[0]] ~= splits[1];
                    }
                    else
                    {   //XXX for debug
                        debug throw new InvalidParamsError("KeyValue line split length != 2.", "ConfigFile.load");
                    }
                }
            }
        }
    }

    /// load from a filename (not using resource group locations)
    void loadDirect(string filename,string separators = "\t:=", bool trimWhitespace = true)
    {
        //#if OGRE_PLATFORM == OGRE_PLATFORM_NACL
        //        OGRE_EXCEPT(Exception::ERR_CANNOT_WRITE_TO_FILE, "loadDirect is not supported on NaCl - tried to open: " + filename,
        //                    "ConfigFile::loadDirect");
        //#endif
        
        /* Open the configuration file */

        // Always open in binary mode
        auto fp = File(filename, "rb");
        if(!fp.isOpen())
            throw new FileNotFoundError("'" ~ filename ~ "' file not found!", "ConfigFile.load" );
        
        // Wrap as a stream
        auto stream = new FileHandleDataStream(filename, fp);
        
        load(stream, separators, trimWhitespace);
        
    }

    /// load from a filename (using resource group locations)
    void loadFromResourceSystem(string filename,string resourceGroup,string separators = "\t:=", bool trimWhitespace = true)
    {
        DataStream stream = ResourceGroupManager.getSingleton().openResource(filename, resourceGroup);
        load(stream, separators, trimWhitespace);
    }
    
    /** Gets the first setting from the file with the named key. 
        @param key The name of the setting
        @param section The name of the section it must be in (if any)
        @param defaultValue The value to return if the setting is not found
        */
    string getSetting(string key,string section = "",string defaultValue = null)
    {
        
        SettingsMultiMap *sec = section in mSettings;
        if (sec is null)
        {
            return defaultValue;
        }
        else
        {
            //if (!sec.hasKey(key))
            if ((key in (*sec)) is null)
            {
                return defaultValue;
            }
            else
            {
                return (*sec)[key][0];
            }
        }
    }

    /** Gets all settings from the file with the named key. */
    StringVector getMultiSetting(string key,string section = "")
    {
        StringVector ret;

        SettingsMultiMap* sec = section in mSettings;
        if (sec !is null)
        {
            auto arr = (*sec)[key];
            return arr;
            // Iterate over matches
            //foreach(val; arr)
            //{
            //    ret.insert(val);
            //}
        }
        return ret;   
    }
    
    //typedef multimap<String, String>::type SettingsMultiMap;
    //typedef MapIterator<SettingsMultiMap> SettingsIterator;

    //alias MultiMap!(string, string) SettingsMultiMap;
    alias string[][string] SettingsMultiMap;

    /** Gets an iterator for stepping through all the keys / values in the file. */
    //typedef map<String, SettingsMultiMap*>::type SettingsBySection;

    //TODO Does MultiMap get ref fed correctly?
    alias SettingsMultiMap[string] SettingsBySection;
    //typedef MapIterator<SettingsBySection> SectionIterator;
    /* * Get an iterator over all the available sections in the config file */
    //SectionIterator getSectionIterator()
    //{
    //    return SectionIterator(mSettings.begin(), mSettings.end());
    //}
    /* * Get an iterator over all the available settings in a section */
    //SettingsIterator getSettingsIterator(string section = StringUtil::BLANK)
    //{
    //SettingsBySection::const_iterator seci = mSettings.find(section);
    //    if (seci == mSettings.end())
    //    {
    //        OGRE_EXCEPT(Exception::ERR_ITEM_NOT_FOUND, 
    //                    "Cannot find section " + section, 
    //                    "ConfigFile::getSettingsIterator");
    //    }
    //    else
    //    {
    //        return SettingsIterator(seci->second->begin(), seci->second->end());
    //    }
    //}

    /** Get an assoc. array of all the available sections in the config file */
    ref SettingsBySection getSections()
    {
        return mSettings;
    }

    /** Get a MultiMap of all the available settings in a section */
    SettingsMultiMap getSettings(string section = "")
    {
        SettingsMultiMap* sec = section in mSettings;
        if(sec is null)
            throw new ItemNotFoundError("Cannot find section " ~ section, 
                                        "ConfigFile.getSettingsIterator");

        return (*sec);
    }
    
    /** Clear the settings */
    void clear()
    {
        //TODO Hmm, GC should probably deal with this
        foreach (k, ref v; mSettings)
        {
            destroy(v);
        }
        mSettings.clear();
    }
protected:
    SettingsBySection mSettings;
}
/** @} */
/** @} */
