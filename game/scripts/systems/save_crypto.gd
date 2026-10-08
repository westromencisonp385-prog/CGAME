class_name SaveCrypto
extends RefCounted

## C17 存档加密（结构对齐 StringCipher：AES-256 + 1000 轮派生 + 随机熵；口令不硬编码）。
## 密钥材料 = ProjectSettings["reclaimer/save/salt"]（工程级盐，可在发布时替换）+ 本机 OS.get_unique_id()
##          → SHA-256 迭代 1000 轮 → 32 字节 AES-256 密钥；另派生一把 HMAC 密钥做防篡改。
## 封装格式（二进制）： "RCLM" | ver(1) | iv(16) | hmac(32) | ciphertext(PKCS#7 填充)
## 任何一位被改 → HMAC 不匹配 → 解密拒绝（返回空字典），调用方回落到新档。

const MAGIC := "RCLM"
const VERSION := 1
const ROUNDS := 1000
const SETTING := "reclaimer/save/salt"

static func _salt() -> String:
	if ProjectSettings.has_setting(SETTING):
		return str(ProjectSettings.get_setting(SETTING))
	return "reclaimer-dev-salt"

static func _stretch(material: String, label: String) -> PackedByteArray:
	var buf := (label + "|" + material).to_utf8_buffer()
	for i in ROUNDS:
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(buf)
		ctx.update(PackedByteArray([i & 0xFF, (i >> 8) & 0xFF]))
		buf = ctx.finish()
	return buf

static func derive_keys(device_id := "") -> Dictionary:
	var dev := device_id if not device_id.is_empty() else OS.get_unique_id()
	var material := _salt() + "#" + dev
	return {"aes": _stretch(material, "aes"), "mac": _stretch(material, "mac")}

static func _hmac(key: PackedByteArray, data: PackedByteArray) -> PackedByteArray:
	var c := Crypto.new()
	return c.hmac_digest(HashingContext.HASH_SHA256, key, data)

static func _pad(data: PackedByteArray) -> PackedByteArray:
	var n := 16 - (data.size() % 16)
	var out := data.duplicate()
	for i in n:
		out.append(n)
	return out

static func _unpad(data: PackedByteArray) -> PackedByteArray:
	if data.is_empty():
		return data
	var n := int(data[data.size() - 1])
	if n < 1 or n > 16 or n > data.size():
		return PackedByteArray()
	return data.slice(0, data.size() - n)

static func encrypt(plain: PackedByteArray, device_id := "") -> PackedByteArray:
	var keys := derive_keys(device_id)
	var iv := Crypto.new().generate_random_bytes(16)
	var aes := AESContext.new()
	aes.start(AESContext.MODE_CBC_ENCRYPT, keys["aes"], iv)
	var cipher := aes.update(_pad(plain))
	aes.finish()
	var body := iv + cipher
	var mac := _hmac(keys["mac"], body)
	var out := MAGIC.to_ascii_buffer()
	out.append(VERSION)
	out.append_array(iv)
	out.append_array(mac)
	out.append_array(cipher)
	return out

## 失败（格式错 / 被篡改 / 换机器）返回空数组
static func decrypt(blob: PackedByteArray, device_id := "") -> PackedByteArray:
	if blob.size() < 4 + 1 + 16 + 32 + 16:
		return PackedByteArray()
	if blob.slice(0, 4).get_string_from_ascii() != MAGIC or int(blob[4]) != VERSION:
		return PackedByteArray()
	var iv := blob.slice(5, 21)
	var mac := blob.slice(21, 53)
	var cipher := blob.slice(53)
	if cipher.size() % 16 != 0:
		return PackedByteArray()
	var keys := derive_keys(device_id)
	if _hmac(keys["mac"], iv + cipher) != mac:
		return PackedByteArray()
	var aes := AESContext.new()
	aes.start(AESContext.MODE_CBC_DECRYPT, keys["aes"], iv)
	var plain := aes.update(cipher)
	aes.finish()
	return _unpad(plain)

static func encrypt_dict(d: Dictionary, device_id := "") -> PackedByteArray:
	return encrypt(JSON.stringify(d).to_utf8_buffer(), device_id)

static func decrypt_dict(blob: PackedByteArray, device_id := "") -> Dictionary:
	var plain := decrypt(blob, device_id)
	if plain.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(plain.get_string_from_utf8())
	return parsed if parsed is Dictionary else {}
