#!/bin/sh
# SPDX-License-Identifier: BSD-3-Clause

# This Source Code Form is subject to the terms of the BSD-3-Clause License.
# If a copy of the BSD-3-Clause License was not distributed with this file, You can obtain one at https://opensource.org/licenses/BSD-3-Clause.
#
# Stefan Zintgraf, stefan@zintgraf.de

# xrdp sesman service
/usr/sbin/xrdp-sesman
# xrdp 
/usr/sbin/xrdp --nodaemon
