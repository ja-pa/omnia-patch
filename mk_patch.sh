#!/bin/bash


print_table() {
	patch_filename="$1"
	patch_file="$2"
	patch_path="$3"

	echo "+----------+"
	echo aaaaaaaaaaaaaaaaaaaaaaaaaaaa
	echo $patch_filename
	echo bbbbbbbbbbbbbbbbbbbbbbbbbbbb

	tbl_line="$patch_file | $patch_path"
	length=${#tbl_line}

	echo
	echo "Patch created!"
	#echo
	echo -n "+"
	for ((i=1; i<=$length; i++)); do echo -n -; done
	echo -n "+"
	echo
	echo "Patch name | Patch full path"

	echo -n "+"
	for ((i=1; i<=$length; i++)); do echo -n -; done
	echo -n "+"
	echo

	echo "$tbl_line"
	echo -n "+"
	for ((i=1; i<=$length; i++)); do echo -n -; done
	echo -n "+"
	echo
}

create_patch() {


	#create patch form feeds/packages/directory (no patches are applied to
	pkg_name=$1
	feed_name=$2

	case "$feed_name" in
	routing)
		git_url="https://github.com/openwrt-routing/packages.git"
		git_hash="a4eae82c155079a4372e4b910ec733f77288b717"
		clone_dir="packages"
		patch_dir="routing"
	;;

	packages|*)
		git_url="https://github.com/openwrt/packages.git"
		git_hash="5fdb011c357c3b79bbb19d934b57cfed2ff00aa0"
		clone_dir="packages"
		patch_dir="packages"
	;;
	esac


	pkg_dir=$(find feeds/$feed_name -maxdepth 3 -name $pkg_name|grep -v tmp|head -n 1 |xargs realpath)

	rm -rf tmp/$clone_dir
	clone_packages $git_url $git_hash $clone_dir $patch_dir
	apply_patches $clone_dir $patch_dir

	#fix so our new patches will be based on pushed patches
	pushd tmp/packages
	echo "commit applied patches"
	git commit . -m " commit applied patches"
	popd

	tmp_pkg_dir=$(find tmp/packages -maxdepth 2 -name $pkg_name|head -n 1 |xargs realpath)

	if [ ! -e $tmp_pkg_dir ]; then
		echo "Error package $pkg_name does not exists!!!"
		exit
	fi

	#move old version and replace it with version from feeds/xxx/yyyy
	mv $tmp_pkg_dir $tmp_pkg_dir.old
	cp -r $pkg_dir $tmp_pkg_dir

	pwd
	pushd tmp/$clone_dir
	subdir_name=$(dirname $tmp_pkg_dir|xargs basename)
	[ -d "$subdir_name" ] && pushd $subdir_name
	git add $pkg_name/
	git commit $pkg_name/ -m "$pkg_name: xxxx"
	git commit --amend

	#make patch file from commit
	patch_filename=$(git format-patch -1 HEAD)
	patch_file=$(basename $patch_filename)
	patch_path=$(realpath $patch_file)
	patch_dir2=$(dirname $patch_path)

	popd
	popd

	patch_number=$(get_patch_number $patch_dir $pkg_name)
	new_patch_filename=$(echo "$patch_file"|sed "s/0001-$pkg_name*/$pkg_name-$patch_number/")
	mv $patch_path $patch_dir2/$new_patch_filename
	patch_path2=$(realpath $patch_dir2/$new_patch_filename)
	print_table $new_patch_filename $new_patch_filename $patch_path2
}


clone_packages() {
	git_url="$1"	# "https://github.com/openwrt-routing/packages.git"
	git_hash="$2"	#"a4eae82c155079a4372e4b910ec733f77288b717"
	clone_dir="$3"	#"packages"
	patch_dir="$4"	#"routing"

	mkdir -p tmp
	pushd tmp
	git clone $git_url
	pushd $clone_dir
	git checkout $git_hash
	popd
	popd
	echo "Cloning done!!"
}

apply_patches() {
	clone_dir="$1"
	patch_dir="$2"

	echo apply patches to tmp dir
	pushd patches
	pushd "$patch_dir"
	for patch in $(ls |sort -n); do
		echo "Patch $patch"
		pushd ../../tmp/$clone_dir
		patch -p1 < ../../patches/$patch_dir/$patch
		popd
	done
	popd
	popd
}

print_help() {
	echo "Help:"
	echo "	make <package name> <feed name> #make patch from package located in feeds/<feed name>"
	echo "	update 				# update patches dir and apply them to feeds"
	echo "	patch-feeds			# apply patches from feed directory"

}

list_patches() {
	echo
	echo "List of patches"
	for i in {1..70};do printf "%s" "-";done;printf "\n"
	printf "%-30s | %-30s\n" Name Path
	for i in {1..70};do printf "%s" "-";done;printf "\n"
	for file_path in tmp/packages/*.patch
	do

		file_name=$(basename $file_path)
		printf "%-30s | %30s\n" $file_name  $file_path

		#echo "$file_name | $file_path"
	done
	echo
}

get_patch_number() {
	patch_dir="$1" #"packages"
	pkg_name="$2" #"ic" #"$2"
	patch_name=$(find patches/$patch_dir/ -name "$pkg_name*.patch"|sort|tail -n1) #|xargs basename)

	number=$(echo $patch_name |awk -F'-' '{print $2}'|tail -n1)
	re='^[0-9]+$'
	if ! [[ $number =~ $re ]] ; then
		echo "Error: Not a number" >&2
		new_number=$(printf "%04d" 1)
	else
		#echo "is number"
		new_number=$(echo "$number+1"|bc|xargs printf "%04d")
	fi

	echo -n "$new_number"
}

update_patches() {
	branch_name=kernel-modules
	#branch_name=test

	rm -rf tmp/update_patches/
	mkdir -p tmp/update_patches
	pushd tmp/update_patches
	git clone -b "$branch_name" git@gitlab.labs.nic.cz:turris/openwrt.git
	popd


	read -p "This action  will delete openwrt/patches and openwrt/feeds dir. Do you want to continue  (y/n)?" choice

	if [ "$choice" = "y" ]; then
		echo ""
		echo "update!!!!!"
	else
		echo "Abording update!"
		exit
	fi


	rm -rf patches/
	cp -r tmp/update_patches/openwrt/patches .
	# Clean feeds
	./scripts/feeds clean
	./scripts/feeds update -a
	# Patch feeds
	pushd patches
	set -e
	for feed in *; do
		pushd $feed
		for patch in $(ls |sort -n); do
			echo "Patch $patch"
			pushd ../../feeds/$feed
			patch -p1 < ../../patches/$feed/$patch
			popd
		done
		popd
	done
	set +e
	popd
	./scripts/feeds install -a
}

patch_feeds() {
	read -p "This action will delete openwrt/feeds dir. Do you want to continue  (y/n)?" choice
	if [ "$choice" = "y" ]; then
	# Clean feeds
	./scripts/feeds clean
	./scripts/feeds update -a
	# Patch feeds
	pushd patches
	set -e
	for feed in $(ls |sort -n); do
		pushd $feed
		for patch in *; do
			echo "Patch $patch"
			pushd ../../feeds/$feed
			patch -p1 < ../../patches/$feed/$patch
			popd
		done
		popd
	done
	set +e
	popd
	./scripts/feeds install -a
	else
		echo "Abording update!"
		exit
	fi

}


case $1 in
list)
	list_patches
;;
make)
	#create patch from givem directory
	create_patch $2 $3
;;
update)
	echo "Update patches and feeds"
	update_patches
;;
patch-feeds)
	patch_feeds
;;

*)
	print_help
;;
esac
