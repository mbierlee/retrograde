#pragma once

#include "irrlicht.h"

#include <Hypodermic/IContainer.h>

/**
 * Upfront creation of all sub-systems and injection of these sub-systems into each other.
 *
 * @param deviceParams Irrlicht device parameters needed to configure the irrlicht device.
 *
 * @return Container built by the function used to resolve types.
 */
std::shared_ptr<Hypodermic::IContainer> SetupDependencies(irr::SIrrlichtCreationParameters& deviceParams);