#!/bin/sh

fail() {
  echo >&2 $@
  exit 1
}

if [ -z "$PREFIX" ]; then
  PREFIX="/Applications/NeteaseMusic.app/Contents/"
fi

[ ! -f "$PREFIX/MacOS/NeteaseMusic" ] && fail "NeteaseMusic is not installed."

[ ! -f "$PREFIX/MacOS/NeteaseMusicExec" ] && fail "Patch is not installed."

mv $PREFIX/MacOS/NeteaseMusic{Exec,}
rm -f $PREFIX/MacOS/unlock.dylib
