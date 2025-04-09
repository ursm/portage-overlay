EAPI=8

DESCRIPTION="dev tools, env vars, task runner"
HOMEPAGE="https://mise.jdx.dev/"
SRC_URI="https://github.com/jdx/mise/releases/download/v${PV}/mise-v${PV}-linux-x64.tar.xz"

S=${WORKDIR}

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

RESTRICT="strip"

src_install() {
	exeinto /usr/bin
	doexe mise/bin/mise

	dodoc mise/LICENSE mise/README.md
	doman mise/man/man1/mise.1
}
