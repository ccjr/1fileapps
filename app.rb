require 'rubygems'
require 'sinatra'
require 'active_record'
require 'digest/md5'
require 'haml'

configure do
  SERVER = "http://localhost"
  APPS_DIRECTORY = File.join(ENV["HOME"], "code/1fileapps/apps")
end

configure :production do
  SERVER = "http://1fileapps.com"
end

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => "1fileapps.db")

begin
  ActiveRecord::Schema.define do
    create_table :applications do |t|
      t.string :name
      t.string :email
      t.string :access_key
      t.text :code
      t.integer :port, :default => 0
      t.timestamps
    end
  end
rescue ActiveRecord::StatementInvalid
end

class Application < ActiveRecord::Base
  before_create :generate_access_key, :sample_application
  after_create :run_application
  
  def permalink; "/application/#{self.access_key}"; end
  
  def generate_access_key
    self.access_key = Digest::MD5.new.update("-#{Time.now.to_s}-#{self.email}-").to_s
  end
  
  def sample_application
    self.code = <<-RUBY
require 'rubygems'
require 'sinatra'
get '/' do
  'Hello world!'
end
RUBY
  end
  
  def run_application
    # sets up a port for the application
    self.update_attribute :port, 4568
    # creates the folder and file with application
    FileUtils.mkdir_p self.directory
    # create a app.rb file in the application folder
    File.open(File.join(self.directory, 'app.rb'), 'w') { |file| file.write self.code } 
    # start the server
    system("ruby #{File.join(self.directory, 'app.rb')} -p #{self.port} &")
  end
  
  def path
    "#{SERVER}:#{self.port}"
  end
  
  # The directory from where the application will be executed
  def directory
    File.join(APPS_DIRECTORY, self.access_key)
  end
end

# Home page, obviously
get '/' do
  haml :index
end

# Creates a new application
post '/applications' do
  application = Application.create(:name  => params[:name],
                                   :email => params[:email])
  haml "Created #{application.name} application - #{application_link(application)}"
end

# Shows the application page with code and preview
get '/application/:id' do
  application = Application.find_by_access_key(params[:id])
  haml :show, :locals => { :application => application }
end

# Updates the application code
put '/application/:id' do
  application = Application.find_by_access_key(params[:id])
  application.update_attribute :code, params[:code]
  redirect application.permalink
end

helpers do
  # Generates a form to create a new application
  def application_form
    <<-HTML
    <form method="POST" action="/applications">
      <label for="name">Name</label><input type="text" id="name" name="name" value="">
      <label for="email">Email</label><input type="text" id="email" name="email" value="">
      <input type="submit" value="Save">
    </form>
    HTML
  end
  
  # Link to an aplication
  def application_link(application)
    "<a href=\"#{application.permalink}\">#{application.name}</a>"
  end
  
  # Uses gravatar for a specific email address
  def gravatar_path(email, options={})
    options[:size] ||= 30
    options[:default] ||= "http://github.com/images/gravatars/gravatar-30.png"
    hash = Digest::MD5.new.update(email)
    "http://www.gravatar.com/avatar/#{hash}?s=#{options[:size]}&d=#{options[:default]}"
  end
end

use_in_file_templates!

__END__

@@ layout
!!!
%html{html_attrs}
  %head
    %meta{'http-equiv' => 'Content-Type', :content => 'text/html; charset=UTF-8'}
    %title 1fileapps - Sinatra apps
    %script{:src => "http://ajax.googleapis.com/ajax/libs/jquery/1.2.6/jquery.min.js", :type => "text/javascript"}
  %body
    .header
      %h3 <a href="/">1 file apps</a>
    .main= yield
    .footer
      &copy; <a href="http://ccjr.name/" alt="ccjr.name">Cloves Carneiro Jr</a>.
      Source code on <a href="http://github.com/ccjr/1fileapps" title="1fileapps by Cloves Carneiro Jr (ccjr)">github</a>

@@ index
%h4 Create your application now
= application_form

@@ show
%h4= application.name
%h5
  by
  %img{:src => gravatar_path(application.email)}
%form{:action => application.permalink, :method => 'POST'}
  %input{:type => 'hidden', :name => '_method', :value => 'put'}
  %label{:for => 'code'}
  %textarea{:name => 'code', :id => 'code', :rows => 15, :cols => 60}= application.code
  %input{:type => 'submit', :value => 'Save'}
.preview
  == #{application.path}/
  %input{:type => 'text', :name => 'uri', :value => ''}
  %input{:type => 'submit', :value => 'Go'}
  %br/
  %iframe{:src => application.path, :style => 'border: solid black 1px;', :id => 'preview'}