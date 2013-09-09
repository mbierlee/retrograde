#include <Engine/EngineMain.h>

#include "DependencyConfig.h"

int main() {
	return Engine::engineMain(SetupDependencies, L"Test Game");
}