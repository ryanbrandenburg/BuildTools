#!/usr/bin/env bash
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

set -e

Bk=$(tput setaf 0)
Rd=$(tput setaf 1)
Gr=$(tput setaf 2)
Ye=$(tput setaf 3)
Bl=$(tput setaf 4)
Ma=$(tput setaf 5)
Cy=$(tput setaf 6)
Wh=$(tput setaf 7)
Rs=$Wh

ARG0=$0
INSTALLATION_ROOT="$HOME/.aspnet-build"

die() {
    echo "${Rd}error:${Rs} $1" 1>&2
    exit 1
}

usage() {
    echo "USAGE: "
    echo "  ${Cy}$ARG0${Rs} [${Ye}-h${Rs}|${Ye}-?${Rs}|${Ye}--help${Rs}]"
    echo "  ${Cy}$ARG0${Rs} [${Ye}--build-tools${Rs} ${Ma}<BUILDTOOLS>${Rs}] [${Ye}--reset-tools${Rs}] [${Ye}--${Rs}] ${Ma}<ARGS...>${Rs}"
    echo ""
    echo "OPTIONS"
    echo "  ${Ye}--build-tools${Rs} ${Ma}<BUILDTOOLS>${Rs}      Optional: The path to build tools to use for the build."
    echo "  ${Ye}--reset-tools${Rs}                   Reset the build tools, even if they are properly installed"  
    echo ""
    echo "NOTES"
    echo "  Upon seeing the first unexpected argument, that argument and"
    echo "  all remaining arguments are forwarded as-is to '${Cy}aspnet-build${Rs}'."
    echo ""
    echo "  The '${Ye}--${Rs}' argument can be used when you want to pass an"
    echo "  argument forward to '${Cy}aspnet-build${Rs}' but that argument has"
    echo "  meaning to '$ARG0' (for example '${Ye}--build-tools${Rs}')."
    echo "  When the '${Ye}--${Rs}' argument is reached, ALL remaining arguments"
    echo "  are ignored and forwarded as-is to '${Cy}aspnet-build${Rs}'"
}

_get_dir_name_from_branch() {
    echo $1 | sed "s/\//-/g"
}

_get_branch() {
    echo $1 | sed "s/aspnet-build\.\([^\.]\+\)\.zip/\1/g" 
}

_get_install_path() {
    echo "$INSTALLATION_ROOT/branches/$(_get_dir_name_from_branch $1)"
}

_get_url_from_trainfile() {
    cat "$1" | grep "^BuildTools:" | cut -d ':' -f 2- | tr -d ' \r\n'
}

install_build_tools() {
    TRAINFILE="$DIR/Trainfile"
    REPOFILE="$DIR/Repofile"
    if [ -e $TRAINFILE ]; then
        SOURCE_URL=$(_get_url_from_trainfile $TRAINFILE)
    elif [ -e $REPOFILE ]; then
        SOURCE_URL=$(_get_url_from_trainfile $REPOFILE)
    else
        die "this repo does not have a 'Trainfile' or a 'Repofile'"
    fi

    local package_file_name=$(basename $SOURCE_URL)
    local package_branch=$(_get_branch $package_file_name)
    local install_path=$(_get_install_path $package_branch)
    BUILD_TOOLS=$install_path

    if [[ -e "$install_path" && $RESET_TOOLS = "1" ]]; then
        echo "${Ye}Clearing existing build tools as requested by --reset-tools switch.${Rs}"
        rm -Rf $install_path
    fi

    if [ -e "$install_path/.etag" ]; then
        echo "${Gr}Tools for $package_branch are already installed. Checking for updates...${Rs}"
        local etag=$(cat "$install_path/.etag" | tr -d '\r\n')

        # Check for a new version
        if curl -sSL -I -H "If-None-Match: $etag" $SOURCE_URL | grep "HTTP/1\.1 304" >/dev/null 2>/dev/null; then
            echo "The latest version of the ASP.NET Build Tools from branch $package_branch are already present in $install_path"
            return
        fi
        echo "Your build tools are out-of-date. Downloading the latest build tools."
    fi

    # If we're here, we need to fetch a new package
    local temp=$(mktemp -d)
    local headers_file="$temp/headers.txt"
    local download_file="$temp/$package_file_name"

    echo "${Gr}Downloading ASP.NET Build Tools Package from $SOURCE_URL${Rs}"
    curl -f -o $download_file -sSL $SOURCE_URL -D $headers_file

    local etag=$(cat $headers_file | grep "ETag:" | sed "s/ETag: //g")
    rm $headers_file

    SOURCE_PACKAGE=$download_file

    # Clean and recreate the existing dir
    [ -d $install_path ] && rm -Rf $install_path
    mkdir -p $install_path

    # Extract
    unzip $SOURCE_PACKAGE -d $install_path >/dev/null

    if [ ! -z $etag ]; then
        echo "$etag" > "$install_path/.etag"
    fi

    # Set execute flags
    find "$BUILD_TOOLS" -name "*.sh" -type f | xargs chmod a+x
    find "$BUILD_TOOLS/bin" ! -name "*.cmd" ! -name "*.ps1" -type f | xargs chmod a+x

    rm -Rf $temp
}

ensure_build_tools() {
    if [ -z $BUILD_TOOLS ]; then
        install_build_tools
    else
        [ -e $BUILD_TOOLS ] || die "could not find build tools in '$BUILD_TOOLS'"
    fi
}

# Argument parsing
while [ $# -gt 0 ]; do
    case $1 in
        --)
            # Remaining args are passed to 'aspnet-build'
            shift
            
            # Exit the while loop
            break
            ;;
        -h|-\?|--help)
            usage
            exit 0
            ;;
        --build-tools)
            [ -z "$BUILD_TOOLS" ] || die "can't specify '--build-tools' more than once"
            BUILD_TOOLS=$2
            shift
            ;;
        --reset-tools)
            RESET_TOOLS=1
            ;;
        *)
            # Unexpected arg, exit the loop without shifting
            break
            ;;
    esac

    shift
done

ensure_build_tools

"$BUILD_TOOLS/bin/aspnet-build" "$@"