EAPI=8

DESCRIPTION="Bitwarden Secrets Manager CLI"
HOMEPAGE="https://bitwarden.com/help/secrets-manager-cli/"
SRC_URI="https://github.com/bitwarden/sdk-sm/releases/download/bws-v${PV}/bws-x86_64-unknown-linux-gnu-${PV}.zip"

S=${WORKDIR}

LICENSE="Bitwarden-SDK"
SLOT="0"
KEYWORDS="~amd64"

RESTRICT="strip"

src_install() {
	exeinto /usr/bin
	doexe bws
}
