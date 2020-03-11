/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2020 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

import retrograde.player;
import dunit;

import retrograde.input;
import retrograde.messaging;
import retrograde.stringid;
import retrograde.option;

import poodinis;

class PlayerRegistryTest {
    mixin UnitTest;

    @Test
    public void testRegisterPlayer() {
        auto registry = new PlayerRegistry();

        auto playerOneDevice = Device(DeviceType.joystick, 1);
        auto playerTwoDevice = Device(DeviceType.joystick, 2);

        auto expectedPlayerOne = Player(1, playerOneDevice);
        auto expectedPlayerTwo = Player(2, playerTwoDevice);

        auto actualPlayerOne = registry.registerPlayer(playerOneDevice);
        auto actualPlayerTwo = registry.registerPlayer(playerTwoDevice);

        assertEquals(expectedPlayerOne, actualPlayerOne);
        assertEquals(expectedPlayerTwo, actualPlayerTwo);
    }

    @Test
    public void testRegisterPlayerPreventDoubleRegistration() {
        auto registry = new PlayerRegistry();

        auto playerDevice = Device(DeviceType.joystick, 1);

        auto playerOne = registry.registerPlayer(playerDevice);
        auto playerTwo = registry.registerPlayer(playerDevice);

        assertEquals(playerOne, playerTwo);
        assertEquals(1, playerTwo.id);
    }

    @Test
    public void testGetPlayerById() {
        auto registry = new PlayerRegistry();

        auto playerDevice = Device(DeviceType.joystick, 1);
        auto expectedPlayer = Some!Player(Player(1, playerDevice));
        registry.registerPlayer(playerDevice);

        auto actualPlayer = registry.get(expectedPlayer.get().id);

        assertEquals(expectedPlayer.get(), actualPlayer.get());
    }

    @Test
    public void testGetNonexistingPlayerById() {
        auto registry = new PlayerRegistry();
        auto actualPlayer = registry.get(65);
        assertTrue(actualPlayer.isEmpty);
    }

    @Test
    public void testGetPlayerByDevice() {
        auto registry = new PlayerRegistry();

        auto playerDevice = Device(DeviceType.joystick, 1);
        auto expectedPlayer = Some!Player(Player(1, playerDevice));
        registry.registerPlayer(playerDevice);

        auto actualPlayer = registry.get(playerDevice);

        assertEquals(expectedPlayer.get(), actualPlayer.get());
    }

    @Test
    public void testGetNonExistingPlayerByDevice() {
        auto registry = new PlayerRegistry();
        auto playerDevice = Device(DeviceType.joystick, 1);
        auto actualPlayer = registry.get(playerDevice);
        assertTrue(actualPlayer.isEmpty);
    }

    @Test
    public void testHasPlayerById() {
        auto registry = new PlayerRegistry();

        auto playerOneDevice = Device(DeviceType.joystick, 1);
        auto playerOne = Player(1, playerOneDevice);

        auto playerTwoDevice = Device(DeviceType.joystick, 2);
        auto playerTwo = Player(2, playerTwoDevice);

        registry.registerPlayer(playerOneDevice);

        assertTrue(registry.hasPlayer(1));
        assertFalse(registry.hasPlayer(2));
    }

    @Test
    public void testHasPlayerByDevice() {
        auto registry = new PlayerRegistry();

        auto playerOneDevice = Device(DeviceType.joystick, 1);
        auto playerOne = Player(1, playerOneDevice);

        auto playerTwoDevice = Device(DeviceType.joystick, 2);
        auto playerTwo = Player(2, playerTwoDevice);

        registry.registerPlayer(playerOneDevice);

        assertTrue(registry.hasPlayer(playerOneDevice));
        assertFalse(registry.hasPlayer(playerTwoDevice));
    }

    @Test
    public void testHasPlayerByPlayer() {
        auto registry = new PlayerRegistry();

        auto playerOneDevice = Device(DeviceType.joystick, 1);
        auto playerOne = Player(1, playerOneDevice);

        auto playerTwoDevice = Device(DeviceType.joystick, 2);
        auto playerTwo = Player(2, playerTwoDevice);

        registry.registerPlayer(playerOneDevice);

        assertTrue(registry.hasPlayer(playerOne));
        assertFalse(registry.hasPlayer(playerTwo));
    }

