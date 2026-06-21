//! KALLAX bridge — base64 codec helpers (跟 napi-rs 0 dep 原则 联合).
//!
//! RFC 4648 encoder + decoder used by [`SqlValue::Blob`] so binary columns
//! can survive the JSON IPC boundary. Implementation is stdlib-free so the
//! bridge crate does not introduce a new dependency.

/// Minimal RFC 4648 base64 encoder.
pub fn base64_encode(bytes: &[u8]) -> String {
    const ALPHABET: &[u8; 64] =
        b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut out = String::with_capacity(((bytes.len() + 2) / 3) * 4);
    let mut i = 0;
    while i + 3 <= bytes.len() {
        let n = ((bytes[i] as u32) << 16) | ((bytes[i + 1] as u32) << 8) | (bytes[i + 2] as u32);
        out.push(ALPHABET[((n >> 18) & 0x3F) as usize] as char);
        out.push(ALPHABET[((n >> 12) & 0x3F) as usize] as char);
        out.push(ALPHABET[((n >> 6) & 0x3F) as usize] as char);
        out.push(ALPHABET[(n & 0x3F) as usize] as char);
        i += 3;
    }
    let rem = bytes.len() - i;
    if rem == 1 {
        let n = (bytes[i] as u32) << 16;
        out.push(ALPHABET[((n >> 18) & 0x3F) as usize] as char);
        out.push(ALPHABET[((n >> 12) & 0x3F) as usize] as char);
        out.push('=');
        out.push('=');
    } else if rem == 2 {
        let n = ((bytes[i] as u32) << 16) | ((bytes[i + 1] as u32) << 8);
        out.push(ALPHABET[((n >> 18) & 0x3F) as usize] as char);
        out.push(ALPHABET[((n >> 12) & 0x3F) as usize] as char);
        out.push(ALPHABET[((n >> 6) & 0x3F) as usize] as char);
        out.push('=');
    }
    out
}

/// Error type for base64 decoding failures.
#[derive(Debug)]
pub struct Base64DecodeError(pub String);

impl std::fmt::Display for Base64DecodeError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "invalid base64: {}", self.0)
    }
}

impl std::error::Error for Base64DecodeError {}

/// Minimal RFC 4648 base64 decoder.
pub fn base64_decode(s: &str) -> std::result::Result<Vec<u8>, Base64DecodeError> {
    fn val(c: u8) -> std::result::Result<u8, Base64DecodeError> {
        match c {
            b'A'..=b'Z' => Ok(c - b'A'),
            b'a'..=b'z' => Ok(c - b'a' + 26),
            b'0'..=b'9' => Ok(c - b'0' + 52),
            b'+' => Ok(62),
            b'/' => Ok(63),
            other => Err(Base64DecodeError(format!(
                "unexpected character '{}'",
                other as char
            ))),
        }
    }
    let bytes = s.as_bytes();
    if bytes.len() % 4 != 0 {
        return Err(Base64DecodeError("length not multiple of 4".into()));
    }
    let mut out = Vec::with_capacity(bytes.len() / 4 * 3);
    let mut i = 0;
    while i < bytes.len() {
        let a = val(bytes[i])?;
        let b = val(bytes[i + 1])?;
        let c_raw = bytes[i + 2];
        let d_raw = bytes[i + 3];
        out.push((a << 2) | (b >> 4));
        if c_raw != b'=' {
            let c = val(c_raw)?;
            out.push(((b & 0x0F) << 4) | (c >> 2));
            if d_raw != b'=' {
                let d = val(d_raw)?;
                out.push(((c & 0x03) << 6) | d);
            }
        }
        i += 4;
    }
    Ok(out)
}

#[cfg(test)]
#[allow(clippy::unwrap_used, clippy::expect_used)]
mod tests {
    use super::*;

    #[test]
    fn encodes_known_vector() {
        assert_eq!(base64_encode(b""), "");
        assert_eq!(base64_encode(b"f"), "Zg==");
        assert_eq!(base64_encode(b"fo"), "Zm8=");
        assert_eq!(base64_encode(b"foo"), "Zm9v");
        assert_eq!(base64_encode(b"foob"), "Zm9vYg==");
        assert_eq!(base64_encode(b"fooba"), "Zm9vYmE=");
        assert_eq!(base64_encode(b"foobar"), "Zm9vYmFy");
    }

    #[test]
    fn roundtrip() {
        for original in [
            b"".to_vec(),
            b"foo".to_vec(),
            b"hello world".to_vec(),
            b"\x00\xff\x10".to_vec(),
        ] {
            let encoded = base64_encode(&original);
            let decoded = base64_decode(&encoded).expect("decode");
            assert_eq!(decoded, original);
        }
    }
}