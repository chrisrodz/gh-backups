require 'sinatra'
require 'cloud_elements'
require 'json'
require 'httparty'


before do
	content_type 'application/json'
end

get '/' do
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