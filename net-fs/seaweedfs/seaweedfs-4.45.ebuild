# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit go-module shell-completion systemd

DESCRIPTION="Fast distributed storage system for blobs, objects, files, and data lake"
HOMEPAGE="https://seaweedfs.com/ https://github.com/seaweedfs/seaweedfs"
SRC_URI="
	https://github.com/seaweedfs/${PN}/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/ursm/portage-overlay/releases/download/${P}/${P}-vendor.tar.xz
"

LICENSE="Apache-2.0"
# Dependent modules licenses
LICENSE+=" BSD BSD-2 ISC MIT MPL-2.0 rclone? ( CC0-1.0 LGPL-3 )"
SLOT="0"
KEYWORDS="~amd64"
IUSE="elasticsearch gocdk large-disk rclone sqlite tarantool tikv ydb"

# fowners on /etc/seaweedfs needs the group at build time already.
DEPEND="acct-group/seaweedfs"
# weed mount talks to /dev/fuse directly as root but goes through
# fusermount3 otherwise, and always unmounts through it (see PATCHES),
# so the FUSE 3 helper is a genuine runtime need.
RDEPEND="
	${DEPEND}
	acct-user/seaweedfs
	sys-fs/fuse:3
"
BDEPEND=">=dev-lang/go-1.26"

PATCHES=( "${FILESDIR}"/${P}-fusermount3.patch )

# Each tag compiles in one optional backend. The set matches upstream's
# full_install Makefile target. Extra tags can be passed in.
weed_tags() {
	local tags=(
		"$@"
		$(usev elasticsearch elastic)
		$(usev gocdk)
		$(usev rclone)
		$(usev sqlite)
		$(usev tarantool)
		$(usev tikv)
		$(usev ydb)
	)
	local IFS=,
	echo "${tags[*]}"
}

src_compile() {
	# 5BytesOffset is upstream's large_disk release variant rather than a
	# backend, and it is a build-only tag here: the storage tests hard-code
	# 4-byte offsets and upstream's CI never runs them with it either.
	#
	# The main package lives in weed/, so an -o of just "weed" would land
	# inside that directory instead of naming the binary.
	ego build -tags "$(weed_tags $(usev large-disk 5BytesOffset))" -o bin/weed ./weed
}

src_test() {
	ego test -tags "$(weed_tags)" -short ./weed/...
}

src_install() {
	dobin bin/weed
	einstalldocs

	systemd_dounit "${FILESDIR}"/seaweedfs-{master,volume,filer,s3,server}.service

	# weed fuse is a mount(8) helper, so mount -t weed and fstab entries
	# work once it can be found under the helper name.
	dosym -r /usr/bin/weed /usr/sbin/mount.weed

	# weed looks here for its TOML files but ships none: each store type
	# has its own and weed scaffold generates the one you need, into an
	# existing directory only. security.toml holds signing keys, so keep
	# the directory to the daemons' group.
	keepdir /etc/seaweedfs
	fowners root:seaweedfs /etc/seaweedfs
	fperms 0750 /etc/seaweedfs

	# The completion scripts call back into weed itself, and upstream
	# generates them with the resolved absolute path of whichever binary
	# printed them. Rewrite that to where the binary is actually going to
	# live. zsh is left out: upstream's zsh script is the bash one wrapped
	# in bashcompinit, which does not autoload as a site function.
	local shell
	for shell in bash fish; do
		bin/weed autocomplete "${shell}" > "${T}/weed.${shell}" || die
		sed -i -e "s|$(realpath bin/weed)|${EPREFIX}/usr/bin/weed|g" \
			"${T}/weed.${shell}" || die
		if grep -qF "${WORKDIR}" "${T}/weed.${shell}"; then
			die "${shell} completion still points at the build directory"
		fi
	done
	newbashcomp "${T}/weed.bash" weed
	dofishcomp "${T}/weed.fish"
}

pkg_postinst() {
	# All of this is one-time setup knowledge; on upgrades the user has
	# already dealt with it.
	if [[ -z ${REPLACING_VERSIONS} ]]; then
		elog "weed looks for its configuration files in /etc/seaweedfs, which only"
		elog "root and the seaweedfs group can read. Generate the ones you need"
		elog "with weed scaffold, for example:"
		elog
		elog "  weed scaffold -config=filer -output=/etc/seaweedfs"
		elog
		elog "systemd units are provided per role (seaweedfs-master, -volume, -filer"
		elog "and -s3) plus seaweedfs-server, which runs master, volume server and"
		elog "filer in one process. They keep their state under /var/lib/seaweedfs"
		elog "and take further flags through a drop-in: systemctl edit seaweedfs-volume"
		elog
		elog "weed master and weed server send anonymous usage statistics to"
		elog "telemetry.seaweedfs.com unless started with -telemetry=false"
		elog "(master) or -master.telemetry=false (server)."
		elog
		elog "weed update replaces /usr/bin/weed behind Portage's back; use"
		elog "emerge to upgrade instead."
	fi
}
