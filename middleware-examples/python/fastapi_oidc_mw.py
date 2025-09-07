"""
FastAPI OIDC Middleware for Keycloak Authentication

This middleware validates JWT tokens from Keycloak using the JWKS endpoint.
It supports token validation, role checking, and user context injection.
"""

import asyncio
import time
from typing import List, Optional, Dict, Any
import httpx
from fastapi import HTTPException, Security, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError, jwk
from jose.utils import base64url_decode
import os
from functools import lru_cache

class KeycloakOIDCMiddleware:
    def __init__(
        self,
        keycloak_url: str = None,
        realm: str = None,
        client_id: str = None,
        jwks_cache_ttl: int = 300  # 5 minutes
    ):
        self.keycloak_url = keycloak_url or os.getenv('KEYCLOAK_URL', 'http://localhost:8080')
        self.realm = realm or os.getenv('PROJECT_REALM', 'project-realm')
        self.client_id = client_id or os.getenv('PROJECT_WEB_CLIENT_ID', 'project-web')
        self.jwks_cache_ttl = jwks_cache_ttl
        self.oidc_config = None
        self.jwks_keys = {}
        self.jwks_last_fetch = 0
        self.security = HTTPBearer(auto_error=False)
        
        # Initialize async
        asyncio.create_task(self.init())
    
    async def init(self):
        """Initialize OIDC configuration"""
        try:
            config_url = f"{self.keycloak_url}/realms/{self.realm}/.well-known/openid-configuration"
            
            async with httpx.AsyncClient() as client:
                response = await client.get(config_url)
                response.raise_for_status()
                self.oidc_config = response.json()
            
            print("✅ Keycloak OIDC middleware initialized")
        except Exception as error:
            print(f"❌ Failed to initialize Keycloak OIDC middleware: {error}")
            raise error
    
    async def get_jwks_keys(self) -> Dict[str, Any]:
        """Fetch and cache JWKS keys"""
        current_time = time.time()
        
        if (current_time - self.jwks_last_fetch) > self.jwks_cache_ttl:
            try:
                async with httpx.AsyncClient() as client:
                    response = await client.get(self.oidc_config['jwks_uri'])
                    response.raise_for_status()
                    jwks_data = response.json()
                
                # Convert keys to usable format
                self.jwks_keys = {}
                for key_data in jwks_data['keys']:
                    kid = key_data['kid']
                    self.jwks_keys[kid] = jwk.construct(key_data)
                
                self.jwks_last_fetch = current_time
                print("🔄 JWKS keys refreshed")
                
            except Exception as error:
                print(f"❌ Failed to fetch JWKS keys: {error}")
                if not self.jwks_keys:  # If no cached keys available
                    raise error
        
        return self.jwks_keys
    
    async def validate_token(self, token: str) -> Dict[str, Any]:
        """Validate JWT token"""
        try:
            # Decode header to get kid
            unverified_header = jwt.get_unverified_header(token)
            kid = unverified_header.get('kid')
            
            if not kid:
                raise JWTError("Token missing 'kid' in header")
            
            # Get signing key
            jwks_keys = await self.get_jwks_keys()
            
            if kid not in jwks_keys:
                raise JWTError(f"Unable to find key '{kid}' in JWKS")
            
            key = jwks_keys[kid]
            
            # Verify token
            payload = jwt.decode(
                token,
                key,
                algorithms=['RS256'],
                audience=self.client_id,
                issuer=self.oidc_config['issuer']
            )
            
            return payload
            
        except JWTError as error:
            raise HTTPException(
                status_code=401,
                detail=f"Token validation failed: {str(error)}"
            )
    
    def has_role(self, user_payload: Dict[str, Any], required_roles: List[str]) -> bool:
        """Check if user has required roles"""
        if not required_roles:
            return True
        
        user_roles = user_payload.get('realm_access', {}).get('roles', [])
        return any(role in user_roles for role in required_roles)
    
    async def get_current_user(
        self,
        credentials: Optional[HTTPAuthorizationCredentials] = Security(HTTPBearer(auto_error=False))
    ) -> Optional[Dict[str, Any]]:
        """Extract and validate user from token"""
        if not credentials:
            return None
        
        try:
            payload = await self.validate_token(credentials.credentials)
            
            return {
                'id': payload.get('sub'),
                'username': payload.get('preferred_username'),
                'email': payload.get('email'),
                'name': payload.get('name'),
                'roles': payload.get('realm_access', {}).get('roles', []),
                'client_roles': payload.get('resource_access', {}),
                'token_payload': payload
            }
        except HTTPException:
            return None
    
    def require_auth(self):
        """Dependency that requires authentication"""
        async def _require_auth(
            credentials: HTTPAuthorizationCredentials = Security(self.security)
        ) -> Dict[str, Any]:
            if not credentials:
                raise HTTPException(
                    status_code=401,
                    detail="Authentication required"
                )
            
            payload = await self.validate_token(credentials.credentials)
            
            return {
                'id': payload.get('sub'),
                'username': payload.get('preferred_username'),
                'email': payload.get('email'),
                'name': payload.get('name'),
                'roles': payload.get('realm_access', {}).get('roles', []),
                'client_roles': payload.get('resource_access', {}),
                'token_payload': payload
            }
        
        return _require_auth
    
    def require_roles(self, required_roles: List[str]):
        """Dependency that requires specific roles"""
        async def _require_roles(
            current_user: Dict[str, Any] = Depends(self.require_auth())
        ) -> Dict[str, Any]:
            if not self.has_role(current_user['token_payload'], required_roles):
                raise HTTPException(
                    status_code=403,
                    detail=f"Access denied. Required roles: {', '.join(required_roles)}"
                )
            
            return current_user
        
        return _require_roles
    
    def optional_auth(self):
        """Dependency for optional authentication"""
        return self.get_current_user


