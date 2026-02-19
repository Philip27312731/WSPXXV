require 'sqlite3'

db = SQLite3::Database.new("db/database.db")
db.results_as_hash = true

db.execute('UPDATE users SET balance = balance + ? WHERE username = ?', [800000, 'hej'])

