# Keycloak Auth Template - Replit Import

## Overview
This is a Keycloak authentication template that has been successfully imported into Replit. The project serves as a demonstration and validation interface for a complete Keycloak authentication system template.

## Current State
- **Status**: Successfully configured for Replit environment
- **Purpose**: Template demonstration and validation interface
- **Main functionality**: Web-based validation server showing template structure and documentation

## Project Architecture
- **Language**: Node.js with Express
- **Main file**: `validation-server.js` - validation and documentation server
- **Port**: 5000 (configured for Replit frontend requirements)
- **Dependencies**: Express, CORS
- **Deployment**: Configured for autoscale deployment

## Key Components
- **Validation Server**: Provides web interface for template validation
- **Docker Configuration**: Complete docker-compose.yml for local Keycloak deployment
- **Realm Configuration**: Pre-configured Keycloak realm settings
- **Scripts**: Database backup, realm import/export utilities
- **Client Configs**: Ready-to-use client configurations for web, backend, and mobile
- **Middleware Examples**: Authentication middleware for Node.js and Python

## Important Notes
- **Docker Limitation**: This template requires Docker to run Keycloak, which is not available in Replit
- **Local Use**: Full functionality requires downloading and running locally with Docker
- **Replit Purpose**: Serves as a preview/documentation interface for the template

## Recent Changes
- Installed Node.js dependencies (express, cors)
- Updated validation server to work without .env file in Replit
- Modified API responses to clarify Replit environment limitations
- Updated HTML interface to explain Docker requirements
- Configured deployment for autoscale mode

## User Instructions
To use this template for actual authentication:
1. Fork this Replit or download the files
2. Run locally with Docker installed
3. Follow README.md instructions for complete setup
4. Access the validation interface at the deployed URL to see template structure

## Deployment Configuration
- **Type**: Autoscale (suitable for stateless validation interface)
- **Command**: `npm start`
- **Environment**: Production-ready for the validation interface