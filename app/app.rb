require 'sinatra/base'
require 'json'
require_relative './models/user'
require_relative './models/booking'
require_relative './models/space'
require 'sinatra/flash'
require_relative 'DataMapperSetup'

class MakersBnB < Sinatra::Base
  data_mapper_setup
  enable :sessions
  set :session_secret, 'super secret'
  register Sinatra::Flash

  helpers do
    def current_user
      @current_user ||= User.get(session[:user_id])
    end
  end

  get '/spaces/my-spaces/new' do
    erb(:newspace)
  end

  get '/users/new' do
    erb(:signup)
  end

  post '/users' do
    user = User.create(email: params[:email],
            username: params[:username],
            first_name: params[:first_name],
            last_name: params[:last_name],
            password: params[:password],
            password_confirm: params[:password_confirm])
    if user.save
      session[:user_id] = user.id
      redirect '/spaces'
    else
      flash.next[:errors] = user.errors.full_messages
      redirect('/users/new')
    end
  end

  get '/spaces' do
    @user = current_user
    @spaces = Space.all
    erb(:spaces)
  end

  get '/spaces/list/:filter' do
    content_type :json

    Space.all(create_filter_for(params[:filter])).map {|space|
      {
        name: space.name,
        description: space.description,
        price: format('%.2f', space.price),
        user: space.user.username,
        id: space.id
        }
    }.to_json
  end

  def create_filter_for(criterion)

    case criterion
      when "lowprice" then {:price.lte => 10}
      when "midprice" then {:price.gt => 10, :price.lte => 20}
      when "highprice" then {:price.gt => 20}
    end

  end

  post '/spaces' do
    space = Space.create(name: params[:name],
      description: params[:description],
      price: params[:price],
      user: current_user)
    redirect "/spaces/#{space.id}"
  end

  post '/login' do
    user = User.authenticate(params[:username], params[:password])
    if user
      session[:user_id] = user.id
      redirect '/spaces'
    else
      flash.next[:errors] = ['The email or password is incorrect']
      redirect '/users/new'
    end
  end

  post '/bookings/new' do
    start_date = Date.parse(params['from'])
    end_date = Date.parse(params['to'])

    space = Space.first(id: params[:space])
    if space.is_available?(start_date..end_date)
      Booking.create(start_date: start_date,
                     end_date: end_date,
                     confirmed: false,
                     user: current_user,
                     space: space)
      redirect '/bookings'
    else
      flash.keep[:notice] = 'This space is not available on those dates!'
    end

  end

  post '/bookings/confirm' do
    booking = Booking.first(id: params[:booking_id])
    booking.confirmed = true
    booking.save
  end

  get '/bookings' do
    @bookings = Booking.all(user: current_user)
    erb :bookings
  end

  post '/logout' do
    session[:user_id] = nil
    flash.keep[:notice] = 'goodbye!'
    redirect '/spaces'
  end

  get '/spaces/my-spaces' do
    @spaces = Space.all(user: current_user)
    @mine = true
    erb :spaces
  end

  get '/spaces/:id' do
    @space = Space.first(id: params[:id])
    erb :viewspace
  end

end
