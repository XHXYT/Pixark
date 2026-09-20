use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::{Arc, Mutex, OnceLock};
use std::time::Duration;

use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine;
use napi_derive_ohos::napi;
use napi_ohos::bindgen_prelude::*;
use reqwest::redirect::Policy;
use reqwest::{Client, Method, Url};
use rustls::client::{EchConfig, EchMode};
use rustls::crypto::aws_lc_rs::hpke::ALL_SUPPORTED_SUITES;
use rustls::pki_types::EchConfigListBytes;
use rustls::RootCertStore;

/// 进程级安装 aws-lc-rs CryptoProvider（reqwest 0.12 + 预配置 rustls 配置需要进程默认 provider）
fn ensure_provider() {
  static INIT: OnceLock<()> = OnceLock::new();
  INIT.get_or_init(|| {
    let _ = rustls::crypto::aws_lc_rs::default_provider().install_default();
  });
}

/// 客户端缓存：key = host|connect_ip|ech_config_b64
/// ech 配置轮换后 key 变化，自然构建新客户端；超过上限时整体清空
fn client_cache() -> &'static Mutex<HashMap<String, Client>> {
  static CACHE: OnceLock<Mutex<HashMap<String, Client>>> = OnceLock::new();
  CACHE.get_or_init(|| Mutex::new(HashMap::new()))
}

const CONNECT_TIMEOUT_SECS: u64 = 15;
const DEFAULT_TIMEOUT_MS: u64 = 30_000;
const MAX_CACHED_CLIENTS: usize = 8;

#[napi(object)]
pub struct EchHeader {
  pub name: String,
  pub value: String,
}

#[napi(object)]
pub struct EchResponse {
  pub status: u16,
  pub headers: Vec<EchHeader>,
  /// 响应体原始字节
  pub body: Uint8Array,
}

#[napi(object)]
pub struct EchFetchOptions {
  /// HTTP 方法，默认 GET
  pub method: Option<String>,
  /// 请求头
  pub headers: Option<Vec<EchHeader>>,
  /// 请求体（POST 等）
  pub body: Option<Uint8Array>,
  /// 整体超时毫秒数，默认 30000
  pub timeout_ms: Option<u32>,
}

fn build_client(host: &str, addr: SocketAddr, ech_config_b64: &str) -> Result<Client> {
  ensure_provider();
  let raw = BASE64
    .decode(ech_config_b64)
    .map_err(|e| Error::new(Status::InvalidArg, format!("ech config base64 decode failed: {e}")))?;
  let ech_config = EchConfig::new(EchConfigListBytes::from(raw), ALL_SUPPORTED_SUITES)
    .map_err(|e| Error::new(Status::InvalidArg, format!("ech config parse failed: {e:?}")))?;

  let mut roots = RootCertStore::empty();
  roots.extend(webpki_roots::TLS_SERVER_ROOTS.iter().cloned());

  let provider = Arc::new(rustls::crypto::aws_lc_rs::default_provider());
  let tls = rustls::ClientConfig::builder_with_provider(provider)
    .with_ech(EchMode::from(ech_config))
    .map_err(|e| Error::new(Status::GenericFailure, format!("ech setup failed: {e:?}")))?
    .with_root_certificates(roots)
    .with_no_client_auth();

  Client::builder()
    .use_preconfigured_tls(tls)
    .resolve(host, addr)
    .redirect(Policy::none())
    .connect_timeout(Duration::from_secs(CONNECT_TIMEOUT_SECS))
    .build()
    .map_err(|e| Error::new(Status::GenericFailure, format!("http client build failed: {e}")))
}

fn parse_connect_ip(connect_ip: &str) -> Result<SocketAddr> {
  if let Ok(a) = connect_ip.parse::<SocketAddr>() {
    return Ok(a);
  }
  format!("{connect_ip}:443")
    .parse::<SocketAddr>()
    .map_err(|_| Error::new(Status::InvalidArg, format!("invalid connect_ip: {connect_ip}")))
}

/// ECH 直连请求：对指定 URL 以 ECH 方式 TLS 握手，TCP 层连接 connect_ip。
/// ech_config_b64 为 cloudflare-ech.com HTTPS RR 中 ech="..." 的 base64 内容。
#[napi]
pub async fn ech_fetch(
  url: String,
  connect_ip: String,
  ech_config_b64: String,
  options: Option<EchFetchOptions>,
) -> Result<EchResponse> {
  let parsed = Url::parse(&url)
    .map_err(|e| Error::new(Status::InvalidArg, format!("invalid url: {e}")))?;
  if parsed.scheme() != "https" {
    return Err(Error::new(Status::InvalidArg, "only https urls are supported"));
  }
  let host = parsed
    .host_str()
    .ok_or_else(|| Error::new(Status::InvalidArg, "url has no host"))?
    .to_string();
  let addr = parse_connect_ip(&connect_ip)?;

  let key = format!("{host}|{connect_ip}|{ech_config_b64}");
  let client = {
    let mut cache = client_cache().lock().unwrap();
    if let Some(c) = cache.get(&key) {
      c.clone()
    } else {
      let c = build_client(&host, addr, &ech_config_b64)?;
      if cache.len() >= MAX_CACHED_CLIENTS {
        cache.clear();
      }
      cache.insert(key, c.clone());
      c
    }
  };

  let opts = options.unwrap_or(EchFetchOptions {
    method: None,
    headers: None,
    body: None,
    timeout_ms: None,
  });
  let method_str = opts
    .method
    .clone()
    .unwrap_or_else(|| "GET".to_string())
    .to_ascii_uppercase();
  let method = Method::from_bytes(method_str.as_bytes())
    .map_err(|e| Error::new(Status::InvalidArg, format!("invalid method: {e}")))?;

  let mut req = client.request(method, parsed);
  req = req.timeout(Duration::from_millis(
    opts.timeout_ms.unwrap_or(DEFAULT_TIMEOUT_MS as u32) as u64,
  ));
  if let Some(body) = opts.body {
    req = req.body(body.as_ref().to_vec());
  }
  if let Some(headers) = &opts.headers {
    for h in headers {
      req = req.header(&h.name, &h.value);
    }
  }

  let resp = req
    .send()
    .await
    .map_err(|e| Error::new(Status::GenericFailure, format!("ech request failed: {e}")))?;
  let status = resp.status().as_u16();
  let headers: Vec<EchHeader> = resp
    .headers()
    .iter()
    .map(|(k, v)| EchHeader {
      name: k.as_str().to_string(),
      value: String::from_utf8_lossy(v.as_bytes()).into_owned(),
    })
    .collect();
  let body = resp
    .bytes()
    .await
    .map_err(|e| Error::new(Status::GenericFailure, format!("ech response read failed: {e}")))?;

  Ok(EchResponse {
    status,
    headers,
    body: Uint8Array::from(body.to_vec()),
  })
}
