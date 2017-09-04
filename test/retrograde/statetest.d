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

import retrograde.state;
import dunit;

import retrograde.entity;

class StateMachineTest {
	mixin UnitTest;

	private class TestState : State {
		public int stateEnters = 0;
		public int stateExits = 0;
		public int stateSuspensions = 0;
		public int stateResumptions = 0;

		this() {
			super("TestState");
		}

		public override void enterState(StateMachine stateMachine){
			stateEnters += 1;
		}

		public override void exitState(StateMachine stateMachine){
			stateExits += 1;
		}

		public override void suspendState(StateMachine stateMachine){
			stateSuspensions += 1;
		}

		public override void resumeState(StateMachine stateMachine){
			stateResumptions += 1;
		}
	}

	@Test
	public void testSetState() {
		auto stateMachine = new StateMachine();
		auto expectedState = new TestState();

		stateMachine.setState(expectedState);

		auto currentState = stateMachine.getCurrentState().get();
		assertEquals(expectedState, currentState);
	}

	@Test
	public void testSetStateExitingPrevious() {
		auto stateMachine = new StateMachine();
		auto state = new TestState();
		stateMachine.pushState(state);
		stateMachine.pushState(state);
		stateMachine.pushState(state);

		stateMachine.setState(state, ExitDiscardedStates.yes);

		assertEquals(4, state.stateEnters);
		assertEquals(5, state.stateExits);
	}

	@Test
	public void testSwitchState() {
		auto stateMachine = new StateMachine();
		auto initialState = new TestState();
		auto intermediateState = new TestState();
		auto expectedState = new TestState();
		stateMachine.setState(initialState);

		stateMachine.switchState(expectedState);

		auto currentState = stateMachine.getCurrentState().get();
		assertEquals(expectedState, currentState);
	}

	@Test
	public void testSwitchStateSetsWhenStackIsEmpty() {
		auto stateMachine = new StateMachine();
		auto expectedState = new TestState();

		stateMachine.switchState(expectedState);

		auto currentState = stateMachine.getCurrentState().get();
		assertEquals(expectedState, currentState);
	}

	@Test
	public void testPushState() {
		auto stateMachine = new StateMachine();
		auto initialState = new TestState();
		stateMachine.setState(initialState);
		auto expectedState = new TestState();

		stateMachine.pushState(expectedState);

		auto currentState = stateMachine.getCurrentState().get();
		assertEquals(expectedState, currentState);
	}

	@Test
	public void testPopState() {
		auto stateMachine = new StateMachine();
		auto expectedState = new TestState();
		stateMachine.setState(expectedState);
		auto addedState = new TestState();
		stateMachine.pushState(addedState);

		auto poppedState = stateMachine.popState().get();

		auto currentState = stateMachine.getCurrentState().get();
		assertEquals(expectedState, currentState);
		assertEquals(addedState, poppedState);
	}

	@Test
	public void testTruncateStates() {
		auto stateMachine = new StateMachine();
		auto initialState = new TestState();
		stateMachine.setState(initialState);
		auto expectedState = new TestState();
		stateMachine.pushState(expectedState);

		stateMachine.truncateStates();

		auto currentState = stateMachine.getCurrentState().get();
		assertEquals(expectedState, currentState);

		bool noStatesLeft = false;
		stateMachine.popState();
		stateMachine.getCurrentState().getOrElse(delegate() {
			noStatesLeft = true;
			return null;
		});
		assertTrue(noStatesLeft);
	}

	@Test
	public void testTruncateStatesExitingPreviousOnes() {
		auto stateMachine = new StateMachine();
		auto state = new TestState();
		stateMachine.setState(state);
		stateMachine.pushState(state);
		stateMachine.pushState(state);
		stateMachine.pushState(state);

		stateMachine.truncateStates(ExitDiscardedStates.yes);

		assertEquals(4, state.stateEnters);
		assertEquals(6, state.stateExits);
	}

	@Test
	public void testClearStates() {
		auto stateMachine = new StateMachine();
		auto initialState = new TestState();
		stateMachine.setState(initialState);

		stateMachine.clearStates();

		bool noStatesLeft = false;
		stateMachine.getCurrentState().getOrElse(delegate() {
			noStatesLeft = true;
			return null;
		});
		assertTrue(noStatesLeft);
		assertEquals(0, initialState.stateExits);
	}

	@Test
	public void testClearStatesExitingAllStates() {
		auto stateMachine = new StateMachine();
		auto state = new TestState();
		stateMachine.setState(state);
		stateMachine.pushState(state);
		stateMachine.pushState(state);

		stateMachine.clearStates(ExitDiscardedStates.yes);

		assertEquals(3, state.stateEnters);
		assertEquals(5, state.stateExits);
	}

	@Test
	public void testEnterState() {
		auto stateMachine = new StateMachine();
		auto state = new TestState();

		stateMachine.setState(state);
		stateMachine.switchState(state);
		stateMachine.pushState(state);

		assertEquals(3, state.stateEnters);
	}

	@Test
	public void testExitState() {
		auto stateMachine = new StateMachine();
		auto state = new TestState();
		stateMachine.setState(state);

		stateMachine.switchState(state);
		stateMachine.popState();

		assertEquals(2, state.stateExits);
	}

	@Test
	public void testPushPopEnterAndExitCount() {
		auto stateMachine = new StateMachine();
		auto state = new TestState();
		stateMachine.setState(state);

		stateMachine.pushState(state);
		stateMachine.popState();

		assertEquals(3, state.stateEnters);
		assertEquals(2, state.stateExits);
	}

	@Test
	public void testStateSuspensionAndResumption() {
		auto stateMachine = new StateMachine(EnableStateSuspension.yes);
		auto initialState = new TestState();
		auto secondState = new TestState();
		auto thirdState = new TestState();

		stateMachine.setState(initialState);
		stateMachine.pushState(secondState);
		stateMachine.pushState(thirdState);
		stateMachine.popState();
		stateMachine.popState();

		assertEquals(1, initialState.stateEnters);
		assertEquals(0, initialState.stateExits);
		assertEquals(1, initialState.stateSuspensions);
		assertEquals(1, initialState.stateResumptions);

		assertEquals(1, secondState.stateEnters);
		assertEquals(1, secondState.stateExits);
		assertEquals(1, secondState.stateSuspensions);
		assertEquals(1, secondState.stateResumptions);

		assertEquals(1, thirdState.stateEnters);
		assertEquals(1, thirdState.stateExits);
		assertEquals(0, thirdState.stateSuspensions);
		assertEquals(0, thirdState.stateResumptions);
	}
}

class StateMachineProcessorTest {
	mixin UnitTest;

	class UpdateableState : State {
		this() {
			super("UpdateableState");
		}

		public bool isUpdated = false;

		public override void update(StateMachine stateMachine, Entity entity) {
			isUpdated = true;
		}
	}

	@Test
	public void testUpdateState() {

		auto stateMachine = new StateMachine();
		auto state = new UpdateableState();
		stateMachine.setState(state);

		auto entity = new Entity();
		entity.id = 666;
		entity.addComponent(new StateMachineEntityComponent(stateMachine));
		entity.finalize();
		auto processor = new StateMachineProcessor();
		processor.addEntity(entity);

		processor.update();

		assertTrue(state.isUpdated);
	}
}
