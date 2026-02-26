require 'sqlite3'

DB_FILE = File.join(__dir__, 'db', 'database.db')

db = SQLite3::Database.new(DB_FILE)
db.results_as_hash = true

username = ARGV[0] || 'philip'

puts "Resetting stats for #{username}..."

new_balance = 1000.0
new_bet_options = '100,200,500'
new_win_odds = 0.5

db.execute('UPDATE users SET balance = ?, bet_options = ?, win_odds = ? WHERE username = ?', [new_balance, new_bet_options, new_win_odds, username])

puts "Done. Set balance=#{new_balance}, bet_options=#{new_bet_options}, win_odds=#{new_win_odds} for #{username}."