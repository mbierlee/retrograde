#pragma once

namespace Engine { namespace Framework {
	class IIDebugDrawer {
	public:
		virtual ~IIDebugDrawer() {};

		virtual void drawDebugData() =0;
	};
}}