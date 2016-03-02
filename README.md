# how to bisect

## requirements

- working [lava-tool](https://lava.coreboot.fe80.eu/static/docs/overview.html#installing-lava-tool)
- compile-ready coreboot
- a working http/ftp server to copy coreboot images to using scp

## overview

Basic 4 steps what the bisect.sh do
- compile coreboot
- publish coreboot to a web url
- lava-tool submit job
- wait for lava-tool job-status

## How to use it?

cd coreboot
git bisect start
git bisect bad REV
git bisect good REV
git bisect run /path/to/this/dir/bisect.sh

