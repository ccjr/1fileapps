require 'rubygems'
require 'sinatra'
require 'active_record'
require 'digest/md5'

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => "1fileapps.db")

begin
  ActiveRecord::Schema.define do
    create_table :applications do |t|
      t.string :name
      t.string :email
      t.string :access_key
      t.timestamps
    end
  end
rescue ActiveRecord::StatementInvalid
end

class Application < ActiveRecord::Base
  before_create :generate_access_key
  def generate_access_key
    self.access_key = Digest::MD5.new.update("-#{Time.now.to_s}-#{self.email}-").to_s
  end
  def permalink; "/application/#{self.access_key}"; end
end

get '/' do
  res = "Hello world!"
  res += application_form
  erb res
end

post '/applications' do
  application = Application.create(:name  => params[:name],
                                   :email => params[:email])
  erb "Created #{application.name} application - #{application_link(application)}"
end

get '/application/:id' do
  application = Application.find_by_access_key(params[:id])
  res = "Application - #{application.name} from "
  res += "<img src=\"#{gravatar_path(application.email)}\"/>"
  erb res
end

layout do
  <<-HTML
  <html>
  <head>
    <meta http-equiv="Content-type" content="text/html; charset=utf-8">
    <title>1fileapps - Sinatra apps</title>
  </head>
  <body>
    <div id="header"><h3><a href="/">1 file apps</a></h3></div>
    <div id="main">
      <%= yield %>
    </div>
    <div id="footer">&copy; <a href="http://ccjr.name/" alt="ccjr.name">Cloves Carneiro Jr</a>. Source code on <a href="http://github.com/ccjr/1fileapps" title="1fileapps by Cloves Carneiro Jr (ccjr)">github</a></div>
  </body>
  </html>
  HTML
end

helpers do
  def application_form
    <<-HTML
    <form method="POST" action="/applications">
      <label for="name">Name</label><input type="text" name="name" value="">
      <label for="email">Email</label><input type="text" name="email" value="">
      <input type="submit" value="Save">
    </form>
    HTML
  end
  
  def application_link(application)
    "<a href=\"#{application.permalink}\">#{application.name}</a>"
  end
  
  def gravatar_path(email, options={})
    options[:size] ||= 50
    hash = Digest::MD5.new.update(email)
    "http://www.gravatar.com/avatar/#{hash}?s=#{options[:size]}"
  end
end