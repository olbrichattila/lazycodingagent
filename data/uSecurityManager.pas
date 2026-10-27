unit uSecurityManager;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils;

const
  LCA_SECRET_BLOB_PREFIX = 'lca-sec:v1:';

function IsEncryptedSecretBlob(const AValue: string): Boolean;
function EncryptSecret(const APlaintext: string): string;
function DecryptSecret(const AStored: string): string;

implementation

uses
  Classes, base64, sha1, openssl;

const
  LCA_DATA_KEY_SALT = 'LazyCodingAgent-data-v1';
  LCA_GCM_NONCE_LEN = 12;
  LCA_GCM_TAG_LEN = 16;
  EVP_CTRL_GCM_SET_IVLEN = 9;
  EVP_CTRL_GCM_GET_TAG = 16;
  EVP_CTRL_GCM_SET_TAG = 17;

{$I uAppBuiltInKey.inc}

function EnsureCryptoReady: Boolean;
begin
  Result := InitSSLInterface;
  if Result then
    OPENSSLaddallalgorithms;
end;

function BuiltInKeyMaterial: TBytes;
var
  I: Integer;
begin
  SetLength(Result, 32);
  for I := 0 to 15 do
    Result[I] := LCA_KEY_PART_A[I] xor LCA_KEY_XOR_MASK;
  for I := 0 to 15 do
    Result[I + 16] := LCA_KEY_PART_B[I] xor LCA_KEY_XOR_MASK;
end;

function DerivedAesKey: TBytes;
var
  Mat: TBytes;
  S, Raw: AnsiString;
  D1, D2: TSHA1Digest;
begin
  Mat := BuiltInKeyMaterial;
  SetLength(Raw, Length(Mat));
  if Length(Mat) > 0 then
    Move(Mat[0], Raw[1], Length(Mat));
  S := Raw + AnsiString(LCA_DATA_KEY_SALT);
  D1 := SHA1Buffer(S[1], Length(S));
  SetLength(S, Length(S) + SizeOf(D1));
  Move(D1[0], S[Length(S) - SizeOf(D1) + 1], SizeOf(D1));
  D2 := SHA1Buffer(S[1], Length(S));
  SetLength(Result, 32);
  Move(D1[0], Result[0], SizeOf(D1));
  Move(D2[0], Result[SizeOf(D1)], 12);
end;

function BytesToBase64(const B: TBytes): string;
var
  S: AnsiString;
begin
  if Length(B) = 0 then
    Exit('');
  SetLength(S, Length(B));
  Move(B[0], S[1], Length(B));
  Result := EncodeStringBase64(S);
end;

function Base64ToBytes(const S: string): TBytes;
var
  Dec: AnsiString;
  I: Integer;
begin
  Dec := DecodeStringBase64(AnsiString(S));
  SetLength(Result, Length(Dec));
  for I := 1 to Length(Dec) do
    Result[I - 1] := Ord(Dec[I]);
end;

function IsEncryptedSecretBlob(const AValue: string): Boolean;
begin
  Result := Copy(AValue, 1, Length(LCA_SECRET_BLOB_PREFIX)) = LCA_SECRET_BLOB_PREFIX;
end;

function EncryptSecret(const APlaintext: string): string;
var
  Key, Nonce, OutBuf, Blob: TBytes;
  Ctx: EVP_CIPHER_CTX;
  Cipher: PEVP_CIPHER;
  OutLen, FinalLen: Integer;
  RC: Integer;
  Tag: array[0..LCA_GCM_TAG_LEN - 1] of Byte;
  PlainUtf8: UTF8String;
  I: Integer;
