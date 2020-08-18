Gem::Specification.new do |s|
  s.name = 'macrohub'
  s.version = '0.1.0'
  s.summary = 'Experimental gem to create macros with the aim to simulate home automation.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/macrohub.rb']
  s.add_runtime_dependency('rowx', '~> 0.7', '>=0.7.0')
  s.add_runtime_dependency('app-routes', '~> 0.1', '>=0.1.19')
  s.add_runtime_dependency('rxfhelper', '~> 1.0', '>=1.0.0')
  s.add_runtime_dependency('chronic_between', '~> 0.4', '>=0.4.0')  
  s.signing_key = '../privatekeys/macrohub.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@jamesrobertson.eu'
  s.homepage = 'https://github.com/jrobertson/macrohub'
end
