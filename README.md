# 163music-mac-client-unlock

Unlock netease music mac client using dylib inject.

## Usage

Run `install.sh` and rocks.

### App Store

Apps from app store will apply force signature verification, will not work
after replace the main executeable, if you are using app store version,
please use offical website version instead.

## Development

This single command builds `unlock.dylib` binary with debug flag for detailed request information.

```shell
clang -DDEBUG -framework Foundation -o unlock.dylib -dynamiclib hijack.m
```

