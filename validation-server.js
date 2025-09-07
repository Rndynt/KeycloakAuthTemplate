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
        realmConfig: fs.existsSync('realm/realm-singletenant.json'),
        scriptsDir: fs.existsSync('scripts'),
        clientConfigsDir: fs.existsSync('client-configs'),
        middlewareDir: fs.existsSync('middleware-examples'),
        helmDir: fs.existsSync('helm')
    };
    
    const score = Object.values(checks).filter(Boolean).length;
    const total = Object.keys(checks).length;
    
    res.json({
        status: score === total ? 'COMPLETE' : 'IN_PROGRESS',
        score: `${score}/${total}`,
        checks,
        message: score === total ? 
            'Template is complete and ready for use!' : 
            'Template is being built...'
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
        title: 'Keycloak Auth Template',
        description: 'Independent Keycloak authentication template for any project',
        quickStart: [
            '1. Copy template files to your project',
            '2. Run: cp .env.example .env && edit credentials',
            '3. Run: docker-compose up -d'
        ],
        dockerStatus: 'Not available in current environment',
        localInstructions: [
            'This template requires Docker to run Keycloak',
            'Copy all files to a local environment with Docker',
            'Follow the README instructions for full setup'
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
            <h1>🔐 Keycloak Auth Template</h1>
            <p>Independent Keycloak authentication template - copy and run!</p>
            
            <div id="status" class="status in-progress">
                <strong>Status:</strong> Loading...
            </div>
            
            <h2>Template Structure</h2>
            <div id="structure">Loading structure...</div>
            
            <h2>API Endpoints</h2>
            <div class="endpoint"><strong>GET /api/validate</strong> - Template validation status</div>
            <div class="endpoint"><strong>GET /api/structure</strong> - Project file structure</div>
            <div class="endpoint"><strong>GET /api/docs</strong> - Documentation and quick start</div>
            <div class="endpoint"><strong>GET /health</strong> - Service health check</div>
            
            <h2>Quick Start (Local with Docker)</h2>
            <pre>
# 1. Copy template files
git clone [your-repo] keycloak-template
cd keycloak-template

# 2. Configure environment
cp .env.example .env
# Edit .env with your credentials

# 3. Start services
docker-compose up -d

# 4. Import realm
./scripts/import-realm.sh

# 5. Seed admin user
./scripts/seed-admin.sh
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