begin
  if Trim(APlaintext) = '' then
    Exit('');
  if not EnsureCryptoReady then
    raise Exception.Create('Encryption requires OpenSSL (libcrypto).');
  Cipher := EVP_get_cipherbyname('aes-256-gcm');
  if Cipher = nil then
    raise Exception.Create('AES-256-GCM is not available in OpenSSL.');
  Key := DerivedAesKey;
  SetLength(Nonce, LCA_GCM_NONCE_LEN);
  if RAND_bytes(@Nonce[0], LCA_GCM_NONCE_LEN) <> 1 then
    raise Exception.Create('Failed to generate encryption nonce.');
  FillChar(Ctx, SizeOf(Ctx), 0);
  EVP_CIPHER_CTX_init(@Ctx);
  try
    RC := EVP_EncryptInit(@Ctx, Cipher, @Key[0], @Nonce[0]);
    if RC <> 1 then
      raise Exception.Create('EVP_EncryptInit failed.');
    PlainUtf8 := UTF8Encode(APlaintext);
    SetLength(OutBuf, Length(PlainUtf8) + 32);
    OutLen := 0;
    if Length(PlainUtf8) > 0 then
      RC := EVP_EncryptUpdate(@Ctx, @OutBuf[0], @OutLen, PByte(PlainUtf8), Length(PlainUtf8))
    else
      RC := 1;
    if RC <> 1 then
      raise Exception.Create('EVP_EncryptUpdate failed.');
    FinalLen := 0;
    RC := EVP_EncryptFinal(@Ctx, @OutBuf[OutLen], @FinalLen);
    if RC <> 1 then
      raise Exception.Create('EVP_EncryptFinal failed.');
    SetLength(OutBuf, OutLen + FinalLen);
    if EVP_CIPHER_CTX_ctrl(@Ctx, EVP_CTRL_GCM_GET_TAG, LCA_GCM_TAG_LEN, @Tag[0]) <> 1 then
      raise Exception.Create('EVP_CTRL_GCM_GET_TAG failed.');
    SetLength(Blob, LCA_GCM_NONCE_LEN + Length(OutBuf) + LCA_GCM_TAG_LEN);
    for I := 0 to LCA_GCM_NONCE_LEN - 1 do
      Blob[I] := Nonce[I];
    if Length(OutBuf) > 0 then
      Move(OutBuf[0], Blob[LCA_GCM_NONCE_LEN], Length(OutBuf));
    Move(Tag[0], Blob[LCA_GCM_NONCE_LEN + Length(OutBuf)], LCA_GCM_TAG_LEN);
    Result := LCA_SECRET_BLOB_PREFIX + BytesToBase64(Blob);
  finally
    EVP_CIPHER_CTX_cleanup(@Ctx);
  end;
end;

function DecryptSecret(const AStored: string): string;
var
  Key, Blob, Nonce, CipherBytes, Plain: TBytes;
  Ctx: EVP_CIPHER_CTX;
  Cipher: PEVP_CIPHER;
  OutLen, FinalLen: Integer;
  RC: Integer;
  Tag: array[0..LCA_GCM_TAG_LEN - 1] of Byte;
  Payload: string;
  CipherLen: Integer;
  RS: RawByteString;
begin
  if Trim(AStored) = '' then
    Exit('');
  if not IsEncryptedSecretBlob(AStored) then
    Exit(AStored);
  if not EnsureCryptoReady then
    raise Exception.Create('Decryption requires OpenSSL (libcrypto).');
  Cipher := EVP_get_cipherbyname('aes-256-gcm');
  if Cipher = nil then
    raise Exception.Create('AES-256-GCM is not available in OpenSSL.');
  Payload := Copy(AStored, Length(LCA_SECRET_BLOB_PREFIX) + 1, MaxInt);
  Blob := Base64ToBytes(Payload);
  if Length(Blob) < LCA_GCM_NONCE_LEN + LCA_GCM_TAG_LEN then
    raise Exception.Create('Invalid encrypted secret blob.');
  CipherLen := Length(Blob) - LCA_GCM_NONCE_LEN - LCA_GCM_TAG_LEN;
  SetLength(Nonce, LCA_GCM_NONCE_LEN);
  Move(Blob[0], Nonce[0], LCA_GCM_NONCE_LEN);
  SetLength(CipherBytes, CipherLen);
  if CipherLen > 0 then
    Move(Blob[LCA_GCM_NONCE_LEN], CipherBytes[0], CipherLen);
  Move(Blob[LCA_GCM_NONCE_LEN + CipherLen], Tag[0], LCA_GCM_TAG_LEN);
  Key := DerivedAesKey;
  FillChar(Ctx, SizeOf(Ctx), 0);
  EVP_CIPHER_CTX_init(@Ctx);
  try
    RC := EVP_DecryptInit(@Ctx, Cipher, @Key[0], @Nonce[0]);
    if RC <> 1 then
      raise Exception.Create('EVP_DecryptInit failed.');
    SetLength(Plain, CipherLen + 32);
    OutLen := 0;
    if CipherLen > 0 then
    begin
      RC := EVP_DecryptUpdate(@Ctx, @Plain[0], @OutLen, @CipherBytes[0], CipherLen);
      if RC <> 1 then
        raise Exception.Create('EVP_DecryptUpdate failed.');
    end;
    if EVP_CIPHER_CTX_ctrl(@Ctx, EVP_CTRL_GCM_SET_TAG, LCA_GCM_TAG_LEN, @Tag[0]) <> 1 then
      raise Exception.Create('EVP_CTRL_GCM_SET_TAG failed.');
    FinalLen := 0;
    RC := EVP_DecryptFinal(@Ctx, @Plain[OutLen], @FinalLen);
    if RC <> 1 then
      raise Exception.Create('Secret decryption failed (tampered or wrong key).');
    SetLength(Plain, OutLen + FinalLen);
    if Length(Plain) = 0 then
      Result := ''
    else
    begin
      SetLength(RS, Length(Plain));
      Move(Plain[0], RS[1], Length(Plain));
      Result := UTF8ToString(RS);
    end;
  finally
    EVP_CIPHER_CTX_cleanup(@Ctx);
  end;
end;

end.
