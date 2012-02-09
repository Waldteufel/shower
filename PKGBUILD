# Maintainer: Benjamin Richter <br@waldteufel.eu>
pkgname=shower-git
pkgver=20120209
pkgrel=1
pkgdesc="Eine Web-Brause"
arch=('any')
url="http://github.com/Waldteufel/shower"
license=()
groups=()
depends=('>=libwebkit-1.6.3' '>=vala-0.14.2' '>=libunique-1.1.6' '>=gtk2-2.24.10')
makedepends=('git')
provides=()
conflicts=()
replaces=()
backup=()
options=()
install=
source=()
noextract=()
md5sums=() #generate with 'makepkg -g'

_gitroot=http://github.com/Waldteufel/shower
_gitname=shower

build() {
  cd "$srcdir"
  msg "Connecting to GIT server...."

  if [[ -d "$_gitname" ]]; then
    cd "$_gitname" && git pull origin
    msg "The local files are updated."
  else
    git clone "$_gitroot" "$_gitname"
  fi

  msg "GIT checkout done or server timeout"
  msg "Starting build..."

  rm -rf "$srcdir/$_gitname-build"
  git clone "$srcdir/$_gitname" "$srcdir/$_gitname-build"
  cd "$srcdir/$_gitname-build"

  #
  # BUILD HERE
  #
  make
}

package() {
  cd "$srcdir/$_gitname-build"
  install -D --mode=755 shower "$pkgdir/usr/bin/shower"
}

# vim:set ts=2 sw=2 et:
