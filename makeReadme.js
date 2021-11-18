#!/usr/bin/env node

let path = require("path");

var myArgs = process.argv.slice(2);

if (myArgs[0] == "-h" || myArgs[0] == "--help" ) {
    console.log(
`
USAGE: makeReadme.js <version> <problem> <jarfile> [-js]
`
    )
    return;
}


let version = myArgs[0]
let problem = myArgs[1]
let fixfile = myArgs[2]
let isJSpatch = myArgs.length > 2 && myArgs[3] == "-js"

let instructions
if (isJSpatch) {
    instructions = `
How to apply the test fix:
~~~~~~~~~~~~~~~~~~~~~~~~~~
1. If the product is currently running, stop it.
2. Transfer the zip file to the UCD installation directory.
3. Change the working directory to the UCD installation directory.
4. Backup the following folder:
		opt/tomcat/webapps/ROOT/static/<UCD Version>
5. Unzip the patch file. The contents of the zip file should replace existing files in your UCD installation.
6. Start the product.
7. Be sure to clear the browser cache.
8. Navigate to the Settings -> System -> Patches tab in the UI. Check that there
   is a Javascript Patches section with the above combination zip named in it


How to uninstall the test fix:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
1. Stop the product.
2. Replace the aforementioned folder (opt/tomcat/webapps/ROOT/static/<UCD Version>) with the backup
3. Start the product.
`
} else {
    instructions = `
How to apply the test fix:
~~~~~~~~~~~~~~~~~~~~~~~~~~
1. If the product is currently running, stop it.
2. Transfer the jar file to a temporary location on the file system.
3. Change directory to <install_dir>/appdata. <install_dir>/appdata holds a "patches" directory. <install_dir>/appdata/patches
   is empty by default. If the "patches" directory does not exist, create it. The typical location for
   <install_dir> is C:\\Program Files\\ucd\\server (Windows), or /opt/ucd/server (Unix)
4. Copy the jar file(s) from this archive into the patches directory.
5. Start the product.
6. Navigate to the Settings -> System -> Patches tab in the UI. Check that there is a patch
   installed for each of the jar files copied in step 4, and that there is no "Conflicts" entry.
   If there are conflicts, please contact the support representative who provided you the patch.

How to uninstall the test fix:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
1. Stop the product.
2. Remove the jar files associated with this patch from the patches directory.
3. Start the product.
`
}

console.log(
`
This TestFix applies to UrbanCode Deploy (UCD) ${version}
*****NOTE: It is mandatory to have UrbanCode Deploy (UCD) ${version} installed before applying this test fix*****

Details on the test fix:
~~~~~~~~~~~~~~~~~~~~~~~~
This test fix addresses the following problem:

${problem}

Files:
${fixfile}

${instructions}
`
)

