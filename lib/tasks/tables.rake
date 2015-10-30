# Rakefile to create tables for execution manage

namespace :tables do
  task :create_list_available => [
    :finished,
    :live,
    :available
  ]
  
  task :create_list_finished do
  end
  
  task :create_list_live do
  end
end