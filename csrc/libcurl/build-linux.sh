cp -f curl_config.h.$P lib/curl_config.h
cp -f curlbuild.h.$P include/curl/curlbuild.h
C="$C -DHAVE_CONFIG_H vtls/openssl.c
	-I../../openssl/src/include
	-I../../openssl/include-$P" \
L="-lrt -lssl" \
D=libcurl.so A=libcurl.a ./build.sh
