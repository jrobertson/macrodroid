#!/usr/bin/env ruby

# file: macrohub.rb

require 'rowx'
require 'app-routes'
require 'rxfhelper'
require 'chronic_between'

# This file includes the following classes:
#
#      * SayAction
#      * WebhookAction
#      * MotionTrigger
#      * FrequencyConstraint
#      * TimeConstraint
#      * TriggersNlp    - selects the trigger to use
#      * ActionsNlp     - selects the action to use
#      * ConstraintsNlp - selects the constraint to use
#      * Macro    - contains the triggers, actions, and constraints
#      * MacroHub - contains the macros

class SayAction

  def initialize(s=nil, msg: s)
    @s  = msg
  end
  
  def invoke()
    "say: %s" % @s
  end
  
  def to_node()
    Rexle::Element.new(:action, attributes: {type: :say, text: @s})
  end        
  
  def to_rowx()
    "action: say '%s'" %  @s
  end    

end

class WebhookAction
  
  attr_accessor :url

  def initialize(idx=nil, id: idx, url: '127.0.0.1', env: {debug: false})
    
    @name, @url = id, url
    
  end
  
  def invoke()
    "webhook: %s" % @url
  end
  
  def to_node()
    Rexle::Element.new(:action, \
                        attributes: {type: :webhook, name: @name, url: @url})
  end    
  
  def to_rowx()
    s = "action: webhook %s" %  @name
    s += "\n  url: %s" % @url
  end

end

class MotionTrigger

  attr_reader :location, :type
  
  def initialize(location: nil)
    
    @location = location
    @type = :motion
    
  end
  
  def match?(detail)

    puts 'inside MotionTrigger#match' if $debug
    location = detail[:location]
    
    if location then
      
      @location.downcase == location.downcase
      
    else
      return false
    end
    
  end  
  
  def to_node()
    Rexle::Element.new(:trigger, attributes: {type: :motion, 
                                              location: @location})
  end
  
  def to_rowx()
    "trigger: Motion detected in the %s" %  @location
  end        

end

class FrequencyConstraint      
    
  def initialize(freqx, freq: freqx)
    
    @freq = freq
    @counter = 0
    @interval = 60
  end
  
  def counter()
    @counter
  end
  
  def increment()
    @counter += 1
  end
  
  def match?()
    @counter < @freq
  end
  
  def reset()
    puts 'resetting' if $debug
    @counter = 0
  end
  
  def to_node()
    Rexle::Element.new(:constraint, \
                        attributes: {type: :frequency, freq: @freq})      
  end
  
  def to_rowx()
    
    freq = case @freq
    when 1
      'Once'
    when 2
      'Twice'
    else
      "Maximum %s times" % @freq
    end
    
    "constraint: %s" %  freq

  end
  
end

class TimeConstraint    
  
  attr_accessor :time
  
  def initialize(timex=nil, times: timex, time: timex)
    
    @time = times || time
    
  end
  
  def match?(detail)
    
    if $debug then
      puts 'inside TimeConstraint#match?' 
      puts 'detail: ' + detail.inspect
      puts '@time: ' + @time.inspect
    end
    
    ChronicBetween.new(@time).within?(detail[:time])
    
  end  
      
  def to_node()
    Rexle::Element.new(:constraint, \
                        attributes: {type: :time, time: @time})      
  end    
  
  def to_rowx()            
    "constraint: %s" %  @time
  end    
      
end




class TriggersNlp
  include AppRoutes

  attr_reader :to_type

  def initialize()

    super()

    params = {}
    puts 'inside Trigger'
    puts 'params: ' + params.inspect
    triggers(params)

  end

  protected

  def triggers(params) 
    
    puts 'inside triggers'

    # e.g. Motion detected in the kitchen
    #
    get /motion detected in the (.*)/i do |location|
      puts 'motion detection trigger' if $debug
      [MotionTrigger, {location: location}]
    end

  end

  private

  alias find_trigger run_route

end

