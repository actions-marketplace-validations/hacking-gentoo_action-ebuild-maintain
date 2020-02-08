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

# Find the ebuild template and get its category, package and name
ebuild_path=$(find_ebuild_template)
ebuild_cat=$(get_ebuild_cat "${ebuild_path}")
ebuild_pkg=$(get_ebuild_pkg "${ebuild_path}")

# Calculate overlay branch name
overlay_branch="${INPUT_OVERLAY_BRANCH:-${ebuild_cat}/${ebuild_pkg}}"

# Display our findings thus far
echo "Located ebuild at ${ebuild_path}"
echo "  in category ${ebuild_cat}"
echo "    for ${ebuild_pkg}"

# Configure ssh
configure_ssh "${INPUT_DEPLOY_KEY}"

# Configure git
configure_git "${GITHUB_ACTOR}"

# Checkout the overlay (master).
checkout_overlay_master "${INPUT_OVERLAY_REPO}"

# Check out the branch or create a new one
checkout_or_create_overlay_branch "${overlay_branch}"

# Try to rebase.
rebase_overlay_branch

# Add the overlay to repos.conf
repo_name="$(configure_overlay)"
infomsg "Added overlay [${repo_name}] to repos.conf"

while read -r ebuild_file; do
	ebuild_ver=$(qatom -C -F'%{PV}' "${ebuild_file}")
	ebuild_unstable=$(curl -s "https://api.github.com/repos/${GITHUB_REPOSITORY}/releases/tags/${ebuild_ver}" | jq '.prerelease')
	
	if [[ "${ebuild_unstable}" != "null" ]]; then
		echo -e "\nChecking ebuild ${ebuild_file} - version ${ebuild_ver} - unstable = ${ebuild_unstable}"
		echo -e "\nkwtool b ${ebuild_cat}/${ebuild_pkg}-${ebuild_ver}::${repo_name}"
		kwtool -N b "${ebuild_cat}/${ebuild_pkg}-${ebuild_ver}::${repo_name}"
		new_keywords="$(kwtool b "${ebuild_cat}/${ebuild_pkg}-${ebuild_ver}")"
		sed-or-die '^KEYWORDS.*' "KEYWORDS=\"${new_keywords}\"" "${ebuild_file}"
		if [[ "${ebuild_unstable}" == "false" ]]; then
			echo -e "\nUsing best KEYWORDS: ${new_keywords}"
		else
			new_keywords="$(unstable_keywords "${ebuild_file}")"
			echo "Pre-release KEYWORDS: ${new_keywords}"
			sed-or-die '^KEYWORDS.*' "KEYWORDS=\"${new_keywords}\"" "${ebuild_file}"
		fi
		ebuild "${ebuild_file}" manifest
	else
		echo "::warning ::Ebuild ${ebuild_file} - version ${ebuild_ver} - has no corresponding release"
		echo
	fi
done < <(find "${ebuild_cat}/${ebuild_pkg}/" -name "*.ebuild" | grep -v ".*9999\.ebuild" | sort -Vr)

# Add it to git
git_add_files

# Check it with repoman
repoman_check || echo "::warning ::Repoman checks failed"

# Commit the new ebuild.
if git_commit "Automated update of ${ebuild_cat}/${ebuild_pkg} keywords"; then

	# Push git repo branch
	git_push "${overlay_branch}"
	
	# Create a pull request
	if [[ -n "${INPUT_AUTH_TOKEN}" ]]; then
		title="Automated update of ${ebuild_cat}/${ebuild_pkg}"
		msg="Automatically generated pull request to update overlay for new keywords for ${ebuild_cat}/${ebuild_pkg}"
		create_pull_request "${overlay_branch}" "master" "${title}" "${msg}" "false" 
	fi
fi

echo "------------------------------------------------------------------------------------------------------------------------"
