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
  db.execute('DROP TABLE IF EXISTS orders')
  db.execute('DROP TABLE IF EXISTS products')
  db.execute('DROP TABLE IF EXISTS example')
  db.execute('DROP TABLE IF EXISTS users')
end

def create_tables(db)
  db.execute('CREATE TABLE products (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              price REAL NOT NULL)')
  db.execute('CREATE TABLE orders (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id INTEGER NOT NULL,
              product_id INTEGER NOT NULL,
              quantity INTEGER DEFAULT 1,
              created_at TEXT DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY(user_id) REFERENCES users(id),
              FOREIGN KEY(product_id) REFERENCES products(id))')
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
              bet_options TEXT DEFAULT "1,100,200,500",
              win_odds REAL DEFAULT 0.5,
              blood_inventory INTEGER DEFAULT 10,
              kidney_inventory INTEGER DEFAULT 1)')
end

def populate_tables(db)
 
  db.execute('INSERT INTO products (name, price) VALUES (?, ?)', ['Lamborghini', 5000000.0])
  db.execute('INSERT INTO products (name, price) VALUES (?, ?)', ['Tren (50ml)', 650.0])
  db.execute('INSERT INTO products (name, price) VALUES (?, ?)', ['Mentos', 7.5])
  db.execute('INSERT INTO products (name, price) VALUES (?, ?)', ['Blood 1 liter', 6000.0])
  db.execute('INSERT INTO products (name, price) VALUES (?, ?)', ['Kidney', 680000.0])
  db.execute('INSERT INTO example (name, description, state) VALUES ("Köp mjölk", "3 liter mellanmjölk, eko",false)')
  db.execute('INSERT INTO example (name, description, state) VALUES ("Köp julgran", "En rödgran",false)')
  db.execute('INSERT INTO example (name, description, state) VALUES ("Pynta gran", "Glöm inte lamporna i granen och tomten",false)')
  pw = BCrypt::Password.create('password123')
  db.execute('INSERT INTO users (username, email, password_digest, balance, bet_options, win_odds, blood_inventory, kidney_inventory) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', ['testuser', 'test@example.com', pw, 1000.0, '100,200,500', 0.5, 10, 1])
  db.execute('INSERT INTO users (username, email, password_digest, balance, bet_options, win_odds, blood_inventory, kidney_inventory) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', ['hej', 'boll@gmail.com', pw, 1000.0, '100,200,500,1000,2000', 0.5, 10, 1])
end


seed!(db)





