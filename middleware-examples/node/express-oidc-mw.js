/**
 * Express.js OIDC Middleware for Keycloak Authentication
 * 
 * This middleware validates JWT tokens from Keycloak using the JWKS endpoint.
 * It supports token validation, role checking, and user context injection.
 */

const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');
const axios = require('axios');

class KeycloakOIDCMiddleware {
    constructor(options = {}) {
        this.keycloakUrl = options.keycloakUrl || process.env.KEYCLOAK_URL || 'http://localhost:8080';
        this.realm = options.realm || process.env.PROJECT_REALM || 'event-platform-organizations';
        this.clientId = options.clientId || process.env.PROJECT_WEB_CLIENT_ID || 'event-platform-web';
        this.jwksCache = new Map();
        this.jwksCacheTTL = options.jwksCacheTTL || 300000; // 5 minutes
        this.oidcConfig = null;
        this.jwksClient = null;
        
        this.init();
    }
    
    async init() {
        try {
            // Fetch OIDC configuration
            const configUrl = `${this.keycloakUrl}/realms/${this.realm}/.well-known/openid-configuration`;
            const response = await axios.get(configUrl);
            this.oidcConfig = response.data;
            
            // Initialize JWKS client
            this.jwksClient = jwksClient({
                jwksUri: this.oidcConfig.jwks_uri,
                requestHeaders: {},
                timeout: 30000,
                cache: true,
                cacheMaxEntries: 5,
                cacheMaxAge: this.jwksCacheTTL
            });
            
            console.log('✅ Keycloak OIDC middleware initialized');
        } catch (error) {
            console.error('❌ Failed to initialize Keycloak OIDC middleware:', error.message);
            throw error;
        }
    }
    
    /**
     * Get signing key for JWT verification
     */
    getKey = (header, callback) => {
        this.jwksClient.getSigningKey(header.kid, (err, key) => {
            if (err) {
                return callback(err);
            }
            const signingKey = key.publicKey || key.rsaPublicKey;
            callback(null, signingKey);
        });
    }
    
    /**
     * Validate JWT token
     */
    validateToken(token) {
        return new Promise((resolve, reject) => {
            jwt.verify(token, this.getKey, {
                audience: this.clientId,
                issuer: this.oidcConfig.issuer,
                algorithms: ['RS256', 'ES256', 'EdDSA']
            }, (err, decoded) => {
                if (err) {
                    reject(err);
                } else {
                    resolve(decoded);
                }
            });
        });
    }
    
    /**
     * Extract token from request
     */
    extractToken(req) {
        const authHeader = req.headers.authorization;
        
        if (authHeader && authHeader.startsWith('Bearer ')) {
            return authHeader.substring(7);
        }
        
        // Check cookie (optional)
        if (req.cookies && req.cookies.access_token) {
            return req.cookies.access_token;
        }
        
        return null;
    }
    
    /**
     * Check if user has required roles
     */
    hasRole(user, requiredRoles) {
        if (!requiredRoles || requiredRoles.length === 0) {
            return true;
        }
        
        const userRoles = user.realm_access?.roles || [];
        return requiredRoles.some(role => userRoles.includes(role));
    }
    
    /**
     * Authentication middleware
     */
    authenticate() {
        return async (req, res, next) => {
            try {
                const token = this.extractToken(req);
                
                if (!token) {
                    return res.status(401).json({
                        error: 'unauthorized',
                        message: 'No access token provided'
                    });
                }
                
                const decoded = await this.validateToken(token);
                
                // Attach user to request
                req.user = {
                    id: decoded.sub,
                    username: decoded.preferred_username,
                    email: decoded.email,
                    name: decoded.name,
                    roles: decoded.realm_access?.roles || [],
                    clientRoles: decoded.resource_access || {},
                    organization: decoded.organization,
                    org_id: decoded.org_id,
                    scopes: decoded.scope ? decoded.scope.split(' ') : [],
                    token: decoded
                };
                
                next();
            } catch (error) {
                console.error('Token validation failed:', error.message);
                return res.status(401).json({
                    error: 'invalid_token',
                    message: 'Invalid or expired token'
                });
            }
        };
    }
    
