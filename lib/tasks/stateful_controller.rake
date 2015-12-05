namespace :stateful_controller do 

  # poor-man's templating.  eventually, this could be some custom generators.
  desc 'dump parts of a simple template for the specified controller including StatefulController'
  task :template, [:controller] => :environment do |t, args|
    controller = args[:controller]
    valid = true
    valid &&= controller.present?
    valid &&= controller.constantize.ancestors.include?(StatefulController)
    
    fail "You must specify a controller that includes StatefulController" unless valid

    controller = controller.constantize

    f = StringIO.new
    f.puts "#{controller} template"
    actions = controller.aasm.events.map(&:name)
    views = controller.aasm.states.map(&:name)

    f.puts "\n--- routes.rb template ---\n"

    controller.to_s =~ /(.*)Controller/
    controller_route = $1.underscore

    f.puts "# special actions"
    f.puts %{get "#{controller_route}/start"}
    f.puts %{get "#{controller_route}/next"}
    f.puts "# actions (events)"
    actions.each {|action| 
      f.puts %{get "#{controller_route}/#{action}"}
    }

    f.puts "\n--- controller actions ---\n"

    f.puts "# actions (events)"
    actions.each {|action|
      f.puts "def #{action}"
      f.puts "end\n"
    }

    f.puts "\n--- views (states) ---\n"
    
    f.puts "app/views/#{controller_route}/"
    views.each {|view|
      f.puts "  #{view}.html.erb"
    }

    list = views.join(",")

    f.puts "\n\n# bash touch the files to create them:"
    f.puts "touch app/views/#{controller_route}/{#{list}}.html.erb\n\n"
  
    puts f.string
  
  end
end