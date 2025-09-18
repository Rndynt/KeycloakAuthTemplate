const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');

const app = express();
const PORT = 4000;

app.use(cors());
app.use(express.json());
app.use(express.static(__dirname));

// JWKS client for token verification
const client = jwksClient({
  jwksUri: `${process.env.KEYCLOAK_URL || 'http://localhost:8080'}/realms/${process.env.REALM || 'event-platform-organizations'}/protocol/openid-connect/certs`
});

function getKey(header, callback) {
  client.getSigningKey(header.kid, (err, key) => {
    const signingKey = key.publicKey || key.rsaPublicKey;
    callback(null, signingKey);
  });
}

// Device verification page
app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>IoT Device Verification</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .success { color: #28a745; background: #d4edda; padding: 20px; border-radius: 5px; }
        .error { color: #dc3545; background: #f8d7da; padding: 20px; border-radius: 5px; }
        .info { color: #0c5460; background: #d1ecf1; padding: 20px; border-radius: 5px; }
        .token-info { background: #f8f9fa; padding: 15px; margin: 10px 0; border-radius: 3px; font-family: monospace; font-size: 12px; }
        button { background: #007bff; color: white; padding: 10px 20px; border: none; border-radius: 3px; cursor: pointer; }
        button:hover { background: #0056b3; }
      </style>
    </head>
    <body>
      <h1>🔗 IoT Device Verification</h1>
      <p>This server demonstrates device authorization grant (RFC 8628) token validation for IoT devices.</p>
      
      <div class="info">
        <strong>Device Flow Test:</strong> Send a POST request to <code>/verify</code> with your device access token in the Authorization header.
      </div>
      
      <h2>Test Device Token</h2>
      <form id="tokenForm">
        <textarea id="tokenInput" placeholder="Paste your access token here..." style="width: 100%; height: 100px;"></textarea><br><br>
        <button type="submit">Verify Token</button>
      </form>
      
      <div id="result"></div>
      
      <h2>cURL Example</h2>
      <div class="token-info">
curl -X POST http://localhost:${PORT}/verify \\
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \\
  -H "Content-Type: application/json"
      </div>
      
      <script>
        document.getElementById('tokenForm').addEventListener('submit', async (e) => {
          e.preventDefault();
          const token = document.getElementById('tokenInput').value.trim();
          const resultDiv = document.getElementById('result');
          
          if (!token) {
            resultDiv.innerHTML = '<div class="error">Please enter a token</div>';
            return;
          }
          
          try {
            const response = await fetch('/verify', {
              method: 'POST',
              headers: {
                'Authorization': 'Bearer ' + token,
                'Content-Type': 'application/json'
              }
            });
            
            const data = await response.json();
            
            if (response.ok) {
              resultDiv.innerHTML = \`
                <div class="success">
                  <h3>✅ Token Valid!</h3>
                  <div class="token-info">
                    <strong>User:</strong> \${data.user.sub}<br>
                    <strong>Organization:</strong> \${data.user.organization || 'N/A'}<br>
                    <strong>Org ID:</strong> \${data.user.org_id || 'N/A'}<br>
                    <strong>Issued At:</strong> \${new Date(data.user.iat * 1000).toISOString()}<br>
                    <strong>Expires At:</strong> \${new Date(data.user.exp * 1000).toISOString()}<br>
                    <strong>Audience:</strong> \${data.user.aud}<br>
                    <strong>Scopes:</strong> \${data.user.scope || 'N/A'}
                  </div>
                </div>
              \`;
            } else {
              resultDiv.innerHTML = \`<div class="error"><h3>❌ Token Invalid</h3><p>\${data.error}</p></div>\`;
            }
          } catch (error) {
            resultDiv.innerHTML = \`<div class="error"><h3>❌ Error</h3><p>\${error.message}</p></div>\`;
          }
        });
      </script>
    </body>
    </html>
  `);
});

// Token verification endpoint
app.post('/verify', (req, res) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid Authorization header' });
  }
  
  const token = authHeader.substring(7);
  
  jwt.verify(token, getKey, {
    audience: ['event-platform-backend', 'event-platform-web', 'device-bootstrap'],
    issuer: `${process.env.KEYCLOAK_URL || 'http://localhost:8080'}/realms/${process.env.REALM || 'event-platform-organizations'}`,
    algorithms: ['RS256', 'ES256', 'EdDSA']
  }, (err, decoded) => {
    if (err) {
      console.error('Token verification failed:', err.message);
      return res.status(401).json({ 
        error: 'Token verification failed', 
        details: err.message 
      });
    }
    
    // Validate organization claims for multi-tenant scenarios
    if (decoded.organization && decoded.org_id) {
      console.log(`Device authenticated for organization: ${decoded.organization} (${decoded.org_id})`);
    }
    
    res.json({
      status: 'success',
      message: 'Device token is valid',
      user: {
        sub: decoded.sub,
        organization: decoded.organization,
        org_id: decoded.org_id,
        iat: decoded.iat,
        exp: decoded.exp,
        aud: decoded.aud,
        scope: decoded.scope,
        client_id: decoded.azp || decoded.client_id
      },
      deviceInfo: {
        verified: true,
        timestamp: new Date().toISOString()
      }
    });
  });
});

// Protected API endpoint for testing
app.get('/protected', (req, res) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid Authorization header' });
  }
  
  const token = authHeader.substring(7);
  
  jwt.verify(token, getKey, {
    audience: ['event-platform-backend', 'event-platform-web', 'device-bootstrap'],
    issuer: `${process.env.KEYCLOAK_URL || 'http://localhost:8080'}/realms/${process.env.REALM || 'event-platform-organizations'}`,
    algorithms: ['RS256', 'ES256', 'EdDSA']
  }, (err, decoded) => {
    if (err) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    
    res.json({
      message: 'Access granted to protected resource',
      user: decoded.sub,
      organization: decoded.organization,
      timestamp: new Date().toISOString()
    });
  });
});

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    service: 'Device Verification Server',
    timestamp: new Date().toISOString()
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🔗 Device Verification Server running on port ${PORT}`);
  console.log(`🌐 Access at http://localhost:${PORT}`);
  console.log(`🔍 Keycloak URL: ${process.env.KEYCLOAK_URL || 'http://localhost:8080'}`);
  console.log(`📋 Realm: ${process.env.REALM || 'event-platform-organizations'}`);
});