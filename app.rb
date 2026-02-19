require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'

enable :sessions

DB = SQLite3::Database.new("db/database.db")
DB.results_as_hash = true

get '/' do
	slim :index
end

get '/play' do
	redirect '/login' unless session[:user_id]
	user = DB.get_first_row('SELECT * FROM users WHERE id = ?', session[:user_id])
	balance = user ? user['balance'].to_f : 0.0
	bet_options = if user && user['bet_options'] && !user['bet_options'].to_s.empty?
		user['bet_options'].to_s.split(',').map { |s| s.to_f }
	else
		[100.0]
	end
	win_odds = user && user['win_odds'] ? user['win_odds'].to_f : 0.5
	error = session.delete(:error)
	message = session.delete(:message)
	slim :play, locals: { balance: balance, error: error, message: message, bet_options: bet_options, win_odds: win_odds }
end

post '/balance' do
	redirect '/login' unless session[:user_id]
	amount = params['amount'].to_f
	user = DB.get_first_row('SELECT * FROM users WHERE id = ?', session[:user_id])
	current = user ? user['balance'].to_f : 0.0
	new_balance = current + amount
	if new_balance < 0
		session[:error] = 'Insufficient funds'
	else
		DB.execute('UPDATE users SET balance = ? WHERE id = ?', [new_balance, session[:user_id]])
	end
	redirect '/play'
end


post '/play' do
	redirect '/login' unless session[:user_id]
	bet = params['bet'].to_f
	user = DB.get_first_row('SELECT * FROM users WHERE id = ?', session[:user_id])
	current = user ? user['balance'].to_f : 0.0
	bet_options = if user && user['bet_options'] && !user['bet_options'].to_s.empty?
		user['bet_options'].to_s.split(',').map { |s| s.to_f }
	else
		[100.0]
	end
	unless bet_options.include?(bet)
		session[:error] = 'Invalid bet amount'
		redirect '/play'
	end
	if current < bet
		session[:error] = 'Insufficient funds'
		redirect '/play'
	end
	win_odds = user && user['win_odds'] ? user['win_odds'].to_f : 0.5
	win = rand < win_odds
	new_balance = current + (win ? bet : -bet)
	DB.execute('UPDATE users SET balance = ? WHERE id = ?', [new_balance, session[:user_id]])
	session[:message] = win ? "You won #{'%.2f' % bet}kr!" : "You lost #{'%.2f' % bet}kr."
	redirect '/play'
end

get '/login' do
	error = session.delete(:error)
	slim :login, locals: { error: error }
end

post '/login' do
	password = params['password']
	user = nil
	if params['email'] && !params['email'].empty?
		user = DB.get_first_row('SELECT * FROM users WHERE email = ?', params['email'])
	end
	if user && BCrypt::Password.new(user['password_digest']) == password
		session[:user_id] = user['id']
		session[:user] = user['username']
		redirect '/play'
	else
		session[:error] = 'Invalid email or password'
		redirect '/login'
	end
end

get '/register' do
	error = session.delete(:error)
	slim :register, locals: { error: error }
end

post '/register' do
	username = params['username']
	email = params['email']
	password = params['password']
	password_confirm = params['password_confirm']
	if password != password_confirm
		session[:error] = 'Passwords do not match'
		redirect '/register'
	end
	password_digest = BCrypt::Password.create(password)
	begin
		DB.execute('INSERT INTO users (username, email, password_digest, balance) VALUES (?, ?, ?, ?)', [username, email, password_digest, 1000.0])
		user = DB.get_first_row('SELECT * FROM users WHERE email = ?', email)
		session[:user_id] = user['id']
		session[:user] = user['username']
		redirect '/play'
	rescue SQLite3::ConstraintException
		session[:error] = 'Username or email already taken'
		redirect '/register'
	end
end

get '/logout' do
	session.clear
	redirect '/'
end