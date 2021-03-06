class AbuseReport < ActiveRecord::Base
  validates_presence_of :comment
  validates_email_veracity_of :email, :message => t('invalid_email', :default => 'appears to be invalid. Please use a different address or leave blank.'), :allow_blank => true
  
  app_url_regex = Regexp.new('^' + ArchiveConfig.APP_URL, true)
  validates_format_of :url, :with => app_url_regex, :message => t('invalid_url', :default => 'does not appear to be on this site.')
end
