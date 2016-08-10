#!/usr/bin/env bash
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
PARENT="$( cd -P "$DIR/.." && pwd)"

Bk=$(tput setaf 0)
Rd=$(tput setaf 1)
Gr=$(tput setaf 2)
Ye=$(tput setaf 3)
Bl=$(tput setaf 4)
Ma=$(tput setaf 5)
Cy=$(tput setaf 6)
Wh=$(tput setaf 7)
Rs=$Wh

banner() {
  echo "${Cy}******${Rs}"
  echo "${Cy}$1${Rs}"
  echo "${Cy}******${Rs}"
}

DEFAULT_MAKEFILE="$PARENT/Microsoft.AspNetCore.Build/msbuild/DefaultMakefile.proj"
DEFAULT_TASKS_MAKEFILE="$PARENT/Microsoft.AspNetCore.Build/msbuild/DefaultTasksMakefile.proj"

# Initialize tools, if necessary (no-ops if already initialized)
"$PARENT/init/init-aspnet-build.sh"

export PATH="$HOME/.dotnet/dotnet:$PATH"

_get_makefile_for() {
  local dir=$1
  local candidate="$dir/makefile.proj"

  if [ -e $candidate ]; then
    echo $candidate
  else
    echo $DEFAULT_MAKEFILE
  fi
}

# Scan the args to identify if we're building a project or repo
SAW_PROJECT=
NEW_ARGS=()
PROJECT_DIR=
MAKEFILE=
while [ $# -gt 0 ]; do
  case $1 in
    -*|/*)
      NEW_ARGS+=($1)
      ;;
    *)
      SAW_PROJECT=1
      if [ -d $1 ]; then
        PROJECT_DIR=$1
        MAKEFILE=$(_get_makefile_for $1)
      else
        echo "You can't use aspnet-build to launch an MSBuild project. Use msbuild directly for that." 1>&2
        exit 1
      fi
  esac
  shift
done

if [ -z $SAW_PROJECT ]; then
  MAKEFILE=$(_get_makefile_for $(pwd))
  PROJECT_DIR=$(pwd)
fi

EXPECTED_VERSION=$(cat "$PARENT/dotnet-install/dotnet-version.txt")
ACTUAL_VER=$(dotnet --version)
if [ $EXPECTED_VERSION != $ACTUAL_VER ]; then
  echo "${Rd}error${Rs}: Expected version '$EXPECTED_VERSION' but dotnet --version returned '$ACTUAL_VER'. Do you have the correct SDK version in your global.json?" 1>&2
  exit 1
fi

ARTIFACTS="$PROJECT_DIR/artifacts"
if [ ! -e $ARTIFACTS ]; then
  mkdir $ARTIFACTS
fi

LOGS="$ARTIFACTS/logs"
if [ ! -e $LOGS ]; then
  mkdir $LOGS
fi

MAIN_LOG="$LOGS/msbuild.log"
TASKS_LOG="$LOGS/tasks.msbuild.log"
ERR_LOG="$LOGS/msbuild.err"
WRN_LOG="$LOGS/msbuild.wrn"

NEW_ARGS+=("-p:AspNetBuildRoot=$PARENT")

# Workaround for https://github.com/Microsoft/msbuild/issues/754
if [ $NO_COLOR = "1" ]; then
  CONSOLE_COLOR_ARG="-clp:DisableConsoleColor"
fi

# Check if we need to build tasks first
TASKS_DIR="$PROJECT_DIR/tasks"

if [ -d $TASKS_DIR ]; then
  cd $TASKS_DIR
  PROJ="$TASKS_DIR/makefile.proj"
  if [ ! -e $PROJ ]; then
    PROJ=$DEFAULT_TASKS_MAKEFILE
  fi
  echo "Building Tasks"
  echo "${Cy}*** dotnet build3 $PROJ ${NEW_ARGS[@]}${Rs}"

  set -e
  dotnet build3 $PROJ -v:q "-flp1:ShowTimestamp;PerformanceSummary;Verbosity=Detailed;LogFile=\"$TASKS_LOG\"" "-p:AspNetBuildRoot=$PARENT" $CONSOLE_COLOR_ARG
  if [ $? != 0 ]; then
    echo "${Rd}error${Rs}: Tasks build failed. See $TASKS_LOG for details" 1>&2
    exit 1
  fi
  set +e
fi

NEW_ARGS+=("-flp1:ShowTimestamp;PerformanceSummary;Verbosity=Detailed;LogFile=\"$MAIN_LOG\"")
NEW_ARGS+=("-flp2:ErrorsOnly;LogFile=\"$ERR_LOG\"")
NEW_ARGS+=("-flp3:WarningsOnly;LogFile=\"$WRN_LOG\"")

cd $PROJECT_DIR
echo "${Cy}> dotnet build3 ${NEW_ARGS[@]} $CONSOLE_COLOR_ARG${Rs}"
dotnet build3 $MAKEFILE "${NEW_ARGS[@]}" $CONSOLE_COLOR_ARG