    @Test
    public void testHasPlayerByPlayerWithMismatchingIdAndDevice() {
        auto registry = new PlayerRegistry();

        auto playerOneDevice = Device(DeviceType.joystick, 1);
        auto playerOne = Player(1, playerOneDevice);

        auto playerTwoDevice = Device(DeviceType.joystick, 2);
        auto playerTwo = Player(2, playerTwoDevice);

        registry.registerPlayer(playerOneDevice);
        registry.registerPlayer(playerTwoDevice);

        auto mismatchingPlayer = Player(1, playerTwoDevice);

        assertFalse(registry.hasPlayer(mismatchingPlayer));
    }

    @Test
    public void testGetPlayers() {
        auto registry = new PlayerRegistry();
        auto playerOneDevice = Device(DeviceType.joystick, 1);
        auto playerOne = Player(1, playerOneDevice);
        registry.registerPlayer(playerOneDevice);

        auto players = registry.players;

        assertEquals(1, players.length);
        assertEquals(playerOne, players[0]);
    }

    @Test
    public void testPlayerData() {
        class TestPlayerData : PlayerData {}
        auto testData = new TestPlayerData();

        auto registry = new PlayerRegistry();
        auto playerOneDevice = Device(DeviceType.joystick, 1);
        auto player = registry.registerPlayer(playerOneDevice, testData);

        assertSame(testData, player.data);
    }

    @Test
    public void testGetPlayerByCommand() {
        auto registry = new PlayerRegistry();
        auto playerOneDevice = Device(DeviceType.joystick, 1);
        auto expectedPlayer = Some!Player(registry.registerPlayer(playerOneDevice));

        auto inputEventData = new InputMessageData();
        inputEventData.device = playerOneDevice;
        auto event = Command(sid("cmd_whatevs"), 1, inputEventData);

        auto actualPlayer = registry.get(event);

        assertEquals(expectedPlayer.get(), actualPlayer.get());
    }

    @Test
    public void testGetOnExistingPlayerByCommand() {
        auto registry = new PlayerRegistry();
        auto playerOneDevice = Device(DeviceType.joystick, 1);

        auto inputEventData = new InputMessageData();
        inputEventData.device = playerOneDevice;
        auto event = Command(sid("cmd_whatevs"), 1, inputEventData);

        auto actualPlayer = registry.get(event);

        assertTrue(actualPlayer.isEmpty);
    }

    @Test
    public void testRemovePlayerById() {
        auto registry = new PlayerRegistry();
        auto player = registry.registerPlayer(Device(DeviceType.mouse, 1));

        registry.removePlayer(player.id);

        assertFalse(registry.hasPlayer(player.id));
        assertFalse(registry.hasPlayer(player.device));
        assertFalse(registry.hasPlayer(player));
    }

    @Test
    public void testRemovePlayerByDevice() {
        auto registry = new PlayerRegistry();
        auto player = registry.registerPlayer(Device(DeviceType.mouse, 1));

        registry.removePlayer(player.device);

        assertFalse(registry.hasPlayer(player.id));
        assertFalse(registry.hasPlayer(player.device));
        assertFalse(registry.hasPlayer(player));
    }

    @Test
    public void testRemovePlayerByPlayer() {
        auto registry = new PlayerRegistry();
        auto player = registry.registerPlayer(Device(DeviceType.mouse, 1));

        registry.removePlayer(player);

        assertFalse(registry.hasPlayer(player.id));
        assertFalse(registry.hasPlayer(player.device));
        assertFalse(registry.hasPlayer(player));
    }

    @Test
    public void testRemovePlayerByPlayerDoesNotRemoveMismatchingPlayer() {
        auto registry = new PlayerRegistry();
        auto playerOne = registry.registerPlayer(Device(DeviceType.mouse, 1));
        auto playerTwoDevice = Device(DeviceType.mouse, 2);
        auto playerTwo = registry.registerPlayer(playerTwoDevice);

        auto mismatchingPlayer = Player(1, playerTwoDevice);

        registry.removePlayer(mismatchingPlayer);

        assertTrue(registry.hasPlayer(playerOne));
        assertTrue(registry.hasPlayer(playerTwo));
    }

