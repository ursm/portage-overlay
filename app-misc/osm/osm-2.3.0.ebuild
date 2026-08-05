# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

CRATES="
	anstream@1.0.0
	anstyle-parse@1.0.0
	anstyle-query@1.0.0
	anstyle-wincon@3.0.11
	anstyle@1.0.14
	bitflags@2.9.3
	bitvec@1.0.1
	cfg-if@1.0.0
	cfg_aliases@0.2.1
	clap@4.6.3
	clap_builder@4.6.2
	clap_derive@4.6.3
	clap_lex@1.0.0
	colorchoice@1.0.0
	evdev@0.13.2
	funty@2.0.0
	heck@0.5.0
	is_terminal_polyfill@1.70.1
	libc@0.2.175
	nix@0.29.0
	once_cell_polyfill@1.70.2
	proc-macro2@1.0.106
	quote@1.0.45
	radium@0.7.0
	strsim@0.11.1
	syn@2.0.117
	tap@1.0.1
	unicode-ident@1.0.3
	utf8parse@0.2.2
	windows-link@0.2.1
	windows-sys@0.48.0
	windows-sys@0.61.2
	windows-targets@0.48.0
	windows_aarch64_gnullvm@0.48.0
	windows_aarch64_msvc@0.48.0
	windows_i686_gnu@0.48.0
	windows_i686_msvc@0.48.0
	windows_x86_64_gnu@0.48.0
	windows_x86_64_gnullvm@0.48.0
	windows_x86_64_msvc@0.48.0
	wyz@0.5.0
"

RUST_MIN_VER="1.85.0"

inherit cargo linux-info systemd udev

DESCRIPTION="Remaps a modifier key to another key when pressed alone"
HOMEPAGE="https://github.com/ursm/osm"
SRC_URI="
	https://github.com/ursm/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	${CARGO_CRATE_URIS}
"

LICENSE="MIT"
# Dependent crate licenses
LICENSE+=" Apache-2.0 Unicode-DFS-2016"
SLOT="0"
KEYWORDS="~amd64"

# The udev rule is what launches osm, so udev is a genuine runtime requirement.
# systemd is not: the binary is a standalone evdev-to-uinput remapper that runs
# under any init, and sys-apps/systemd is masked on every split-usr profile, so
# depending on it would make osm uninstallable there.
RDEPEND="virtual/udev"

# README.md.hms is the template README.md is generated from, not documentation.
DOCS=( README.md )

CONFIG_CHECK="~INPUT_EVDEV ~INPUT_UINPUT"
ERROR_INPUT_EVDEV="osm reads key events from your keyboards through /dev/input/event*
nodes, so it needs evdev support (INPUT_EVDEV) built into your kernel or loaded as a module."
ERROR_INPUT_UINPUT="osm emits key events through a virtual keyboard, so it needs
user level driver support (INPUT_UINPUT) built into your kernel or loaded as a module."

# Both linux-info and rust (via cargo) export pkg_setup, and only the last
# inherit would survive. Run both explicitly instead.
pkg_setup() {
	linux-info_pkg_setup
	rust_pkg_setup
}

src_install() {
	cargo_src_install
	einstalldocs

	udev_dorules dist/udev/99-osm.rules

	sed -e "s|@BINDIR@|${EPREFIX}/usr/bin|g" -e "s|@SYSCONFDIR@|${EPREFIX}/etc|g" \
		dist/systemd/osm@.service.in > osm@.service || die
	systemd_dounit osm@.service

	insinto /etc/default
	doins dist/default/osm
}

pkg_postinst() {
	udev_reload

	# osm ships with no key mappings set, so it starts but does nothing until
	# /etc/default/osm is configured. Tell a first-time installer how to turn
	# it on; on upgrades they already know.
	if [[ -z ${REPLACING_VERSIONS} ]]; then
		elog "osm does nothing until you set a key mapping in /etc/default/osm."
		elog "For example, to map both Shift keys:"
		elog
		elog "  KEYMAP=\"LeftShift=Home RightShift=End\""
		elog
		elog "osm is started per keyboard by udev, so once configured it picks up"
		elog "existing devices only after a re-trigger:"
		elog
		elog "  udevadm trigger --action=add --subsystem-match=input"
	fi
}

pkg_postrm() {
	udev_reload
}
