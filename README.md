

mk_patch.sh should be copied into openwrt root directory.

Help:
```
	make <package name> <feed name> #make patch from package located in feeds/<feed name>
	update 				# update patches dir and apply them to feeds
	patch-feeds			# apply patches from feed directory
```

Example:
```
./mk_patch.sh make knot packages
```
