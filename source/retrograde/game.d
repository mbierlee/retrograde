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

module retrograde.game;

import retrograde.application;

interface Game {
    void initialize();
    void update();
    void render(double extraPolation);
    void cleanup();

    @property long targetFrameTime();
    @property long lagFrameLimit();

    @property bool terminatable();
    void requestTermination();

    @property string name();
    @property string copyright();
    @property WindowCreationContext windowCreationContext();
}


abstract class BaseGame : Game {
    private bool _terminatable = false;
    private string _gameName;
    private string _copyright;

    public this(string gameName, string copyright = "No copyright") {
        this._gameName = gameName;
        this._copyright = copyright;
    }

    public override @property long targetFrameTime() {
        return 10L;
    }

    public override @property long lagFrameLimit() {
        return 100L;
    }

    public override @property string name() {
        return _gameName;
    }

    public override @property string copyright() {
        return _copyright;
    }

    public override @property WindowCreationContext windowCreationContext() {
        return WindowCreationContext();
    }

    public override @property bool terminatable() {
        return _terminatable;
    }

    public override void requestTermination() {
        _terminatable = true;
    }
}
