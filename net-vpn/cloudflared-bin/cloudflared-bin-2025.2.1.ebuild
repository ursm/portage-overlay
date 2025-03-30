EAPI=8

DESCRIPTION="Cloudflare Tunnel client (formerly Argo Tunnel)"
HOMEPAGE="https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/tunnel-guide"
SRC_URI="https://github.com/cloudflare/cloudflared/releases/download/${PV}/cloudflared-linux-amd64 -> cloudflared-${PV}-amd64"

S=${WORKDIR}

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"

RESTRICT="strip"

src_prepare() {
	default

	cp "${DISTDIR}/cloudflared-${PV}-amd64" cloudflared || die
}

src_install() {
	exeinto /usr/bin
	doexe cloudflared
}
