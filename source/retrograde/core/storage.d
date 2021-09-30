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
     * Returns a slice of the binary representation of this file.
     */
    ubyte[] data() {
        return _data;
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
     * Returns a copy of the textual representation of this file.
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

    @("Filebytes cannot be altered via get handle")
    unittest {
        const ubyte[] expectedData = [0x0, 0x1, 0x2, 0x3];
        auto file = new File("test.bin", expectedData);
        file.data[0] = 0x4;
        assert(file.data == expectedData);
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