class ActionsNlp
  include AppRoutes

  def initialize()

    super()

    params = {}
    actions(params)

  end

  protected

  def actions(params) 

    puts 'inside actions'
    # e.g. Say 'Good morning'
    #
    get /say ['"]([^'"]+)/i do |s|
      puts 's: ' + s.inspect if $debug
      [SayAction, {msg: s} ]
    end
    
    # e.g. webhook entered_kitchen
    #
    get /webhook (.*)/i do |name|
      [WebhookAction, {id: name }]
    end      
    
    get /.*/ do
      puts 'action unknown' if $debug
      []
    end

  end

  private

  alias find_action run_route

end

class ConstraintsNlp
  include AppRoutes
  
  
  def initialize()
    
    super()
    
    params = {}
    constraints(params)
    
  end
  
  protected

  def constraints(params) 

    puts 'inside constraints' if $debug
    # e.g. Between 8am and 10am
    #
    get /^between (.*)/i do |s|
      [TimeConstraint,  {time: s}]
    end
    
    get /^on a (.*)/i do |s|
      [TimeConstraint, {time: s}]
    end
    
    get /^(after .*)/i do |s|
      [TimeConstraint, {time: s}]
    end      
    
    get /^(#{(Date::DAYNAMES + Date::ABBR_DAYNAMES).join('|')}$)/i do |s|
      [TimeConstraint, {time: s}]
    end    
    
    get /^once only|only once|once|one time|1 time$/i do |s|
      [FrequencyConstraint, {freq: 1}]
    end
    
    get /^twice only|only twice|twice|two times|2 times$/i do |s|
      [FrequencyConstraint, {freq: 2}]
    end
    
    get /^(Maximum|Max|Up to) ?three times|3 times$/i do |s|
      [FrequencyConstraint, {freq: 3}]
    end                    
    
    get /^(Maximum|Max|Up to) ?four times|4 times$/i do |s|
      [FrequencyConstraint, {freq: 4}]
    end                          

  end

  private

  alias find_constraint run_route    
end

class Macro

  attr_accessor :title, :env
  attr_reader :triggers, :actions, :constraints

  def initialize(node, title: '')

    @title = title

    @actions = []
    @triggers = []
    @constraints = []

  end

  def import_xml(node)
    
    @title = node.text('macro')

    if node.element('triggers') then
      
      triggers = {motion: MotionTrigger, timer: TimerTrigger}
      
      # level 2
      @triggers = node.xpath('triggers/*').map do |e| 

        puts 'e.name: ' + e.name.inspect if $debug
        triggers[e.name.to_sym].new(e.attributes.to_h)

      end

      actions = {say: SayAction, webhook: WebhookAction}
      
      @actions = node.xpath('actions/*').map do |e|
        
        actions[e.name.to_sym].new(e.attributes.to_h)
        
      end
      
      constraints = {time: TimeConstraint, frequency: FrequencyConstraint}

      @constraints = node.xpath('constraints/*').map do |e|

        puts 'before Constraints.new' if $debug
        constraints[e.name.to_sym].new(e.attributes.to_h)
        
      end

    else

      # Level 1
      
      tp = TriggersNlp.new      
      
      @triggers = node.xpath('trigger').map do |e|
        
        r = tp.find_trigger e.text
        
        if r then
          r[0].new(r[1])
        end
        
      end
      
      ap = ActionsNlp.new      
      
      @actions = node.xpath('action').map do |e|
        
        r = ap.find_action e.text
        
        if r then
          
          a = e.xpath('item/*')
          
          h = if a.any? then
            a.map {|node| [node.name.to_sym, node.text.to_s]}.to_h
          else
            {}
          end
          
          r[0].new(r[1].merge(h))
        end
        
      end
            
      cn = ConstraintsNlp.new      
      
      @constraints = node.xpath('constraint').map do |e|

        puts 'constraint e: ' + e.xml.inspect
        r = cn.find_constraint e.text
        
        puts 'r: ' + r.inspect if $debug
        
        if r then
          r[0].new(r[1])
        end
        
      end        

    end
  end
  
  def match?(triggerx, detail={} )
                
    if @triggers.any? {|x| x.type == triggerx and x.match?(detail) } then
      
      if $debug then
        puts 'checking constraints ...' 
        puts '@constraints: ' + @constraints.inspect
      end
      
      if @constraints.all? {|x| x.match?($env.merge(detail)) } then
      
        true
        
      else

        return false
        
      end
      
    end
    
  end
  
  def run()
    @actions.map(&:invoke)
  end  
  
  def to_node()
    
    if $debug then
      puts 'inside to_node' 
      puts '@title: ' + @title.inspect
    end
    
    e = Rexle::Element.new(:macro, attributes: {title: @title})
    
    e.add node_collection(:triggers, @triggers)
    e.add node_collection(:actions, @actions)
    e.add node_collection(:constraints, @constraints)
    
    return e
  end
  
  def to_rowx()
    
    s = "macro: %s\n\n" % @title
    s + [@triggers, @actions, @constraints]\
        .map {|x| x.collect(&:to_rowx).join("\n")}.join("\n")
  end
  
  private
  
  def node_collection(name, a)
    
    if $debug then
      puts 'inside node_collection name: ' + name.inspect
      puts 'a: ' + a.inspect
    end
    
    e = Rexle::Element.new(name)
    a.each do |x|
      
      puts 'x: ' + x.inspect if $debug
      e.add x.to_node

    end
    
    return e
    
  end
  
end

class MacroHub

  attr_reader :macros

  def initialize(obj=nil)
    
    if obj then
      
      s, _ = RXFHelper.read(obj)    
      
      if  s[0] == '<'
        import_xml(s)
      else        
        import_xml(RowX.new(s.gsub(/^#.*/,'')).to_xml)
      end
      
    else

      @macros = []

    end
  end

  def import_xml(raws)
   
    s = RXFHelper.read(raws).first
    puts 's: ' + s.inspect if $debug
    doc = Rexle.new(s)
    puts 'after doc' if $debug
    
    @macros = doc.root.xpath('item').map do |node|
          
      macro = Macro.new node.text('macro')
      macro.import_xml(node)
      macro
      
    end

  end

  def to_doc()
    
    doc = Rexle.new('<macros/>')      
    
    @macros.each do |macro|  
      puts 'macro: ' + macro.inspect if $debug
      doc.root.add macro.to_node
    end
    
    return doc
    
  end
  
  def to_rowx()
    
    s = ''
    s += "title: %s\n%s\n\n" % [@title, '-' * 50] if @title
    s += @macros.collect(&:to_rowx).join("\n\n#{'-'*50}\n\n")
    
  end
  
  alias to_s to_rowx
  
  def to_xml()
    to_doc.xml pretty: true
  end
  
end
