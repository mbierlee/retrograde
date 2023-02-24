/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2023 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.core.scripting;

import retrograde.core.storage : File;

/** 
 * Script systems manage, (pre)compile and run scripts.
 * Implemenations might use various scripting languages, 
 * but whichever language they use they should provide the same input and
 * output.
 */
interface ScriptSystem {

    /**
     * Load a script into memory.
     */
    void loadScript(File scriptPath);

    /**
     * Load a libary script into memory.
     * Libary scripts cannot be executed directly but can often be included into main scripts
     * via imports.
     * Script systems may not support libraries.
     */
    void loadLibrary(File scriptPath);

    /**
     * Compiles or preprocesses scripts, if neccesary.
     */
    void compileScripts();

    /**
     * Runs a script.
     *
     * This call is expected to block during script execution. To run scripts in the background, it is advised to use threads.
     *
     * Params: 
     *  scriptName = Name of the script to execute, often without file extension.
     *  entryPoint = Where in the script execution should start. Often points to a main function of sorts, but it depends on the type of script.
     *  arguments = input arguments to supply to the entrypoint, if supported by the script system.
     * Returns: Map of returned outputs, if such a thing is supported by the script system implementation.
     */
    string[string] runScript(string scriptName, string entryPoint, string[string] arguments);

}
