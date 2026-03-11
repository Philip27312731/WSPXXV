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
		DB.execute('INSERT INTO users (username, email, password_digest, balance, blood_inventory, kidney_inventory) VALUES (?, ?, ?, ?, ?, ?)', [username, email, password_digest, 1000.0, 10, 1])
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

get '/edit_profile' do
	redirect '/login' unless session[:user_id]
	user = DB.get_first_row('SELECT * FROM users WHERE id = ?', session[:user_id])
	error = session.delete(:error)
	message = session.delete(:message)
	slim :edit_profile, locals: { error: error, message: message, user: user }
end

post '/edit_profile' do
	redirect '/login' unless session[:user_id]
	user = DB.get_first_row('SELECT * FROM users WHERE id = ?', session[:user_id])

	old_username = params['old_username']
	new_username = params['new_username']
	old_password = params['old_password']
	new_password = params['new_password']
	error = nil


	if new_username && !new_username.empty?
		if old_username != user['username']
			error = 'Old username does not match current username'
		else
			existing = DB.get_first_row('SELECT * FROM users WHERE username = ?', new_username)
			if existing && existing['id'] != user['id']
				error = 'Username already taken'
			end
		end
	end

	
	if error.nil? && new_password && !new_password.empty?
		if old_password.to_s.empty? || BCrypt::Password.new(user['password_digest']) != old_password
			error = 'Old password is incorrect'
		end
	end

	if error
		session[:error] = error
	else
		if new_username && !new_username.empty?
			begin
				DB.execute('UPDATE users SET username = ? WHERE id = ?', [new_username, session[:user_id]])
				session[:user] = new_username
				user['username'] = new_username
			rescue SQLite3::ConstraintException
				session[:error] = 'Username already taken'
				redirect '/edit_profile'
				return
			end
		end

		if new_password && !new_password.empty?
			new_digest = BCrypt::Password.create(new_password)
			DB.execute('UPDATE users SET password_digest = ? WHERE id = ?', [new_digest, session[:user_id]])
		end

		session[:message] = 'Profile updated successfully'
	end
	redirect '/edit_profile'
end

get '/upgrade' do
	redirect '/login' unless session[:user_id]
	user = DB.get_first_row('SELECT * FROM users WHERE id = ?', session[:user_id])
	balance = user ? user['balance'].to_f : 0.0
	error = session.delete(:error)
	notice = session.delete(:message)
	slim :upgrade, locals: { balance: balance, error: error, notice: notice }
end

post '/upgrade' do
	redirect '/login' unless session[:user_id]
	upgrade_type = params['upgrade_type']
	amount = (params['amount'] || 1).to_i
	cost_per = case upgrade_type
	when 'increase_bet' then 1000
	when 'better_odds' then 2500
	else 0
	end
	cost = cost_per * amount
	user = DB.get_first_row('SELECT * FROM users WHERE id = ?', session[:user_id])
	current = user ? user['balance'].to_f : 0.0
	if current < cost
		session[:error] = 'Insufficient funds for upgrade'
		redirect '/play'
	end
	# Deduct cost
	new_balance = current - cost
	DB.execute('UPDATE users SET balance = ? WHERE id = ?', [new_balance, session[:user_id]])

	case upgrade_type
	when 'increase_bet'
		bet_options = (user['bet_options'] || '100').to_s.split(',').map { |s| s.to_f }
		new_opt = (bet_options.max || 100) + 100.0 * amount
		bet_options << new_opt
		DB.execute('UPDATE users SET bet_options = ? WHERE id = ?', [bet_options.map { |b| (b % 1).zero? ? b.to_i : b }.join(','), session[:user_id]])
		session[:message] = "Increased bet options. Added #{new_opt}kr"
	when 'better_odds'
		current_odds = user['win_odds'] ? user['win_odds'].to_f : 0.5
		new_odds = [current_odds + 0.01 * amount, 0.95].min
		DB.execute('UPDATE users SET win_odds = ? WHERE id = ?', [new_odds, session[:user_id]])
		session[:message] = "Improved win odds to #{'%.2f' % new_odds}"
	else
		session[:message] = 'Unknown upgrade selected'
	end

	redirect '/play'
end

get '/shop' do
	redirect '/login' unless session[:user_id]
	products = DB.execute('SELECT * FROM products')
	user = DB.get_first_row('SELECT * FROM users WHERE id = ?', session[:user_id])
	redirect '/login' unless user
	error = session.delete(:error)
	notice = session.delete(:message)
	slim :shop, locals: { products: products, error: error, notice: notice, user: user }
end

post '/shop/buy' do
	redirect '/login' unless session[:user_id]
	product_id = params['product_id'].to_i
	quantity = (params['quantity'] || 1).to_i
	product = DB.get_first_row('SELECT * FROM products WHERE id = ?', product_id)
	halt 404, 'Product not found' unless product
	if ['Blood 1 liter','Kidney'].include?(product['name'])
		session[:error] = 'These items cannot be purchased'
		redirect '/shop'
		return
	end
	user = DB.get_first_row('SELECT * FROM users WHERE id = ?', session[:user_id])
	halt 404, 'User not found' unless user

	current = user['balance'].to_f
	cost = product['price'].to_f * quantity
	if current < cost
		session[:error] = 'Insufficient funds for purchase'
	else
		new_balance = current - cost
		DB.execute('UPDATE users SET balance = ? WHERE id = ?', [new_balance, session[:user_id]])
		DB.execute('INSERT INTO orders (user_id, product_id, quantity) VALUES (?, ?, ?)', [session[:user_id], product_id, quantity])
		session[:message] = "Purchased #{quantity} #{product['name']}#{'s' unless quantity == 1}"
	end
	redirect '/shop'
