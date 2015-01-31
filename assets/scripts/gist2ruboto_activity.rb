require 'ruboto'
require 'open-uri'
require 'openssl' 
module OpenSSL 
  module SSL remove_const :VERIFY_PEER 
  end
end
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

ruboto_import_widgets :TextView, :LinearLayout, :Button

$activity.handle_create do |bundle|
  setTitle 'gist2ruboto'

  setup_content do
    #一例。実行されるコードを外から取っているので状況次第で大変危険
    gist_id = "22109"
    file_name = "helloworld.rb"

    eval open("https://raw.github.com/gist/#{gist_id}/#{file_name}").read
  end
end
