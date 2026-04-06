use reqwest::Client;
use serde_json::Value;
use std::io::{BufRead, BufReader, Write};
use std::net::TcpListener;

/// Generic OAuth2 authorization code flow
/// Returns { "access_token": "...", "refresh_token": "...", "expires_in": ... }
pub async fn oauth2_authorize(
    auth_url: &str,
    token_url: &str,
    client_id: &str,
    client_secret: &str,
    scopes: &str,
    redirect_uri: &str,
) -> Result<Value, String> {
    let full_auth_url = format!(
        "{}?client_id={}&response_type=code&redirect_uri={}&scope={}",
        auth_url,
        urlencoding::encode(client_id),
        urlencoding::encode(redirect_uri),
        urlencoding::encode(scopes)
    );

    // Open browser
    open::that(&full_auth_url).map_err(|e| format!("Failed to open browser: {}", e))?;

    // Listen for callback
    let listener = TcpListener::bind("127.0.0.1:8080").map_err(|e| format!("Failed to bind: {}", e))?;
    listener.set_nonblocking(false).ok();

    let (mut stream, _) = listener.accept().map_err(|e| format!("Accept failed: {}", e))?;
    let mut reader = BufReader::new(&stream);
    let mut request_line = String::new();
    reader.read_line(&mut request_line).map_err(|e| e.to_string())?;

    // Extract code from GET /callback?code=XXX
    let code = request_line
        .split_whitespace()
        .nth(1)
        .and_then(|path| {
            url::Url::parse(&format!("http://localhost{}", path)).ok()
        })
        .and_then(|url| {
            url.query_pairs()
                .find(|(k, _)| k == "code")
                .map(|(_, v)| v.to_string())
        })
        .ok_or("No authorization code in callback")?;

    // Send success response to browser
    let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n<html><body><h1>Authorization successful!</h1><p>You can close this window.</p></body></html>";
    stream.write_all(response.as_bytes()).ok();
    drop(stream);
    drop(listener);

    // Exchange code for tokens
    let client = Client::new();
    let resp = client
        .post(token_url)
        .form(&[
            ("grant_type", "authorization_code"),
            ("code", &code),
            ("redirect_uri", redirect_uri),
            ("client_id", client_id),
            ("client_secret", client_secret),
        ])
        .send()
        .await
        .map_err(|e| e.to_string())?;

    let body: Value = resp.json().await.map_err(|e| e.to_string())?;

    if body.get("access_token").is_some() {
        Ok(body)
    } else {
        Err(format!("Token exchange failed: {}", body))
    }
}
