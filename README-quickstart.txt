🔐 KEYCLOAK AUTH TEMPLATE - 3-STEP QUICKSTART

======================================================

STEP 1: CONFIGURE
-----------------
cp .env.example .env
nano .env  # Change default passwords!

STEP 2: START SERVICES  
---------------------
docker-compose up -d

STEP 3: IMPORT & SEED
--------------------
./scripts/import-realm.sh
./scripts/seed-admin.sh

DONE! 🎉
--------
✅ Keycloak Admin: http://localhost:8080 (admin/admin)
✅ MailHog UI: http://localhost:8025
✅ Validation Server: http://localhost:5000

YOUR AUTHENTICATION ENDPOINTS:
------------------------------
• Auth URL: http://localhost:8080/realms/project-realm/protocol/openid-connect/auth
• Token URL: http://localhost:8080/realms/project-realm/protocol/openid-connect/token
• User Info: http://localhost:8080/realms/project-realm/protocol/openid-connect/userinfo
• JWKS: http://localhost:8080/realms/project-realm/protocol/openid-connect/certs

DEFAULT CLIENTS:
---------------
• project-web (SPA): Authorization Code + PKCE
• project-backend (API): Client Credentials  
• project-mobile (Mobile): Authorization Code + PKCE

SECURITY DEFAULTS:
-----------------
• Access tokens: 10 minutes
• Refresh tokens: 7 days (with rotation)
• MFA required for admin role
• Password policy: 8+ chars, mixed case, numbers

NEXT STEPS:
----------
1. See README.md for integration examples
2. Check curl_examples.md for API testing
3. Review middleware-examples/ for your tech stack
4. Change default passwords in .env before production!

PRODUCTION CHECKLIST:
-------------------
□ Change all default passwords
□ Use HTTPS (Let's Encrypt)
□ Use managed database
□ Configure real SMTP
□ Restrict admin console access
□ Set up monitoring and backups

NEED HELP?
---------
• Validation Dashboard: http://localhost:5000
• Health Check: http://localhost:8080/health/ready  
• Logs: docker-compose logs -f keycloak