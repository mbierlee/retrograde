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

    import std.string : toStringz;

    import glfw3.api;

    import poodinis;

    struct WindowData
    {
        int xpos;
        int ypos;
        int width;
        int height;

        void update(GLFWwindow* window)
        {
            glfwGetWindowPos(window, &this.xpos, &this.ypos);
            glfwGetWindowSize(window, &this.width, &this.height);
        }
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

        private GLFWwindow* window;
        private WindowData windowData;

        void initialize(const PlatformSettings platformSettings)
        {
            auto ps = cast(const(GlfwPlatformSettings)) platformSettings;
            if (!ps)
            {
                //TODO: Log error
                return;
            }

            extern (C) @nogc nothrow void errorCallback(int error, const(char)* description)
            {
                //TODO: Replace with engine logger
                import core.stdc.stdio;

                fprintf(stderr, "Error: %s\n", description);
            }

            glfwSetErrorCallback(&errorCallback);

            if (!glfwInit())
            {
                //TODO: log
                return;
            }

            glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
            glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 6);

            window = glfwCreateWindow(ps.windowWidth, ps.windowHeight,
                    ps.windowTitle.toStringz(), null, null);

            if (!window)
            {
                glfwTerminate();
                //TODO: log
                return;
            }

            glfwSetWindowUserPointer(window, &windowData);
            glfwMakeContextCurrent(window);
            glfwSwapInterval(ps.swapInterval);
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
