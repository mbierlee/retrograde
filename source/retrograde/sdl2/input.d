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

module retrograde.sdl2.input;

version(Have_derelict_sdl2) {

import poodinis;

import std.experimental.logger;
import std.string;

import derelict.sdl2.sdl;

class Sdl2InputDeviceManager {
	private SDL_Joystick*[SDL_JoystickID] joysticks;
	private double _mouseSensitivity = 6;

	@Autowire
	private Logger logger;

	public @property void captureMouse(bool capture) {
		SDL_SetRelativeMouseMode(capture);
	}

	public @property bool captureMouse() {
		return cast(bool) SDL_GetRelativeMouseMode();
	}

	public bool emitMouseMotionReset = true;

	public @property void mouseAcceleration(bool mouseAcceleration) {
		SDL_SetHint(SDL_HINT_MOUSE_RELATIVE_MODE_WARP, mouseAcceleration ? "1" : "0");
	}

	public @property bool mouseAcceleration() {
		auto hint = SDL_GetHint(SDL_HINT_MOUSE_RELATIVE_MODE_WARP);
		return hint !is null && *hint == '1';
	}

	public @property void mouseSensitivityModifier(double sensitivity) {
		_mouseSensitivity = sensitivity;
	}

	public @property double mouseSensitivityModifier() {
		return _mouseSensitivity;
	}

	public void initialize() {
		if (SDL_WasInit(SDL_INIT_JOYSTICK)) {
			SDL_JoystickEventState(SDL_ENABLE);
		}
	}

	public void cleanup() {
		foreach(joystick ; joysticks) {
			if (joystick is null) {
				continue;
			}

			SDL_JoystickClose(joystick);
		}
		joysticks.destroy();
	}

	public void openJoystick(int joystickNumber) {
		SDL_Joystick* joystick = SDL_JoystickOpen(joystickNumber);
		if (joystick) {
			auto index = SDL_JoystickInstanceID(joystick);
			joysticks[index] = joystick;
		} else {
			logger.errorf("Couldn't open joystick %s", joystickNumber);
		}
	}

	public void closeJoystick(int joystickNumber) {
		auto joystick = joystickNumber in joysticks;
		if (joystick) {
			SDL_JoystickClose(*joystick);
			joysticks[joystickNumber] = null;
		}
	}
}

}
