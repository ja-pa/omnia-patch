#!/bin/bash


AUTORUN_MELD=True
RUN_DIR=$(pwd)


get_upstream() {

	local feed_name="$1"
	cd tmp
	[ -d "upstream_up" ] && rm -rf upstream_up
	mkdir upstream_up
	cd upstream_up
	git clone --depth 1  https://github.com/openwrt/$feed_name.git
	cd ..
	cd ..
}

update_package_sdk() {
	local pkg_name="$1"
	local feed_name="$2" # "turrispackages"
	local run_dir=$(pwd)

	get_upstream packages
	local pkg_dir=$(find $run_dir/feeds/$feed_name -maxdepth 3 -name $pkg_name|grep -v tmp|head -n 1|xargs realpath)
	local upstream_pkg_dir=$(find $run_dir/tmp/upstream_up/packages -maxdepth 3 -name $pkg_name|head -n 1)

	echo "meld $pkg_dir $upstream_pkg_dir"
	meld $pkg_dir $upstream_pkg_dir
}

commit_package() {
	#commit changes from package inside feeds to given branch
	local pkg_name="$1"
	local branch_name="$2"
	local feed_name="turrispackages"

	local run_dir=$(pwd)
	cd tmp
	[ -d "commit_changes" ] && rm -rf commit_changes
	mkdir commit_changes
	cd commit_changes
	git clone -b $branch_name git@gitlab.labs.nic.cz:turris/turris-os-packages.git
	cd ..
	cd ..
	local pkg_dir_new=$(find $run_dir/tmp/commit_changes/turris-os-packages -maxdepth 3 -name $pkg_name|head -n 1)
	local pkg_dir=$(find $run_dir/feeds/$feed_name -maxdepth 3 -name $pkg_name|grep -v tmp|head -n 1|xargs realpath)

	mv $pkg_dir_new $pkg_dir_new.old
	echo "Copy updated version"
	echo "cp -r $pkg_dir $pkg_dir_new"
	cp -r $pkg_dir $pkg_dir_new
	echo "dir with prepared changes"
	echo "$pkg_dir_new"
	cd $pkg_dir_new/..
	git commit $pkg_name
	git status


	echo "commit changes"
}

openwrt_bump_feed() {
	local branch_name="$1"
	cd tmp
	[ -d "bump_openwrt" ] && rm -rf bump_openwrt
	mkdir bump_openwrt
	[ -d "bump_turris" ] && rm -rf bump_turris
	mkdir bump_turris

	cd bump_turris
	git clone -b $branch_name git@gitlab.labs.nic.cz:turris/turris-os-packages.git
	cd turris-os-packages
	last_commit=$(git rev-parse HEAD)
	echo "aaaaaaaaaaaaaaaaaa"
	echo "$last_commit"
	cd ..
	cd ..
	cd bump_openwrt
	git clone -b $branch_name git@gitlab.labs.nic.cz:turris/openwrt.git
	cd openwrt
	sed -i "s|src-git turrispackages https://gitlab.labs.nic.cz/turris/turris-os-packages.git^.*|src-git turrispackages https://gitlab.labs.nic.cz/turris/turris-os-packages.git^$last_commit|g" feeds.conf.default
	git commit feeds.conf.default
	git log -p

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
	echo "commit <package-name>"
	echo "bump-feed <branch-name>"

}


case $1 in
update-packages)
	[ ! -z "$2" ] && update_package_sdk "$2" packages
;;
update-turris)
	[ ! -z "$2" ] && update_package_sdk "$2" packages
;;
commit)

	[ ! -z "$2" ] && commit_package "$2" dev-honza
;;
bump-feed)
	openwrt_bump_feed dev-honza
;;
help|*)
	print_help
;;
esac

