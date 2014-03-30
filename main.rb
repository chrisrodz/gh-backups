require 'sinatra'
require 'cloud_elements'
require 'json/ext'
require 'httparty'
require 'mongo'

include Mongo

# Create Connections to mongodb instance in mongohq
def get_connection
  return @db_connection if @db_connection
  db = URI.parse(ENV['MONGOHQ_URL'])
  db_name = db.path.gsub(/^\//, '')
  @db_connection = Mongo::Connection.new(db.host, db.port).db(db_name)
  @db_connection.authenticate(db.user, db.password) unless (db.user.nil? || db.user.nil?)
  @db_connection
end

# Helper function that copies a repo to the cloud
# Input: username, repo name, cloud_elements client.
def copy_to_cloud(username, repo, drive_client)
	# Get repo information fromo github api
	r = HTTParty.get("https://api.github.com/repos/#{username}/#{repo}", :headers => {'User-Agent' => 'yosoyelmejor'} )
	body = JSON.parse(r.body)
	# Get git_url from repo response body
	git_url = body["git_url"]
	# Clone the repo to local filesystem
	if system("git clone #{git_url}")
		# Zip the repo folder up
		if system("zip -r #{repo} #{repo}")
			# Upload the file using the CE client
			up_result = drive_client.uploadFiles({:path => "/#{repo}"}, ["#{repo}.zip"])
			puts up_result
			# Delete the zip file from local filesystem
			system("rm -rf #{repo}.zip")	
		end
		# Delete the repo folder from local filesystem
		system("rm -rf #{repo}")
		# Setup and return metadata on backup
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

# Sinatra global configs
configure do
	set :public_folder, 'public'
	# init mongodq connection
	conn = get_connection
	set :mongo_connection, conn
	set :mongo_db, conn.collection('hackpr')
end

# Basic route just serves html
get '/' do
	send_file File.join(settings.public_folder, 'index.html')
end

# Route to make backup given parameters
post '/copy' do
	drive_client = Element.new('document', ENV['CE_DRIVE_TOKEN'])
	username = params[:username]
	repo = params[:repo]
	data = copy_to_cloud(username, repo, drive_client)
	if data != false
		settings.mongo_db.insert(data)
		send_file File.join(settings.public_folder, 'success.html')
	else
		"Failure"
	end
end

# Github webhook route that backs up repos on push
post '/copy_from_push' do
	drive_client = Element.new('document', ENV['CE_DRIVE_TOKEN'])
	push = JSON.parse(params[:payload])	
	username = push["repository"]["owner"]["name"]
	repo = push["repository"]["name"]

	data = copy_to_cloud(username, repo, drive_client)
	if data != false
		settings.mongo_db.insert(data)
		send_file File.join(settings.public_folder, 'success.html')
	else
		"Failure!"
	end
end

# Route that runs a terminal command with the repo in the cloud
post '/gitcommand' do
	drive_client = Element.new('document', ENV['CE_DRIVE_TOKEN'])
	command = params[:command]
	repo = params[:repo]
	repo_file = drive_client.get( {:path => "/#{repo}/#{repo}.zip"})
	File.open("#{repo}.zip", "w") {|f| f.write(repo_file)}
	if system("unzip #{repo}.zip")
		command_output = `cd #{repo} && #{command}`
		`rm -rf #{repo}`
		`rm #{repo}.zip`
		command_output
	end
end

