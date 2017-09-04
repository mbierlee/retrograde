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

module retrograde.player;

import retrograde.input;
import retrograde.messaging;
import retrograde.option;
import retrograde.stringid;
import retrograde.entity;
import retrograde.option;

import poodinis;

import std.exception;

interface PlayerData {}

struct Player {
	uint id;
	Device device;
	PlayerData data;
}

enum PlayerLifecycleCommand : StringId {
	addPlayer = sid("cmd_add_player"),
	removePlayer = sid("cmd_remove_player"),
}

public void registerPlayerLifecycleDebugSids(SidMap sidMap) {
	sidMap.add("cmd_add_player");
	sidMap.add("cmd_remove_player");
}

class PlayerAddCommandData : MessageData {
	private Device _device;
	private PlayerData _playerData;

	public @property device() {
		return _device;
	}

	public @property playerData() {
		return _playerData;
	}

	this(Device device, PlayerData playerData = null) {
		this._device = device;
		this._playerData = playerData;
	}
}

class PlayerRemoveCommandData : MessageData {
	private Player _player;

	public @property player() {
		return _player;
	}

	this(Player player) {
		this._player = player;
	}
}

class PlayerLifecycleCommandChannel : CommandChannel {}

class PlayerLifecycleManager {

	@Autowire
	private PlayerLifecycleCommandChannel lifecycleChannel;

	@Autowire
	private PlayerRegistry registry;

	private void handleCommand(const(Command) command) {
		switch(command.type) {
			case PlayerLifecycleCommand.addPlayer:
				if (command.magnitude > 0) {
					auto data = cast(PlayerAddCommandData) command.data;
					enforce(data !is null, "cmd_add_player emitted on PlayerLifecycleCommandChannel without data");
					registry.registerPlayer(data.device, data.playerData);
				}
				break;

			case PlayerLifecycleCommand.removePlayer:
				if (command.magnitude > 0) {
					auto data = cast(PlayerRemoveCommandData) command.data;
					enforce(data !is null, "cmd_remove_player emitted on PlayerLifecycleCommandChannel without data");
					registry.removePlayer(data.player);
				}
				break;

			default:
				break;
		}
	}

	public void initialize() {
		lifecycleChannel.connect(&handleCommand);
	}
}

class PlayerRegistry {
	private uint playerId = 0;
	private Player[uint] playersbyId;
	private Player[Device] playersbyDevice;

	public @property Player[] players() {
		return playersbyId.values;
	}

	public Player registerPlayer(Device device, PlayerData data = null) {
		if (hasPlayer(device)) {
			return get(device).get();
		}

		auto player = Player(++playerId, device, data);
		playersbyId[player.id] = player;
		playersbyDevice[device] = player;
		return player;
	}

	public void removePlayer(uint id) {
		auto player = id in playersbyId;
		if (player) {
			playersbyId.remove(id);
			playersbyDevice.remove((*player).device);
		}
	}

	public void removePlayer(Device device) {
		auto player = device in playersbyDevice;
		if (player) {
			playersbyId.remove((*player).id);
			playersbyDevice.remove(device);
		}
	}

	public void removePlayer(Player player) {
		if (hasPlayer(player)) {
			removePlayer(player.id);
		}
	}

	public Option!Player get(uint id) {
		return hasPlayer(id) ? Some!Player(playersbyId[id]) : None!Player();
	}

	public Option!Player get(Device device) {
		return hasPlayer(device) ? Some!Player(playersbyDevice[device]) : None!Player();
	}

	public Option!Player get(ref const(Event) event) {
		auto inputData = cast(InputMessageData) event.data;
		if (inputData) {
			return get(inputData.device);
		}

		return None!Player();
	}

	public bool hasPlayer(uint id) {
		return (id in playersbyId) !is null;
	}

	public bool hasPlayer(Device device) {
		return (device in playersbyDevice) !is null;
	}

	public bool hasPlayer(Player player) {
		bool result = false;
		get(player.id).ifNotEmpty((p) {
			result = p.device == player.device;
		});

		return result;
	}

}

class PlayerEntityComponent : EntityComponent {
	mixin EntityComponentIdentity!"PlayerEntityComponent";

	public Option!Player player = None!Player();

	this() {}

	this(Player player) {
		this.player = Some!Player(player);
	}
}
