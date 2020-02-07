#!/usr/bin/env bash
set -e

# shellcheck disable=SC1090
if ! source "${GITHUB_ACTION_LIB:-/usr/lib/github-action-lib.sh}"; then
	echo "::error::Unable to locate github-action-lib.sh"
	exit 1
fi

[[ ${GITHUB_REF} = refs/heads/* ]] && git_branch="${GITHUB_REF##*/}"
[[ ${GITHUB_REF} = refs/tags/* ]] && git_tag="${GITHUB_REF##*/}"

cat << END
------------------------------------------------------------------------------------------------------------------------
                  _   _                       _           _ _     _        _                                    _ 
                 | | (_)                     | |         (_) |   | |      | |                                  | |
        __ _  ___| |_ _  ___  _ __ ______ ___| |__  _   _ _| | __| |______| | _____ _   ___      _____  _ __ __| |
       / _\` |/ __| __| |/ _ \| '_ \______/ _ \ '_ \| | | | | |/ _\` |______| |/ / _ \ | | \ \ /\ / / _ \| '__/ _\` |
      | (_| | (__| |_| | (_) | | | |    |  __/ |_) | |_| | | | (_| |      |   <  __/ |_| |\ V  V / (_) | | | (_| |
       \__,_|\___|\__|_|\___/|_| |_|     \___|_.__/ \__,_|_|_|\__,_|      |_|\_\___|\__, | \_/\_/ \___/|_|  \__,_|
                                                                                     __/ |                        
                                                                                    |___/                         
      https://github.com/hacking-gentoo/action-ebuild-keyword                            (c) 2019-2020 Max Hacking 
------------------------------------------------------------------------------------------------------------------------
INPUT_PACKAGE_ONLY="${INPUT_PACKAGE_ONLY}"
GITHUB_ACTOR="${GITHUB_ACTOR}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY}"
GITHUB_REF="${GITHUB_REF}"
git_branch="${git_branch}"
git_tag="${git_tag}"
------------------------------------------------------------------------------------------------------------------------
END

# Check for a GITHUB_WORKSPACE env variable
[[ -z "${GITHUB_WORKSPACE}" ]] && die "Must set GITHUB_WORKSPACE in env"
cd "${GITHUB_WORKSPACE}" || exit 2

# Check for an overlay
[[ -z "${INPUT_OVERLAY_REPO}" ]] && die "Must set INPUT_OVERLAY_REPO"

# Check for repository deploy key.
[[ -z "${INPUT_DEPLOY_KEY}" ]] && die "Must set INPUT_DEPLOY_KEY"

# If there isn't a .gentoo directory in the base of the workspace then bail
[[ -d .gentoo ]] || die "No .gentoo directory in workspace root"



echo "------------------------------------------------------------------------------------------------------------------------"
