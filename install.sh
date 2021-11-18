fail () {
    RED='\033[0;31m'
    NC='\033[0m' # No Color
    echo "${RED}ERROR:$NC $1"
    echo "${RED}COMMAND FAILED${NC}"
    exit 1
}

killUCD () {
    pkill -f udeploy/resources/agents
    pkill -f udeploy/resources/clients
    pkill -f udeploy/resources/servers
}

###############################################################################################################################################################
# GLOBAL                                                                
###############################################################################################################################################################

VERSION_REGEX="\d{1}\.\d{1}\.\d{1}\.\d{1}\.(ifix\d{2}\.)?(\d{6}|\d{7})"
PROJECT_PATH="/Users/jacobalspaw/Desktop/Projects/udeploy"
SERVER_REPO_PATH="${PROJECT_PATH}/ucd-server"
RES_PATH="${PROJECT_PATH}/resources"
EXEC_PATH="${RES_PATH}/exec"
LOG_DIR="${RES_PATH}/logs"
LOG="${LOG_DIR}/$1.log"
VENDOR="hcl"

mkdir -p ${LOG_DIR}
echo "Timestamp: $(date +'%Y-%m-%d %H:%M:%S')" > ${LOG}



###############################################################################################################################################################
# INFO                                                                
###############################################################################################################################################################

if [[ "$1" = "help" ]]
then
    echo "---------------------"
    echo "||     OPTIONS     ||"
    echo "---------------------"
    echo ""
    echo " help"
    echo "  -> display list of helpful commands"
    echo ""
    echo " patch"
    echo "  * web {version}"
    echo "   -> apply a ui patch to a version"
    echo "  * jar {version}"
    echo "   -> apply a jar patch to a version"
    echo "  * make-readme"
    echo "   -> generate the readme file"
    echo "  * list-files {version} {search-string}"
    echo "   -> list all patched files for a version and optionally highlight results that match search"
    echo ""
    echo " install"
    echo "  * basic {version}"
    echo "   -> clean and then install"
    echo "  * full {version}"
    echo "   -> clean all, resolve, and then install"
    echo "  * reset {version}"
    echo "   -> delete installation, clean all, resolve, and then install"
    echo "  * ui {version}"
    echo "   -> install css and js changes through war update"
    echo "  * agent {version}"
    echo "   -> delete intallation of old agent and then install a new agent"
    echo "  * client {version}"
    echo "   -> delete installation of old client and then install a new client"
    echo ""
    echo " run"
    echo "  * server {version}"
    echo "   -> open new terminal with server running"
    echo "  * agent {version}"
    echo "   -> open new terminal with agent running"
    echo "  * client {version}"
    echo "   -> open new terminal with client running"
    echo ""
    echo " lint"
    echo "  * test"
    echo "   -> lint staged js files"
    echo "  * fix"
    echo "   -> lint and fix staged js files"
    echo "  * test-all"
    echo "   -> lint all js files in ucd-server/src/web/war"
    echo "  * fix-all"
    echo "   -> lint and fix all js files in ucd-server/src/web/war"
    echo ""
    echo " test"
    echo "  -> resolve, and then run ecj-scan, unit tests, hibernate tests, and security tests"
    echo ""
    echo " ssh"
    echo "  * zos"
    echo "   -> ssh into zos machine"
    echo ""
    echo " copy"
    echo "  * agent-resources"
    echo "   -> path to agent resources (JPet-Store)"
    echo ""

    exit 0;
fi



###############################################################################################################################################################
# PATCHING
###############################################################################################################################################################

