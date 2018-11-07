#!/bin/bash
set -o errexit -o nounset

AUTORUN_MELD=True
RUN_DIR=$(pwd)



clone_repo() {
	local dir_name="$1"	# where should we clone
	local feed_name="$2"
	local branch_name="$3"	# test,master,dev-something
	local repo_type="$4"	# github or gitlab
	local clone_depth="$5"

	# every operation is done inside openwrt/tmp
	cd tmp
	[ -d "$dir_name" ] && rm -rf "$dir_name"
	mkdir "$dir_name"
	cd "$dir_name" || exit


	if [ "$repo_type" == "github" ]; then
		url="https://github.com/openwrt"
	else
		url="git@gitlab.labs.nic.cz:turris"
	fi

	if [ "$clone_depth" == "full" ]; then

		git clone -b "$branch_name" "$url/$feed_name.git"
	else
		git clone -b "$branch_name" --depth 1 "$url/$feed_name.git"
	fi

	cd ..
	cd ..
}

get_upstream() {
	local feed_name="$1"
	clone_repo "upstream_up" "$feed_name" "master" "github" "nofull"
}

update_package_sdk() {
	# update packages inside openwrt/feed directory from
	# upstream source
	local pkg_name="$1"
	local feed_name="$2" # "turrispackages"
	local pkg_dir
	local upstream_pkg_dir

	get_upstream packages
	pkg_dir=$(find "$RUN_DIR/feeds/$feed_name" -maxdepth 3 -name "$pkg_name"|grep -v tmp|head -n 1|xargs realpath)
	upstream_pkg_dir=$(find "$RUN_DIR/tmp/upstream_up/packages" -maxdepth 3 -name "$pkg_name"|head -n 1)

	#echo "meld $pkg_dir $upstream_pkg_dir"
	if [ "$AUTORUN_MELD" == "True" ]; then
		meld "$pkg_dir" "$upstream_pkg_dir"
	else
		echo "Could not run meld"
	fi
}

commit_package() {
	#commit changes from package inside feeds to given branch
	local pkg_name="$1"
	local branch_name="$2"
	local feed_name="turrispackages"
	local pkg_dir_new
	local pkg_dir

	clone_repo "commit_changes" "turris-os-packages" "$branch_name" "gitlab" "full"

	pkg_dir_new=$(find "$RUN_DIR/tmp/commit_changes/turris-os-packages" -maxdepth 3 -name "$pkg_name"|head -n 1)
	pkg_dir=$(find "$RUN_DIR/feeds/$feed_name" -maxdepth 3 -name "$pkg_name"|grep -v tmp|head -n 1|xargs realpath)


	# copy update package and prepare it for commit
	mv "$pkg_dir_new" "$pkg_dir_new.old"
	echo "Copy updated version"
	cp -r "$pkg_dir" "$pkg_dir_new"
	cd "$pkg_dir_new/.."
	git commit "$pkg_name"
	git status


	echo "Commit changes"
	echo "------------------------------------------"
	echo "To commit changes go to:"
	echo "$pkg_dir_new"
	echo "------------------------------------------"
}

openwrt_bump_feed() {
	local branch_name="$1"

	# get last commit hash
	clone_repo "bump_turris" "turris-os-packages" "$branch_name" "gitlab" "full"
	cd tmp/bump_turris/turris-os-packages || exit -1
	last_commit=$(git rev-parse HEAD)
	cd ../../..

	# update commit hash in feeds.conf.default
	clone_repo "bump_openwrt" "openwrt" "$branch_name" "gitlab" "full"
	cd tmp/bump_openwrt/openwrt
	sed -i "s|src-git turrispackages https://gitlab.labs.nic.cz/turris/turris-os-packages.git^.*|src-git turrispackages https://gitlab.labs.nic.cz/turris/turris-os-packages.git^$last_commit|g" feeds.conf.default
	git commit feeds.conf.default

	# show log
	set +o +e #rrexit
	git log -p

	# push changes
	echo "Push changes to $branch_name [y/n]"
	read -r push_var
	if [ "$push_var" == "y" ]; then
		git push
	fi

}


print_help() {

	echo "Help:"
	echo "update-packages <package-name>	# update package from packages feed"
	echo "update-turris <package-name>	# update package from turrispackages feed"
	echo "commit <package-name> <branch-name>"
	echo "bump-feed <branch-name>		# dev-something"

}

if [ $# -eq 0 ]; then
	print_help
	exit
fi

case "$1" in
update-packages)
	[ ! -z "$2" ] && update_package_sdk "$2" packages
;;
update-turris)
	[ ! -z "$2" ] && update_package_sdk "$2" turrispackages
;;
commit)
	[ ! -z "$2" ] && [ ! -z "$3" ] && commit_package "$2" "$3"
;;
bump-feed)
	[ ! -z "$2" ] && openwrt_bump_feed "$2"
;;
help|*)
	print_help
;;
esac

