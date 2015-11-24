---
tagname: libcurl binding
---

<warn>Work In Progress.</warn>

## `curl = require'libcurl'`

[LibCURL](http://curl.haxx.se/) binding.

## API

-------------------------------------- --------------------------------------
__easy interface__
`curl.easy{options...} -> easy`        create an easy request
`easy:perform() -> true|nil,err,ecode` perform the request
`easy:free()`                          free the request
`easy:getinfo(...) -> t`               get info
`easy:duphandle() -> easy`             duplicate the request
`easy:reset()`                         reset the request
`easy:recv() -> true|nil,err,ecode`
`easy:send() -> true|nil,err,ecode`
`easy.strerror(ecode) -> s`            look-up an error code
-------------------------------------- --------------------------------------

## Easy interface

### `curl.easy{options...} -> easy`

Create an request using the easy interface. Options below:

-------------------------------------- --------------------------------------
__Basic__
`url`
`protocols`
`default_protocol`
`redir_protocols`
`port`
`userpwd`
`range`
`referer`
`useragent`
`postfields`
`cookie`
`cookiefile`
`post`
`put`
`header`
`headerdata`
`nobody`
`followlocation`

__Timeouts__
`timeout`
`timeout_ms`
`connecttimeout`
`connecttimeout_ms`
`accepttimeout_ms`
`server_response_timeout`

__Progress Tracking__
`noprogress`
`progressfunction`
`progressdata`

__Error Handling__
`verbose`
`stderr`
`errorbuffer`
`failonerror`

__Proxy__
`proxy`
`proxytype`
`proxyport`
`proxyuserpwd`
`proxy_service_name`
`proxyauth`
`proxy_transfer_mode`
`proxyusername`
`proxypassword`
`proxyheader`
`noproxy`

__I/O Callbacks__
`writefunction`
`writedata`
`readfunction`
`readdata`
`seekfunction`
`seekdata`

`infilesize`

__Speed Limits__
`low_speed_limit`
`low_speed_time`
`max_send_speed_large`
`max_recv_speed_large`

`resume_from`
`keypasswd`
`crlf`
`quote`
`timecondition`
`timevalue`
`customrequest`
`postquote`
`upload`
`dirlistonly`
`append`
`transfertext`
`autoreferer`
`postfieldsize`

__HTTP__
`httpheader`
`httppost`
`httpproxytunnel`
`httpget`
`http_version`
`http200aliases`
`httpauth`
`http_transfer_decoding`
`http_content_decoding`

`interface`
`krblevel`
`cainfo`
`maxredirs`
`filetime`
`telnetoptions`
`maxconnects`
`fresh_connect`
`forbid_reuse`
`random_file`
`egdsocket`
`headerfunction`
`cookiejar`

__SSL__
`use_ssl`
`sslcert`
`sslversion`
`sslcerttype`
`sslkey`
`sslkeytype`
`sslengine`
`sslengine_default`
`ssl_options`
`ssl_cipher_list`
`ssl_verifyhost`
`ssl_verifypeer`
`ssl_ctx_function`
`ssl_ctx_data`
`ssl_sessionid_cache`
`ssl_enable_npn`
`ssl_enable_alpn`
`ssl_verifystatus`
`ssl_falsestart`
`crlfile`
`issuercert`
`certinfo`

`prequote`
`debugfunction`
`debugdata`
`cookiesession`
`capath`
`buffersize`
`nosignal`
`share`
`accept_encoding`
`private`
`unrestricted_auth`

`ipresolve`
`maxfilesize`
`infilesize_large`
`resume_from_large`
`maxfilesize_large`
`postfieldsize_large`
`tcp_nodelay`
`ftpsslauth`
`ioctlfunction`
`ioctldata`
`cookielist`
`ignore_content_length`

__FTP__
`ftpport`
`ftp_use_eprt`
`ftp_create_missing_dirs`
`ftp_response_timeout`
`ftp_use_epsv`
`ftp_account`
`ftp_skip_pasv_ip`
`ftp_filemethod`
`ftp_use_pret`
`ftp_ssl_ccc`
`ftp_alternative_to_user`

__Socket__
`localport`
`localportrange`
`connect_only`
`conv_from_network_function`
`conv_to_network_function`
`conv_from_utf8_function`
`opensocketfunction`
`opensocketdata`
`closesocketfunction`
`closesocketdata`
`sockoptfunction`
`sockoptdata`

__SSH__
`ssh_auth_types`
`ssh_public_keyfile`
`ssh_private_keyfile`
`ssh_knownhosts`
`ssh_keyfunction`
`ssh_keydata`
`ssh_host_public_key_md5`

`new_file_perms`
`new_directory_perms`
`postredir`
`copypostfields`
`address_scope`

`username`
`password`

__SOCKS5__
`socks5_gssapi_service`
`socks5_gssapi_nec`

`interleavedata`
`interleavefunction`

`chunk_bgn_function`
`chunk_end_function`
`chunk_data`

`fnmatch_function`
`fnmatch_data`

`resolve`
`wildcardmatch`
__TLS Auth__
`tlsauth_username`
`tlsauth_password`
`tlsauth_type`

`transfer_encoding`
`gssapi_delegation`

__TCP__
`tcp_keepalive`
`tcp_keepidle`
`tcp_keepintvl`

__MAIL__
`mail_from`
`mail_rcpt`
`mail_auth`

__TFTP__
`tftp_blksize`

__RTSP__
`rtsp_request`
`rtsp_session_id`
`rtsp_stream_uri`
`rtsp_transport`
`rtsp_client_cseq`
`rtsp_server_cseq`

__NETRC__
`netrc`
`netrc_file`

__DNS__
`dns_servers`
`dns_interface`
`dns_local_ip4`
`dns_local_ip6`
`dns_use_global_cache`
`dns_cache_timeout`

__MISC__
`login_options`
`expect_100_timeout_ms`
`headeropt`
`pinnedpublickey`
`unix_socket_path`
`path_as_is`
`service_name`
`pipewait`
`sasl_ir`
`xoauth2_bearer`
`xferinfofunction`
`xferinfodata`
-------------------------------------- --------------------------------------
