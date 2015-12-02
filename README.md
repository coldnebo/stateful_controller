# StatefulController

StatefulController combines the idea of a Rails controller with a [state machine](https://en.wikipedia.org/wiki/Finite-state_machine) 
that controls navigation through a sequence of views and actions (i.e. a user 'flow').

StatefulController uses the [aasm gem](https://github.com/aasm/aasm) to implement the state machine part of things, so we use its
terminology to define the state machine. A state machine can be thought of as a graph of states (vertices) connected by event transitions (edges). 
A StatefulController treats states as Rails' views and events as Rails' actions.  A StatefulController is a Rails controller, so you can call actions directly. But, more interestingly, you can call two special actions: *start* and *next*.

## Example

Start with a simple controller in your Rails app:

```ruby
class ExampleController < ApplicationController
  include StatefulController

  class ExampleState < StatefulController::State
  end

  # states are 'views' and events are 'actions'
  aasm do 
    state :sleeping, initial: true
    state :running
    state :cleaning
    
    event :run do
      transitions from: :sleeping, to: :running
    end

    event :clean do 
      transitions from: :running, to: :cleaning
    end

    event :sleep do 
      transitions from: [:running, :cleaning], to: :sleeping
    end
  end

  # controller actions here: (same names as events)
  # do anything here that you need to do for your views, i.e. modify state
  # load auxillary objects, etc, just like regular Rails controller actions,
  # the corresponding view (state) will be automatically rendered for you.

  def run
  end

  def clean
  end

  def sleep
  end

  private

  def load_state
    session[:state] || ExampleState.new
  end

  def save_state(s)
    session[:state] = s
  end

end
```

Add some views:
(note that views are not named the same as your actions, but should match your state names!)

```
app/
  views/
    example/
      cleaning.html.erb
      running.html.erb
      sleeping.html.erb
```


Add some routes:

```ruby
  
  # don't forget to add the two special routes!
  get "example/start"
  get "example/next"

  # and your defined routes:
  get "example/run"
  get "example/clean"
  get "example/sleep"
```


### What does that get us?

Try the following:

```
http://localhost:3000/example/start   # resets ExampleState, sets current_state to the aasm intial (:sleeping) and shows sleeping.html.erb
http://localhost:3000/example/next    # checks the permitted events from :sleeping, fires it (:run) and shows running.html.erb
http://localhost:3000/example/next    # checks the permitted events from :running, fires it (:clean) and shows cleaning.html.erb
http://localhost:3000/example/next    # checks the permitted events from :cleaning, fires it (:sleep) and shows sleeping.html.erb

```

So, the special *next* action dispatches whatever the next permitted action is (according to the state machine definition above).

What if we don't follow the rules?

```
http://localhost:3000/example/start   # resets ExampleState, sets current_state to the aasm intial (:sleeping) and shows sleeping.html.erb
http://localhost:3000/example/clean   # tries to send event :clean, but raises: 
                                        AASM::InvalidTransition in ExampleController#clean
                                        Event 'clean' cannot transition from 'sleeping'
```

### Summary 

You can define the legal transitions in your user flow in the state machine and StatefulController will enforce that flow for you, which 
greatly simplifies the Rails controller logic for complex flows.  See the source for the dummy Rails application which has more detail and
interactive examples.



## Installation

Add this line to your application's Gemfile:

```ruby
gem 'stateful_controller'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install stateful_controller

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/coldnebo/stateful_controller. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

