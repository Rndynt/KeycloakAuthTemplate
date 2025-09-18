const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = 5000;

app.use(cors());
app.use(express.json());
app.use(express.static('.'));

// Template validation endpoint
app.get('/api/validate', (req, res) => {
    const checks = {
        dockerCompose: fs.existsSync('docker-compose.yml'),
        envExample: fs.existsSync('.env.example'),
        realmConfig: fs.existsSync('realm/realm-organizations-complete.json'),
        scriptsDir: fs.existsSync('scripts'),
        clientConfigsDir: fs.existsSync('client-configs'),
        middlewareDir: fs.existsSync('middleware-examples'),
        helmDir: fs.existsSync('helm')
    };
    
    const score = Object.values(checks).filter(Boolean).length;
    const total = Object.keys(checks).length;
    
    res.json({
        environment: 'Replit Cloud Environment',
        status: score === total ? 'COMPLETE' : 'IN_PROGRESS',
        score: `${score}/${total}`,
        checks,
        message: score === total ? 
            'Template is complete and ready for local deployment!' : 
            'Template is being built...',
        note: 'This template requires Docker to run Keycloak. Download and use locally with Docker for full functionality.'
    });
});

// Project structure endpoint
app.get('/api/structure', (req, res) => {
    const getDirectoryStructure = (dir, prefix = '') => {
        try {
            const items = fs.readdirSync(dir);
            return items.map(item => {
                const fullPath = path.join(dir, item);
                const stat = fs.statSync(fullPath);
                return {
                    name: item,
                    type: stat.isDirectory() ? 'directory' : 'file',
                    path: fullPath
                };
            });
        } catch (error) {
            return [];
        }
    };
    
    res.json({
        structure: getDirectoryStructure('.'),
        timestamp: new Date().toISOString()
    });
});

// Documentation endpoint
app.get('/api/docs', (req, res) => {
    const docs = {
        title: 'Keycloak Enterprise Auth Template v2.0',
        description: 'Enterprise-grade multi-tenant authentication platform with Organizations, IoT, Token Exchange & Authorization Services',
        environment: 'Replit Preview Environment',
        quickStart: [
            '1. Download/fork this template to your local machine',
            '2. Run: cp .env.example .env && edit credentials',
            '3. Run: docker-compose up -d',
            '4. Run: ./scripts/import-realm.sh',
            '5. Access Keycloak at http://localhost:8080'
        ],
        replitInfo: {
            purpose: 'This Replit shows the template structure and documentation',
            limitation: 'Docker is not available in Replit - use locally for full functionality',
            downloadInstructions: 'Fork this Replit or download files to use with Docker locally'
        },
        localInstructions: [
            'This template requires Docker to run Keycloak',
            'Download all files to a local environment with Docker installed',
            'Follow the README.md instructions for complete setup',
            'Includes PostgreSQL database, MailHog for email testing',
            'Production-ready with security best practices'
        ]
    };
    
    res.json(docs);
});

// Health check
app.get('/health', (req, res) => {
    res.json({ 
        status: 'OK', 
        service: 'Keycloak Template Validation Server',
        timestamp: new Date().toISOString()
    });
});

// Serve main page
app.get('/', (req, res) => {
    res.send(`
        <!DOCTYPE html>
        <html>
        <head>
            <title>Keycloak Auth Template</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 40px; }
                .status { padding: 20px; border-radius: 5px; margin: 20px 0; }
                .complete { background-color: #d4edda; border: 1px solid #c3e6cb; }
                .in-progress { background-color: #fff3cd; border: 1px solid #ffeaa7; }
                .endpoint { background-color: #f8f9fa; padding: 10px; margin: 10px 0; border-radius: 3px; }
            </style>
        </head>
        <body>
            <h1>🔐 Keycloak Enterprise Auth Template v2.0</h1>
            <p><strong>Replit Preview:</strong> Enterprise-grade multi-tenant authentication platform with Organizations, IoT Device Auth, Token Exchange & Authorization Services!</p>
            
            <div style="background-color: #e7f3ff; border: 1px solid #b3d9ff; padding: 15px; margin: 20px 0; border-radius: 5px;">
                <strong>ℹ️ About This Preview:</strong> This is a demonstration of the Keycloak template structure and documentation. 
                To use the full authentication system, download these files and run locally with Docker.
            </div>
            
            <div id="status" class="status in-progress">
                <strong>Template Status:</strong> Loading...
            </div>
            
            <h2>Template Structure</h2>
            <div id="structure">Loading structure...</div>
            
            <h2>API Endpoints</h2>
            <div class="endpoint"><strong>GET /api/validate</strong> - Template validation status</div>
            <div class="endpoint"><strong>GET /api/structure</strong> - Project file structure</div>
            <div class="endpoint"><strong>GET /api/docs</strong> - Documentation and quick start</div>
            <div class="endpoint"><strong>GET /health</strong> - Service health check</div>
            
            <h2>Quick Start (Requires Local Docker)</h2>
            <pre>
# 1. Download template files (fork this Replit or clone)
git clone [your-repo] keycloak-template
cd keycloak-template

# 2. Configure environment
cp .env.example .env
# Edit .env with your secure credentials

# 3. Start services (requires Docker)
docker-compose up -d

# 4. Import realm configuration
./scripts/import-realm.sh

# 5. Create admin user
./scripts/seed-admin.sh

# 6. Access Keycloak Admin Console
open http://localhost:8080
            </pre>
            
            <script>
                fetch('/api/validate')
                    .then(r => r.json())
                    .then(data => {
                        const statusDiv = document.getElementById('status');
                        statusDiv.className = 'status ' + (data.status === 'COMPLETE' ? 'complete' : 'in-progress');
                        statusDiv.innerHTML = '<strong>Status:</strong> ' + data.status + ' (' + data.score + ')';
                    });
                    
                fetch('/api/structure')
                    .then(r => r.json())
                    .then(data => {
                        const structureDiv = document.getElementById('structure');
                        structureDiv.innerHTML = '<pre>' + 
                            data.structure.map(item => 
                                (item.type === 'directory' ? '📁' : '📄') + ' ' + item.name
                            ).join('\\n') + '</pre>';
                    });
            </script>
        </body>
        </html>
    `);
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Keycloak Template Validation Server running on port ${PORT}`);
    console.log(`📊 Access validation dashboard at http://localhost:${PORT}`);
    console.log(`🔍 API endpoints available at http://localhost:${PORT}/api/*`);
});