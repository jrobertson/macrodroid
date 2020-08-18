# Introducing the MacroHub gem

    require 'macrohub'
    require 'projectsimulator'

    s=<<EOF
    macro: Morning welcoming announcement

    trigger: Motion detected in the kitchen
    action: Say 'Good morning'
    action: webhook entered_kitchen
      url: http://someurl/?id=kitchen
    constraint: between 7am and 7:30am

    macro: Good night announcement
    trigger: Motion detected in the kitchen
    action: Say 'Good night'
    constraint: After 10pm
    EOF


    mh = MacroHub.new(s)

    ps = ProjectSimulator::Controller.new(mh)

    $env = {time: Time.parse('7:15am')}
    $debug = true
    ps.trigger :motion, location: 'kitchen'
    #=> ["say: Good morning", "webhook: http://someurl/?id=kitchen"] 

    $env = {time: Time.parse('8:05pm')}
    ps.trigger :motion, location: 'kitchen'
    #=> []

    $env = {time: Time.parse('10:05pm')}
    ps.trigger :motion, location: 'kitchen'
    #=> ["say: Good night"] 


In the above example a couple of macros are created in plain text. The 1st macro is triggered when there is motion detected in the kitchen between 7am and 7:30am. If successful it returns the message 'say: Good morning'.

The 2nd macro is triggered when there is motion detected in the kitchen after 10pm. If successful it returns the message 'say: Good night'.

The ProjectSimulator facilitates the execution of triggers, validation of constraints and invocation of actions in cooperation with the MacroHub gem.

## Resources

* macrohub https://rubygems.org/gems/macrohub

macro macrohub gem simulator project projectsimulator macrodroid
