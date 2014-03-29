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
		Dir.glob("#{repo}/**/*") do |item|
			if not File.directory?(item)
				*before, after = item.split("/")
				path = before.join("/")
				up_result = drive_client.uploadFiles({:path => "/#{path}"}, [item])
				puts up_result
			end
		end
		Dir.glob("#{repo}/.git/*") do |item|
			if not File.directory?(item)
				*before, after = item.split("/")
				path = before.join("/")
				up_result = drive_client.uploadFiles({:path => "/#{path}"}, [item])
				puts up_result
			end
		end
		system("rm -rf #{repo}")
		"Uploaded repo"
	else
		"Not cloned repo"
	end
end