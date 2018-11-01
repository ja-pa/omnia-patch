

mk_patch.sh should be copied into **openwrt** root directory.

# Help:
```
	make <package name> <feed name> #make patch from package located in feeds/<feed name>
	update <branch-name> 		# update patches dir and apply them to feeds
	patch-feeds			# apply patches from feed directory
```

# Examples:
## Create patch for knot packages from feeds/packages

```
./mk_patch.sh make knot packages
```

## Update package from packages feed which was patched before

1) Remove old patches
```
rm patches/packages/knot*.patch
```
2) Update feeds/packages without applying removed patches 
```
./mk_patches.sh patch-feeds
```
3) Create patch 
```
./mk_patch.sh make knot packages
```
