#!/bin/sh

fail() {
  echo >&2 $@
  exit 1
}

if [ -z "$PREFIX" ]; then
  PREFIX="/Applications/NeteaseMusic.app/Contents/"
fi

[ ! -f "$PREFIX/MacOS/NeteaseMusic" ] && fail "NeteaseMusic is not installed."

[ -f "$PREFIX/MacOS/NeteaseMusicExec" ] && fail "Patch is already installed."

[ ! -f "unlock.dylib" ] && clang -DOUTSIDE_CHINA -framework Foundation -o unlock.dylib -dynamiclib hijack.m || fail "Cannot compile library."

mv $PREFIX/MacOS/NeteaseMusic{,Exec}
cp unlock.dylib $PREFIX/MacOS/unlock.dylib

cat > $PREFIX/MacOS/NeteaseMusic << EOF
#!/bin/sh
export DYLD_INSERT_LIBRARIES=$PREFIX/MacOS/unlock.dylib
exec $PREFIX/MacOS/NeteaseMusicExec
EOF

chmod +x $PREFIX/MacOS/NeteaseMusic

PASSWORD="czh9r3xgGxdaOw9b8qrizM1FWMBQBAztdCDjbYz5r46a97EFQ0uP5c8EL56rqgC38nmlqVBNlHbgGEjToQeRkPcpLQjuQ1y2TNRYW59euPbbLlVQ32saq2j7TdvfZnSe"

unzip -P "$PASSWORD" "$PREFIX/Resources/resources.pack" && \
  find webfiles/webapp/pub -type f -depth | xargs -n1 sed -i'.deletethis' 's/encrypt_reponse:!0/encrypt_reponse:!1/g' && rm webfiles/webapp/pub/*.deletethis && \
  zip -rP "$PASSWORD" resources.pack2 webfiles/ && rm -rf webfiles/ && \
  mv resources.pack2 "$PREFIX/Resources/resources.pack" || fail "Cannot apply resource patch."
