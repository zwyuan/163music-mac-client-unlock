#!/bin/sh

fail() {
  echo >&2 $@
  exit 1
}

if [ -z "$PREFIX" ]; then
  PREFIX="/Applications/NeteaseMusic.app/Contents/"
fi

[ ! -f "$PREFIX/MacOS/NeteaseMusic" ] && fail "NeteaseMusic is not installed."

if [ "$1" != "-f" ]; then
  [ -f "$PREFIX/MacOS/NeteaseMusicExec" ] && fail "Patch is already installed. Add '-f' to enforce install (update)."
else
  `dirname $0`/uninstall.sh 2>/dev/null
fi

clang -isysroot $(xcrun --sdk macosx --show-sdk-path) -DOUTSIDE_CHINA $CFLAGS -framework Foundation -o unlock.dylib -dynamiclib hijack.m || fail "Cannot compile library."

cp unlock.dylib $PREFIX/MacOS/unlock.dylib || fail "Cannot write target directory."

PASSWORD="iVBORw0KGgoAAAANSUhEUgAABAAAAAQACAYAAAEIGhsVAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAA2hpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw"

unzip -P "$PASSWORD" "$PREFIX/Resources/resources.pack" && \
  find webfiles/webapp/pub -type f -depth | xargs -n1 sed -i'.deletethis' 's/encrypt_reponse:!0/encrypt_reponse:!1/g' && rm webfiles/webapp/pub/*.deletethis && \
  zip -rP "$PASSWORD" resources.pack2 webfiles/ && rm -rf webfiles/ && \
  mv resources.pack2 "$PREFIX/Resources/resources.pack" || fail "Cannot apply resource patch."

mv $PREFIX/MacOS/NeteaseMusic{,Exec}

cat > $PREFIX/MacOS/NeteaseMusic << EOF
#!/bin/sh
export DYLD_INSERT_LIBRARIES=$PREFIX/MacOS/unlock.dylib
exec $PREFIX/MacOS/NeteaseMusicExec
EOF

chmod +x $PREFIX/MacOS/NeteaseMusic