end

post '/shop/sell' do
	redirect '/login' unless session[:user_id]
	product_id = params['product_id'].to_i
	quantity = (params['quantity'] || 1).to_i
	product = DB.get_first_row('SELECT * FROM products WHERE id = ?', product_id)
	halt 404, 'Product not found' unless product
	unless ['Blood 1 liter','Kidney'].include?(product['name'])
		session[:error] = 'This item cannot be sold here'
		redirect '/shop'
		return
	end
	user = DB.get_first_row('SELECT * FROM users WHERE id = ?', session[:user_id])
	halt 404, 'User not found' unless user
	case product['name']
	when 'Blood 1 liter'
		if quantity > user['blood_inventory']
			session[:error] = "You only have #{user['blood_inventory']} liters of blood left"
			redirect '/shop'
			return
		end
		new_inv = user['blood_inventory'] - quantity
		DB.execute('UPDATE users SET blood_inventory = ? WHERE id = ?', [new_inv, user['id']])
	when 'Kidney'
		if quantity > user['kidney_inventory']
			session[:error] = "You only have #{user['kidney_inventory']} kidney left"
			redirect '/shop'
			return
		end
		new_inv = user['kidney_inventory'] - quantity
		DB.execute('UPDATE users SET kidney_inventory = ? WHERE id = ?', [new_inv, user['id']])
	end
	# perform sale
	gain = product['price'].to_f * quantity
	new_balance = user['balance'].to_f + gain
	DB.execute('UPDATE users SET balance = ? WHERE id = ?', [new_balance, session[:user_id]])
	session[:message] = "Sold #{quantity} #{product['name']}#{'s' unless quantity == 1} for #{'%.2f' % gain}kr"
	redirect '/shop'
end

get '/orders' do
	redirect '/login' unless session[:user_id]
	orders = DB.execute('SELECT orders.*, products.name AS product_name, products.price AS product_price
                       FROM orders
                       JOIN products ON orders.product_id = products.id
                       WHERE orders.user_id = ?', session[:user_id])
	error = session.delete(:error)
	notice = session.delete(:message)
	slim :orders, locals: { orders: orders, error: error, notice: notice }
end

post '/orders/:id/delete' do
	redirect '/login' unless session[:user_id]
	id = params['id'].to_i
	order = DB.get_first_row('SELECT * FROM orders WHERE id = ? AND user_id = ?', id, session[:user_id])
	halt 404, 'Order not found' unless order
	product = DB.get_first_row('SELECT * FROM products WHERE id = ?', order['product_id'])
	refund = product['price'].to_f * order['quantity'].to_i
	user = DB.get_first_row('SELECT * FROM users WHERE id = ?', session[:user_id])
	new_balance = user['balance'].to_f + refund
	DB.execute('UPDATE users SET balance = ? WHERE id = ?', [new_balance, session[:user_id]])
	DB.execute('DELETE FROM orders WHERE id = ?', id)
	session[:message] = "Order cancelled and #{'%.2f' % refund}kr refunded"
	redirect '/orders'
end

get '/orders/:id/edit' do
	redirect '/login' unless session[:user_id]
	id = params['id'].to_i
	order = DB.get_first_row('SELECT * FROM orders WHERE id = ? AND user_id = ?', id, session[:user_id])
	halt 404, 'Order not found' unless order
	product = DB.get_first_row('SELECT * FROM products WHERE id = ?', order['product_id'])
	slim :edit_order, locals: { order: order, product: product }
end

post '/orders/:id' do
	redirect '/login' unless session[:user_id]
	id = params['id'].to_i
	quantity = params['quantity'].to_i
	order = DB.get_first_row('SELECT * FROM orders WHERE id = ? AND user_id = ?', id, session[:user_id])
	halt 404, 'Order not found' unless order
	product = DB.get_first_row('SELECT * FROM products WHERE id = ?', order['product_id'])
	user = DB.get_first_row('SELECT * FROM users WHERE id = ?', session[:user_id])
	old_cost = product['price'].to_f * order['quantity'].to_i
	new_cost = product['price'].to_f * quantity
	diff = new_cost - old_cost
	if diff > 0 && user['balance'].to_f < diff
		session[:error] = 'Insufficient funds to increase quantity'
		redirect "/orders/#{id}/edit"
	else
		new_balance = user['balance'].to_f - diff
		DB.execute('UPDATE users SET balance = ? WHERE id = ?', [new_balance, session[:user_id]])
		DB.execute('UPDATE orders SET quantity = ? WHERE id = ?', [quantity, id])
		session[:message] = 'Order updated'
		redirect '/orders'
	end
end