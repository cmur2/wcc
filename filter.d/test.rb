#!/usr/bin/ruby -KuW0

require 'wcc'

WCC::Filter.add 'test' do |data|
	true
end
