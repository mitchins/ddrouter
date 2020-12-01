Pod::Spec.new do |spec|
  spec.name         = 'DDRouter'
  spec.version      = '2020.2.0'
  spec.license      = { :type => 'ISC' }
  spec.homepage     = 'https://hub.deloittedigital.com.au/stash/projects/DDMCD/repos/ddrouter/browse'
  spec.authors      = { 'Deloitte Digital' => 'wrigney@deloitte.com.au' }
  spec.summary      = 'Deloitte Digital simple networking framework.'
  spec.source       = { :git => 'https://qdigitalcode.visualstudio.com/BOQ%20Group%20Mobile%20Applications/_git/ios-lib-legacy-ddrouter', :tag => "#{spec.version}" }
  spec.source_files = 'DDRouter', 'DDRouter/**/*.swift'
  spec.framework    = 'RxSwift'
  spec.platform     = :ios, "11.0"
  spec.swift_version = '5'
  spec.dependency 'RxSwift', '~> 5.0'
  spec.static_framework = true
end
