require 'rubygems'
require 'sinatra'
require 'active_record'
require 'digest/md5'
require 'haml'

configure do
  SERVER = "http://localhost"
  STARTING_PORT = 5000
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
  after_save :generate_file
  
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
  
  # Generates the file that will be used to run the application
  def generate_file
    # creates the folder and file with application
    FileUtils.mkdir_p self.directory
    # create a app.rb file in the application folder
    File.open(File.join(self.directory, 'app.rb'), 'w') { |file| file.write self.code } 
  end 
  
  # Run the application 
  def run_application
    if self.port == 0
      # sets up a port for the application
      self.update_attribute :port, Application.assign_port_mumber
      # start the server
      system("ruby #{File.join(self.directory, 'app.rb')} -p #{self.port} &")
    end
  end
  
  def path
    "#{SERVER}:#{self.port}"
  end
  
  # The directory from where the application will be executed
  def directory
    File.join(APPS_DIRECTORY, self.access_key)
  end
  
  # Assigns a port number for a new application
  def self.assign_port_mumber
    next_port = Application.maximum(:port) + 1
    (next_port > STARTING_PORT) ? next_port : STARTING_PORT
  end
end

# Home page, obviously
get '/' do
  applications = Application.all :conditions => {:email => params[:email]}
  haml :index, :locals => {:applications => applications}
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
    <form method="post" action="/applications">
      <label for="name">Application name</label><input type="text" id="name" name="name" class="text" value=""/>
      <label for="email">Email</label><input type="text" id="email" name="email" class="text"  value=""/>
      <br/>
      <input type="submit" value="Save"/>
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
    %style{:type => "text/css", :media => "screen"}
      :sass
        *
          :margin 0
          :padding 0
        body
          :font-size 12px
          :letter-spacing 0.05em
          :line-height 1.3
          :background #FFF
        #header
          :padding 10px 0
          :width 926px
          :margin 0 auto
          :border-bottom 1px solid #ccc
          :text-align center
        form
          :padding 10px
        input.text, textarea, select
          :width 200px
        label
          :display block
          :font-size 11px
          :width 150px
          :color #666
      
        h2, h3
          :border-bottom 1px solid #ccc
          :padding 6px
          :margin-bottom 13px
        .info
          :float right
          img
            :vertical-align middle
        #main
          :width 900px
          :min-height 500px
          :margin 0 auto
          :margin-top 10px
          :overflow hidden
          
          li
            :font-size 14px
            :padding-left 10px
            
          
          .left
            :padding-left 24px
            :width 47%
            :float left

          .right
            :padding-left 20px
            :padding-right 20px
            :border-left 1px solid #ccc            
            :width 45%
            :float right
            iframe
              :margin 10px
          
        #footer
          :width 926px
          :margin 0 auto
          :padding 10px 0px
          :letter-spacing 0.1em
          :border-top 1px solid #ccc
          :text-align center
  %body
    #header
      %h1 <a href="/">1 file apps</a>
    #main= yield
    #footer
      &copy; <a href="http://ccjr.name/" title="ccjr.name">Cloves Carneiro Jr</a>.
      Source code on <a href="http://github.com/ccjr/1fileapps" title="1fileapps by Cloves Carneiro Jr (ccjr)">github</a>

@@ index
%h2 Create your application now
= application_form
%h3 Your apps
%ul
  - for application in applications
    %li= application_link(application)

@@ show
.info
  by
  %img{:src => gravatar_path(application.email)}
%h2
  = application.name
.left
  %form{:action => application.permalink, :method => 'post'}
    %input{:type => 'hidden', :name => '_method', :value => 'put'}
    %label{:for => 'code'} Code
    %textarea{:name => 'code', :id => 'code', :rows => 15, :cols => 50}= application.code
    %input{:type => 'submit', :value => 'Save'}
.right
  .preview_area
    == #{application.path}/
    %input{:type => 'text', :name => 'uri', :id => 'uri', :class => 'text', :value => ''}
    %input{:type => 'button', :value => 'Go', :onclick => "$('#preview')[0].src = '#{application.path}/' +  $('#uri')[0].value"}
    %br/
    %iframe{:src => application.path, :style => 'border: solid black 1px;', :id => 'preview'}