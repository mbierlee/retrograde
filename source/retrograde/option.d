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

module retrograde.option;

import std.exception;
import std.traits;

abstract class Option(Type) {
	public Type get();
	public bool isEmpty();

	public Type getOrElse(Type delegate() fn) {
		return isEmpty() ? fn() : get();
	}

	public void ifNotEmpty(void delegate(Type instance) fn) {
		if (!isEmpty()) {
			fn(get());
		}
	}
}

class Some(Type) : Option!Type {
	private Type data;

	this(Type data) {
		static if (__traits(compiles, data = null)) {
			enforce!Exception(data !is null, "Data reference passed to option cannot be null");
		}

		this.data = data;
	}

	public override Type get() {
		return data;
	}

	public override bool isEmpty() {
		return false;
	}

	public static Some opCall(Type data) {
		return new Some(data);
	}
}

class None(Type) : Option!Type {
	public override Type get() {
		throw new Exception("No data is available (Option type None)");
	}

	public override bool isEmpty() {
		return true;
	}

	public static None opCall() {
		return new None();
	}
}
