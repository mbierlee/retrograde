/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2021 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.core.storage;

import std.file : read, write, thisExePath, stdTempDir = tempDir, mkdirRecurse;
import std.path : dirName, baseName, buildNormalizedPath, isValidPath;

/**
 * File metadata flags.
 */
struct FileMeta {
    /**
     * Whether the file was created by the storage API.
     *
     * This is typically not the case for files created on-the-fly (via new File())
     */
    bool fromStorage = false;

    /**
     * Whether on the storage API the user has read access to the file.
     */
    bool readAccess = false;

    /**
     * Whether on the storage API the user has write access to the file.
     */
    bool writeAccess = false;
}

/**
 * A platform-independent implementation of files.
 */
class File {

    private const string _name;
    private ubyte[] _data;
    private FileMeta _meta;

    /**
     * Creates a new empty file.
     *
     * Creating the file does not implicitly store it on a storage device yet. You must use the Storage API for that.
     *
     * Params:
     *  name = The name of the file. Platform constraints are not checked, the file may have an illegal name. 
               For safety stick with alpha-numeric filenames only.
     */
    this(const string name) {
        this._name = name;
    }

    /**
     * Creates a new file with the given binary data.
     *
     * Creating the file does not implicitly store it on a storage device yet. You must use the Storage API for that.
     *
     * Params:
     *  name = The name of the file. Platform constraints are not checked, the file may have an illegal name. 
               For safety stick with alpha-numeric filenames only.
     *  data = Binary data of the file.
     */
    this(const string name, const ubyte[] data) {
        this(name);
        this._data = cast(ubyte[]) data;
    }

    /**
     * Creates a new file with the given textual data.
     *
     * Creating the file does not implicitly store it on a storage device yet. You must use the Storage API for that.
     *
     * Params:
     *  name = The name of the file. Platform constraints are not checked, the file may have an illegal name. 
               For safety stick with alpha-numeric filenames only.
     *  textData = UTF-8 encoded text data.
     */
    this(const string name, const string textData) {
        this(name);
        this._data = cast(ubyte[]) textData;
    }

    /**
     * The name of the file.
     */
    string name() const {
        return _name;
    }

    /**
     * Returns the binary representation of this file.
     */
    const(ubyte[]) data() const {
        return cast(const(ubyte[])) _data;
    }

    /**
     * Change this file's binary data.
     *
     * Changing it doesn't persist it yet. Use the Storage API to persist it.
     */
    void data(const ubyte[] newData) {
        _data = cast(ubyte[]) newData;
    }

    /**
     * Returns the textual representation of this file.
     */
    string textData() const {
        return cast(string) _data;
    }

    /**
     * Change this file's textual data.
     *
     * Changing it doesn't persist it yet. Use the Storage API to persist it.
     */
    void textData(const string newTextData) {
        _data = cast(ubyte[]) newTextData;
    }

    /**
     * Returns a copy of this file's metadata flags.
     */
    FileMeta meta() const {
        return _meta;
    }

}

/**
 * An API interface for a platform-dependent storage system.
 */
interface StorageApi {

    /**
     * Read a file from storage at a specific location.
     *
     * The file is immediately loaded into memory.
     * Params:
     *  location = Location of the file. How to specify the location dependends on the API implementation.
     */
    File readFile(string location);

    /**
     * Write a file to storage at a specific location.
     * Params:
     *  location = Physical Location of the file. How to specify the location dependends on the API implementation.
     *  file = File to store.
     */
    void writeFile(string location, const File file);

    /**
     * Returns the absolute path to a directory where this application is allowed to read/write.
     * Whether it is sandboxed from other applications depends on the platform and storage API implementation.
     */
    string tempDir();
}

/**
 * A generic storage API that uses the D std libary for file I/O.
 *
 * Typically used for desktop OSes with traditional filesystems.
 */
class GenericStorageApi : StorageApi {

    /**
     * Read a file from storage at a specific location.
     *
     * The file is immediately loaded into memory.
     * Params:
     *  location = Path of the file including the filename. Use the OS' file and path naming convention.
     *
     * Throws: FileException on read error.
     */
    File readFile(string location) {
        assert(isValidPath(location));

        ubyte[] data = cast(ubyte[]) read(location);
        auto fileName = baseName(location);
        return new File(fileName, data);
    }

    /**
     * Write a file to storage at a specific location.
     *
     * If the file does not exist it will be created, including the complete path.
     * Params:
     *  location = Path of the file including the filename. Use the OS' file and path naming convention.
     *  file = File to store.
     */
    void writeFile(string location, const File file) {
        assert(isValidPath(location));

        auto fileDir = dirName(location);
        mkdirRecurse(fileDir);
        const(ubyte[]) data = file.data;
        write(location, data);
    }

    /**
     * Returns the absolute path to a directory where this application is allowed to read/write.
     * On Desktop OSes this directory is not sandboxed since it will be the shared temp directory.
     * If the temp directory cannot be found, "." is returned (the current working directory).
     */
    string tempDir() {
        return stdTempDir;
    }
}

/**
 * Returns the absolute location to the given file/directory relative from the directory of the program's executable.
 *
 * For example, if the executable (on Windows) resides in "C:\games\thisgame\game.exe" and the relative path given is "assets\tex.png", 
 * the resulting path is "C:\games\thisgame\assets\tex.png".
 *
 * This function only returns absolute paths on platforms where the executable is physically located on a filesystem.
 * On other platforms it might simply return relativePath. You want to use this function when the executable's current working
 * directory differs from the executable's path.
 *
 * Params:
 *  relativePath: Path of a file/dir relative from the executable.
 */
string appendToExeDir(string relativePath) {
    return buildNormalizedPath(dirName(thisExePath), relativePath);
}

// File tests
version (unittest) {
    import std.conv : to;

    @("Create empty file")
    unittest {
        auto file = new File("null");
        assert(file.name == "null");
        assert(file.data == []);
        assert(file.textData == "");
    }

    @("Create binary file")
    unittest {
        const ubyte[] expectedData = [0x0, 0x1, 0x2, 0x3];
        auto file = new File("test.bin", expectedData);
        assert(file.name == "test.bin");
        assert(file.data == expectedData);
    }

    @("Create text file")
    unittest {
        string expectedText = "test content";
        auto file = new File("test.txt", expectedText);
        assert(file.name == "test.txt");
        assert(file.textData == expectedText);
    }

    @("Create binary file and read text")
    unittest {
        const ubyte[] data = [0x48, 0x69];
        auto file = new File("test.txt", data);
        assert(file.textData == "Hi");
    }

    @("Default filemeta of files created on-the-fly")
    unittest {
        auto file = new File("test.txt", "Hi");
        assert(!file.meta.fromStorage);
        assert(!file.meta.readAccess);
        assert(!file.meta.writeAccess);
    }

    @("Change binary file")
    unittest {
        const ubyte[] initialData = [0x0, 0x1, 0x2, 0x3];
        const ubyte[] newData = [0x4, 0x5, 0x6, 0x7];
        auto file = new File("test.bin", initialData);
        file.data = newData;
        assert(file.data == newData);
    }

    @("Change text file")
    unittest {
        const string initialText = "test content";
        const string newText = "new content";
        auto file = new File("test.txt", initialText);
        file.textData = newText;
        assert(file.textData == newText);
    }
}
