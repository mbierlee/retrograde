/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2018 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.file;

import std.file;

class File {
    private string _fileName;

    public @property string fileName() {
        return _fileName;
    }

    public @property bool exists() {
        return std.file.exists(fileName);
    }

    this(string fileName) {
        this._fileName = fileName;
    }

    public string readAsText() {
        return readText(fileName);
    }
}

class VirtualTextFile : File {
    private string content;

    this(string content) {
        this("VirtualTextFile", content);
    }

    this(string fileName, string content) {
        super(fileName);
        this.content = content;
    }

    public override string readAsText() {
        return content;
    }
}
