require 'erubi'
require './command'

set :erb, :escape_html => true

if development?
  require 'sinatra/reloader'
  also_reload './command.rb'
end

# Define a route at the root '/' of the app.
get '/' do
  @command = Command.new
  @quotas, @error = @command.exec("/sfs/ceph/standard/rc-students/ood/ResourceManager/local_hdquota")
  # @allocations, @error = @command.exec("/sfs/ceph/standard/rc-students/ood/ResourceManager/local_allocations")

  # Render the view
  erb :index
end
