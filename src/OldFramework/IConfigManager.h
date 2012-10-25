#pragma once

#include <memory>
#include <string>

namespace Framework {

	struct Config;
	struct Session;

	class IConfigManager {

	public:
		std::shared_ptr<Config> getConfig();
		std::shared_ptr<Session> getSessionSettings();
		std::shared_ptr<Session> getSessionSettings(std::shared_ptr<Config> config);
		
		void saveSettings(const std::wstring file);
	};

}