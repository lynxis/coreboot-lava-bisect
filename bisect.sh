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

if [ -z "$COREBOOT_SCP_URL" ] ; then
	echo "You need to define a url COREBOOT_SCP_URL"
	exit -1
fi

TEMPLATE=job_description.yml

job_done() {
	local jobid="$1"
	lava-tool job-status "$LAVAURL" $jobid |egrep -q '(Complete|Incomplete|Canceled|Canceling)'
}

compile_coreboot() {
	local i=3
	while [ $i > 0 ] ; do
		yes "" | make oldconfig
		make clean || true
		make -j${CPUS}
		if [ $? -eq 0 ] ; then
			break
		fi
	done
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
	lava-tool submit-job "$LAVAURL" "$file_name"
}

job_status() {
	# return 0 = SUCESSFUL
	# return 1 = Incomplete
	# return 125 = unknown error
	local jobid="$1"
	local status=$(lava-tool job-status "$LAVAURL" $jobid |grep '^Job Status:')
	if [ $? -ne 0 ] ; then
		# can not get job status
		return 125
	fi
	status=$(echo $status | awk -F': ' '{print $2}')
	case "$status" in
		"Complete")
			return 0
			;;
		"Incomplete")
			return 1
			;;
		*)
			# Submitted|Running|Canceled|Canceling
			return 125
			;;
	esac
}

copy_coreboot() {
	scp build/coreboot.rom "$COREBOOT_SCP_URL"
}

GIT_HASH="$(git log -1 --format=format:%h)"
if ! compile_coreboot ; then
	# 125 means this revision can not be tested
	exit 125
fi

copy_coreboot
job_template "git_bisect_${GIT_HASH}" "job_${GIT_HASH}"
JOB_ID=$(job_submit "$GIT_HASH" "job_${GIT_HASH}")

echo "wait until job $JOB_ID is done"
while ! job_done ; do
	echo -n .
	sleep 1
done

job_status $JOB_ID
exit $?
