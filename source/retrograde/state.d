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

module retrograde.state;

import retrograde.entity;
import retrograde.option;

import std.typecons;

alias ExitDiscardedStates = Flag!"exitDiscardedStates";
alias EnableStateSuspension = Flag!"enableStateSuspension";

class StateMachine {
    private State[] stateStack;

    private bool stateSuspensionEnabled = false;

    this(EnableStateSuspension enableStateSuspension = EnableStateSuspension.no) {
        stateSuspensionEnabled = enableStateSuspension;
    }

    public void setState(State state, ExitDiscardedStates exitDiscardedStates = ExitDiscardedStates.no) {
        clearStates(exitDiscardedStates);
        pushState(state);
    }

    public void switchState(State state) {
        if (stateStack.length == 0) {
            setState(state);
        } else {
            getCurrentState().ifNotEmpty(state => state.exitState(this));
            stateStack[$ - 1] = state;
            state.enterState(this);
        }
    }

    public void pushState(State state) {
        getCurrentState().ifNotEmpty((state) {
            stateSuspensionEnabled ? state.suspendState(this) : state.exitState(this);
        });
        stateStack ~= state;
        state.enterState(this);
    }

    public Option!State popState() {
        auto poppedState = getCurrentState();
        poppedState.ifNotEmpty(state => state.exitState(this));
        stateStack = stateStack[0 .. $-1];
        getCurrentState().ifNotEmpty((state) {
            stateSuspensionEnabled ? state.resumeState(this) : state.enterState(this);
        });
        return poppedState;
    }

    public void truncateStates(ExitDiscardedStates exitDiscardedStates = ExitDiscardedStates.no) {
        if (stateStack.length > 0) {
            auto topState = getCurrentState().get();
            if (exitDiscardedStates) {
                foreach (state; stateStack[0 .. $-1]) {
                    state.exitState(this);
                }
            }
            clearStates();
            stateStack ~= topState;
        }
    }

    public void clearStates(ExitDiscardedStates exitDiscardedStates = ExitDiscardedStates.no) {
        if (exitDiscardedStates) {
            foreach (state; stateStack) {
                state.exitState(this);
            }
        }

        stateStack.destroy();
    }

    public Option!State getCurrentState() {
        return stateStack.length > 0 ? new Some!State(stateStack[$ - 1]) : new None!State();
    }
}

class StateMachineEntityComponent : EntityComponent, Snapshotable {
    mixin EntityComponentIdentity!"StateMachineEntityComponent";

    private StateMachine _stateMachine;

    this(StateMachine stateMachine) {
        this._stateMachine = stateMachine;
    }

    public @property StateMachine stateMachine() {
        return _stateMachine;
    }

    public string[string] getSnapshotData() {
        string currentStateName = "";
        _stateMachine.getCurrentState().ifNotEmpty((s) { currentStateName = s.stateName; });

        return [
            "currentState": currentStateName
        ];
    }
}

class StateMachineProcessor : EntityProcessor {
    public override bool acceptsEntity(Entity entity) {
        return entity.hasComponent!StateMachineEntityComponent;
    }

    public override void update() {
        foreach (entity; _entities.getAll()) {
            auto stateMachine = entity.getFromComponent!StateMachineEntityComponent(component => component.stateMachine);
            stateMachine.getCurrentState().ifNotEmpty(state => state.update(stateMachine, entity));
        }
    }
}

abstract class State {
    private string _stateName;

    public @property string stateName() {
        return _stateName;
    }

    this(string stateName) {
        this._stateName = stateName;
    }

    public void enterState(StateMachine stateMachine){}
    public void update(StateMachine stateMachine, Entity entity){}
    public void exitState(StateMachine stateMachine){}
    public void suspendState(StateMachine stateMachine){}
    public void resumeState(StateMachine stateMachine){}
}
