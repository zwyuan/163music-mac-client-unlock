#!/bin/sh

fail() {
  echo >&2 $@
  exit 1
}

[ ! -f "/Applications/NeteaseMusic.app/Contents/MacOS/NeteaseMusic" ] && fail "NeteaseMusic is not installed."

[ -f "/Applications/NeteaseMusic.app/Contents/MacOS/NeteaseMusicExec" ] && fail "Patch is already installed."

[ ! -f "unlock.dylib" ] && clang -DOUTSIDE_CHINA -framework Foundation -o unlock.dylib -dynamiclib hijack.m || fail "Cannot compile library."

mv /Applications/NeteaseMusic.app/Contents/MacOS/NeteaseMusic{,Exec}
cp unlock.dylib /Applications/NeteaseMusic.app/Contents/MacOS/unlock.dylib
cat > /Applications/NeteaseMusic.app/Contents/MacOS/NeteaseMusic << EOF
#!/bin/sh
export DYLD_INSERT_LIBRARIES=/Applications/NeteaseMusic.app/Contents/MacOS/unlock.dylib
exec /Applications/NeteaseMusic.app/Contents/MacOS/NeteaseMusicExec
EOF
chmod +x /Applications/NeteaseMusic.app/Contents/MacOS/NeteaseMusic

PASSWORD="czh9r3xgGxdaOw9b8qrizM1FWMBQBAztdCDjbYz5r46a97EFQ0uP5c8EL56rqgC38nmlqVBNlHbgGEjToQeRkPcpLQjuQ1y2TNRYW59euPbbLlVQ32saq2j7TdvfZnSe"

unzip -P "$PASSWORD" /Applications/NeteaseMusic.app/Contents/Resources/resources.pack && \
  find webfiles/webapp/pub -type f -depth | xargs -n1 sed -i'.deletethis' 's/encrypt_reponse:!0/encrypt_reponse:!1/g' && rm webfiles/webapp/pub/*.deletethis && \
  zip -rP "$PASSWORD" resources.pack2 webfiles/ && rm -rf webfiles/ && \
  mv resources.pack2 /Applications/NeteaseMusic.app/Contents/Resources/resources.pack || fail "Cannot apply resource patch."
