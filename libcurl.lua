
--libcurl ffi binding.
--Written by Cosmin Apreutesei. Public Domain.

if not ... then require'libcurl_test'; return end

local ffi = require'ffi'
require'libcurl_h'
local C = ffi.load'curl'
local M = {C = C}

local function X(prefix, x) --lookup a name in C (case-insensitive, no prefix)
	return type(x) == 'string' and C[prefix..x:upper()] or x
end

local function check(code)
	assert(code == C.CURLE_OK)
end

function M.init(flags)
	check(C.curl_global_init(X('CURL_GLOBAL_', flags or 'all')))
end

function M.init_mem(flags, malloc, free, realloc, strdup, calloc)
	check(C.curl_global_init_mem(flags, malloc, free, realloc, strdup, calloc))
end

M.free = C.curl_global_cleanup

function M.version()
	return ffi.string(C.curl_version())
end

function M.version_info(ver)
	local info = C.curl_version_info(X('CURLVERSION_', ver or 'now'))
	assert(info ~= nil)
	local function str(s) return s ~= nil and ffi.string(s) or nil end
	local protocols = {}
	local p = info.protocols
	while p ~= nil and p[0] ~= nil do
		table.insert(protocols, ffi.string(p[0]))
		p = p + 1
	end
	return {
		age = info.age,
		version = str(info.version),
		version_num = info.version_num,
		host = str(info.host),
		features = info.features,
		ssl_version = str(info.ssl_version),
		ssl_version_num = info.ssl_version_num,
		libz_version = str(info.libz_version),
		protocols = protocols,
		ares = str(info.ares),
		ares_num = info.ares_num,
		libidn = str(info.libidn),
		iconv_ver_num = info.iconv_ver_num,
		libssh_version = str(info.libssh_version),
	}
end

function M.getdate(s)
	local t = C.curl_getdate(s, nil)
	return t ~= -1 and t or nil
end

--[[
--TODO
C.curl_formadd()
C.curl_formfree()
]]

--option encoders ------------------------------------------------------------

local function longbool(b) return 'long', b and 1 or 0 end
local function long(i) return 'long', i end
local function str(s) return 'char*', ffi.cast('const char*', s) end
local function flag(prefix)
	return function(flag)
		return 'long', X(prefix, flag)
	end
end
local function flags(prefix, ctype)
	local ctype = ctype or 'long'
	return function(t)
		local val = 0
		for flag, truthy in pairs(t) do
			if truthy then
				val = bit.bor(val, X(prefix, flag))
			end
		end
		return ctype, val
	end
