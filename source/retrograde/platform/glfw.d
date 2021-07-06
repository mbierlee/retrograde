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

module retrograde.platform.glfw;

version (Have_glfw_d)
{
    import retrograde.core.platform;
    import retrograde.core.runtime;

    import std.experimental.logger : Logger;
    import std.string : toStringz;
    import std.conv : to;

    import glfw3.api;

    import poodinis;

    struct StateData
    {
    }

    class GlfwPlatformSettings : PlatformSettings
    {
        int windowWidth = 1920;
        int windowHeight = 1080;
        string windowTitle = "Retrograde Engine";
        int swapInterval = 1;
    }

    /**
     * A GLFW-based platform for Desktop OSes.
     * To use, dependency glfw-d must be included in your project's dub project.
     */
    class GlfwPlatform : Platform
    {
        private @Autowire EngineRuntime runtime;
        private @Autowire Logger logger;

        private GLFWwindow* window;
        private StateData stateData;

        void initialize(const PlatformSettings platformSettings)
        {
            auto ps = cast(const(GlfwPlatformSettings)) platformSettings;
            if (!ps)
            {
                logger.error("GLFW Platform: Unable to use platformSettings. Did you supply settings of type GlfwPlatformSettings?");
                return;
            }

            glfwSetErrorCallback((&errorCallback).funcptr); //TODO: Move to update and use glfwGetError so we can use own logger

            if (!glfwInit())
            {
                logger.error("GLFW Platform: Failed to initialize.");
                return;
            }

            glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
            glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 6);

            window = glfwCreateWindow(ps.windowWidth, ps.windowHeight,
                    ps.windowTitle.toStringz(), null, null);

            if (!window)
            {
                glfwTerminate();
                logger.error("GLFW Platform: Failed to create window.");
                return;
            }

            glfwSetWindowUserPointer(window, &stateData);
            glfwMakeContextCurrent(window);
            glfwSwapInterval(ps.swapInterval);
        }

        extern (C) void errorCallback(int error, const(char)* description) nothrow @nogc
        {
            debug
            {
                // Due to @nogc we cannot make use of the engine's logger
                import core.stdc.stdio;

                auto errorCode = toStringz(to!string(error));
                fprintf(stderr, "GLFW Platform Error %s: %s\n", errorCode, description);
            }
        }

        void update()
        {
            if (glfwWindowShouldClose(window))
            {
                runtime.terminate();
            }
            else if (window)
            {
                glfwSwapBuffers(window);
                glfwPollEvents();
            }
        }

        void terminate()
        {
            if (window)
            {
                glfwDestroyWindow(window);
            }

            glfwTerminate();
        }
    }
}
