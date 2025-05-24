import os
import psycopg2
import time
import requests
import json
from flask import Flask, jsonify, request
import logging

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Vault configuration
VAULT_CONFIG = {
    'url': 'http://vault-service.vault.svc.cluster.local:8200',
    'token': os.getenv('VAULT_TOKEN', ''),
    'db_role': 'readonly'  # or 'readwrite' based on needs
}

class VaultClient:
    def __init__(self):
        self.vault_url = VAULT_CONFIG['url']
        self.token = VAULT_CONFIG['token']
        self.headers = {'X-Vault-Token': self.token}
    
    def get_db_credentials(self, role='readonly'):
        """Get dynamic database credentials from Vault"""
        try:
            start_time = time.time()
            
            # Request dynamic credentials from Vault
            url = f"{self.vault_url}/v1/database/creds/{role}"
            response = requests.get(url, headers=self.headers, timeout=10)
            
            vault_time = time.time() - start_time
            
            if response.status_code == 200:
                data = response.json()['data']
                credentials = {
                    'username': data['username'],
                    'password': data['password'],
                    'lease_id': data.get('lease_id', ''),
                    'lease_duration': data.get('lease_duration', 0)
                }
                logger.info(f"Dynamic credentials obtained in {vault_time:.3f}s")
                return credentials, vault_time
            else:
                logger.error(f"Vault request failed: {response.status_code} - {response.text}")
                raise Exception(f"Vault authentication failed: {response.status_code}")
                
        except Exception as e:
            logger.error(f"Failed to get credentials from Vault: {str(e)}")
            raise

def get_db_connection_with_vault():
    """Get database connection using Vault dynamic credentials"""
    try:
        # Get dynamic credentials from Vault
        vault_client = VaultClient()
        creds, vault_time = vault_client.get_db_credentials()
        
        # Connect to database with dynamic credentials
        conn_start = time.time()
        conn = psycopg2.connect(
            host='postgres-service.database.svc.cluster.local',
            port=5432,
            database='testdb',
            user=creds['username'],
            password=creds['password']
        )
        conn_time = time.time() - conn_start
        
        total_auth_time = vault_time + conn_time
        
        logger.info(f"Database connection with Vault auth: Vault={vault_time:.3f}s, DB={conn_time:.3f}s, Total={total_auth_time:.3f}s")
        
        return conn, {
            'vault_time': vault_time,
            'db_connection_time': conn_time,
            'total_auth_time': total_auth_time,
            'credentials_user': creds['username'],
            'lease_duration': creds['lease_duration']
        }
        
    except Exception as e:
        logger.error(f"Database connection with Vault failed: {str(e)}")
        raise

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'app_type': 'vault-secrets',
        'timestamp': time.time(),
        'vault_url': VAULT_CONFIG['url']
    })

@app.route('/users')
def get_users():
    """Get users from database using Vault dynamic credentials"""
    start_time = time.time()
    
    try:
        conn, auth_metrics = get_db_connection_with_vault()
        cursor = conn.cursor()
        
        # Execute query
        query_start = time.time()
        cursor.execute("SELECT id, username, email, created_at FROM users")
        users = cursor.fetchall()
        query_time = time.time() - query_start
        
        cursor.close()
        conn.close()
        
        total_time = time.time() - start_time
        
        result = {
            'status': 'success',
            'app_type': 'vault-secrets',
            'users': [
                {
                    'id': user[0],
                    'username': user[1],
                    'email': user[2],
                    'created_at': str(user[3])
                } for user in users
            ],
            'metrics': {
                'total_time': f"{total_time:.3f}s",
                'vault_auth_time': f"{auth_metrics['vault_time']:.3f}s",
                'db_connection_time': f"{auth_metrics['db_connection_time']:.3f}s",
                'total_auth_time': f"{auth_metrics['total_auth_time']:.3f}s",
                'query_time': f"{query_time:.3f}s",
                'vault_overhead': f"{auth_metrics['vault_time']:.3f}s"
            },
            'security_info': {
                'credentials_user': auth_metrics['credentials_user'],
                'lease_duration': auth_metrics['lease_duration'],
                'dynamic_credentials': True
            }
        }
        
        logger.info(f"Request completed in {total_time:.3f}s (Vault overhead: {auth_metrics['vault_time']:.3f}s)")
        return jsonify(result)
        
    except Exception as e:
        error_time = time.time() - start_time
        logger.error(f"Request failed after {error_time:.3f}s: {str(e)}")
        return jsonify({
            'status': 'error',
            'app_type': 'vault-secrets',
            'error': str(e),
            'time_elapsed': f"{error_time:.3f}s"
        }), 500

@app.route('/metrics')
def metrics():
    """Expose Vault-specific metrics"""
    return jsonify({
        'app_type': 'vault-secrets',
        'credentials_type': 'dynamic',
        'security_risk': 'low - dynamic credentials from Vault',
        'vault_config': {
            'url': VAULT_CONFIG['url'],
            'role': VAULT_CONFIG['db_role'],
            'token_configured': bool(VAULT_CONFIG['token'])
        }
    })

@app.route('/vault-status')
def vault_status():
    """Check Vault connectivity"""
    try:
        vault_client = VaultClient()
        start_time = time.time()
        
        # Test Vault connection
        url = f"{vault_client.vault_url}/v1/sys/health"
        response = requests.get(url, timeout=5)
        
        response_time = time.time() - start_time
        
        return jsonify({
            'vault_reachable': response.status_code == 200,
            'vault_status': response.status_code,
            'response_time': f"{response_time:.3f}s",
            'vault_url': vault_client.vault_url
        })
        
    except Exception as e:
        return jsonify({
            'vault_reachable': False,
            'error': str(e),
            'vault_url': VAULT_CONFIG['url']
        }), 500

if __name__ == '__main__':
    logger.info("Starting Vault Secrets App...")
    logger.info(f"Vault URL: {VAULT_CONFIG['url']}")
    logger.info(f"Token configured: {bool(VAULT_CONFIG['token'])}")
    app.run(host='0.0.0.0', port=5000, debug=False)
