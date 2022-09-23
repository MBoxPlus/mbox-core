
require 'yaml'
yaml = YAML.load_file('../manifest.yml')
name = yaml["NAME"]
name2 = name.sub('MBox', 'mbox').underscore
version = ENV["VERSION"] || yaml["VERSION"]

Pod::Spec.new do |spec|
  spec.name         = "#{name}"
  spec.version      = "#{version}"
  spec.summary      = "MBox GUI Core."
  spec.description  = <<-DESC
    The Core include many utils.
                   DESC

  spec.homepage     = "https://github.com/MBoxPlus/#{name2}"

  spec.license      = "MIT"
  spec.author       = { `git config user.name`.strip => `git config user.email`.strip }
  spec.source       = { :git => "git@github.com:MBoxPlus/#{name2}.git", :tag => "#{spec.version}" }

  spec.platform = :osx, '10.15'

  spec.source_files  = "#{name}/*.{h,m,swift}", "#{name}/**/*.{h,m,swift}"

  spec.user_target_xcconfig = {
    "FRAMEWORK_SEARCH_PATHS" => "\"$(DSTROOT)/MBoxCore/MBoxCore.framework/Versions/A/Frameworks\""
  }

  spec.dependency 'Alamofire', '~> 4.8.2'
  spec.dependency 'Yams', '~> 4.0'
  spec.dependency 'BlueSignals', '~> 1.0.20'
  spec.dependency 'Then', '~> 2.6.0'
  spec.dependency 'ObjCCommandLine'
  spec.dependency 'SwifterSwift/SwiftStdlib'
  spec.dependency 'SwifterSwift/Foundation'
end
