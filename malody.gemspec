(File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__).tap do |file|
  if file.start_with?(File.join(Gem.dir,'specifications')) then
    require 'malody/version'
  else
    # No gemfile for local symlink trick
    lib = File.expand_path("../lib", file)
    lib.tap do |here| $:.push here unless $:.include?(here) end
    ver_file = File.join(lib, 'malody', 'version.rb')
    eval(File.read(ver_file),nil,ver_file,__LINE__+1)
    $" << ver_file
  end
end unless defined?(Malody::VERSION)


Gem::Specification.new do |s|
  fn = (File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__)
  is_local = !fn.start_with?(File.join(Gem.dir,'specifications'))
  
  s.name          = "malody"
  s.version       = Malody::VERSION
  s.authors       = ["Rei Hakurei"]
  s.email         = ["reimu_after_marisa@yahoo.com"]

  s.summary       = %q{Basic Malody library}
  s.description   = %q{Defining Malody basic sense of utility.}
  s.homepage      = "https://github.com/ReiFan49/ruby-malody"
  s.license       = "MIT"
  s.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  # s.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  s.metadata["homepage_uri"] = s.homepage
  s.metadata["source_code_uri"] = s.homepage
  # s.metadata["changelog_uri"] = "im moody."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  if is_local then
    s.files = Dir["test/**/*.rb", "MIT-LICENSE", "Rakefile", "*.md"]
  else
    s.files         = Dir.chdir(File.expand_path(__dir__)) do
      `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
    end
  end
  s.bindir        = "exe"
  s.executables   = s.files.grep(%r{^exe/}) { |f| File.basename(f) }
  s.require_paths = ["lib"]
  
  s.add_development_dependency 'rubocop', '~> 1.17'
  s.add_development_dependency "rake", ">= 12.0"
  s.add_development_dependency "minitest", "~> 5.0"
end