    /**
     * Authorization middleware with role checking and organization validation
     */
    authorize(requiredRoles = [], options = {}) {
        return (req, res, next) => {
            if (!req.user) {
                return res.status(401).json({
                    error: 'unauthorized',
                    message: 'Authentication required'
                });
            }
            
            // Validate organization claims if required
            if (options.requireOrganization) {
                if (!req.user.organization || !req.user.org_id) {
                    return res.status(403).json({
                        error: 'forbidden',
                        message: 'Organization context required'
                    });
                }
                
                // Check if organization matches URL parameter
                if (req.params.orgSlug && req.user.organization !== req.params.orgSlug) {
                    return res.status(403).json({
                        error: 'forbidden',
                        message: `Organization mismatch. Token: ${req.user.organization}, Request: ${req.params.orgSlug}`
                    });
                }
            }
            
            // Validate required scopes
            if (options.requiredScopes && options.requiredScopes.length > 0) {
                const hasScope = options.requiredScopes.some(scope => 
                    req.user.scopes.includes(scope)
                );
                if (!hasScope) {
                    return res.status(403).json({
                        error: 'forbidden',
                        message: `Missing required scopes: ${options.requiredScopes.join(', ')}`
                    });
                }
            }
            
            if (!this.hasRole(req.user, requiredRoles)) {
                return res.status(403).json({
                    error: 'forbidden',
                    message: `Access denied. Required roles: ${requiredRoles.join(', ')}`
                });
            }
            
            next();
        };
    }
    
    /**
     * Combined auth middleware (authenticate + authorize)
     */
    protect(requiredRoles = []) {
        return [
            this.authenticate(),
            this.authorize(requiredRoles)
        ];
    }
    
    /**
     * Optional authentication (doesn't fail if no token)
     */
    optional() {
        return async (req, res, next) => {
            try {
                const token = this.extractToken(req);
                
                if (token) {
                    const decoded = await this.validateToken(token);
                    req.user = {
                        id: decoded.sub,
                        username: decoded.preferred_username,
                        email: decoded.email,
                        name: decoded.name,
                        roles: decoded.realm_access?.roles || [],
                        clientRoles: decoded.resource_access || {},
                        token: decoded
                    };
                }
                
                next();
            } catch (error) {
                // Continue without user if token is invalid
                next();
            }
        };
    }
}

/**
 * Express app example usage
 */
function createExampleApp() {
    const express = require('express');
    const app = express();
    
    // Initialize middleware
    const keycloakAuth = new KeycloakOIDCMiddleware({
        keycloakUrl: 'http://localhost:8080',
        realm: 'project-realm',
        clientId: 'project-web'
    });
    
    app.use(express.json());
    
    // Public endpoint
    app.get('/api/public', (req, res) => {
        res.json({ message: 'This is a public endpoint' });
    });
    
    // Protected endpoint
    app.get('/api/protected', keycloakAuth.authenticate(), (req, res) => {
        res.json({
            message: 'This is a protected endpoint',
            user: req.user
        });
    });
    
    // Admin only endpoint
    app.get('/api/admin', keycloakAuth.protect(['admin']), (req, res) => {
        res.json({
            message: 'This is an admin-only endpoint',
            user: req.user
        });
    });
    
    // Optional auth endpoint
    app.get('/api/optional', keycloakAuth.optional(), (req, res) => {
        res.json({
            message: 'This endpoint works with or without authentication',
            authenticated: !!req.user,
            user: req.user || null
        });
    });
    
    return app;
}

module.exports = {
    KeycloakOIDCMiddleware,
    createExampleApp
};

/*
Installation:
npm install jsonwebtoken jwks-rsa axios

Usage:
const { KeycloakOIDCMiddleware } = require('./express-oidc-mw');

const keycloakAuth = new KeycloakOIDCMiddleware({
    keycloakUrl: 'http://localhost:8080',
    realm: 'project-realm',
    clientId: 'project-web'
});

// Protect all routes
app.use('/api', keycloakAuth.authenticate());

// Protect specific routes with roles
app.get('/admin', keycloakAuth.protect(['admin']), handler);
*/