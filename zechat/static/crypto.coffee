zc.SCRYPT_DIFFICULTY = 16384
zc.SCRYPT_SALT = 'zechat'
zc.NONCE_SIZE = 24
zc.KEY_SIZE = 32


zc.scrypt = (input_txt) ->
  scrypt = scrypt_module_factory()
  input = scrypt.encode_utf8(input_txt)
  salt = scrypt.encode_utf8(zc.SCRYPT_SALT)
  secret = scrypt.crypto_scrypt(input, salt, zc.SCRYPT_DIFFICULTY,
                                8, 1, zc.KEY_SIZE)
  return zc.encode_secret_key(secret)


zc.nacl = nacl_factory.instantiate()


zc.encode_secret_key = (key) ->
  return 'sk:' + zc.b64fromu8array(key)


zc.secret_key = (key) ->
  throw "Not a secret key" unless (key.slice(0, 3) == 'sk:')
  return zc.b64tou8array(key.slice(3))


zc.encode_public_key = (key) ->
  return 'pk:' + zc.b64fromu8array(key)


zc.public_key = (key) ->
  throw "Not a public key" unless (key.slice(0, 3) == 'pk:')
  return zc.b64tou8array(key.slice(3))


zc.encode_message = (data) ->
  return 'msg:' + zc.b64fromu8array(data)


zc.decode_message = (message) ->
  throw "Not a message" unless (message.slice(0, 4) == 'msg:')
  return zc.b64tou8array(message.slice(4))


zc.encode_secret = (data) ->
  return 'sec:' + zc.b64fromu8array(data)


zc.decode_secret = (message) ->
  throw "Not a secret box" unless (message.slice(0, 4) == 'sec:')
  return zc.b64tou8array(message.slice(4))


zc.message_hash = (message) ->
  message_data = zc.decode_message(message)
  hash = zc.nacl.crypto_hash(message_data).subarray(0, 16)
  return 'mh:' + zc.nacl.to_hex(hash)


class zc.CurveCrypto

  constructor: ->
    @last_nonce = zc.nacl.crypto_box_random_nonce()

  nonce: ->
    now = zc.nacl.encode_latin1(""+Date.now())
    new_nonce = zc.nacl.crypto_hash(zc.u8cat(@last_nonce, now))
    @last_nonce = new_nonce
    return new_nonce.subarray(0, zc.NONCE_SIZE)

  encrypt: (message, sender_b64, recipient_pub_b64) ->
    sender = zc.secret_key(sender_b64)
    recipient_pub = zc.public_key(recipient_pub_b64)
    nonce = @nonce()
    plain = zc.nacl.encode_utf8(message)
    ciphertext = zc.nacl.crypto_box(plain, nonce, recipient_pub, sender)
    encrypted = new Uint8Array(nonce.byteLength + ciphertext.byteLength)
    encrypted.set(nonce, 0)
    encrypted.set(ciphertext, nonce.byteLength)
    return zc.encode_message(encrypted)

  decrypt: (encrypted_b64, sender_pub_b64, recipient_b64) ->
    encrypted = zc.decode_message(encrypted_b64)
    nonce = encrypted.subarray(0, zc.NONCE_SIZE)
    ciphertext = encrypted.subarray(zc.NONCE_SIZE)
    sender_pub = zc.public_key(sender_pub_b64)
    recipient = zc.secret_key(recipient_b64)
    try
      plain = zc.nacl.crypto_box_open(ciphertext, nonce, sender_pub, recipient)
    catch e
      return null
    return zc.nacl.decode_utf8(plain)

  secret_encrypt: (message, key_b64) ->
    key = zc.secret_key(key_b64)
    nonce = @nonce()
    plain = zc.nacl.encode_utf8(message)
    ciphertext = zc.nacl.crypto_secretbox(plain, nonce, key)
    encrypted = new Uint8Array(nonce.byteLength + ciphertext.byteLength)
    encrypted.set(nonce, 0)
    encrypted.set(ciphertext, nonce.byteLength)
    return zc.encode_secret(encrypted)

  secret_decrypt: (encrypted_b64, key_b64) ->
    encrypted = zc.decode_secret(encrypted_b64)
    nonce = encrypted.subarray(0, zc.NONCE_SIZE)
    ciphertext = encrypted.subarray(zc.NONCE_SIZE)
    key = zc.secret_key(key_b64)
    try
      plain = zc.nacl.crypto_secretbox_open(ciphertext, nonce, key)
    catch e
      return null
    return zc.nacl.decode_utf8(plain)

  derive_pubkey: (secret_b64) ->
    secret = zc.secret_key(secret_b64)
    pubkey = zc.nacl.crypto_box_keypair_from_raw_sk(secret).boxPk
    return zc.encode_public_key(pubkey)


zc.curve = new zc.CurveCrypto()
