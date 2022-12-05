#!/bin/bash

usage()
{
cat <<EOF

Check number of snapshot for each vm in xoa.


  Options:
    -t     auth token
    -s     fqdn xoa server
    -a     snapshot's age (a.k.a. grace period)
    -n     number of snapshot
    -x     comma separated host excluded from check
    -h     this help
EOF
exit 1
}

if [ $# -eq 0 ]; then
    usage
    exit 0
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
    -h)
        usage
		exit 0
		;;
    -s)
        XOASERVER=$2
        shift
        ;;
    -t)
        TOKEN=$2
        shift
        ;;
    -n)
        NUMBER=$2
        shift
        ;;
    -x)
        IFS=',' read -r -a EXCLUDED <<< "$2"
        shift
        ;;
    -a)
        AGE=$2
        shift
        ;;
    -*)
        usage
        exit 0
        ;;
    *)
        usage
        exit 0
        ;;
    esac
    shift
done

check_snapshot()
{
VMLIST=$(curl -k -s -b authenticationToken=${TOKEN} "https://${XOASERVER}/rest/v0/vms?filter=snapshots:length:>=${NUMBER}&fields=name_label,power_state" | jq .[].name_label)
#convert to array
readarray -t VMARRAY <<<"$VMLIST"
#get rid of ""
for i in "${!VMARRAY[@]}"; do
    cleanarray+=($( echo "${VMARRAY[i]}" | sed 's/^.//;s/.$//'))
done
VMARRAY=("${cleanarray[@]}")
unset arraypulito

#get rid of EXCLUDED vms
for excluded in  "${EXCLUDED[@]}"; do
    for vm in "${!VMARRAY[@]}"; do
        if [ "${VMARRAY[vm]}" = "$excluded" ];then
            unset 'VMARRAY[vm]'
        fi
    done
done
#rebuild array without gaps
for i in "${!VMARRAY[@]}"; do
    VMRESULT+=( "${VMARRAY[i]}" )
done
TIME=$(date +%s -d "${AGE} day ago")

SNAPLIST=$(curl -k -s -b authenticationToken=${TOKEN} "https://${XOASERVER}/rest/v0/vm-snapshots?filter=snapshot_time:<${TIME}&fields=name_label,uuid,%24snapshot_of"| jq '.[]."$snapshot_of"')
#converto to array
readarray -t SNAPARRAY <<<"$SNAPLIST"
for i in "${!SNAPARRAY[@]}"; do
    cleanarray+=($( echo "${SNAPARRAY[i]}" | sed 's/^.//;s/.$//'))
done
SNAPARRAY=("${cleanarray[@]}")
unset cleanarray

for vm in "${!VMRESULT[@]}"; do
    UUID=$(curl -k -s -b authenticationToken=${TOKEN} "https://${XOASERVER}/rest/v0/vms?filter=name_label:${VMRESULT[vm]}&fields=uuid" | jq .[].uuid | sed 's/^.//;s/.$//')

    for snap in "${!SNAPARRAY[@]}"; do
        if [ "$UUID" = "${SNAPARRAY[snap]}" ];then
            RESULT+=( "${VMRESULT[vm]}" )
            break
        fi
    done
done



#answer
if [ -z "$RESULT" ]
then
    echo "OK - No VM has more than $CRITICAL snapshot $AGE days old"
    exit 0
else
    echo "CRITICAL"
    for i in "${!RESULT[@]}"; do
        echo ${RESULT[i]}
    done
    exit 2
fi
}

check_snapshot
