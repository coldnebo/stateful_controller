module StatefulController
  class Railtie < Rails::Railtie
    railtie_name :stateful_controller

    rake_tasks do 
      load 'tasks/stateful_controller.rake'
    end
  end
end
