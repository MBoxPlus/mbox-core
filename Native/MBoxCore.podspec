
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

  spec.homepage     = "https://github.com/MBoxSpace/#{name2}"

  spec.license      = "MIT"
  spec.author       = { `git config user.name`.strip => `git config user.email`.strip }
  spec.source       = { :git => "git@github.com:MBoxSpace/#{name2}.git", :tag => "#{spec.version}" }

  spec.default_subspec = 'Core'
  spec.platform = :osx, '10.15'

  spec.subspec 'Core' do |ss|
    ss.source_files  = "#{name}/*.{h,m,swift}", "#{name}/**/*.{h,m,swift}"

    ss.user_target_xcconfig = {
      "SKIP_INSTALL" => "NO",
      "INSTALL_PATH" => "$(PROJECT_NAME)",
      "DEPLOYMENT_LOCATION" => "YES",
      "DEPLOYMENT_POSTPROCESSING" => "YES",
      "DSTROOT" => "$(PODS_PODFILE_DIR_PATH)/build",
      "STRIP_INSTALLED_PRODUCT" => "NO",
      "OTHER_SWIFT_FLAGS" => "-Xfrontend -enable-dynamic-replacement-chaining",
      "SWIFT_COMPILATION_MODE" => "singlefile",

      "FRAMEWORK_SEARCH_PATHS" => "\"$(DSTROOT)/MBoxCore/MBoxCore.framework/Versions/A/Frameworks\""
    }
    # ss.resources = "Resources/*.png"

    ss.preserve_paths = ['Native/repackage-dylibs.rb', 'Native/repackage-dylibs.input.xcfilelist', 'Native/repackage-dylibs.output.xcfilelist']

    # spec.frameworks = "SomeFramework", "AnotherFramework"
    # spec.libraries = "iconv", "xml2"

    ss.dependency 'Alamofire', '~> 4.8.2'
    ss.dependency 'Yams', '~> 4.0'
    ss.dependency 'CocoaLumberjack/Swift'
    ss.dependency 'BlueSignals', '~> 1.0.20'
    ss.dependency 'Then', '~> 2.6.0'
    ss.dependency 'ObjCCommandLine'
  end

  spec.app_spec do |app|
    app.source_files = 'MBoxCLI/*.{swift}'
  end
end
