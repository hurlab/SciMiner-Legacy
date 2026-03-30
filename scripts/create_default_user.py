#!/usr/bin/env python3
"""
Create a default admin user for SciMiner 2.0

This script creates the initial admin user for the modernized system.
It ensures the users table exists and creates an admin account with
proper bcrypt password hashing.

Configuration:
- Database: MariaDB/MySQL
- Host: 127.0.0.1:3306
- User: sciminer
- Password: 124356!@

Usage:
  python3 create_default_user.py

Dependencies:
  - bcrypt (system-level package)
  - SQLAlchemy models from the backend

The script will:
1. Check if the users table exists, create if needed
2. Remove any existing admin user to ensure clean state
3. Create a new admin user with proper permissions
"""

import sys
import os
sys.path.append('/home/sciminer/backend')

from sqlalchemy import create_engine, text
import bcrypt

# Database configuration
DB_URL = "mysql+aiomysql://sciminer:124356!%40@127.0.0.1:3306/sciminer"

def create_admin_user():
    # Create engine
    engine = create_engine("mysql+pymysql://sciminer:124356!%40@127.0.0.1:3306/sciminer")

    with engine.connect() as conn:
        # Check if users table exists
        result = conn.execute(text("SHOW TABLES LIKE 'users'"))
        if not result.fetchone():
            print("Users table does not exist. Creating...")
            # Create users table
            conn.execute(text("""
                CREATE TABLE users (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    email VARCHAR(255) UNIQUE NOT NULL,
                    password_hash VARCHAR(255) NOT NULL,
                    name VARCHAR(255),
                    institute VARCHAR(255),
                    department VARCHAR(255),
                    is_active BOOLEAN DEFAULT TRUE,
                    is_admin BOOLEAN DEFAULT FALSE,
                    is_verified BOOLEAN DEFAULT FALSE,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    last_login TIMESTAMP NULL
                )
            """))
            conn.commit()
            print("Users table created successfully!")

        # Check if admin user already exists and delete it
        result = conn.execute(text("SELECT id FROM users WHERE email = 'admin@sciminer.localhost'"))
        if result.fetchone():
            print("Admin user already exists! Deleting and recreating...")
            conn.execute(text("DELETE FROM users WHERE email = 'admin@sciminer.localhost'"))

        # Create admin user
        hashed_password = bcrypt.hashpw("admin123".encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

        conn.execute(text("""
            INSERT INTO users (email, password_hash, name, is_active, is_admin, is_verified, institute)
            VALUES (:email, :password, :name, :is_active, :is_admin, :is_verified, :institute)
        """), {
            'email': 'admin@sciminer.localhost',
            'password': hashed_password,
            'name': 'SciMiner Administrator',
            'is_active': True,
            'is_admin': True,
            'is_verified': True,
            'institute': 'SciMiner'
        })

        conn.commit()
        print("\n✅ Default admin user created successfully!")
        print("\nLogin credentials:")
        print("Email: admin@sciminer.localhost")
        print("Password: admin123")
        print("\nPlease change the password after first login.")

if __name__ == "__main__":
    create_admin_user()