    @Test
    public void testRemoveNonExistingPlayer() {
        auto registry = new PlayerRegistry();
        auto player = Player(1, Device(DeviceType.mouse, 1));

        registry.removePlayer(player.id);
        registry.removePlayer(player.device);
        registry.removePlayer(player);

        assertFalse(registry.hasPlayer(player.id));
        assertFalse(registry.hasPlayer(player.device));
        assertFalse(registry.hasPlayer(player));
    }
}

class PlayerLifecycleManagerTest {
    mixin UnitTest;

    @Test
    public void testAddPlayer() {
        auto container = new shared DependencyContainer();
        container.register!PlayerLifecycleManager;
        container.register!PlayerRegistry;
        container.register!PlayerLifecycleCommandChannel;

        auto lifecycleManager = container.resolve!PlayerLifecycleManager;
        auto registry = container.resolve!PlayerRegistry;
        auto eventChannel = container.resolve!PlayerLifecycleCommandChannel;

        auto device = Device(DeviceType.keyboard, 1);
        auto data  = new PlayerAddCommandData(device);

        lifecycleManager.initialize();

        eventChannel.emit(Command(PlayerLifecycleCommand.addPlayer, 1, data));

        assertTrue(registry.hasPlayer(device));
    }

    @Test
    public void testRemovePlayer() {
        auto container = new shared DependencyContainer();
        container.register!PlayerLifecycleManager;
        container.register!PlayerRegistry;
        container.register!PlayerLifecycleCommandChannel;

        auto lifecycleManager = container.resolve!PlayerLifecycleManager;
        auto registry = container.resolve!PlayerRegistry;
        auto eventChannel = container.resolve!PlayerLifecycleCommandChannel;

        auto device = Device(DeviceType.keyboard, 1);
        auto player = registry.registerPlayer(device);

        auto data  = new PlayerRemoveCommandData(player);

        lifecycleManager.initialize();

        eventChannel.emit(Command(PlayerLifecycleCommand.removePlayer, 1, data));

        assertFalse(registry.hasPlayer(player.id));
    }

    @Test
    public void testAddPlayerOnlyWhenMagnitudeIsPositive() {
        auto container = new shared DependencyContainer();
        container.register!PlayerLifecycleManager;
        container.register!PlayerRegistry;
        container.register!PlayerLifecycleCommandChannel;

        auto lifecycleManager = container.resolve!PlayerLifecycleManager;
        auto registry = container.resolve!PlayerRegistry;
        auto eventChannel = container.resolve!PlayerLifecycleCommandChannel;

        lifecycleManager.initialize();

        auto deviceOne = Device(DeviceType.keyboard, 1);
        auto deviceTwo = Device(DeviceType.keyboard, 2);

        eventChannel.emit(Command(PlayerLifecycleCommand.addPlayer, 1, new PlayerAddCommandData(deviceOne)));
        eventChannel.emit(Command(PlayerLifecycleCommand.addPlayer, 0, new PlayerAddCommandData(deviceTwo)));

        assertTrue(registry.hasPlayer(deviceOne));
        assertFalse(registry.hasPlayer(deviceTwo));
    }

    @Test
    public void testRemovePlayerOnlyWhenMagnitudeIsPositive() {
        auto container = new shared DependencyContainer();
        container.register!PlayerLifecycleManager;
        container.register!PlayerRegistry;
        container.register!PlayerLifecycleCommandChannel;

        auto lifecycleManager = container.resolve!PlayerLifecycleManager;
        auto registry = container.resolve!PlayerRegistry;
        auto eventChannel = container.resolve!PlayerLifecycleCommandChannel;

        auto deviceOne = Device(DeviceType.keyboard, 1);
        auto deviceTwo = Device(DeviceType.keyboard, 2);
        auto playerOne = registry.registerPlayer(deviceOne);
        auto playerTwo = registry.registerPlayer(deviceTwo);

        lifecycleManager.initialize();

        eventChannel.emit(Command(PlayerLifecycleCommand.removePlayer, 1, new PlayerRemoveCommandData(playerOne)));
        eventChannel.emit(Command(PlayerLifecycleCommand.removePlayer, 0, new PlayerRemoveCommandData(playerTwo)));

        assertFalse(registry.hasPlayer(playerOne.id));
        assertTrue(registry.hasPlayer(playerTwo.id));
    }
}
