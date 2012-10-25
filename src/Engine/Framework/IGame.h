#pragma once

namespace Engine { namespace Framework {

	class IGame {
	public:
		virtual ~IGame() {}

		virtual void initialize() =0;
		virtual void update() =0;
		virtual void draw() =0;

		virtual bool exitRequested() =0;
		virtual void requestExit() =0;
	};

}}