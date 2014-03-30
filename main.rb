require 'sinatra'
require 'cloud_elements'
require 'json/ext'
require 'httparty'
require 'mongo'

include Mongo

def get_connection
  return @db_connection if @db_connection
  db = URI.parse(ENV['MONGOHQ_URL'])
  db_name = db.path.gsub(/^\//, '')
  @db_connection = Mongo::Connection.new(db.host, db.port).db(db_name)
  @db_connection.authenticate(db.user, db.password) unless (db.user.nil? || db.user.nil?)
  @db_connection
end

def copy_to_cloud(username, repo)
	drive_client = Element.new('document', ENV['CE_DRIVE_TOKEN'])
	r = HTTParty.get("https://api.github.com/repos/#{username}/#{repo}", :headers => {'User-Agent' => 'yosoyelmejor'} )
	body = JSON.parse(r.body)
	git_url = body["git_url"]
	if system("git clone #{git_url}")
		if system("zip -r #{repo} #{repo}")
			up_result = drive_client.uploadFiles({:path => "/#{repo}"}, ["#{repo}.zip"])
			puts up_result
			system("rm -rf #{repo}.zip")	
		end
		system("rm -rf #{repo}")
		backup_data = {
			:username => username,
			:repo => repo,
			:git_url => git_url,
			:timestamp => Time.now.utc
		}
		return backup_data
	else
		return false
	end
end

configure do
	set :public_folder, 'public'
	conn = get_connection
	set :mongo_connection, conn
	set :mongo_db, conn.collection('hackpr')
end

get '/' do
	send_file File.join(settings.public_folder, 'index.html')
end

post '/copy' do
	username = params[:username]
	repo = params[:repo]
	data = copy_to_cloud(username, repo)
	if data != false
		settings.mongo_db.insert(data)
		"Success!"
	else
		"Failure"
	end
end

post '/copy_from_push' do
	push = JSON.parse(params[:payload])	
	username = push["repository"]["owner"]["name"]
	repo = push["repository"]["name"]

	data = copy_to_cloud(username, repo)
	if data != false
		settings.mongo_db.insert(data)
		"Success!"
	else
		"Failure!"
	end
end

post '/gitcommand' do
	command = params[:command]
	repo = params[:repo]
	drive_client = Element.new('document', ENV['CE_DRIVE_TOKEN'])
	repo_file = drive_client.get( {:path => "/#{repo}/#{repo}.zip"})
	File.open("#{repo}.zip", "w") {|f| f.write(repo_file)}
	if system("unzip #{repo}.zip")
		command_output = `cd #{repo} && #{command}`
		`rm -rf #{repo}`
		`rm #{repo}.zip`
		command_output
	end
end

get '/db' do
	if settings.mongo_db['hackpr'].insert({:otra => 'cosa'})
		"funciono"
	else
		"no funciono"
	end
end


