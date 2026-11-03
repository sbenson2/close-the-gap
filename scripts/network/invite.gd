extends RefCounted

const Rules = preload("res://scripts/rules.gd")
const PREFIX := "CTG1:"
const LIFETIME: int = 900
const TLS_NAME := "close-the-gap.test"
const PROTOCOL := "close-the-gap/friends/" + Rules.BUILD_ID

static func encode(oid: String, certificate: X509Certificate, secret: PackedByteArray, expiry: int) -> String:
	var pem := certificate_text(certificate)
	if pem.is_empty():
		return ""
	var data := {"v": 1, "build": Rules.BUILD_ID, "oid": oid, "cert": pem, "key": Marshalls.raw_to_base64(secret), "expires": expiry}
	return PREFIX + Marshalls.raw_to_base64(JSON.stringify(data).to_utf8_buffer()).replace("+", "-").replace("/", "_").trim_suffix("=").trim_suffix("=")

static func certificate_text(certificate: X509Certificate) -> String:
	# Godot 4.7.2 save_to_string() includes a C terminator in UTF-8 decoding.
	# Export only the public certificate through the byte-safe file API instead.
	var path := "user://ctg-public-%d-%s.pem" % [OS.get_process_id(), Crypto.new().generate_random_bytes(6).hex_encode()]
	if certificate.save(path) != OK:
		return ""
	var bytes := FileAccess.get_file_as_bytes(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	while not bytes.is_empty() and bytes[-1] == 0:
		bytes.resize(bytes.size() - 1)
	return bytes.get_string_from_utf8()

static func valid_oid(oid: String) -> bool:
	if oid.is_empty() or oid.length() > 96:
		return false
	for c in oid:
		if c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-":
			return false
	return true

static func decode(text: String) -> Dictionary:
	text = text.strip_edges()
	if not text.begins_with(PREFIX) or text.length() > 4096:
		return {}
	var encoded := text.substr(PREFIX.length())
	for c in encoded:
		if c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-":
			return {}
	if encoded.length() % 4 == 1:
		return {}
	encoded = encoded.replace("-", "+").replace("_", "/")
	while encoded.length() % 4:
		encoded += "="
	var raw := Marshalls.base64_to_raw(encoded)
	# This protocol's JSON is printable ASCII; reject malformed binary before decoding.
	for byte in raw:
		if byte < 32 or byte > 126:
			return {}
	var parser := JSON.new()
	if raw.size() > 3072 or parser.parse(raw.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return {}
	var data: Dictionary = parser.data
	if data.get("build") != Rules.BUILD_ID or data.get("v") != 1 or not data.get("oid") is String or not valid_oid(data.oid):
		return {}
	if not data.get("cert") is String or not data.get("key") is String or typeof(data.get("expires")) not in [TYPE_INT, TYPE_FLOAT]:
		return {}
	var now := int(Time.get_unix_time_from_system())
	var expiry := int(data.expires)
	if expiry <= now or expiry > now + LIFETIME + 60:
		return {}
	if data.cert.length() > 2500 or not data.cert.begins_with("-----BEGIN CERTIFICATE-----") or data.key.length() != 44:
		return {}
	for c in data.key:
		if c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+/=":
			return {}
	var secret := Marshalls.base64_to_raw(data.key)
	if secret.size() != 32 or Marshalls.raw_to_base64(secret) != data.key:
		return {}
	var certificate := X509Certificate.new()
	if certificate.load_from_string(data.cert) != OK:
		return {}
	return {"oid": data.oid, "certificate": certificate, "secret": secret, "expires": expiry}