if [[ "$1" = "patch" ]]
then
    cd ${SERVER_REPO_PATH}

    VERSION=$3
    [[ -z ${VERSION} ]] && fail "Version not specified."

    if [[ "$2" = "web" ]]
    then
        echo ${VERSION} | grep -qE "^${VERSION_REGEX}$" || fail "Version not recognized."
        SERVER_INSTALL_PATH="${RES_PATH}/servers/${VERSION}"
        [[ -d ${SERVER_INSTALL_PATH} ]] || fail "Version could not be found."
        rm -r patches/*
        ant resolve && ant patch-web -Dresolve.no=y
        cd "patches"
        cp *.zip "${SERVER_INSTALL_PATH}/opt/tomcat/webapps/ROOT/static/"
        cd "${SERVER_INSTALL_PATH}/opt/tomcat/webapps/ROOT/static/"
        echo "\nPatching files on server:"
        unzip -o *.zip "opt/tomcat/webapps/ROOT/static/*" -d "../../../../.."
        rm *.zip
    elif [[ "$2" = "jar" ]]
    then
        echo ${VERSION} | grep -qE "^${VERSION_REGEX}$" || fail "Version not recognized."
        SERVER_INSTALL_PATH="${RES_PATH}/servers/${VERSION}"
        [[ -d ${SERVER_INSTALL_PATH} ]] || fail "Version could not be found."
        rm -r patches/*
        ant resolve && ant patch-jar -Dresolve.no=y
        echo "\nPatching files on server:"
        cd "patches"
        ls | grep -F ".jar"
        cp *.jar "${SERVER_INSTALL_PATH}/appdata/patches"
    elif [[ "$2" = "make-readme" ]]
    then
        read -p "Version (X.X.X.X): " cmd_version
        read -p "APAR# (PHXXXXX): " cmd_apar
        read -p "File: " cmd_file
        echo "Is this a web patch?"
        select yn in "Yes" "No"; do
            case $yn in
                Yes ) README=$(node "${EXEC_PATH}/makeReadme.js" "${cmd_version}" "Test Fix for APARs: ${cmd_apar}" "${cmd_file}" "-js"); break;;
                No  ) README=$(node "${EXEC_PATH}/makeReadme.js" "${cmd_version}" "Test Fix for APARs: ${cmd_apar}" "${cmd_file}"); break;;
            esac
        done
        mkdir patches > /dev/null
        echo "${README}" | tee "patches/readme.txt"
    elif [[ "$2" = "list-files" ]]
    then
        git fetch origin ${VERSION}
        PATCH_BRANCHES=$(git branch -r --contains ${VERSION})
        echo "${PATCH_BRANCHES}" | while read BRANCH_NAME; do
            FILES_CHANGED=$(git diff ${VERSION}..${BRANCH_NAME} --name-only)
            if [[ ${FILES_CHANGED} =~ [a-zA-Z] ]]
            then
                echo "\n\033[1m${BRANCH_NAME}\033[0m"
                echo "${FILES_CHANGED}" | while read FILE_PATH; do
                    FILE_NAME=$(basename ${FILE_PATH})
                    if ! echo ${FILE_NAME} | grep -qi "build\.xml\|patches\.js\|readme"
                    then
                        if ! [[ -z $4 ]] && echo ${FILE_NAME} | grep -qiF "$4"
                        then
                            echo "\t\033[1;32m${FILE_NAME}\033[0m"
                        else
                            echo "\t${FILE_NAME}"
                        fi
                    fi
                done
            fi
        done
    else
        fail "Command not recognized."
    fi

    exit 0;
fi



###############################################################################################################################################################
# INSTALLING
###############################################################################################################################################################

installFromGit_server () {
    cd ${SERVER_REPO_PATH}

    if [[ "$1" = "ui" ]]
    then
        ant install-web -Dinstall.dir=${SERVER_INSTALL_PATH} -Dresolve.no=y -Dinstall.vendor=${VENDOR} -Ddojo.build.no=y -Dtests.no=y -Denun.no=y -Dcompile.no=y -Dcompilejs.force=y -Dlint-js.no=y
        rsync -rvI "vendor-overlay/${VENDOR}/opt/tomcat/webapps/ROOT/static/VERSION_STAMP/" "${SERVER_INSTALL_PATH}/opt/tomcat/webapps/ROOT/static/dev" > /dev/null
        rsync -rvI "vendor-overlay/${VENDOR}/opt/tomcat/webapps/ROOT/WEB-INF/jsps/snippets/" "${SERVER_INSTALL_PATH}/opt/tomcat/webapps/ROOT/WEB-INF/jsps/snippets" > /dev/null
    elif [[ "$1" = "basic" ]]
    then
        killUCD
        ant clean
        ant install -Dinstall.dir=${SERVER_INSTALL_PATH} -Ddojo.build.no=y -Dtests.no=y -Dinstall.vendor=${VENDOR} -Dresolve.no=y -Dlint-js.no=y
    elif [[ "$1" = "full" ]]
    then
        killUCD
        ant clean-all
        ant install -Dinstall.dir=${SERVER_INSTALL_PATH} -Ddojo.build.no=y -Dtests.no=y -Dinstall.vendor=${VENDOR} -Dlint-js.no=y
    elif [[ "$1" = "reset" ]]
    then
        killUCD
        rm -r ${SERVER_INSTALL_PATH}
        ant clean-all
        ant install -Dinstall.dir=${SERVER_INSTALL_PATH} -Ddojo.build.no=y -Dtests.no=y -Dinstall.vendor=${VENDOR} -Dlint-js.no=y
    else
        fail "Command not recognized."
    fi
}

installFromGit_agent () {
    AGENT_SRC="${SERVER_INSTALL_PATH}/opt/tomcat/webapps/ROOT/tools/"
    if [[ -f "${AGENT_SRC}/launch-agent.zip" ]]
    then
        AGENT_NAME="launch-agent"
    else
        AGENT_NAME="ucd-agent"
    fi

    rm -r "${AGENT_INSTALL_PATH}"
    unzip "${AGENT_SRC}/${AGENT_NAME}.zip" -d "${AGENT_SRC}"
    printf "${AGENT_INSTALL_PATH}" | pbcopy
    sh "${AGENT_SRC}/${AGENT_NAME}-install/install-agent.sh"
    rm -r "${AGENT_SRC}/${AGENT_NAME}-install"
}

installFromGit_relay () {
    RELAY_SRC="${SERVER_INSTALL_PATH}/opt/tomcat/webapps/ROOT/tools/"
    RELAY_NAME="agent-relay"

    rm -r "${RELAY_INSTALL_PATH}"
    unzip "${RELAY_SRC}/${RELAY_NAME}.zip" -d "${RELAY_SRC}"
    printf "${RELAY_INSTALL_PATH}" | pbcopy
    sh "${RELAY_SRC}/${RELAY_NAME}-install/install.sh"
    rm -r "${RELAY_SRC}/${RELAY_NAME}-install"
}

installFromGit_client () {
    rm -r "${UDCLIENT_INSTALL_PATH}"
    unzip "${SERVER_INSTALL_PATH}/opt/tomcat/webapps/ROOT/tools/udclient.zip" -d "${SERVER_INSTALL_PATH}/opt/tomcat/webapps/ROOT/tools"
    mv "${SERVER_INSTALL_PATH}/opt/tomcat/webapps/ROOT/tools/udclient" "${UDCLIENT_INSTALL_PATH}"
}

installFromDist_server () {
    sh "${INSTALLER_PATH}/install-server.sh" -install-dir ${SERVER_INSTALL_PATH}
}

installFromDist_agent () {
    AGENT_SRC="${INSTALLER_PATH}/overlay/opt/tomcat/webapps/ROOT/tools/"
    if [[ -f "${AGENT_SRC}/ucd-agent.zip" ]]
    then
        AGENT_NAME="ucd-agent"
    else
        AGENT_NAME="ibm-ucd-agent"
    fi

    rm -r "${AGENT_INSTALL_PATH}"
    unzip "${AGENT_SRC}/${AGENT_NAME}.zip" -d "${AGENT_SRC}"
    printf "${AGENT_INSTALL_PATH}" | pbcopy
    sh "${AGENT_SRC}/${AGENT_NAME}-install/install-agent.sh"
    rm -r "${AGENT_SRC}/${AGENT_NAME}-install"
}

installFromDist_relay () {
    RELAY_SRC="${INSTALLER_PATH}/overlay/opt/tomcat/webapps/ROOT/tools/"
    RELAY_NAME="agent-relay"

    rm -r "${RELAY_INSTALL_PATH}"
    unzip "${RELAY_SRC}/${RELAY_NAME}.zip" -d "${RELAY_SRC}"
    printf "${RELAY_INSTALL_PATH}" | pbcopy
    sh "${RELAY_SRC}/${RELAY_NAME}-install/install.sh"
    rm -r "${RELAY_SRC}/${RELAY_NAME}-install"
}

installFromDist_client () {
    rm -r "${UDCLIENT_INSTALL_PATH}"
    unzip "${INSTALLER_PATH}/overlay/opt/tomcat/webapps/ROOT/tools/udclient.zip" -d "${INSTALLER_PATH}/overlay/opt/tomcat/webapps/ROOT/tools"
    mv "${INSTALLER_PATH}/overlay/opt/tomcat/webapps/ROOT/tools/udclient" "${UDCLIENT_INSTALL_PATH}"
}

if [[ "$1" = "install" ]]
then
    TYPE=$2
    VERSION=$3
    OPTION=$4

    echo "${TYPE}" | grep -qE "^(server|agent|relay|client)$" || fail "Command not recognized."
    [[ -z ${VERSION} ]] && fail "Version not specified."
    echo ${VERSION} | grep -qE "^(repo|${VERSION_REGEX})$" || fail "Version not recognized."

    SERVER_INSTALL_PATH="${RES_PATH}/servers/${VERSION}"
    AGENT_INSTALL_PATH="${RES_PATH}/agents/${VERSION}"
    RELAY_INSTALL_PATH="${RES_PATH}/relays/${VERSION}"
    UDCLIENT_INSTALL_PATH="${RES_PATH}/clients/${VERSION}"

    if [[ "${VERSION}" = "repo" ]]
    then
        eval "installFromGit_${TYPE} ${OPTION}"
    else
        INSTALLER_PATH="${RES_PATH}/servers/installers/ibm-ucd-${VERSION}"
        [[ -d ${INSTALLER_PATH} ]] || fail "Version dist not downloaded."
        cd ${INSTALLER_PATH}
        eval "installFromDist_${TYPE} ${VERSION}"
    fi

    say "Install Finished"
    exit 0;
fi



###############################################################################################################################################################
# RUNNING                                                                
###############################################################################################################################################################

if [[ "$1" = "run" ]]
then
    TYPE=$2
    VERSION=$3

    echo "${TYPE}" | grep -qE "^(server|agent|relay|client)$" || fail "Command not recognized."
    [[ -z ${VERSION} ]] && fail "Version not specified."
    echo ${VERSION} | grep -qE "^(repo|${VERSION_REGEX})$" || fail "Version not recognized."

    if [[ "${TYPE}" = "server" ]]
    then
        ttab -t "server ${VERSION}" "cd ${RES_PATH}/servers/${VERSION}/bin; ./server run -debug"
    elif [[ "${TYPE}" = "agent" ]]
    then
        ttab -t "agent ${VERSION}" "cd ${RES_PATH}/agents/${VERSION}/bin; ./agent run"
    elif [[ "${TYPE}" = "relay" ]]
    then
        ttab -t "relay ${VERSION}" "cd ${RES_PATH}/relays/${VERSION}/bin; ./agentrelay run"
    elif [[ "${TYPE}" = "client" ]]
    then
        ttab -t "client ${VERSION}" "cd ${RES_PATH}/clients/${VERSION}; ./udclient -username admin -password admin -weburl https://localhost:8443"
    fi

    exit 0;
fi



###############################################################################################################################################################
# LINTING                                                                
###############################################################################################################################################################

if [[ "$1" = "lint" ]]
then

    if [[ "$2" = "test" ]]
    then
        cd ${SERVER_REPO_PATH}
        ant lint-js -Dresolve.no=y -Dlint.quiet=y
    elif [[ "$2" = "fix" ]]
    then
        cd ${SERVER_REPO_PATH}
        ant fix-js -Dresolve.no=y
    elif [[ "$2" = "test-all" ]]
    then
        cd ${SERVER_REPO_PATH}
        ./node_modules/.bin/eslint -c src/build/eslintConfig.js src/web/war/ --quiet

        if [[ $? -eq 0 ]]; then
            echo "LINTING SUCCESSFUL"
        fi
    elif [[ "$2" = "fix-all" ]]
    then
        cd ${SERVER_REPO_PATH}
        ./node_modules/.bin/eslint -c src/build/eslintConfig.js src/web/war/ --fix --quiet

        if [[ $? -eq 0 ]]; then
            echo "LINTING SUCCESSFUL"
        fi
    else
        fail "Command not recognized."
    fi

    say "Linting Finished"
    exit 0;
fi

###############################################################################################################################################################
# TESTING                                                                
###############################################################################################################################################################

if [[ "$1" = "test" ]]
then
    cd ${SERVER_REPO_PATH}

    echo "Running ant clean..."
    ant clean-all >> ${LOG}
    if [[ ! $? -eq 0 ]]; then
        say "Cleaning Failed"
        fail "Failed ant clean-all. Check the logs at ${LOG}"
    else
        say "Cleaning Finished"
    fi

    echo "Running ant resolve..."
    ant resolve >> ${LOG}
    if [[ ! $? -eq 0 ]]; then
        say "Resolving Failed"
        fail "Failed ant resolve. Check the logs at ${LOG}"
    else
        say "Resolving Finished"
    fi

    echo "Running ant compile..."
    ant compile -Dresolve.no=y >> ${LOG}
    if [[ ! $? -eq 0 ]]; then
        say "Compiling Failed"
        fail "Failed ant compile. Check the logs at ${LOG}"
    else
        say "Compiling Finished"
    fi

    echo "Running ecj-scan..."
    ant ecj-scan -Dresolve.no=y >> ${LOG}
    if [[ ! $? -eq 0 ]]; then
        say "Scan Failed"
        fail "Failed ecj-scan. Check the logs at ${LOG}"
    else
        say "Scan Finished"
    fi

    echo "Running unit tests..."
    ant junit-unit-tests -Dresolve.no=y >> ${LOG}
    if [[ ! $? -eq 0 ]]; then
        say "Unit Tests Failed"
        fail "Failed unit tests. Check the logs at ${LOG}"
    else
        say "Unit Tests Finished"
    fi

    echo "Running hibernate tests..."
    ant junit-hibernate-tests -Dresolve.no=y >> ${LOG}
    if [[ ! $? -eq 0 ]]; then
        say "Hibernate Tests Failed"
        fail "Failed hibernate tests. Check the logs at ${LOG}"
    else
        say "Hibernate Tests Finished"
    fi

    echo "Running security tests..."
    ant junit-security-tests -Dresolve.no=y >> ${LOG}
    if [[ ! $? -eq 0 ]]; then
        say "Security Tests Failed"
        fail "Failed security tests. Check the logs at ${LOG}"
    else
        say "Security Tests Finished"
    fi

    exit 0;
fi



###############################################################################################################################################################
# REMOTE                                                                
###############################################################################################################################################################

if [[ "$1" = "ssh" ]]
then

    if [[ "$2" = "zos" ]]
    then
        osascript -e "tell application \"Terminal\" to do script \"ssh UCDSERV@10.134.71.182\""
    else
        fail "Command not recognized."
    fi

    exit 0;
fi



###############################################################################################################################################################
# REMOTE
###############################################################################################################################################################

if [[ "$1" = "copy" ]]
then

    if [[ "$2" = "agent-resources" ]]
    then
        printf "${RES_PATH}/agents/resources/JPetStore-artifacts/shared/app/" | pbcopy
    else
        fail "Command not recognized."
    fi

    exit 0;
fi



fail "Command not recognized."