require 'rubygems'
require 'sinatra'
require 'active_record'
require 'digest/md5'
require 'haml'

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => "1fileapps.db")

begin
  ActiveRecord::Schema.define do
    create_table :applications do |t|
      t.string :name
      t.string :email
      t.string :access_key
      t.text :code
      t.timestamps
    end
  end
rescue ActiveRecord::StatementInvalid
end

class Application < ActiveRecord::Base
  before_create :generate_access_key, :sample_application
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
end

get '/' do
  haml :index
end

post '/applications' do
  application = Application.create(:name  => params[:name],
                                   :email => params[:email])
  haml "Created #{application.name} application - #{application_link(application)}"
end

get '/application/:id' do
  application = Application.find_by_access_key(params[:id])
  haml :show, :locals => { :application => application }
end

put '/application/:id' do
  application = Application.find_by_access_key(params[:id])
  application.update_attribute :code, params[:code]
  redirect application.permalink
end

helpers do
  def application_form
    <<-HTML
    <form method="POST" action="/applications">
      <label for="name">Name</label><input type="text" id="name" name="name" value="">
      <label for="email">Email</label><input type="text" id="email" name="email" value="">
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

use_in_file_templates!

__END__

@@ layout
!!!
%html{html_attrs}
  %head
    %meta{'http-equiv' => 'Content-Type', :content => 'text/html; charset=UTF-8'}
    %title 1fileapps - Sinatra apps
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