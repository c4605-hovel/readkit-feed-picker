require 'rubygems'
require 'bundler/setup'
require 'erb'
require 'active_record'
require 'inoreader-api'

#ActiveRecord::Base.logger = Logger.new(STDERR)
#ActiveRecord::Base.colorize_logging = true

ActiveRecord::Base.establish_connection(
  :adapter => "sqlite3",
  :database  => "ReadKit.storedata"
)

class Feedfolder < ActiveRecord::Base
end

class Item < ActiveRecord::Base
  self.table_name = 'ZFOLDER'

  alias_attribute :id              , :Z_PK
  alias_attribute :account         , :ZACCOUNT
  alias_attribute :is_expanded     , :ZIS_EXPANDED
  alias_attribute :date_updated    , :ZDATE_UPDATED
  alias_attribute :folder_id       , :ZFOLDER_ID
  alias_attribute :title           , :ZTITLE
  alias_attribute :feed_link       , :ZFEED_LINK
  alias_attribute :predicate       , :ZPREDICATE
end

class Folder < Item
  default_scope { where feed_link: nil }

  def to_h
    as_json only: [], methods: [:id, :title]
  end
end

class Feed < Item
  def to_h
    as_json only: [], methods: [:id, :title, :feed_link]
  end
end

folders = []
Folder.find_each do |folder|
  data = folder.to_h
  data['feeds'] = Feed.find(Feedfolder.where(folder_id: folder.id).map(&:feed_id)).map(&:to_h)
  folders << data
end
folders = folders.reject { |folder| folder['feeds'].empty? }


inoreader = InoreaderApi::Api.new(:username => '', :password => '')
folders.each do |folder|
  folder['feeds'].each do |feed|
    begin
      subscription = inoreader.add_subscription feed['feed_link']
      if inoreader.subscribe(subscription.streamId, folder['title']) != 'OK'
        puts "feed #{feed} in #{folder['title']} add failed"
      end
    rescue
      puts "feed #{feed} in #{folder['title']} add failed"
    end
  end
end

=begin
template = <<-ERB
<%- folders.each do |folder| -%>
  <%- next if folder['feeds'].empty? -%>

## <%= folder['title'] %>

  <%- folder['feeds'].each do |feed| -%>
* [<%= feed['title'] %>](<%= feed['feed_link'] %>) <%= feed['feed_link'] %>
  <%- end -%>

<%- end -%>
ERB
puts ERB.new(template, nil, '-').result binding
=end
