require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'

enable :sessions

get '/' do
	slim :index
end

get '/play' do
	redirect '/login' unless session[:user]
	slim :play
end

get '/login' do
	slim :login
end

post '/login' do
	session[:user] = params['email'] || params['username'] || 'player'
	redirect '/play'
end

get '/register' do
	slim :register
end

post '/register' do
	session[:user] = params['email'] || params['username'] || 'player'
	redirect '/play'
end

get '/logout' do
	session.clear
	redirect '/'
end