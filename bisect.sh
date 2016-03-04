#!/bin/sh
# 2016 Alexander Couzens <lynxis@fe80.eu>
# GPLv2
#

# a script to use it with git
# run it with git bisect

ROOT=$(dirname $0)

if [ -z "$CPUS" ] ; then
	CPUS="$(grep -c 'processor' /proc/cpuinfo)"
fi

if [ -z "$LAVAURL" ] ; then
	if [ -z "$LAVAUSER" ] ; then
		LAVAUSER="$USER"
	fi
	LAVAURL="https://$LAVAUSER@lava.coreboot.fe80.eu/RPC2"
fi

if [ -z "$COREBOOTURL" ] ; then
	echo "You need to define a url COREBOOTURL"
	exit -1
fi

if [ -z "$COREBOOT_COPY_URL" ] ; then
	echo "You need to define a url COREBOOT_COPY_URL"
	exit -1
fi

TEMPLATE=job_description.yml

job_done() {
	local jobid="$1"
	lava-tool job-status "$LAVAURL" $jobid |grep -q 'Job Status: Complete'
}

compile_coreboot() {
	yes "" | make oldconfig
	make clean || true
	make -j$(CPUS)
	stat build/coreboot.rom 2>/dev/null >/dev/null
}

job_template() {
	local job_name="$1"
	local file_name="$2"
	sed "s!COREBOOTURL!${COREBOOTURL}!g" "$ROOT/$TEMPLATE" | \
		sed "s!JOBNAME!${job_name}!g" > "$file_name"
}

job_submit() {
	# submit a job by using a template
	local file_name=$1
	lava-tool submit-job "$LAVASERVER" "$file_name"
}

copy_coreboot() {
	scp build/coreboot.rom "$COREBOOT_COPY_URL"
}

GIT_HASH="$(git log -1 --format=format:%h)"
if ! compile_coreboot ; then
	# 125 means this revision can not be tested
	exit 125
fi

copy_coreboot
job_template "git_bisect_${GIT_HASH}" "job_${GIT_HASH}"
JOB_ID=$(job_submit "$GIT_HASH" "job_${GIT_HASH}")
copy_coreboot

echo "wait until job $JOB_ID is done"
while ! job_done ; do
	echo -n .
	sleep 1
done
