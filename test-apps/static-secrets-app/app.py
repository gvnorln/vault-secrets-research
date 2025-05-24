import os
import psycopg2
import time
from flask import Flask, jsonify, request
import logging

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Static database credentials (BASELINE - NOT SECURE)
DB_CONFIG = {
    'host': 'postgres-service.database.svc.cluster.local',
    'port': 5432,
    'database': 'testdb',
    'user': 'postgres',
    'password': 'initialpassword123'  # Static password - security risk!
}

def get_db_connection():
    """Get database connection with static credentials"""
    try:
        start_time = time.time()
        conn = psycopg2.connect(**DB_CONFIG)
        connection_time = time.time() - start_time
        logger.info(f"Database connection established in {connection_time:.3f}s")
        return conn, connection_time
    except Exception as e:
        logger.error(f"Database connection failed: {str(e)}")
        raise

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'app_type': 'static-secrets',
        'timestamp': time.time()
    })

@app.route('/users')
def get_users():
    """Get users from database"""
    start_time = time.time()
    
    try:
        conn, conn_time = get_db_connection()
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
            'app_type': 'static-secrets',
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
                'connection_time': f"{conn_time:.3f}s",
                'query_time': f"{query_time:.3f}s"
            }
        }
        
        logger.info(f"Request completed in {total_time:.3f}s")
        return jsonify(result)
        
    except Exception as e:
        error_time = time.time() - start_time
        logger.error(f"Request failed after {error_time:.3f}s: {str(e)}")
        return jsonify({
            'status': 'error',
            'app_type': 'static-secrets',
            'error': str(e),
            'time_elapsed': f"{error_time:.3f}s"
        }), 500

@app.route('/metrics')
def metrics():
    """Expose basic metrics"""
    return jsonify({
        'app_type': 'static-secrets',
        'credentials_type': 'static',
        'security_risk': 'high - static credentials in code',
        'database_config': {
            'host': DB_CONFIG['host'],
            'user': DB_CONFIG['user'],
            'password_exposed': True
        }
    })

if __name__ == '__main__':
    logger.info("Starting Static Secrets App...")
    app.run(host='0.0.0.0', port=5000, debug=False)
