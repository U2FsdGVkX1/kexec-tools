#!/bin/sh
#
# Kdump common variables and functions
#

DEFAULT_PATH="/var/crash/"
FENCE_KDUMP_CONFIG_FILE="/etc/sysconfig/fence_kdump"
FENCE_KDUMP_SEND="/usr/libexec/fence_kdump_send"

is_ssh_dump_target()
{
    grep -q "^ssh[[:blank:]].*@" /etc/kdump.conf
}

is_nfs_dump_target()
{
    grep -q "^nfs" /etc/kdump.conf
}

is_raw_dump_target()
{
    grep -q "^raw" /etc/kdump.conf
}

is_fs_type_nfs()
{
    local _fstype=$1
    [ $_fstype = "nfs" ] || [ $_fstype = "nfs4" ] && return 0
    return 1
}

is_fs_dump_target()
{
    egrep -q "^ext[234]|^xfs|^btrfs|^minix" /etc/kdump.conf
}

is_user_configured_dump_target()
{
    return $(is_ssh_dump_target || is_nfs_dump_target || is_raw_dump_target || is_fs_dump_target)
}

strip_comments()
{
    echo $@ | sed -e 's/\(.*\)#.*/\1/'
}

# Check if fence kdump is configured in Pacemaker cluster
is_pcs_fence_kdump()
{
    # no pcs or fence_kdump_send executables installed?
    type -P pcs > /dev/null || return 1
    [ -x $FENCE_KDUMP_SEND ] || return 1

    # fence kdump not configured?
    (pcs cluster cib | grep -q 'type="fence_kdump"') &> /dev/null || return 1
}

# Check if fence_kdump is configured using kdump options
is_generic_fence_kdump()
{
    [ -x $FENCE_KDUMP_SEND ] || return 1

    grep -q "^fence_kdump_nodes" /etc/kdump.conf
}

get_user_configured_dump_disk()
{
    local _target

    if is_ssh_dump_target || is_nfs_dump_target; then
        return
    fi

    _target=$(egrep "^ext[234]|^xfs|^btrfs|^minix|^raw" /etc/kdump.conf 2>/dev/null |awk '{print $2}')
    [ -n "$_target" ] && echo $_target

    return
}

get_root_fs_device()
{
    local _target
    _target=$(findmnt -k -f -n -o SOURCE /)
    [ -n "$_target" ] && echo $_target

    return
}

get_mntpoint_from_path() 
{
    echo $(df $1 | tail -1 |  awk '{print $NF}')
}

get_target_from_path()
{
    echo $(df $1 | tail -1 |  awk '{print $1}')
}

get_fs_type_from_target() 
{
    echo $(findmnt -k -f -n -r -o FSTYPE $1)
}

get_mntpoint_from_target()
{
    echo $(findmnt -k -f -n -r -o TARGET $1)
}

# get_option_value <option_name>
# retrieves value of option defined in kdump.conf
get_option_value() {
    echo $(strip_comments `grep "^$1[[:space:]]\+" /etc/kdump.conf | tail -1 | cut -d\  -f2-`)
}

#This function compose a absolute path with the mount
#point and the relative $SAVE_PATH.
#target is passed in as argument, could be UUID, LABEL,
#block device or even nfs server export of the form of
#"my.server.com:/tmp/export"?
#And possibly this could be used for both default case
#as well as when dump taret is specified. When dump
#target is not specified, then $target would be null.
make_absolute_save_path()
{
    local _target=$1
    local _mnt

    [ -n $_target ] && _mnt=$(get_mntpoint_from_target $1)
    echo "${_mnt}/$SAVE_PATH"
}

check_save_path_fs()
{
    local _path=$1

    if [ ! -d $_path ]; then
        perror_exit "Dump path $_path does not exist."
    fi
}