# Example FastAPI application
def create_example_app():
    from fastapi import FastAPI, Depends
    
    app = FastAPI(title="Keycloak Auth Example")
    
    # Initialize middleware
    keycloak_auth = KeycloakOIDCMiddleware(
        keycloak_url='http://localhost:8080',
        realm='project-realm',
        client_id='project-web'
    )
    
    @app.get("/api/public")
    async def public_endpoint():
        return {"message": "This is a public endpoint"}
    
    @app.get("/api/protected")
    async def protected_endpoint(
        current_user: Dict[str, Any] = Depends(keycloak_auth.require_auth())
    ):
        return {
            "message": "This is a protected endpoint",
            "user": current_user
        }
    
    @app.get("/api/admin")
    async def admin_endpoint(
        current_user: Dict[str, Any] = Depends(keycloak_auth.require_roles(['admin']))
    ):
        return {
            "message": "This is an admin-only endpoint",
            "user": current_user
        }
    
    @app.get("/api/optional")
    async def optional_endpoint(
        current_user: Optional[Dict[str, Any]] = Depends(keycloak_auth.optional_auth())
    ):
        return {
            "message": "This endpoint works with or without authentication",
            "authenticated": current_user is not None,
            "user": current_user
        }
    
    return app


# Middleware factory function
@lru_cache()
def get_keycloak_auth() -> KeycloakOIDCMiddleware:
    """Get cached instance of Keycloak auth middleware"""
    return KeycloakOIDCMiddleware()


"""
Installation:
pip install fastapi python-jose[cryptography] httpx

Usage:

from fastapi import FastAPI, Depends
from fastapi_oidc_mw import KeycloakOIDCMiddleware

app = FastAPI()
keycloak_auth = KeycloakOIDCMiddleware()

@app.get("/protected")
async def protected_route(
    user = Depends(keycloak_auth.require_auth())
):
    return {"user": user}

@app.get("/admin")
async def admin_route(
    user = Depends(keycloak_auth.require_roles(['admin']))
):
    return {"admin_user": user}
"""