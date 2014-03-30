require 'sinatra'
require 'cloud_elements'
require 'json'
require 'httparty'
require 'haml'


set :public_folder, 'public'

get '/' do
	send_file File.join(settings.public_folder, 'index.html')
end

post '/' do
	drive_client = Element.new('document', ENV['CE_DRIVE_TOKEN'])
	username = 'chrisrodz'
	repo = 'Snipps'
	r = HTTParty.get('https://api.github.com/repos/chrisrodz/Snipps', :headers => {'User-Agent' => 'yosoyelmejor'} )
	body = JSON.parse(r.body)
	git_url = body["git_url"]
	if system("git clone #{git_url}")
		if system("zip -r #{repo} #{repo}")
			up_result = drive_client.uploadFiles({:path => "/#{repo}"}, ["#{repo}.zip"])
			puts up_result
			system("rm -rf #{repo}.zip")	
		end
		system("rm -rf #{repo}")
		"Uploaded repo"
	else
		"Not cloned repo"
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




