/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2017 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.font;

import retrograde.entity;
import retrograde.file;

import std.conv;

class Font {
	private string _fontName;
	private uint _pointSize;
	private ulong _index;

	public @property string fontName() {
		return _fontName;
	}

	public @property uint pointSize() {
		return _pointSize;
	}

	public @property ulong index() {
		return _index;
	}

	this(string fontName, uint pointSize, ulong index) {
		this._fontName = fontName;
		this._pointSize = pointSize;
		this._index = index;
	}
}

class FontComponent : EntityComponent, Snapshotable {
	mixin EntityComponentIdentity!"FontComponent";

	private Font _font;

	public @property Font font() {
		return _font;
	}

	this(Font font) {
		this._font = font;
	}

	public string[string] getSnapshotData() {
		string[string] snapshotData;
		if (_font !is null) {
			snapshotData = [
				"fontName": _font.fontName,
				"pointSize": to!string(_font.pointSize),
				"index": to!string(_font.index)
			];
		}

		return snapshotData;
	}
}

class FontComponentFactory {
	public abstract FontComponent create(File fontFile, uint pointSize, ulong index = 0);
}

class TextComponent : EntityComponent, Snapshotable {
	mixin EntityComponentIdentity!"TextComponent";

	private string _text;
	private bool _isChanged;

	public @property void text(string newText) {
		this._text = newText;
		this._isChanged = true;
	}

	public @property string text() {
		return this._text;
	}

	public @property bool isChanged() {
		return this._isChanged;
	}

	public void clearChanged() {
		this._isChanged = false;
	}

	this(string text = "") {
		this.text = text;
	}

	public string[string] getSnapshotData() {
		return [
			"text": this._text
		];
	}
}
