extends SceneTree

var failures: int = 0
var checks: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	if not FileAccess.file_exists("res://scripts/network/invite.gd"):
		check(false, "private invite codec is available")
		finish()
		return
	var codec = load("res://scripts/network/invite.gd")
	var crypto := Crypto.new()
	var key := crypto.generate_rsa(2048)
	var certificate := crypto.generate_self_signed_certificate(key, "CN=close-the-gap.test,O=CloseTheGap,C=US")
	var secret := crypto.generate_random_bytes(32)
	var expiry := int(Time.get_unix_time_from_system()) + 900
	var invite: String = codec.encode("test-host-id", certificate, secret, expiry)
	var decoded: Dictionary = codec.decode(invite)
	check(not decoded.is_empty(), "valid invite decodes")
	check(decoded.get("oid") == "test-host-id", "invite identifies host")
	check(decoded.get("secret") == secret, "invite preserves authorization secret")
	var payload := invite.substr(5).replace("-", "+").replace("_", "/")
	while payload.length() % 4:
		payload += "="
	var json_text := Marshalls.base64_to_raw(payload).get_string_from_utf8()
	check(not json_text.contains("PRIVATE KEY") and json_text.contains("BEGIN CERTIFICATE"), "decoded invite contains only the public certificate, not a private key")
	check(codec.decode("invalid").is_empty(), "reject unknown invite format")
	check(codec.decode("CTG1:" + "A".repeat(10000)).is_empty(), "reject oversized invite")
	check(codec.decode("CTG1:!!??").is_empty(), "reject invalid encoding")
	check(codec.decode("CTG1:AAAA").is_empty(), "reject binary data without attempting UTF-8 decoding")
	check(codec.decode("CTG1:e30").is_empty(), "reject incomplete JSON schema")
	check(codec.decode(codec.encode("host", certificate, secret, expiry - 1000)).is_empty(), "reject expired invite")
	check(codec.decode(codec.encode("host", certificate, secret, expiry + 99999)).is_empty(), "reject implausible invite lifetime")
	check(codec.decode(codec.encode("host\nconnect other", certificate, secret, expiry)).is_empty(), "reject broker command injection")
	check(codec.decode(codec.encode("host", certificate, PackedByteArray([1, 2]), expiry)).is_empty(), "reject weak authorization secret")
	var old_text: String = json_text.replace(codec.Rules.BUILD_ID,"older-build")
	var old_invite: String = codec.PREFIX + Marshalls.raw_to_base64(old_text.to_utf8_buffer()).replace("+","-").replace("/","_").trim_suffix("=").trim_suffix("=")
	check(codec.decode(old_invite).is_empty(),"mismatched demo builds are rejected before networking")
	finish()

func finish() -> void:
	print("INVITE_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
