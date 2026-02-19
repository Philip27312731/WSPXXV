require 'sqlite3'
require 'bcrypt'

db = SQLite3::Database.new("db/database.db")


def seed!(db)
  puts "Using db file: db/database.db"
  puts "🧹 Dropping old tables..."
  drop_tables(db)
  puts "🧱 Creating tables..."
  create_tables(db)
  puts "🍎 Populating tables..."
  populate_tables(db)
  puts "✅ Done seeding the database!"
end

def drop_tables(db)
  db.execute('DROP TABLE IF EXISTS example')
  db.execute('DROP TABLE IF EXISTS users')
end

def create_tables(db)
  db.execute('CREATE TABLE example (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL, 
              description TEXT,
              state BOOLEAN)')
  db.execute('CREATE TABLE users (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              username TEXT UNIQUE,
              email TEXT UNIQUE,
              password_digest TEXT NOT NULL,
              balance REAL DEFAULT 0.0,
              bet_options TEXT DEFAULT "100,200,500",
              win_odds REAL DEFAULT 0.5)')
end

def populate_tables(db)
  db.execute('INSERT INTO example (name, description, state) VALUES ("Köp mjölk", "3 liter mellanmjölk, eko",false)')
  db.execute('INSERT INTO example (name, description, state) VALUES ("Köp julgran", "En rödgran",false)')
  db.execute('INSERT INTO example (name, description, state) VALUES ("Pynta gran", "Glöm inte lamporna i granen och tomten",false)')
  pw = BCrypt::Password.create('password123')
  db.execute('INSERT INTO users (username, email, password_digest, balance, bet_options, win_odds) VALUES (?, ?, ?, ?, ?, ?)', ['testuser', 'test@example.com', pw, 1000.0, '100,200,500', 0.5])
  db.execute('INSERT INTO users (username, email, password_digest, balance, bet_options, win_odds) VALUES (?, ?, ?, ?, ?, ?)', ['hej', 'boll@gmail.com', pw, 1000.0, '100,200,500,1000,2000', 0.5])
end


seed!(db)





