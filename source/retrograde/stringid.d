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

module retrograde.stringid;

debug(readableStringId) {
	alias StringId = string;
} else {
	alias StringId = uint;
}

public pure StringId sid(string idString) {
	debug(readableStringId) {
		return idString;
	} else {
		StringId stringId = 7;
		foreach(char strChar; idString) {
			stringId = (stringId * 31) + cast(StringId) strChar;
		}

		return stringId;
	}
}

class SidMap {
	private string[StringId] sids;

	public void add(string str) {
		sids[sid(str)] = str;
	}

	public string get(StringId sid) {
		return sids[sid];
	}

	public bool contains(StringId sid) {
		auto str = sid in sids;
		return str !is null;
	}

	public string opIndex(StringId sid) {
		return get(sid);
	}
}