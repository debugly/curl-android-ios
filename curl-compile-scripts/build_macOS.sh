#!/bin/bash

# https://github.com/curl/curl/issues/3189
# https://curl.haxx.se/docs/install.html

realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

XCODE=$(xcode-select -p)
if [ ! -d "$XCODE" ]; then
	echo "You have to install Xcode and the command line tools first"
	exit 1
fi

REL_SCRIPT_PATH="$(dirname $0)"
SCRIPTPATH=$(realpath "$REL_SCRIPT_PATH")
CURLPATH="$SCRIPTPATH/../curl"

PWD=$(pwd)
cd "$CURLPATH"

if [ ! -x "$CURLPATH/configure" ]; then
	echo "Curl needs external tools to be compiled"
	echo "Make sure you have autoconf, automake and libtool installed"

	./buildconf

	EXITCODE=$?
	if [ $EXITCODE -ne 0 ]; then
		echo "Error running the buildconf program"
		cd "$PWD"
		exit $EXITCODE
	fi
fi

# git apply ../patches/patch_curl_fixes1172.diff

export CC="$XCODE/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"
DESTDIR="$SCRIPTPATH/../prebuilt-with-ssl/macOS"

export MACOSX_DEPLOYMENT_TARGET="10.10"
ARCHS=(x86_64)
HOSTS=(x86_64)
PLATFORMS=(MacOSX)
SDK=(MacOSX)

rm -rf "${DESTDIR}/*"

#Build for all the architectures
for (( i=0; i<${#ARCHS[@]}; i++ )); do
	ARCH=${ARCHS[$i]}
	export CFLAGS="-arch $ARCH -pipe -Os -gdwarf-2 -isysroot $XCODE/Platforms/${PLATFORMS[$i]}.platform/Developer/SDKs/${SDK[$i]}.sdk -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET} -Werror=partial-availability"
	export LDFLAGS="-arch $ARCH -isysroot $XCODE/Platforms/${PLATFORMS[$i]}.platform/Developer/SDKs/${SDK[$i]}.sdk"
	cd "$CURLPATH"
	./configure	\
			--with-darwinssl \
			--without-ssl    \
			--enable-static \
			--enable-shared \
			--enable-threaded-resolver \
			--disable-verbose \
			--enable-ipv6 \
			--disable-file --disable-dict \
			--disable-telnet --disable-tftp \
			--disable-ftp --disable-ldap    \
			--disable-manual --disable-ldaps \
			--disable-rtsp --disable-librtsp --disable-pop3 \
			--disable-imap --disable-smtp \
			--disable-gopher --disable-smb \
			--without-libidn --disable-proxy \
			--disable-manual --enable-cookies \
			--prefix="${DESTDIR}" \
			--libdir="${DESTDIR}/$ARCH"
			# --host="${HOSTS[$i]}-apple-darwin"

	EXITCODE=$?
	if [ $EXITCODE -ne 0 ]; then
		echo "Error running the cURL configure program"
		cd "$PWD"
		exit $EXITCODE
	fi

	make -j $(sysctl -n hw.logicalcpu_max)
	EXITCODE=$?
	if [ $EXITCODE -ne 0 ]; then
		echo "Error running the make program"
		cd "$PWD"
		exit $EXITCODE
	fi
	# mkdir -p "$DESTDIR/$ARCH"
	# cp "$CURLPATH/lib/.libs/libcurl.a" "$DESTDIR/$ARCH/"
	# cp "$CURLPATH/lib/.libs/libcurl.a" "$DESTDIR/libcurl-$ARCH.a"
	make install
	make clean
done

git checkout $CURLPATH

exit

#Build a single static lib with all the archs in it
cd "$DESTDIR"
lipo -create -output libcurl.a libcurl-*.a
rm libcurl-*.a

#Copying cURL headers
if [ -d "$DESTDIR/include" ]; then
	echo "Cleaning headers"
	rm -rf "$DESTDIR/include"
fi
cp -R "$CURLPATH/include" "$DESTDIR/"
rm "$DESTDIR/include/curl/.gitignore"

cd "$PWD"
