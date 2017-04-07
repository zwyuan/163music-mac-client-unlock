# 163music-mac-client-unlock

Unlock netease music mac client using dylib inject

# Build

This single command builds `unlock.dylib` binary

```shell
clang -framework Foundation -o unlock.dylib -dynamiclib hijack.m
```

Add `-DDEBUG` if you'd like to inspect detailed request information.

# Installation

1. Download this repo
2. Enter /Applications/NeteaseMusic.app/Contents/MacOS
3. Rename "NeteaseMusic" to "NeteaseMusicExec"
4. Build project and place unlock.dylib and NeteaseMusic to the folder
5. Enjoy! All paid and blocked music are unlocked !

If you got LSOpenURL error , run

```shell
chmod +x /Applications/NeteaseMusic.app/Contents/MacOS/NeteaseMusic
```

# App Store

Apps from app store will apply force signature verification, will not work
after replace the main executeable, if you are using app store version,
please use offical website version instead.