end
local function slist(t, self)
	local slist = ffi.new('struct curl_slist[?]', #t)
	self._pins[slist] = true
	local dt = {slist}
	for i=0,#t-1 do
		local s = t[i+1]
		slist[i].data = s
		slist[i].next = slist[i+1]
		self._pins[s] = true
	end
	return 'struct curl_slist*', slist
end

local function ctype(ctype)
	return function(val) return ctype, val end
end
local off_t = ctype'curl_off_t'
local voidp = ctype'void*'
local function cb(ctype)
	return function(func, self)
		local function wrapper(...)
			return func(self, ...)
		end
		local cb = ffi.cast(ctype, wrapper)
		table.insert(self._callbacks, cb)
		return ctype, cb
	end
end

--easy interface -------------------------------------------------------------

local options = {
	[C.CURLOPT_TIMEOUT] = long,
	[C.CURLOPT_VERBOSE] = longbool,
	[C.CURLOPT_STDERR] = voidp, --FILE*
	[C.CURLOPT_ERRORBUFFER] = ctype'char*', --output buffer
	[C.CURLOPT_FAILONERROR] = longbool,
	[C.CURLOPT_NOPROGRESS] = longbool,
	[C.CURLOPT_PROGRESSFUNCTION] = cb'curl_progress_callback',
	[C.CURLOPT_PROGRESSDATA] = voidp,
	[C.CURLOPT_URL] = str,
	[C.CURLOPT_PORT] = long,
	[C.CURLOPT_PROTOCOLS] = flags'CURLPROTO_',
	[C.CURLOPT_DEFAULT_PROTOCOL] = str,
	[C.CURLOPT_USERPWD] = str, --user:pass
	[C.CURLOPT_RANGE] = str,
	[C.CURLOPT_REFERER] = str,
	[C.CURLOPT_USERAGENT] = str,
	[C.CURLOPT_POSTFIELDS] = str,
	[C.CURLOPT_COOKIE] = str,
	[C.CURLOPT_COOKIEFILE] = voidp,
	[C.CURLOPT_POST] = longbool,
	[C.CURLOPT_PUT] = longbool,
	[C.CURLOPT_HEADER] = longbool,
	[C.CURLOPT_HEADERDATA] = voidp,
	[C.CURLOPT_NOBODY] = longbool,
	[C.CURLOPT_FOLLOWLOCATION] = longbool,
	[C.CURLOPT_PROXY] = str,
	[C.CURLOPT_PROXYTYPE] = flag'CURLPROXY_',
	[C.CURLOPT_PROXYPORT] = long,
	[C.CURLOPT_PROXYUSERPWD] = str,
	[C.CURLOPT_PROXY_SERVICE_NAME] = str,
	[C.CURLOPT_PROXYAUTH] = flags('CURLAUTH_', 'unsigned long'),
	[C.CURLOPT_PROXY_TRANSFER_MODE] = longbool,
	[C.CURLOPT_PROXYUSERNAME] = str,
	[C.CURLOPT_PROXYPASSWORD] = str,
	[C.CURLOPT_PROXYHEADER] = slist,
	[C.CURLOPT_NOPROXY] = str, --proxy exception list
	[C.CURLOPT_WRITEFUNCTION] = cb'curl_write_callback',
	[C.CURLOPT_WRITEDATA] = voidp, --FILE* or callback arg
	[C.CURLOPT_READFUNCTION] = cb'curl_read_callback',
	[C.CURLOPT_READDATA] = voidp,
	--[C.CURLOPT_INFILESIZE] = long,
	[C.CURLOPT_LOW_SPEED_LIMIT] = long,
	[C.CURLOPT_LOW_SPEED_TIME] = long,
	[C.CURLOPT_MAX_SEND_SPEED] = off_t,
	[C.CURLOPT_MAX_RECV_SPEED] = off_t,
	--[C.CURLOPT_RESUME_FROM] = long,
	[C.CURLOPT_KEYPASSWD] = str,
	[C.CURLOPT_CRLF] = longbool,
	[C.CURLOPT_QUOTE] = str,
	[C.CURLOPT_TIMECONDITION] = flag'CURL_TIMECOND_',
	[C.CURLOPT_TIMEVALUE] = long, --time_t
	[C.CURLOPT_CUSTOMREQUEST] = str,
	[C.CURLOPT_POSTQUOTE] = slist,
	[C.CURLOPT_UPLOAD] = longbool,
	[C.CURLOPT_DIRLISTONLY] = longbool,
	[C.CURLOPT_APPEND] = longbool,
	[C.CURLOPT_TRANSFERTEXT] = longbool,
	[C.CURLOPT_AUTOREFERER] = longbool,
	--[C.CURLOPT_POSTFIELDSIZE] = long,
	[C.CURLOPT_HTTPHEADER] = slist,
	[C.CURLOPT_HTTPPOST] = ctype'struct curl_httppost *',
	[C.CURLOPT_HTTPPROXYTUNNEL] = longbool,
	[C.CURLOPT_HTTPGET] = longbool,
	[C.CURLOPT_HTTP_VERSION] = flag'CURL_HTTP_VERSION_',
	[C.CURLOPT_HTTP200ALIASES] = slist,
	[C.CURLOPT_HTTPAUTH] = flags('CURLAUTH_', 'unsigned long'),
	[C.CURLOPT_HTTP_TRANSFER_DECODING] = longbool,
	[C.CURLOPT_HTTP_CONTENT_DECODING] = longbool,
	[C.CURLOPT_INTERFACE] = str,
	[C.CURLOPT_KRBLEVEL] = longbool,
	[C.CURLOPT_CAINFO] = str,
	[C.CURLOPT_MAXREDIRS] = long,
	[C.CURLOPT_FILETIME] = longbool,
	[C.CURLOPT_TELNETOPTIONS] = slist,
	[C.CURLOPT_MAXCONNECTS] = long,
	[C.CURLOPT_FRESH_CONNECT] = longbool,
	[C.CURLOPT_FORBID_REUSE] = longbool,
	[C.CURLOPT_RANDOM_FILE] = str,
	[C.CURLOPT_EGDSOCKET] = str,
	[C.CURLOPT_CONNECTTIMEOUT] = long,
	[C.CURLOPT_HEADERFUNCTION] = cb'curl_write_callback',
	[C.CURLOPT_COOKIEJAR] = str,
	[C.CURLOPT_USE_SSL] = flag'CURLUSESSL_',
	[C.CURLOPT_SSLCERT] = str,
	[C.CURLOPT_SSLVERSION] = long,
	[C.CURLOPT_SSLCERTTYPE] = str,
	[C.CURLOPT_SSLKEY] = str,
	[C.CURLOPT_SSLKEYTYPE] = str,
	[C.CURLOPT_SSLENGINE] = str,
	[C.CURLOPT_SSLENGINE_DEFAULT] = longbool,
	[C.CURLOPT_SSL_OPTIONS] = flags'CURLSSLOPT_',
	[C.CURLOPT_SSL_CIPHER_LIST] = str,
	[C.CURLOPT_SSL_VERIFYHOST] = function(b) return 'long', b and 2 or 0 end,
	[C.CURLOPT_SSL_VERIFYPEER] = longbool,
	[C.CURLOPT_SSL_CTX_FUNCTION] = cb'curl_ssl_ctx_callback',
	[C.CURLOPT_SSL_CTX_DATA] = voidp,
	[C.CURLOPT_SSL_SESSIONID_CACHE] = longbool,
	[C.CURLOPT_SSL_ENABLE_NPN] = longbool,
	[C.CURLOPT_SSL_ENABLE_ALPN] = longbool,
	[C.CURLOPT_SSL_VERIFYSTATUS] = longbool,
	[C.CURLOPT_SSL_FALSESTART] = longbool,
	[C.CURLOPT_PREQUOTE] = slist,
	[C.CURLOPT_DEBUGFUNCTION] = cb'curl_debug_callback',
	[C.CURLOPT_DEBUGDATA] = voidp,
	[C.CURLOPT_COOKIESESSION] = longbool,
	[C.CURLOPT_CAPATH] = str,
	[C.CURLOPT_BUFFERSIZE] = long,
	[C.CURLOPT_NOSIGNAL] = longbool,
	[C.CURLOPT_SHARE] = ctype'struct Curl_share *',
	[C.CURLOPT_ACCEPT_ENCODING] = str,
	[C.CURLOPT_PRIVATE] = voidp,
	[C.CURLOPT_UNRESTRICTED_AUTH] = longbool,
	[C.CURLOPT_SERVER_RESPONSE_TIMEOUT] = long,
	[C.CURLOPT_IPRESOLVE] = flag'CURL_IPRESOLVE_',
	--[C.CURLOPT_MAXFILESIZE] = long,
	[C.CURLOPT_INFILESIZE] = off_t,
	[C.CURLOPT_RESUME_FROM] = off_t,
	[C.CURLOPT_MAXFILESIZE] = off_t,
	[C.CURLOPT_POSTFIELDSIZE] = off_t,
	[C.CURLOPT_TCP_NODELAY] = longbool,
	[C.CURLOPT_FTPSSLAUTH] = flag'CURLFTPAUTH_',
	[C.CURLOPT_IOCTLFUNCTION] = cb'curl_ioctl_callback',
	[C.CURLOPT_IOCTLDATA] = voidp,
	[C.CURLOPT_COOKIELIST] = str,
	[C.CURLOPT_IGNORE_CONTENT_LENGTH] = longbool,
	[C.CURLOPT_FTPPORT] = str, --IP:PORT
	[C.CURLOPT_FTP_USE_EPRT] = longbool,
	[C.CURLOPT_FTP_CREATE_MISSING_DIRS] = flag'CURLFTP_CREATE_DIR_',
	[C.CURLOPT_FTP_RESPONSE_TIMEOUT] = long,
	[C.CURLOPT_FTP_USE_EPSV] = longbool,
	[C.CURLOPT_FTP_ACCOUNT] = str,
	[C.CURLOPT_FTP_SKIP_PASV_IP] = longbool,
	[C.CURLOPT_FTP_FILEMETHOD] = flag'CURLFTPMETHOD_',
	[C.CURLOPT_FTP_USE_PRET] = longbool,
	[C.CURLOPT_FTP_SSL_CCC] = flag'CURLFTPSSL_CCC_',
	[C.CURLOPT_FTP_ALTERNATIVE_TO_USER] = str,
	[C.CURLOPT_LOCALPORT] = long,
	[C.CURLOPT_LOCALPORTRANGE] = long,
	[C.CURLOPT_CONNECT_ONLY] = longbool,
	[C.CURLOPT_CONV_FROM_NETWORK_FUNCTION] = cb'curl_conv_callback',
	[C.CURLOPT_CONV_TO_NETWORK_FUNCTION] = cb'curl_conv_callback',
	[C.CURLOPT_CONV_FROM_UTF8_FUNCTION] = cb'curl_conv_callback',
	[C.CURLOPT_SOCKOPTFUNCTION] = cb'curl_sockopt_callback',
	[C.CURLOPT_SOCKOPTDATA] = voidp,
	[C.CURLOPT_SSH_AUTH_TYPES] = flags'CURLSSH_AUTH_',
	[C.CURLOPT_SSH_PUBLIC_KEYFILE] = str,
	[C.CURLOPT_SSH_PRIVATE_KEYFILE] = str,
	[C.CURLOPT_SSH_KNOWNHOSTS] = str,
	[C.CURLOPT_SSH_KEYFUNCTION] = cb'curl_sshkeycallback',
	[C.CURLOPT_SSH_KEYDATA] = voidp,
	[C.CURLOPT_SSH_HOST_PUBLIC_KEY_MD5] = str,
	[C.CURLOPT_TIMEOUT_MS] = long,
	[C.CURLOPT_CONNECTTIMEOUT_MS] = long,
	[C.CURLOPT_NEW_FILE_PERMS] = long,
	[C.CURLOPT_NEW_DIRECTORY_PERMS] = long,
	[C.CURLOPT_POSTREDIR] = flag'CURL_REDIR_',
	[C.CURLOPT_OPENSOCKETFUNCTION] = cb'curl_opensocket_callback',
	[C.CURLOPT_OPENSOCKETDATA] = voidp,
	[C.CURLOPT_COPYPOSTFIELDS] = str,
	[C.CURLOPT_SEEKFUNCTION] = cb'curl_seek_callback',
	[C.CURLOPT_SEEKDATA] = voidp,
	[C.CURLOPT_CRLFILE] = str,
	[C.CURLOPT_ISSUERCERT] = str,
	[C.CURLOPT_ADDRESS_SCOPE] = long,
	[C.CURLOPT_CERTINFO] = longbool,
	[C.CURLOPT_USERNAME] = str,
	[C.CURLOPT_PASSWORD] = str,
	[C.CURLOPT_SOCKS5_GSSAPI_SERVICE] = str,
	[C.CURLOPT_SOCKS5_GSSAPI_NEC] = longbool,
	[C.CURLOPT_REDIR_PROTOCOLS] = flags'CURLPROTO_',
	[C.CURLOPT_MAIL_FROM] = str,
	[C.CURLOPT_MAIL_RCPT] = str,
	[C.CURLOPT_MAIL_AUTH] = str,
	[C.CURLOPT_RTSP_REQUEST] = flag'CURL_RTSPREQ_',
	[C.CURLOPT_RTSP_SESSION_ID] = str,
	[C.CURLOPT_RTSP_STREAM_URI] = str,
	[C.CURLOPT_RTSP_TRANSPORT] = str,
	[C.CURLOPT_RTSP_CLIENT_CSEQ] = long,
	[C.CURLOPT_RTSP_SERVER_CSEQ] = long,
	[C.CURLOPT_TFTP_BLKSIZE] = long,
	[C.CURLOPT_INTERLEAVEDATA] = voidp,
	[C.CURLOPT_INTERLEAVEFUNCTION] = cb'curl_write_callback',
	[C.CURLOPT_CHUNK_BGN_FUNCTION] = cb'curl_chunk_bgn_callback',
	[C.CURLOPT_CHUNK_END_FUNCTION] = cb'curl_chunk_end_callback',
	[C.CURLOPT_CHUNK_DATA] = voidp,
	[C.CURLOPT_FNMATCH_FUNCTION] = cb'curl_fnmatch_callback',
	[C.CURLOPT_FNMATCH_DATA] = voidp,
	[C.CURLOPT_RESOLVE] = slist,
	[C.CURLOPT_WILDCARDMATCH] = longbool,
	[C.CURLOPT_TLSAUTH_USERNAME] = str,
	[C.CURLOPT_TLSAUTH_PASSWORD] = str,
	[C.CURLOPT_TLSAUTH_TYPE] = str,
	[C.CURLOPT_TRANSFER_ENCODING] = longbool,
	[C.CURLOPT_CLOSESOCKETFUNCTION] = cb'curl_closesocket_callback',
	[C.CURLOPT_CLOSESOCKETDATA] = voidp,
	[C.CURLOPT_GSSAPI_DELEGATION] = long,
	[C.CURLOPT_ACCEPTTIMEOUT_MS] = long,
	[C.CURLOPT_TCP_KEEPALIVE] = longbool,
	[C.CURLOPT_TCP_KEEPIDLE] = long,
	[C.CURLOPT_TCP_KEEPINTVL] = long,
	[C.CURLOPT_SASL_IR] = longbool,
	[C.CURLOPT_XOAUTH2_BEARER] = str,
	[C.CURLOPT_XFERINFOFUNCTION] = cb'curl_xferinfo_callback',
	[C.CURLOPT_XFERINFODATA] = voidp,
	[C.CURLOPT_NETRC] = flag'CURL_NETRC_',
	[C.CURLOPT_NETRC_FILE] = str,
	[C.CURLOPT_DNS_SERVERS] = str,
	[C.CURLOPT_DNS_INTERFACE] = str,
	[C.CURLOPT_DNS_LOCAL_IP4] = str,
	[C.CURLOPT_DNS_LOCAL_IP6] = str,
	[C.CURLOPT_DNS_USE_GLOBAL_CACHE] = longbool,
	[C.CURLOPT_DNS_CACHE_TIMEOUT] = long,
	[C.CURLOPT_LOGIN_OPTIONS] = str,
	[C.CURLOPT_EXPECT_100_TIMEOUT_MS] = long,
	[C.CURLOPT_HEADEROPT] = flag'CURLHEADER_',
	[C.CURLOPT_PINNEDPUBLICKEY] = str,
	[C.CURLOPT_UNIX_SOCKET_PATH] = str,
	[C.CURLOPT_PATH_AS_IS] = longbool,
	[C.CURLOPT_SERVICE_NAME] = str,
	[C.CURLOPT_PIPEWAIT] = longbool,
}

local function strerror(code)
	return ffi.string(C.curl_easy_strerror(code))
end

function ret(code)
	if code == C.CURLE_OK then return true end
	return nil, strerror(code), code
end

local function check(code)
	local ok, err, errcode = ret(code)
	if ok then return true end
	error('libcurl error: '..err, 2)
end

local easy = {}
easy.__index = easy

function M.easy(opt)
	local curl = C.curl_easy_init()
	assert(curl ~= nil)
	local self = setmetatable({_curl = curl, _callbacks = {}, _pins = {}}, easy)
	ffi.gc(curl, function() self:free() end)
	if opt then
		for k,v in pairs(opt) do
			self:set(k, v)
		end
	end
	return self
end

function easy:free()
	if not self._curl then return end
	C.curl_easy_cleanup(self._curl)
	ffi.gc(self._curl, nil)
	for i,cb in ipairs(self._callbacks) do
		cb:free()
	end
	self._curl = nil
end

function easy:set(k, v)
	local optnum = X('CURLOPT_', k)
	local convert = assert(options[optnum])
	local ctype, cval = convert(v, self) --keep v from being gc'ed
	check(C.curl_easy_setopt(self._curl, optnum, ffi.cast(ctype, cval)))
end

function easy:reset()
	C.curl_easy_reset(self._curl)
end

function easy:perform()
	return ret(C.curl_easy_perform(self._curl))
end

--info

local function strbuf(buf)
	return ffi.new'char*[1]', function(buf)
		return buf[0] ~= nil and ffi.string(buf[0]) or nil
	end
end
local function longbuf(buf)
	return ffi.new'long[1]', function(buf)
		local n = tonumber(buf[0])
		return n ~= -1 and n or nil
	end
end
local function longboolbuf(buf)
	return ffi.new'long[1]', function(buf)
		return buf[0] ~= 0
	end
end
local function doublebuf(buf)
	return ffi.new'double[1]', function(buf)
		return buf[0] ~= -1 and buf[0] or nil
	end
end
local function decode_slist(buf)
		local slist0 = buf[0]
		local t = {}
		local slist = slist0
		while slist ~= nil do
			t[#t+1] = ffi.string(slist.data)
			slist = slist.next
		end
		if slist0 ~= nil then
			C.curl_slist_free_all(slist0)
		end
		return t
	end
local function slistbuf(buf)
	return ffi.new'struct curl_slist*[1]', decode_slist
end
local function certinfobuf(buf)
	return ffi.new'struct curl_certinfo*[1]', function(buf)
		return buf[0].certinfo ~= nil and decode_slist(buf[0].certinfo) or {}
	end
end
local function tlssessioninfobuf(buf)
	return ffi.new'struct curl_tlssessioninfo*[1]', function(buf)
		return buf[0]
	end
end
local function socketbuf(buf)
	return ffi.new'curl_socket_t[1]', function(buf)
		return buf[0]
	end
end

local info_buffers = {
	[C.CURLINFO_EFFECTIVE_URL] = strbuf,
	[C.CURLINFO_RESPONSE_CODE] = longbuf,
	[C.CURLINFO_TOTAL_TIME] = doublebuf,
	[C.CURLINFO_NAMELOOKUP_TIME] = doublebuf,
	[C.CURLINFO_CONNECT_TIME] = doublebuf,
	[C.CURLINFO_PRETRANSFER_TIME] = doublebuf,
	[C.CURLINFO_SIZE_UPLOAD] = doublebuf,
	[C.CURLINFO_SIZE_DOWNLOAD] = doublebuf,
	[C.CURLINFO_SPEED_DOWNLOAD] = doublebuf,
	[C.CURLINFO_SPEED_UPLOAD] = doublebuf,
	[C.CURLINFO_HEADER_SIZE] = longbuf,
	[C.CURLINFO_REQUEST_SIZE] = longbuf,
	[C.CURLINFO_SSL_VERIFYRESULT] = longboolbuf,
	[C.CURLINFO_FILETIME] = longbuf,
	[C.CURLINFO_CONTENT_LENGTH_DOWNLOAD] = doublebuf,
	[C.CURLINFO_CONTENT_LENGTH_UPLOAD] = doublebuf,
	[C.CURLINFO_STARTTRANSFER_TIME] = doublebuf,
	[C.CURLINFO_CONTENT_TYPE] = strbuf,
	[C.CURLINFO_REDIRECT_TIME] = doublebuf,
	[C.CURLINFO_REDIRECT_COUNT] = longbuf,
	[C.CURLINFO_PRIVATE] = strbuf,
	[C.CURLINFO_HTTP_CONNECTCODE] = longbuf,
	[C.CURLINFO_HTTPAUTH_AVAIL] = longbuf,
	[C.CURLINFO_PROXYAUTH_AVAIL] = longbuf,
	[C.CURLINFO_OS_ERRNO] = longbuf,
	[C.CURLINFO_NUM_CONNECTS] = longbuf,
	[C.CURLINFO_SSL_ENGINES] = slistbuf,
	[C.CURLINFO_COOKIELIST] = slistbuf,
	[C.CURLINFO_LASTSOCKET] = longbuf,
	[C.CURLINFO_FTP_ENTRY_PATH] = strbuf,
	[C.CURLINFO_REDIRECT_URL] = strbuf,
	[C.CURLINFO_PRIMARY_IP] = strbuf,
	[C.CURLINFO_APPCONNECT_TIME] = doublebuf,
	[C.CURLINFO_CERTINFO] = certinfobuf,
	[C.CURLINFO_CONDITION_UNMET] = longboolbuf,
	[C.CURLINFO_RTSP_SESSION_ID] = strbuf,
	[C.CURLINFO_RTSP_CLIENT_CSEQ] = longbuf,
	[C.CURLINFO_RTSP_SERVER_CSEQ] = longbuf,
	[C.CURLINFO_RTSP_CSEQ_RECV] = longbuf,
	[C.CURLINFO_PRIMARY_PORT] = longbuf,
	[C.CURLINFO_LOCAL_IP] = strbuf,
	[C.CURLINFO_LOCAL_PORT] = longbuf,
	[C.CURLINFO_TLS_SESSION] = tlssessioninfobuf,
	[C.CURLINFO_ACTIVESOCKET] = socketbuf,
}

function easy:info(k)
	local infonum = X('CURLINFO_', k)
	local buf, decode = assert(info_buffers[infonum])()
	check(C.curl_easy_getinfo(self._curl, infonum, buf))
	return decode(buf)
end

function easy:recv(buf, buflen, n)
	return ret(C.curl_easy_recv(self._curl, buf, buflen, n))
end

function easy:send(buf, buflen, n)
	return ret(C.curl_easy_send(self._curl, buf, buflen, n))
end

easy.strerror = strerror

function easy:escape(s)
	local p = C.curl_easy_escape(self._curl, s, #s)
	if p == nil then return end
	local s = ffi.string(p)
	C.curl_free(p)
	return s
end

local szbuf = ffi.new'int[1]'
function easy:unescape(s)
	local p = C.curl_easy_unescape(self._curl, s, #s, szbuf)
	if p == nil then return end
	local s = ffi.string(p, szbuf[0])
	C.curl_free(p)
	return s
end

--multi interface ------------------------------------------------------------

local function strerror(code)
	return ffi.string(C.curl_multi_strerror(code))
end

function ret(code)
	if code == C.CURLE_OK then return true end
	return nil, strerror(code), code
end

local function check(code)
	local ok, err, errcode = ret(code)
	if ok then return true end
	error('libcurl error: '..err, 2)
end

local multi = {}
multi.__index = multi

function M.multi(opt)
	local curl = C.curl_multi_init()
	assert(curl ~= nil)
	local self = setmetatable({_curl = curl, _callbacks = {}, _pins = {}}, easy)
	ffi.gc(curl, function() self:free() end)
	if opt then
		for k,v in pairs(opt) do
			self:set(k, v)
		end
	end
	return self
end

function multi:free()
	if not self._curl then return end
	check(C.curl_multi_cleanup(self._curl))
	ffi.gc(self._curl, nil)
	for i,cb in ipairs(self._callbacks) do
		cb:free()
	end
	self._curl = nil
end

local function strlist(t, self)
	local buf = ffi.new('char*[?]', #t)
	for i,s in ipairs(t) do
		buf[i-1] = s
		self._pins[s] = true
	end
	return buf
end

local options = {
	[C.CURLMOPT_SOCKETFUNCTION] = cb'curl_socket_callback',
	[C.CURLMOPT_SOCKETDATA] = voidp,
	[C.CURLMOPT_PIPELINING] = flags'CURLPIPE_',
	[C.CURLMOPT_TIMERFUNCTION] = cb'curl_multi_timer_callback',
	[C.CURLMOPT_TIMERDATA] = voidp,
	[C.CURLMOPT_MAXCONNECTS] = longbool,
	[C.CURLMOPT_MAX_HOST_CONNECTIONS] = longbool,
	[C.CURLMOPT_MAX_PIPELINE_LENGTH] = longbool,
	[C.CURLMOPT_CONTENT_LENGTH_PENALTY_SIZE] = longbool,
	[C.CURLMOPT_CHUNK_LENGTH_PENALTY_SIZE] = longbool,
	[C.CURLMOPT_PIPELINING_SITE_BL] = strlist,
	[C.CURLMOPT_PIPELINING_SERVER_BL] = strlist,
	[C.CURLMOPT_MAX_TOTAL_CONNECTIONS] = long,
	[C.CURLMOPT_PUSHFUNCTION] = cb'curl_push_callback',
	[C.CURLMOPT_PUSHDATA] = voidp,
}

function multi:set(k, v)
	local optnum = X('CURLMOPT_', k)
	local convert = assert(options[optnum])
	local ctype, cval = convert(v, self) --keep v from being gc'ed
	check(C.curl_multi_setopt(self._curl, optnum, ffi.cast(ctype, cval)))
end

function multi:reset()
	C.curl_easy_reset(self._curl)
end

local running_handles = ffi.new'int[1]'
function multi:perform()
	local ok, err, errcode = ret(C.curl_multi_perform(self._curl, running_handles))
	if not ok then return nil, err, errcode end
	return running_handles[0]
end

--[[
function multi:add_easy(easy)
	local curl = getmetatable(easy) == easy and easy._curl or easy
	check(C.curl_multi_add_handle(self._curl, curl))
end

function multi:remove_easy(easy)
	local curl = getmetatable(easy) == easy and easy._curl or easy
	check(C.curl_multi_remove_handle(self._curl, curl))
end

function multi:fdset()
	return ret(C.curl_multi_fdset(self._curl, read_fd_set, write_fd_set, exc_fd_set, max_fd))
end

function multi:wait()
	return ret(C.curl_multi_wait(self._curl, extra_fds, extra_nfds, timeout, ret))
end

local msgs_in_queue = ffi.new'int[1]'
function multi:info_read()
	local msg = C.curl_multi_info_read(self._curl, msgs_in_queue)
end

function multi:socket()
	return ret(C.curl_multi_socket(self._curl, curl_socket_t s, int *running_handles))
end

function multi:socket_action()
	return ret(C.curl_multi_socket_action(self._curl,
																  curl_socket_t s,
																  int ev_bitmask,
																  int *running_handles))
end

function multi:socket_all()
	return ret(C.curl_multi_socket_all(self._curl, int *running_handles))
end

function multi:timeout()
	return ret(C.curl_multi_timeout(self._curl, long *milliseconds))
end

function multi:assign()
	return ret(C.curl_multi_assign(self._curl, curl_socket_t sockfd, void *sockp))
end

multi.strerror = strerror
]]

return M
