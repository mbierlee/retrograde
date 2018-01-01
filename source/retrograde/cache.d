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

module retrograde.cache;

import retrograde.option;

import std.exception;

class Cache(KeyType, DataType) {
    private DataType[KeyType] cacheData;

    public Option!DataType get(KeyType key) {
        auto cachedData = key in cacheData;
        if (cachedData) {
            return Some!DataType(*cachedData);
        }

        return None!DataType();
    }

    public DataType getOrAdd(KeyType key, DataType delegate() fetch) {
        auto cachedData = key in cacheData;
        if (cachedData) {
            return *cachedData;
        }

        auto fetchedData = fetch();
        add(key, fetchedData);
        return fetchedData;
    }

    public void add(KeyType key, DataType data) {
        enforce(data !is null, "Given cache data is null");
        cacheData[key] = data;
    }

    public void remove(KeyType key) {
        cacheData.remove(key);
    }

    public bool has(KeyType key) {
        return (key in cacheData) !is null;
    }

    public void clear() {
        cacheData.destroy();
    }
}
