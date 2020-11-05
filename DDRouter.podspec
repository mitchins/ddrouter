Pod::Spec.new do |spec|
  spec.name         = 'DDRouter'
  spec.version      = '0.4.0'
  spec.license      = { :type => 'ISC' }
  spec.homepage     = 'https://hub.deloittedigital.com.au/stash/projects/DDMCD/repos/ddrouter/browse'
  spec.authors      = { 'Deloitte Digital' => 'wrigney@deloitte.com.au' }
  spec.summary      = 'Deloitte Digital simple networking framework.'
  spec.source       = { :git => 'ssh://git@dvcs.deloittedigital.com.au:22/ddmcd/ddrouter.git', :tag => 'v0.3.0' }
  spec.source_files = 'DDRouter', 'DDRouter/**/*.swift'
  spec.framework    = 'RxSwift'
  spec.platform     = :ios, "11.0"
  spec.swift_version = '5'
  spec.dependency 'RxSwift', '~> 5.0'
  spec.static_framework = true
end
