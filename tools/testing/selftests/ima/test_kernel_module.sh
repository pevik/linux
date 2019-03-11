#!/bin/sh
# SPDX-License-Identifier: GPL-2.0
#
# On secure boot enabled systems with "CONFIG_IMA_ARCH_POLICY" configured,
# this test verifies that at least an appended kernel module signature or
# an IMA signature is required.  It does not attempt to load a kernel module.

TEST="KERNEL_MODULE"
. ./ima_common_lib.sh

trap "{ rm -f $IKCONFIG ; }" EXIT

# Some of the IMA builtin policies may require the kernel modules to
# be signed, but these policy rules may be replaced with a custom
# policy.  Only CONFIG_IMA_APPRAISE_REQUIRE_MODULE_SIGS persists after
# loading a custom policy.  Check if it is enabled, before reading the
# IMA runtime sysfs policy file.
# Return 1 for IMA signature required and 0 for not required.
is_ima_sig_required()
{
	local ret=0

	kconfig_enabled "CONFIG_IMA_APPRAISE_REQUIRE_MODULE_SIGS=y" \
		"IMA kernel module signature required"
	if [ $? -eq 1 ]; then
		return 1
	fi

	# The architecture specific or a custom policy may require the
	# kernel module to be signed.  Policy rules are walked sequentially.
	# As a result, a policy rule may be defined, but might not necessarily
	# be used.  This test assumes if a policy rule is specified, that is
	# the intent.
	if [ $ima_read_policy -eq 1 ]; then
		check_ima_policy "appraise" "func=MODULE_CHECK" \
			"appraise_type=imasig"
		ret=$?
		[ $ret -eq 1 ] && log_info "IMA signature required";
	fi
	return $ret
}

# loading kernel modules requires root privileges
require_root_privileges

# Are appended signatures required?
if [ -e /sys/module/module/parameters/sig_enforce ]; then
	sig_enforce=$(cat /sys/module/module/parameters/sig_enforce)
	if [ $sig_enforce = "Y" ]; then
		log_pass "appended kernel module signature required"
	fi
fi

get_secureboot_mode
if [ $? -eq 0 ]; then
	log_skip "secure boot not enabled"
fi

# get the kernel config
get_kconfig

# Determine which kernel config options are enabled
kconfig_enabled "CONFIG_IMA_ARCH_POLICY=y" \
	"architecture specific policy enabled"
arch_policy=$?

kconfig_enabled "CONFIG_MODULE_SIG=y" \
	"appended kernel modules signature enabled"
appended_sig_enabled=$?

kconfig_enabled "CONFIG_IMA_READ_POLICY=y" "reading IMA policy permitted"
ima_read_policy=$?

is_ima_sig_required
ima_sig_required=$?

if [ $arch_policy -eq 0 ]; then
	log_skip "architecture specific policy not enabled"
fi

if [ $appended_sig_enabled -eq 1 ]; then
	log_fail "appended kernel module signature enabled, but not required"
fi

if [ $ima_sig_required -eq 1 ]; then
	log_pass "IMA kernel module signature required"
fi

if [ $ima_read_policy -eq 1 ]; then
	log_fail "IMA kernel module signature not required"
else
	log_skip "reading IMA policy not permitted"
fi
